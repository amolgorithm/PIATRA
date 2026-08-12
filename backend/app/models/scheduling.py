from pydantic import BaseModel
from typing import List, Dict


class RecipeStepInput(BaseModel):
    text: str
    duration_minutes: float
    resource: str = "hands"  # "stove", "oven", "hands", or any custom label


class RecipeInput(BaseModel):
    id: str
    name: str
    steps: List[RecipeStepInput]  # order matters, step i depends on step i-1


class ScheduleRequest(BaseModel):
    recipes: List[RecipeInput]
    # how many of each resource the kitchen actually has, e.g. 2 stove
    # burners means 2 steps needing "stove" can run at once
    resource_counts: Dict[str, int] = {"stove": 1, "oven": 1, "hands": 1}


class ScheduledStep(BaseModel):
    recipe_id: str
    recipe_name: str
    step_index: int
    text: str
    resource: str
    start_minute: float
    end_minute: float


class ScheduleResponse(BaseModel):
    timeline: List[ScheduledStep]
    makespan_minutes: float          # actual total time, resource contention included
    naive_sequential_minutes: float  # cooking each recipe fully before starting the next
    critical_path_minutes: float     # best possible with unlimited resources
    minutes_saved: float             # naive_sequential - makespan
