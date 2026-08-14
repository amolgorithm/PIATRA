import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import assistant, nutrition, pantry, recipes, users, feedback, optimize, schedule, ingredients, diversity

app = FastAPI(title="PIATRA Backend API", version="1.0.0")

# ── CORS ──────────────────────────────────────────────────────────────────────
# Allow Flutter web, mobile, and local dev to call the API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # Tighten this after launch (e.g. your domain only)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(assistant, prefix="/api/assistant", tags=["assistant"])
app.include_router(nutrition, prefix="/api/nutrition", tags=["nutrition"])
app.include_router(pantry, prefix="/api/pantry", tags=["pantry"])
app.include_router(recipes, prefix="/api/recipes", tags=["recipes"])
app.include_router(users, prefix="/api/users", tags=["users"])
app.include_router(feedback, prefix="/api/feedback", tags=["feedback"])
app.include_router(optimize, prefix="/api/optimize", tags=["optimize"])
app.include_router(schedule, prefix="/api/schedule", tags=["schedule"])
app.include_router(ingredients, prefix="/api/ingredients", tags=["ingredients"])
app.include_router(diversity, prefix="/api/diversity", tags=["diversity"])

@app.get("/")
async def root():
    return {"message": "Welcome to PIATRA Backend API"}

@app.get("/health")
async def health():
    """Render uses this to confirm the service is alive."""
    return {"status": "ok"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)