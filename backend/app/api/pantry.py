from fastapi import APIRouter

router = APIRouter()

@router.get("/")
async def pantry_root():
    return {"message": "Pantry API endpoint"}