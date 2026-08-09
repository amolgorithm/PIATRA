from fastapi import APIRouter, HTTPException

from app.models.optimization import OptimizeRequest, OptimizeResponse
from app.services.optimization_engine import solve_diet

router = APIRouter()


@router.post("/meal-plan", response_model=OptimizeResponse)
async def optimize_meal_plan(req: OptimizeRequest):
    """Solves for the cheapest set of recipes that hits the user's nutrient targets under their budget and time limit."""
    if not req.candidates:
        raise HTTPException(status_code=400, detail="need at least one candidate recipe to optimize over")

    try:
        return solve_diet(req)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"optimizer failed: {str(e)}")