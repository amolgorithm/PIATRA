"""
Two meals with the same calories and macros can leave you feeling very
different two hours later, one keeps you steady through a study session,
the other gives you a 2pm crash. This models that as a pair of coupled
first-order ODEs, same family as exponential growth/decay and Newton's law
of cooling, just two of them linked together:

    dG/dt = -k1*G + M(t)      glucose: decays over time, rises from the meal
    dI/dt =  k2*G - k3*I       insulin: rises with glucose, decays over time

M(t) is the meal's glucose delivery rate, modeled as a Gaussian bump rather
than derived from first principles, a reasonable choice justified by being
easy to integrate and shape with two knobs (when it peaks, how spread out
it is). Solved numerically with scipy's RK45, not analytically, which
sidesteps the eigenvalue-based matrix methods normally used to solve linear
ODE systems by hand.

IMPORTANT: G and I are relative, unitless response curves, not real blood
glucose in mg/dL. This is a simplified, comparative model (this meal vs.
that meal), built on illustrative rate constants and a nutrition-derived
glycemic load estimate, not a clinical or diagnostic tool. It should never
be read as medical advice.

Glycemic load is estimated from the recipe's aggregate macros (already
available everywhere else in this app via NutrientMapper) rather than
requiring an exact per-ingredient glycemic-index lookup, which would hit
the same fragile exact-name-matching problem Feature 3's substitution
engine already has. Available carbs (carbs minus fiber, since fiber isn't
digested) scaled by an estimated effective GI based on how much of those
carbs are sugar vs starch. Protein and fat slow gastric emptying in
reality, so they push the modeled peak later and spread it out, that
relationship is a simple linear heuristic here, not measured.
"""

import numpy as np
from scipy.integrate import solve_ivp

from app.models.energy import EnergyCurveRequest, EnergyCurveResponse

# illustrative, population-average-ish rate constants for a comparative
# model, not measured, not patient-specific
K1_GLUCOSE_CLEARANCE = 0.045
K2_INSULIN_RESPONSE = 0.02
K3_INSULIN_DECAY = 0.05

# rough dividing line for the "possible energy dip" flag, tuned by
# comparing a high-glycemic-load test meal (~-0.93 units/min) against a
# high-fiber/protein/fat one (~-0.22 units/min), sits between them
CRASH_THRESHOLD_PER_MINUTE = -0.5


def _estimate_glycemic_load(nutrients: dict) -> tuple[float, float, float]:
    carbs = nutrients.get("carbs_g", 0.0)
    fiber = nutrients.get("fiber_g", 0.0)
    sugar = nutrients.get("sugar_g", 0.0)
    protein = nutrients.get("protein_g", 0.0)
    fat = nutrients.get("fat_g", 0.0)

    available_carbs = max(carbs - fiber, 0.0)
    if available_carbs <= 0:
        return 0.0, 0.0, 0.0

    sugar_fraction = min(sugar / available_carbs, 1.0)
    effective_gi = 40 + 40 * sugar_fraction  # rough 40-80 range, not a real GI lookup

    glycemic_load = available_carbs * (effective_gi / 100.0)
    # protein/fat slow digestion, capped so a single huge number can't
    # push the curve unrealistically far out
    delay_factor = min((protein + fat) / 40.0, 1.5)

    return glycemic_load, effective_gi, delay_factor


def _glucose_input_rate(t: float, glycemic_load: float, delay_factor: float) -> float:
    peak_time = 35 + 25 * delay_factor
    width = 20 + 15 * delay_factor
    amplitude = glycemic_load * 0.06
    return amplitude * np.exp(-((t - peak_time) ** 2) / (2 * width ** 2))


def compute_energy_curve(req: EnergyCurveRequest) -> EnergyCurveResponse:
    glycemic_load, effective_gi, delay_factor = _estimate_glycemic_load(req.nutrients)

    def odes(t, y):
        G, I = y
        M = _glucose_input_rate(t, glycemic_load, delay_factor)
        return [-K1_GLUCOSE_CLEARANCE * G + M, K2_INSULIN_RESPONSE * G - K3_INSULIN_DECAY * I]

    t_eval = np.arange(0, req.duration_minutes + 1, 5, dtype=float)
    sol = solve_ivp(odes, [0, req.duration_minutes], [0.0, 0.0], t_eval=t_eval, method="RK45")

    glucose = sol.y[0]
    insulin = sol.y[1]
    times = sol.t

    peak_idx = int(np.argmax(glucose))
    peak_glucose = float(glucose[peak_idx])
    peak_time = float(times[peak_idx])

    window_start = max(peak_idx, 12)  # don't look for the "crash" before ~60 min in
    window = glucose[window_start:]
    if len(window) > 1:
        slopes = np.diff(window) / 5.0
        steepest_drop = float(np.min(slopes))
    else:
        steepest_drop = 0.0

    return EnergyCurveResponse(
        times_minutes=[round(float(t), 1) for t in times],
        glucose=[round(float(g), 3) for g in glucose],
        insulin=[round(float(i), 3) for i in insulin],
        glycemic_load_estimate=round(glycemic_load, 1),
        peak_glucose=round(peak_glucose, 2),
        peak_time_minutes=peak_time,
        steepest_drop_per_minute=round(steepest_drop, 3),
        possible_energy_dip=steepest_drop < CRASH_THRESHOLD_PER_MINUTE,
        note="Simplified comparative model, not a clinical or diagnostic tool. Units are relative, not real blood glucose.",
    )
