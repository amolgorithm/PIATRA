import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")

    DEBUG = os.getenv("DEBUG", "False").lower() == "true"

    # Firebase settings
    FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID")
    FIREBASE_PRIVATE_KEY = os.getenv("FIREBASE_PRIVATE_KEY")
    FIREBASE_CLIENT_EMAIL = os.getenv("FIREBASE_CLIENT_EMAIL")

    # JWT settings
    SECRET_KEY = os.getenv("SECRET_KEY", "change-me-in-production")
    ALGORITHM = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES = 30

    @classmethod
    def validate(cls):
        """Call this at startup to check required vars are present."""
        if not cls.GEMINI_API_KEY:
            raise ValueError("GEMINI_API_KEY environment variable is not set")
        if not all([cls.FIREBASE_PROJECT_ID, cls.FIREBASE_PRIVATE_KEY, cls.FIREBASE_CLIENT_EMAIL]):
            print("Warning: Firebase credentials not fully configured.")