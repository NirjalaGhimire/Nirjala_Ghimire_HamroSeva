"""
Send password-reset OTP by email only (Django SMTP).

Set EMAIL_HOST, EMAIL_HOST_USER, EMAIL_HOST_PASSWORD, DEFAULT_FROM_EMAIL
(see docs/GMAIL_SMTP_PASSWORD_RESET.md). Never logs the OTP.
"""
from __future__ import annotations

import logging
import os

from django.conf import settings
from django.core.mail import send_mail

logger = logging.getLogger(__name__)


def _mask_contact(contact: str) -> str:
    c = (contact or "").strip()
    if "@" in c:
        local, _, domain = c.partition("@")
        if len(local) <= 2:
            return "***@" + domain
        return local[:2] + "***@" + domain
    if len(c) <= 4:
        return "***"
    return c[:4] + "***"


def send_password_reset_email(to_email: str, otp_code: str) -> tuple[bool, str | None]:
    """
    Returns (success, error_message_for_logs_only).
    Never puts otp_code in logger output.
    """
    subject = "Your Hamro Sewa password reset code"
    body = (
        "You requested to reset your Hamro Sewa password.\n\n"
        "Your verification code is valid for 10 minutes.\n\n"
        "If you did not request this, you can ignore this message.\n"
    )
    full_body = body + f"\nVerification code: {otp_code}\n"

    host = getattr(settings, "EMAIL_HOST", None) or os.environ.get("EMAIL_HOST", "").strip()
    if not host:
        logger.warning("EMAIL_HOST not set — cannot send password reset email")
        return False, "email_not_configured"

    try:
        from_email = (
            getattr(settings, "DEFAULT_FROM_EMAIL", None)
            or os.environ.get("DEFAULT_FROM_EMAIL", "")
            or "noreply@localhost"
        )
        send_mail(
            subject,
            full_body,
            from_email,
            [to_email],
            fail_silently=False,
        )
        logger.info("Password reset email sent via SMTP to %s", _mask_contact(to_email))
        return True, None
    except Exception as e:
        logger.warning("SMTP send failed: %s", type(e).__name__)
        return False, str(e)


def send_registration_verification_email(to_email: str, otp_code: str) -> tuple[bool, str | None]:
    """
    Send registration email verification code.
    Returns (success, error_message_for_logs_only).
    """
    subject = "Your Hamro Sewa registration verification code"
    body = (
        "Welcome to Hamro Sewa.\n\n"
        "Please verify your email to complete account registration.\n"
        "Your verification code is valid for 10 minutes.\n\n"
        "If you did not try to create an account, you can ignore this email.\n"
    )
    full_body = body + f"\nVerification code: {otp_code}\n"

    host = getattr(settings, "EMAIL_HOST", None) or os.environ.get("EMAIL_HOST", "").strip()
    if not host:
        logger.warning("EMAIL_HOST not set — cannot send registration verification email")
        return False, "email_not_configured"

    try:
        from_email = (
            getattr(settings, "DEFAULT_FROM_EMAIL", None)
            or os.environ.get("DEFAULT_FROM_EMAIL", "")
            or "noreply@localhost"
        )
        send_mail(
            subject,
            full_body,
            from_email,
            [to_email],
            fail_silently=False,
        )
        logger.info("Registration verification email sent via SMTP to %s", _mask_contact(to_email))
        return True, None
    except Exception as e:
        logger.warning("SMTP send failed: %s", type(e).__name__)
        return False, str(e)
