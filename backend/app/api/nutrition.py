from fastapi import APIRouter

router = APIRouter()

@router.get("/")
async def nutrition_root():
    return {"message": "Nutrition API endpoint"}