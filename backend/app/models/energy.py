from pydantic import BaseModel
from typing import Dict, List


class EnergyCurveRequest(BaseModel):
    # same nutrient shape Features 1/3/4 already use
    nutrients: Dict[str, float]
    duration_minutes: int = 180


class EnergyCurveResponse(BaseModel):
    times_minutes: List[float]
    glucose: List[float]          # relative units, NOT clinical mg/dL, see energy_model.py
    insulin: List[float]
    glycemic_load_estimate: float
    peak_glucose: float
    peak_time_minutes: float
    steepest_drop_per_minute: float
    possible_energy_dip: bool
    note: str
