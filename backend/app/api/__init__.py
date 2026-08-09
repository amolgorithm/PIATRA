from .assistant import router as assistant_router
from .nutrition import router as nutrition_router
from .pantry import router as pantry_router
from .recipes import router as recipes_router
from .users import router as users_router
from .feedback   import router as feedback_router
from .optimize import router as optimize_router

# For backward compatibility
assistant = assistant_router
nutrition = nutrition_router
pantry = pantry_router
recipes = recipes_router
users = users_router
feedback  = feedback_router
optimize = optimize_router