from fastapi import FastAPI
from app.api import assistant, nutrition, pantry, recipes, users

app = FastAPI(title="PIATRA Backend API", version="1.0.0")

# Include routers
app.include_router(assistant, prefix="/api/assistant", tags=["assistant"])
app.include_router(nutrition, prefix="/api/nutrition", tags=["nutrition"])
app.include_router(pantry, prefix="/api/pantry", tags=["pantry"])
app.include_router(recipes, prefix="/api/recipes", tags=["recipes"])
app.include_router(users, prefix="/api/users", tags=["users"])

@app.get("/")
async def root():
    return {"message": "Welcome to PIATRA Backend API"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)