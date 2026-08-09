"""
Solves the weekly meal plan as an actual constrained optimization problem
instead of a weighted score. Two modes:

lp: hard nutrient floors/ceilings, minimize cost. Can come back infeasible,
which is honest, some weeks a tight budget just can't hit every target.

qp: same setup but nutrient minimums become a squared penalty instead of a
wall, so it always returns a plan, just tells you what it missed.
"""

import numpy as np
from scipy.optimize import linprog

from app.models.optimization import OptimizeRequest, PlanItem, OptimizeResponse


def _build_matrices(req: OptimizeRequest):
    """Turns the candidate list into the vectors/matrix the solver needs."""
    candidates = req.candidates
    n = len(candidates)

    nutrient_names = sorted(
        set(req.nutrient_targets.minimums.keys()) | set(req.nutrient_targets.maximums.keys())
    )

    cost = np.array([c.cost for c in candidates])
    time = np.array([c.prep_minutes for c in candidates])
    bounds = [(0, c.max_servings) for c in candidates]

    # rows = nutrients, cols = candidates
    N = np.zeros((len(nutrient_names), n))
    for j, c in enumerate(candidates):
        for i, nut in enumerate(nutrient_names):
            N[i, j] = c.nutrients.get(nut, 0.0)

    return candidates, nutrient_names, cost, time, bounds, N


def solve_lp(req: OptimizeRequest) -> OptimizeResponse:
    candidates, nutrient_names, cost, time, bounds, N = _build_matrices(req)

    A_ub = []
    b_ub = []

    # nutrient minimums: N x >= b  ->  flip sign to fit linprog's <= form
    for i, nut in enumerate(nutrient_names):
        if nut in req.nutrient_targets.minimums:
            A_ub.append(-N[i])
            b_ub.append(-req.nutrient_targets.minimums[nut])

    # nutrient ceilings, no sign flip needed
    for i, nut in enumerate(nutrient_names):
        if nut in req.nutrient_targets.maximums:
            A_ub.append(N[i])
            b_ub.append(req.nutrient_targets.maximums[nut])

    A_ub.append(time)
    b_ub.append(req.time_budget_minutes)

    A_ub.append(cost)
    b_ub.append(req.budget)

    result = linprog(
        c=cost,
        A_ub=np.array(A_ub),
        b_ub=np.array(b_ub),
        bounds=bounds,
        method="highs",
    )

    if not result.success:
        return OptimizeResponse(
            status="infeasible",
            plan=[],
            total_cost=0.0,
            total_time_minutes=0.0,
            nutrients_achieved={},
            message="Nothing satisfies every nutrient target under this budget and time limit. Try mode=qp or loosen a constraint.",
        )

    return _to_response(candidates, nutrient_names, N, result.x, status="optimal")


def solve_qp(req: OptimizeRequest, lam: float = 1.0) -> OptimizeResponse:
    """
    lam controls how hard the solver tries to hit the nutrient targets vs
    keeping cost down. higher lam = closer to targets, more expensive plan.
    """
    import cvxpy as cp

    candidates, nutrient_names, cost, time, bounds, N = _build_matrices(req)
    n = len(candidates)

    # only penalize nutrients that actually have a floor. sodium etc (max-only)
    # was leaking into this before, since its target defaulted to 0, which
    # meant the penalty punished eating ANY sodium instead of just enforcing
    # the ceiling below. floors get the soft penalty, ceilings stay hard.
    min_idx = [i for i, nut in enumerate(nutrient_names) if nut in req.nutrient_targets.minimums]
    N_min = N[min_idx]
    b = np.array([req.nutrient_targets.minimums[nutrient_names[i]] for i in min_idx])

    x = cp.Variable(n)
    deviation = N_min @ x - b
    objective = cp.Minimize(cost @ x + lam * cp.sum_squares(deviation))

    constraints = [x >= 0]
    constraints += [x[j] <= candidates[j].max_servings for j in range(n)]
    constraints.append(time @ x <= req.time_budget_minutes)
    constraints.append(cost @ x <= req.budget)

    for i, nut in enumerate(nutrient_names):
        if nut in req.nutrient_targets.maximums:
            constraints.append(N[i] @ x <= req.nutrient_targets.maximums[nut])

    problem = cp.Problem(objective, constraints)
    problem.solve()

    if x.value is None:
        return OptimizeResponse(
            status="infeasible",
            plan=[],
            total_cost=0.0,
            total_time_minutes=0.0,
            nutrients_achieved={},
            message="Couldn't find anything under the budget and time caps, even with soft nutrient targets.",
        )

    x_val = np.clip(x.value, 0, None)
    return _to_response(candidates, nutrient_names, N, x_val, status="penalized")


def _to_response(candidates, nutrient_names, N, x, status) -> OptimizeResponse:
    plan = []
    total_cost = 0.0
    total_time = 0.0

    for j, c in enumerate(candidates):
        servings = round(float(x[j]), 2)
        if servings < 0.05:
            continue  # basically zero, skip it
        plan.append(PlanItem(id=c.id, name=c.name, servings=servings, cost=round(servings * c.cost, 2)))
        total_cost += servings * c.cost
        total_time += servings * c.prep_minutes

    achieved = {nutrient_names[i]: round(float(N[i] @ x), 2) for i in range(len(nutrient_names))}

    return OptimizeResponse(
        status=status,
        plan=plan,
        total_cost=round(total_cost, 2),
        total_time_minutes=round(total_time, 2),
        nutrients_achieved=achieved,
    )


def solve_diet(req: OptimizeRequest) -> OptimizeResponse:
    if req.mode == "qp":
        return solve_qp(req)
    return solve_lp(req)