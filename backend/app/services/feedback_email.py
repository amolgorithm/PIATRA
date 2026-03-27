import smtplib
import ssl
import os

def send_feedback_email(feedback_text: str, user_id: str = None):
    """
    Send feedback email with the provided message.
    """
    # Get credentials from environment variables
    sender_email = os.getenv('FEEDBACK_EMAIL')
    password = os.getenv('FEEDBACK_EMAIL_PASSWORD')
    receiver_email = os.getenv('FEEDBACK_EMAIL')  # Send to self for now

    if not sender_email or not password:
        raise ValueError("FEEDBACK_EMAIL and FEEDBACK_EMAIL_PASSWORD environment variables must be set")

    port = 465  # For SSL
    smtp_server = "smtp.gmail.com"

    # Build the message
    subject = "User Feedback"
    if user_id:
        subject += f" from User {user_id}"
    message = f"Subject: {subject}\n\n{feedback_text}"

    context = ssl.create_default_context()

    try:
        with smtplib.SMTP_SSL(smtp_server, port, context=context) as server:
            server.login(sender_email, password)
            server.sendmail(sender_email, receiver_email, message)
        print("Feedback email sent successfully!")
    except Exception as e:
        print(f"Failed to send feedback email: {e}")
        raise