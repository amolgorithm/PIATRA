from fastapi import APIRouter

router = APIRouter()

@router.get("/")
async def recipes_root():
    return {"message": "Recipes API endpoint"}