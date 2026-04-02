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
    """Receive feedback from the mobile app and attempt to send it via email.

    Email delivery is best-effort: if the SMTP credentials are missing or the
    send fails for any reason we still return 200 so the client never sees a
    server error just because email isn't configured on the host.
    """
    if not request.feedback.strip():
        raise HTTPException(status_code=400, detail="Feedback cannot be empty.")

    try:
        send_feedback_email(request.feedback, request.user_id)
        print(f"[feedback] Email sent OK (user={request.user_id})")
    except Exception as e:
        # Log the problem but never surface it as a 500 to the client.
        # Feedback is captured in server logs even when email is unavailable.
        print(f"[feedback] Email delivery failed (non-fatal): {e}")
        print(f"[feedback] Feedback content: {request.feedback[:200]}")

    return {"message": "Feedback received. Thank you!"}