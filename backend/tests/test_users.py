import pytest
from app.models.user import UserCreate, UserUpdate
from app.db.user_repository import user_repository

def test_user_model_creation():
    """Test user model creation"""
    user_data = {
        "email": "test@example.com",
        "display_name": "Test User",
        "password": "testpass123"
    }

    user = UserCreate(**user_data)
    assert user.email == "test@example.com"
    assert user.display_name == "Test User"
    assert user.password == "testpass123"

def test_user_update_model():
    """Test user update model"""
    update_data = {
        "display_name": "Updated Name",
        "first_name": "John"
    }

    user_update = UserUpdate(**update_data)
    assert user_update.display_name == "Updated Name"
    assert user_update.first_name == "John"
    assert user_update.last_name is None  # Should be optional