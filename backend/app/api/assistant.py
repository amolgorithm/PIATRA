from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.services.ai_assistant import AIAssistant
from app.services.context_builder import ContextBuilder
from typing import Optional

router = APIRouter()
ai_assistant = AIAssistant()
context_builder = ContextBuilder()

class ChatRequest(BaseModel):
    message: str
    context: str = ""
    user_id: str = None

class NutritionRequest(BaseModel):
    query: str
    user_id: str = None

class RecipeRequest(BaseModel):
    ingredients: list[str]
    user_id: str = None

@router.post("/chat")
async def chat_with_assistant(request: ChatRequest):
    """General chat endpoint for the AI assistant with real-time context access"""
    try:
        # Build rich context from user data if user_id is provided
        context = request.context
        if request.user_id:
            rich_context = context_builder.build_chat_context(request.user_id)
            context = rich_context if not request.context else f"{rich_context}\n\nAdditional Context: {request.context}"
        
        response = ai_assistant.generate_response(request.message, request.user_id, context)
        return {"response": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating response: {str(e)}")

@router.post("/nutrition-advice")
async def get_nutrition_advice(request: NutritionRequest):
    """Get nutrition-specific advice with user context"""
    try:
        context = ""
        if request.user_id:
            context = context_builder.build_nutrition_context(request.user_id)
        
        response = ai_assistant.get_nutrition_advice(request.query, request.user_id, context)
        return {"response": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting nutrition advice: {str(e)}")

@router.post("/recipe-suggestions")
async def get_recipe_suggestions(request: RecipeRequest):
    """Get recipe suggestions based on ingredients and user preferences"""
    try:
        context = ""
        if request.user_id:
            context = context_builder.build_recipe_context(request.user_id, request.ingredients)
        
        response = ai_assistant.get_recipe_suggestions(request.ingredients, request.user_id, context)
        return {"response": response}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting recipe suggestions: {str(e)}")