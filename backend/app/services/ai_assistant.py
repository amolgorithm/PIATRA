import google.generativeai as genai
from app.core.config import Config
from app.utils.text_processing import format_gemini_response
from app.db.user_repository import user_repository
from app.db.pantry_repository import pantry_repository
import json

genai.configure(api_key=Config.GEMINI_API_KEY)

class AIAssistant:
    def __init__(self):
        self.model = genai.GenerativeModel(
            'gemini-2.5-flash',
            tools=[
                self._get_pantry_tool(),
                self._get_profile_tool(),
            ]
        )
        self.user_id = None

    def _get_pantry_tool(self):
        """Define pantry query tool for the AI"""
        # simple dict format without `type` field that caused ValueError previously
        return {
            "name": "get_user_pantry",
            "description": "Get the user's current pantry items and inventory. Use this when the user asks about what ingredients they have available or when planning recipes.",
            "parameters": {
                "properties": {},
                "required": []
            }
        }

    def _get_profile_tool(self):
        """Define profile query tool for the AI"""
        return {
            "name": "get_user_profile",
            "description": "Get the user's profile information including dietary preferences, allergies, and favorite cuisines. Use this when the user asks about their preferences or dietary restrictions.",
            "parameters": {
                "properties": {},
                "required": []
            }
        }

    def _execute_tool(self, tool_name: str) -> str:
        """Execute a tool and return results"""
        if not self.user_id:
            return "User ID not available"
        
        if tool_name == "get_user_pantry":
            try:
                pantry_items = pantry_repository.get_pantry_items(self.user_id)
                if not pantry_items:
                    return "Pantry is empty"
                
                items_list = []
                for item in pantry_items:
                    items_list.append(f"- {item.name}: {item.quantity}" + 
                                    (f" (expires: {item.expiry_date})" if item.expiry_date else ""))
                
                return "Current Pantry Items:\n" + "\n".join(items_list)
            except Exception as e:
                return f"Error fetching pantry: {str(e)}"
        
        elif tool_name == "get_user_profile":
            try:
                user = user_repository.get_user_by_uid(self.user_id)
                if not user:
                    user = user_repository.get_user_by_email(self.user_id)
                
                if not user:
                    return "User profile not found"
                
                profile_info = f"""User Profile Information:
Name: {user.display_name}
Email: {user.email}
Favorite Cuisines: {', '.join(user.favorite_cuisines) if user.favorite_cuisines else 'Not specified'}
Dietary Preferences: {', '.join(user.dietary_preferences) if user.dietary_preferences else 'None'}
Allergies/Restrictions: {', '.join(user.allergies) if user.allergies else 'None'}"""
                
                return profile_info
            except Exception as e:
                return f"Error fetching profile: {str(e)}"
        
        return "Unknown tool"

    def generate_response(self, user_input: str, user_id: str = "", context: str = "") -> str:
        """
        Generate a response using Gemini API with tool access to pantry and profile.
        AI can call tools to look up real-time data like a GitHub connector.
        """
        self.user_id = user_id
        context_section = f"Additional Context:\n{context}\n\n" if context else ""

        prompt = f"""You are PIATRA, an intelligent AI assistant for a nutrition and pantry management app.
You are designed to be helpful, personalized, and contextually aware.

You have access to real-time tools to check the user's pantry and profile information:
- get_user_pantry: Check what ingredients are currently available
- get_user_profile: Check dietary preferences, allergies, and favorite cuisines

When the user mentions their pantry, profile settings, allergies, dietary preferences, or asks what they can cook:
ALWAYS use the appropriate tool to get current, accurate information.
Do NOT assume - always check the tools first.

{context_section}
User Query: {user_input}

Guidelines:
- Use tools to get real-time pantry and profile data
- For recipe suggestions, always check the pantry first
- For nutrition advice, always check their allergies and dietary preferences
- Be specific and personalized based on actual user data
- Suggest practical, actionable advice
- Include nutritional information when relevant
- Be friendly and encouraging"""

        try:
            # Use streaming/multi-turn with tool calling
            conversation_history = prompt
            max_iterations = 10
            iteration = 0
            
            while iteration < max_iterations:
                iteration += 1
                response = self.model.generate_content(conversation_history)
                
                # Check if there was a function call
                if response.candidates and response.candidates[0].content.parts:
                    has_tool_call = False
                    
                    for part in response.candidates[0].content.parts:
                        if part.function_call:
                            has_tool_call = True
                            tool_name = part.function_call.name
                            tool_result = self._execute_tool(tool_name)
                            
                            # Append to conversation history
                            conversation_history += f"\n\n[Tool Call: {tool_name}]\nResult:\n{tool_result}"
                            break
                    
                    if not has_tool_call:
                        # It's a text response, return it
                        return format_gemini_response(response.text.strip())
                else:
                    if response.text:
                        return format_gemini_response(response.text.strip())
                    break
            
            return "I'm ready to help! Ask me about recipes, nutrition, or check your pantry."
        
        except Exception as e:
            return f"Sorry, I encountered an error: {str(e)}"

    def get_nutrition_advice(self, query: str, user_id: str = "", context: str = "") -> str:
        """Get nutrition-specific advice with tool access to profile"""
        self.user_id = user_id
        context_section = f"Additional Context:\n{context}\n\n" if context else ""

        prompt = f"""You are a nutrition expert assistant for PIATRA, a nutrition and pantry management app.
Provide evidence-based, personalized nutrition advice.

You have access to get_user_profile tool to check dietary preferences and allergies.
ALWAYS use this tool to ensure you respect the user's dietary restrictions.

{context_section}
User Query: {query}

Guidelines:
- Use get_user_profile tool to check allergies and dietary preferences
- Provide evidence-based nutrition advice
- Consider macronutrients, micronutrients, and healthy eating patterns
- Provide practical, actionable recommendations
- Be encouraging and supportive"""

        try:
            conversation_history = prompt
            max_iterations = 10
            iteration = 0
            
            while iteration < max_iterations:
                iteration += 1
                response = self.model.generate_content(conversation_history)
                
                if response.candidates and response.candidates[0].content.parts:
                    has_tool_call = False
                    
                    for part in response.candidates[0].content.parts:
                        if part.function_call:
                            has_tool_call = True
                            tool_name = part.function_call.name
                            tool_result = self._execute_tool(tool_name)
                            
                            conversation_history += f"\n\n[Tool Call: {tool_name}]\nResult:\n{tool_result}"
                            break
                    
                    if not has_tool_call:
                        return format_gemini_response(response.text.strip())
                else:
                    if response.text:
                        return format_gemini_response(response.text.strip())
                    break
            
            return "I'm here to provide nutrition advice!"
        
        except Exception as e:
            return f"Sorry, I encountered an error: {str(e)}"

    def get_recipe_suggestions(self, ingredients: list, user_id: str = "", context: str = "") -> str:
        """Suggest recipes with real-time pantry and profile access"""
        self.user_id = user_id
        ingredient_list = ", ".join(ingredients) if ingredients else "user's available items"
        context_section = f"Additional Context:\n{context}\n\n" if context else ""

        prompt = f"""You are a culinary assistant for PIATRA, a nutrition and pantry management app.
Suggest practical recipes that users can make.

You have access to tools:
- get_user_pantry: See all available ingredients
- get_user_profile: Check dietary preferences and allergies

ALWAYS use these tools to provide accurate, personalized recipes.

{context_section}
Ingredients User Mentioned: {ingredient_list}

Guidelines:
- Use get_user_pantry tool to see all available items
- Use get_user_profile tool to check dietary restrictions and allergies
- Suggest recipes using available items
- Respect dietary preferences and ALWAYS avoid allergens
- Provide step-by-step instructions
- Include nutritional information
- Be practical and encouraging"""

        try:
            conversation_history = prompt
            max_iterations = 10
            iteration = 0
            
            while iteration < max_iterations:
                iteration += 1
                response = self.model.generate_content(conversation_history)
                
                if response.candidates and response.candidates[0].content.parts:
                    has_tool_call = False
                    
                    for part in response.candidates[0].content.parts:
                        if part.function_call:
                            has_tool_call = True
                            tool_name = part.function_call.name
                            tool_result = self._execute_tool(tool_name)
                            
                            conversation_history += f"\n\n[Tool Call: {tool_name}]\nResult:\n{tool_result}"
                            break
                    
                    if not has_tool_call:
                        return format_gemini_response(response.text.strip())
                else:
                    if response.text:
                        return format_gemini_response(response.text.strip())
                    break
            
            return "I can help you find recipes!"
        
        except Exception as e:
            return f"Sorry, I encountered an error: {str(e)}"
