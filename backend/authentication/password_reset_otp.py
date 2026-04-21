"""
OTP generation and storage helpers for password reset.
Codes are never logged; only HMAC-SHA256 hashes are stored in Supabase.
"""
from __future__ import annotations

import hashlib
import hmac
import secrets
from datetime import datetime, timezone, timedelta

from django.conf import settings


def generate_numeric_otp(length: int = 4) -> str:
    return "".join(secrets.choice("0123456789") for _ in range(length))


def otp_storage_hash(contact_value: str, code: str) -> str:
    """
    Deterministic hash for comparing submitted OTP without storing plaintext.
    Uses Django SECRET_KEY as pepper (server-side only).
    """
    pepper = (getattr(settings, "SECRET_KEY", "") or "unsafe").encode()
    msg = f"{contact_value.strip().lower()}|{code}".encode()
    return hmac.new(pepper, msg, hashlib.sha256).hexdigest()


def otp_expires_at(minutes: int = 10) -> str:
    return (datetime.now(timezone.utc) + timedelta(minutes=minutes)).isoformat()


def parse_expires_at(expires_at) -> datetime | None:
    if not expires_at:
        return None
    try:
        s = expires_at if isinstance(expires_at, str) else str(expires_at)
        s = s.replace("Z", "+00:00")
        exp = datetime.fromisoformat(s)
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)
        return exp
    except Exception:
        return None


def is_expired(expires_at) -> bool:
    exp = parse_expires_at(expires_at)
    if exp is None:
        return True
    return datetime.now(timezone.utc) > exp
