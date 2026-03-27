from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from app.services.feedback_email import send_feedback_email

router = APIRouter()


class FeedbackRequest(BaseModel):
    feedback: str
    user_id: Optional[str] = None


@router.post("/")
async def submit_feedback(request: FeedbackRequest):
    """Receive feedback from the mobile app and send it via email."""
    if not request.feedback.strip():
        raise HTTPException(status_code=400, detail="Feedback cannot be empty.")
    try:
        send_feedback_email(request.feedback, request.user_id)
        return {"message": "Feedback received. Thank you!"}
    except ValueError as e:
        # Missing env vars — still accept the feedback, just log the warning
        print(f"[feedback] Email not configured: {e}")
        return {"message": "Feedback received (email delivery not configured)."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to send feedback: {str(e)}")
