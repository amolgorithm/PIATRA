from fastapi import APIRouter, HTTPException

from app.models.scheduling import ScheduleRequest, ScheduleResponse
from app.services.batch_scheduler import solve_schedule

router = APIRouter()


@router.post("/batch-cook", response_model=ScheduleResponse)
async def batch_cook_schedule(req: ScheduleRequest):
    """Schedules several recipes at once against shared kitchen resources, instead of cooking them one after another."""
    if not req.recipes:
        raise HTTPException(status_code=400, detail="need at least one recipe to schedule")

    try:
        return solve_schedule(req)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"scheduler failed: {str(e)}")
