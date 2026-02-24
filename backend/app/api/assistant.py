from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.services.ai_assistant import AIAssistant

router = APIRouter()
ai_assistant = AIAssistant()

class ChatRequest(BaseModel):
    message: str
    context: str = ""

class NutritionRequest(BaseModel):
    query: str

class RecipeRequest(BaseModel):
    ingredients: list[str]

@router.post("/chat")
async def chat_with_assistant(request: ChatRequest):
    """General chat endpoint for the AI assistant"""
    try:
        response = ai_assistant.generate_response(request.message, request.context)
        return {"response": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating response: {str(e)}")

@router.post("/nutrition-advice")
async def get_nutrition_advice(request: NutritionRequest):
    """Get nutrition-specific advice"""
    try:
        response = ai_assistant.get_nutrition_advice(request.query)
        return {"response": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting nutrition advice: {str(e)}")

@router.post("/recipe-suggestions")
async def get_recipe_suggestions(request: RecipeRequest):
    """Get recipe suggestions based on ingredients"""
    try:
        response = ai_assistant.get_recipe_suggestions(request.ingredients)
        return {"response": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting recipe suggestions: {str(e)}")