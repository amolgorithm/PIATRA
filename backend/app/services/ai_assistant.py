import google.generativeai as genai
from app.core.config import Config

genai.configure(api_key=Config.GEMINI_API_KEY)

class AIAssistant:
    def __init__(self):
        self.model = genai.GenerativeModel('gemini-pro')

    def generate_response(self, user_input: str, context: str = "") -> str:
        """
        Generate a response using Gemini API for the assistant chatbot.
        Includes rule-based elements for nutrition/pantry context.
        """
        prompt = f"""
        You are PIATRA, an AI assistant for a nutrition and pantry management app.
        Help users with recipes, nutrition advice, pantry management, and general cooking questions.

        Context: {context}

        User: {user_input}

        Provide helpful, accurate, and friendly responses. For nutrition advice, be evidence-based.
        For recipes, ensure they are practical and include nutritional information when relevant.
        """

        try:
            response = self.model.generate_content(prompt)
            return response.text.strip()
        except Exception as e:
            return f"Sorry, I encountered an error: {str(e)}"

    def get_nutrition_advice(self, query: str) -> str:
        """Get nutrition-specific advice"""
        context = "Focus on providing evidence-based nutrition advice, including macronutrients, micronutrients, and healthy eating patterns."
        return self.generate_response(query, context)

    def get_recipe_suggestions(self, ingredients: list) -> str:
        """Suggest recipes based on available ingredients"""
        ingredient_list = ", ".join(ingredients)
        query = f"Suggest recipes using these ingredients: {ingredient_list}"
        context = "Provide practical recipes with step-by-step instructions, nutritional info, and cooking tips."
        return self.generate_response(query, context)