import google.generativeai as genai
from app.core.config import Config
from app.utils.text_processing import format_gemini_response

genai.configure(api_key=Config.GEMINI_API_KEY)


class AIAssistant:
    def __init__(self):
        # No tools needed — context is injected inline by the Flutter client
        self.model = genai.GenerativeModel("gemini-2.5-flash")

    def _call_model(self, prompt: str) -> str:
        """Simple single-turn call; returns formatted text."""
        try:
            response = self.model.generate_content(prompt)
            return format_gemini_response(response.text.strip())
        except Exception as e:
            return f"Sorry, I encountered an error: {e}"

    def generate_response(self, user_input: str, user_id: str = "", context: str = "") -> str:
        """General chat. All user context (pantry + profile) arrives pre-built in `context`."""
        context_section = f"\n\n--- User Context ---\n{context}\n--- End Context ---\n" if context else ""

        prompt = f"""You are PIATRA, an intelligent AI assistant for a nutrition and pantry management app.
You are helpful, friendly, and highly personalised.

The user's current pantry inventory and cooking profile are provided below in the context section.
Use them to give accurate, specific answers — never say you cannot see the pantry or profile.
{context_section}
User message: {user_input}

Guidelines:
- Reference specific pantry items by name when suggesting recipes
- Always respect dietary preferences and allergies from the profile
- Be practical, encouraging, and concise
- Include nutritional info when relevant"""

        return self._call_model(prompt)

    def get_nutrition_advice(self, query: str, user_id: str = "", context: str = "") -> str:
        context_section = f"\n\n--- User Context ---\n{context}\n--- End Context ---\n" if context else ""

        prompt = f"""You are a nutrition expert assistant for PIATRA.
Provide evidence-based, personalised nutrition advice.
Always respect the user's allergies and dietary preferences shown in the context below.
{context_section}
User nutrition query: {query}"""

        return self._call_model(prompt)

    def get_recipe_suggestions(self, ingredients: list, user_id: str = "", context: str = "") -> str:
        ingredient_list = ", ".join(ingredients) if ingredients else "whatever is available"
        context_section = f"\n\n--- User Context ---\n{context}\n--- End Context ---\n" if context else ""

        prompt = f"""You are a culinary assistant for PIATRA.
Suggest practical recipes using the ingredients listed below AND what is in the user's pantry (see context).
Always respect dietary restrictions and allergies from the profile.
{context_section}
User mentioned: {ingredient_list}

Provide step-by-step instructions and nutritional info for each recipe."""

        return self._call_model(prompt)