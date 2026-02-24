import firebase_admin
from firebase_admin import credentials, firestore, auth
from app.core.config import Config
import json

class FirebaseClient:
    def __init__(self):
        if not firebase_admin._apps:
            # Initialize Firebase Admin SDK
            if Config.FIREBASE_PRIVATE_KEY and Config.FIREBASE_CLIENT_EMAIL and Config.FIREBASE_PROJECT_ID:
                # Use service account credentials
                # Handle private key formatting (remove literal \n and replace with actual newlines)
                private_key = Config.FIREBASE_PRIVATE_KEY
                if '\\n' in private_key:
                    private_key = private_key.replace('\\n', '\n')
                elif '\\\\n' in private_key:
                    private_key = private_key.replace('\\\\n', '\n')

                cred_dict = {
                    "type": "service_account",
                    "project_id": Config.FIREBASE_PROJECT_ID,
                    "private_key": private_key,
                    "client_email": Config.FIREBASE_CLIENT_EMAIL,
                    "token_uri": "https://oauth2.googleapis.com/token"
                }
                cred = credentials.Certificate(cred_dict)
            else:
                # Use default credentials (for deployed environments)
                cred = credentials.ApplicationDefault()

            firebase_admin.initialize_app(cred)

        self.db = firestore.client()
        self.auth = auth

    def get_firestore_client(self):
        return self.db

    def get_auth_client(self):
        return self.auth

# Global instance
firebase_client = FirebaseClient()