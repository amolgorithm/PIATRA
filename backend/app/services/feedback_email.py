import smtplib
import ssl
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart


def send_feedback_email(feedback_text: str, user_id: str = None):
    """
    Send feedback email via Gmail SMTP (SSL, port 465).

    Required environment variables:
        FEEDBACK_EMAIL           — Gmail address used to send (and receive) feedback
        FEEDBACK_EMAIL_PASSWORD  — Gmail App Password (NOT your login password)
                                   Generate one at: Google Account → Security →
                                   2-Step Verification → App passwords

    Optional:
        FEEDBACK_RECEIVER_EMAIL  — where feedback is delivered (defaults to FEEDBACK_EMAIL)
    """
    sender_email = os.getenv("FEEDBACK_EMAIL", "").strip()
    password = os.getenv("FEEDBACK_EMAIL_PASSWORD", "").strip()
    receiver_email = os.getenv("FEEDBACK_RECEIVER_EMAIL", sender_email).strip()

    if not sender_email or not password:
        raise ValueError(
            "FEEDBACK_EMAIL and FEEDBACK_EMAIL_PASSWORD must both be set as "
            "environment variables. Use a Gmail App Password, not your login password."
        )

    # Build a proper MIME message so it isn't misread as spam
    msg = MIMEMultipart("alternative")
    msg["Subject"] = f"PIATRA Feedback{f' from user {user_id}' if user_id else ''}"
    msg["From"] = sender_email
    msg["To"] = receiver_email

    body = feedback_text
    if user_id:
        body = f"User ID: {user_id}\n\n{feedback_text}"

    msg.attach(MIMEText(body, "plain"))

    context = ssl.create_default_context()
    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465, context=context) as server:
            server.login(sender_email, password)
            server.sendmail(sender_email, receiver_email, msg.as_string())
        print(f"[feedback_email] ✅ Sent to {receiver_email}")
    except smtplib.SMTPAuthenticationError as e:
        raise RuntimeError(
            "Gmail authentication failed. Make sure FEEDBACK_EMAIL_PASSWORD is a "
            "Gmail App Password (16 chars, no spaces), not your login password. "
            f"Original error: {e}"
        ) from e
    except Exception as e:
        raise RuntimeError(f"SMTP send failed: {e}") from e