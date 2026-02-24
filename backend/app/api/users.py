from fastapi import APIRouter, HTTPException, Depends, status, Header
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.models.user import UserCreate, UserUpdate, UserProfile, UserBase, Token
from app.db.user_repository import user_repository
from app.core.security import create_access_token, verify_token
from datetime import timedelta

router = APIRouter()
security = HTTPBearer()

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> str:
    """Dependency to get current user from JWT token"""
    token = credentials.credentials
    email = verify_token(token)
    if email is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return email

async def get_current_user_from_firebase(authorization: str = Header(None)) -> UserProfile:
    """Dependency to get current user from Firebase ID token"""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase ID token required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    id_token = authorization.split(" ")[1]
    user = await user_repository.verify_firebase_token(id_token)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase ID token"
        )
    return user

@router.post("/register", response_model=UserProfile)
async def register_user(user: UserCreate):
    """Register a new user - Note: Registration should typically happen client-side with Firebase Auth"""
    try:
        # Check if user already exists
        existing_user = await user_repository.get_user_by_email(user.email)
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User with this email already exists"
            )

        # Note: In production, user creation should happen client-side with Firebase Auth SDK
        # This endpoint is for creating the user profile in Firestore after Firebase Auth registration
        # For now, we'll create both for testing purposes
        new_user = await user_repository.create_user(user)
        return new_user

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to register user: {str(e)}"
        )

@router.post("/create-profile", response_model=UserProfile)
async def create_user_profile(
    user_data: UserBase,
    current_user: UserProfile = Depends(get_current_user_from_firebase)
):
    """Create or update user profile in Firestore after Firebase Auth registration"""
    try:
        # Update the existing user profile with additional data
        update_data = UserUpdate(
            display_name=user_data.display_name,
            first_name=user_data.first_name,
            last_name=user_data.last_name,
            avatar_url=user_data.avatar_url
        )

        updated_user = await user_repository.update_user(current_user.uid, update_data)
        if not updated_user:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create user profile"
            )

        return updated_user

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create user profile: {str(e)}"
        )

@router.post("/login", response_model=Token)
async def login_user(id_token: str):
    """Login user with Firebase ID token and return access token"""
    try:
        user = await user_repository.verify_firebase_token(id_token)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Firebase ID token"
            )

        # Create access token
        access_token_expires = timedelta(minutes=30)
        access_token = create_access_token(
            data={"sub": user.email}, expires_delta=access_token_expires
        )

        return Token(access_token=access_token, token_type="bearer")

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Login failed: {str(e)}"
        )

@router.get("/profile", response_model=UserProfile)
async def get_user_profile(current_user: UserProfile = Depends(get_current_user_from_firebase)):
    """Get current user's profile"""
    return current_user

@router.put("/profile", response_model=UserProfile)
async def update_user_profile(
    user_update: UserUpdate,
    current_user: UserProfile = Depends(get_current_user_from_firebase)
):
    """Update current user's profile"""
    try:
        # Update user
        updated_user = await user_repository.update_user(current_user.uid, user_update)
        if not updated_user:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to update user profile"
            )

        return updated_user

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update user profile: {str(e)}"
        )

@router.delete("/profile")
async def delete_user_profile(current_user: UserProfile = Depends(get_current_user_from_firebase)):
    """Delete current user's profile"""
    try:
        # Delete user
        success = await user_repository.delete_user(current_user.uid)
        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to delete user profile"
            )

        return {"message": "User profile deleted successfully"}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete user profile: {str(e)}"
        )