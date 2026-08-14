from fastapi import APIRouter, HTTPException

from app.models.diversity import DiversifyRequest, DiversifyResponse
from app.services.diversity_engine import diversify

router = APIRouter()


@router.post("/select", response_model=DiversifyResponse)
async def diversify_recommendations(req: DiversifyRequest):
    """Greedy correlation-minimizing selection over already-scored candidates, so top-k isn't five near-identical recipes."""
    if not req.candidates:
        raise HTTPException(status_code=400, detail="need at least one candidate to diversify over")

    try:
        return diversify(req)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"diversity engine failed: {str(e)}")
