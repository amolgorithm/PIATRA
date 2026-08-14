from fastapi import APIRouter, HTTPException

from app.models.energy import EnergyCurveRequest, EnergyCurveResponse
from app.services.energy_model import compute_energy_curve

router = APIRouter()


@router.post("/curve", response_model=EnergyCurveResponse)
async def get_energy_curve(req: EnergyCurveRequest):
    """Predicted post-meal glucose/energy response, a simplified comparative model, not clinical advice."""
    try:
        return compute_energy_curve(req)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"energy model failed: {str(e)}")
