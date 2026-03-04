"""
Context builder service that gathers user data to provide rich context to the AI assistant.
This makes the AI more "agentic" by including pantry, profile, objectives, and dietary information.
"""

from app.db.user_repository import user_repository
from app.db.pantry_repository import pantry_repository
from typing import List, Optional


class ContextBuilder:
    """Builds rich context information from user data for the AI assistant"""

    def build_chat_context(self, user_id: str) -> str:
        """Build comprehensive context for general chat interactions"""
        try:
            context_parts = []

            # Get user profile
            user = user_repository.get_user_by_uid(user_id)
            if user:
                context_parts.append(self._build_profile_context(user))

            # Get pantry items
            pantry_context = self._build_pantry_context(user_id)
            if pantry_context:
                context_parts.append(pantry_context)

            # Get dietary/allergy information
            dietary_context = self._build_dietary_context(user)
            if dietary_context:
                context_parts.append(dietary_context)

            return "\n\n".join(context_parts)

        except Exception as e:
            return f"[Context Note: Unable to load full context - {str(e)}]"

    def build_nutrition_context(self, user_id: str, additional_context: str = "") -> str:
        """Build context specifically for nutrition advice"""
        try:
            context_parts = []

            # Get user profile
            user = user_repository.get_user_by_uid(user_id)
            if user:
                context_parts.append(self._build_profile_context(user))

            # Get dietary/allergy information
            dietary_context = self._build_dietary_context(user)
            if dietary_context:
                context_parts.append(dietary_context)

            # Add nutrition-specific note
            context_parts.append(
                "When providing nutrition advice, consider the user's dietary preferences, allergies, and any goals."
            )

            if additional_context:
                context_parts.append(f"Additional Context: {additional_context}")

            return "\n\n".join(context_parts)

        except Exception as e:
            return f"[Context Note: Unable to load nutrition context - {str(e)}]"

    def build_recipe_context(
        self, user_id: str, ingredients: Optional[List[str]] = None
    ) -> str:
        """Build context specifically for recipe suggestions"""
        try:
            context_parts = []

            # Get user profile
            user = user_repository.get_user_by_uid(user_id)
            if user:
                context_parts.append(self._build_profile_context(user))

            # Get pantry items
            pantry_context = self._build_pantry_context(user_id)
            if pantry_context:
                context_parts.append(f"Available in Pantry:\n{pantry_context}")

            # Get dietary/allergy information
            dietary_context = self._build_dietary_context(user)
            if dietary_context:
                context_parts.append(dietary_context)

            # Add recipe-specific note
            if ingredients:
                context_parts.append(
                    f"Requested ingredients: {', '.join(ingredients)}\n"
                    "Consider these ingredients along with what's in the user's pantry and their dietary restrictions."
                )

            context_parts.append(
                "Provide practical recipes with step-by-step instructions and nutritional information."
            )

            return "\n\n".join(context_parts)

        except Exception as e:
            return f"[Context Note: Unable to load recipe context - {str(e)}]"

    def _build_profile_context(self, user) -> str:
        """Build user profile context"""
        if not user:
            return ""

        profile_parts = [f"User Profile: {user.display_name}"]

        if user.favorite_cuisines:
            profile_parts.append(f"Favorite Cuisines: {', '.join(user.favorite_cuisines)}")

        return " | ".join(profile_parts)

    def _build_pantry_context(self, user_id: str) -> str:
        """Build pantry inventory context"""
        try:
            pantry_items = pantry_repository.get_pantry_items(user_id)

            if not pantry_items:
                return "Pantry: Empty or no items recorded"

            # Group items by category if available
            items_list = []
            for item in pantry_items[:20]:  # Limit to 20 items for token efficiency
                if hasattr(item, 'name') and hasattr(item, 'quantity'):
                    items_list.append(f"{item.name} ({item.quantity})")
                else:
                    items_list.append(str(item))

            return f"Pantry Items Available: {', '.join(items_list)}"

        except Exception as e:
            return f"[Pantry: Unable to load - {str(e)}]"

    def _build_dietary_context(self, user) -> str:
        """Build dietary preferences and allergies context"""
        if not user:
            return ""

        context_parts = []

        if user.dietary_preferences:
            context_parts.append(
                f"Dietary Preferences: {', '.join(user.dietary_preferences)}"
            )

        if user.allergies:
            context_parts.append(f"Allergies/Restrictions: {', '.join(user.allergies)}")

        return " | ".join(context_parts) if context_parts else ""
