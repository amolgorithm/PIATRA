from .assistant import router as assistant_router
from .nutrition import router as nutrition_router
from .pantry import router as pantry_router
from .recipes import router as recipes_router
from .users import router as users_router
from .feedback   import router as feedback_router
from .optimize import router as optimize_router
from .schedule import router as schedule_router
from .ingredients import router as ingredients_router
from .diversity import router as diversity_router
from .energy import router as energy_router

# For backward compatibility
assistant = assistant_router
nutrition = nutrition_router
pantry = pantry_router
recipes = recipes_router
users = users_router
feedback  = feedback_router
optimize = optimize_router
schedule = schedule_router
ingredients = ingredients_router
diversity = diversity_router
energy = energy_router