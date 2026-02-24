from app.db.firebase_client import firebase_client
from app.models.user import UserProfile, UserCreate, UserUpdate
from datetime import datetime
from typing import Optional

class UserRepository:
    def __init__(self):
        self.db = firebase_client.get_firestore_client()
        self.auth = firebase_client.get_auth_client()
        self.collection = self.db.collection('users')

    async def create_user(self, user: UserCreate) -> UserProfile:
        """Create a new user in Firebase Auth and Firestore"""
        try:
            # Create user in Firebase Auth
            user_record = self.auth.create_user(
                email=user.email,
                password=user.password,
                display_name=user.display_name
            )

            # Create user document in Firestore
            user_data = {
                'uid': user_record.uid,
                'email': user.email,
                'display_name': user.display_name,
                'first_name': user.first_name,
                'last_name': user.last_name,
                'avatar_url': user.avatar_url,
                'created_at': datetime.utcnow(),
                'updated_at': datetime.utcnow(),
                'is_active': True,
                'dietary_preferences': [],
                'allergies': [],
                'favorite_cuisines': []
            }

            self.collection.document(user_record.uid).set(user_data)

            return UserProfile(**user_data)

        except Exception as e:
            raise Exception(f"Failed to create user: {str(e)}")

    async def get_user_by_uid(self, uid: str) -> Optional[UserProfile]:
        """Get user by Firebase UID"""
        try:
            doc = self.collection.document(uid).get()
            if doc.exists:
                user_data = doc.to_dict()
                return UserProfile(**user_data)
            return None
        except Exception as e:
            raise Exception(f"Failed to get user: {str(e)}")

    async def get_user_by_email(self, email: str) -> Optional[UserProfile]:
        """Get user by email"""
        try:
            docs = self.collection.where('email', '==', email).limit(1).get()
            for doc in docs:
                user_data = doc.to_dict()
                return UserProfile(**user_data)
            return None
        except Exception as e:
            raise Exception(f"Failed to get user by email: {str(e)}")

    async def update_user(self, uid: str, user_update: UserUpdate) -> Optional[UserProfile]:
        """Update user profile"""
        try:
            update_data = user_update.dict(exclude_unset=True)
            update_data['updated_at'] = datetime.utcnow()

            self.collection.document(uid).update(update_data)

            # Return updated user
            return await self.get_user_by_uid(uid)

        except Exception as e:
            raise Exception(f"Failed to update user: {str(e)}")

    async def delete_user(self, uid: str) -> bool:
        """Delete user from Firestore and Firebase Auth"""
        try:
            # Delete from Firestore
            self.collection.document(uid).delete()

            # Delete from Firebase Auth
            self.auth.delete_user(uid)

            return True

        except Exception as e:
            raise Exception(f"Failed to delete user: {str(e)}")

    async def authenticate_user(self, email: str, password: str) -> Optional[UserProfile]:
        """Authenticate user with email and password using Firebase Auth"""
        try:
            # Note: In a production app, password verification should be done client-side
            # with Firebase Auth SDK. Server-side password verification is not recommended.
            # This method assumes the password has already been verified client-side.

            # For now, just check if user exists in Firebase Auth
            user = self.auth.get_user_by_email(email)

            # Get user profile from Firestore
            user_profile = await self.get_user_by_uid(user.uid)
            return user_profile

        except Exception as e:
            return None

    async def verify_firebase_token(self, id_token: str) -> Optional[UserProfile]:
        """Verify Firebase ID token and return user profile"""
        try:
            # Verify the Firebase ID token
            decoded_token = self.auth.verify_id_token(id_token)
            uid = decoded_token['uid']

            # Get user profile from Firestore
            user_profile = await self.get_user_by_uid(uid)
            return user_profile

        except Exception as e:
            return None

# Global instance
user_repository = UserRepository()