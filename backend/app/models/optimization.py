from pydantic import BaseModel
from typing import Dict, List, Optional


class NutrientTargets(BaseModel):
    # minimums the plan has to hit, maximums it can't cross (sodium ceiling etc)
    minimums: Dict[str, float] = {}
    maximums: Dict[str, float] = {}


class MealCandidate(BaseModel):
    # candidates come from the client, already pulled from Spoonacular/Firestore,
    # same as everywhere else in the app. this endpoint just does the math on top
    id: str
    name: str
    cost: float                 # dollars per serving
    prep_minutes: float
    nutrients: Dict[str, float]  # e.g. {"protein_g": 32, "sodium_mg": 410}
    max_servings: float = 7      # stop the solver from picking 14x the same lasagna


class OptimizeRequest(BaseModel):
    candidates: List[MealCandidate]
    nutrient_targets: NutrientTargets
    budget: float
    time_budget_minutes: float
    mode: str = "lp"  # "lp" = hard constraints, "qp" = soft/penalized version


class PlanItem(BaseModel):
    id: str
    name: str
    servings: float
    cost: float


class OptimizeResponse(BaseModel):
    status: str  # "optimal", "penalized", or "infeasible"
    plan: List[PlanItem]
    total_cost: float
    total_time_minutes: float
    nutrients_achieved: Dict[str, float]
    message: Optional[str] = None