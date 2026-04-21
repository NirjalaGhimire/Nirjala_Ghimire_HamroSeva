import re
import json
import secrets
import requests
import time
import hmac
import os
from collections import defaultdict
from datetime import datetime, timezone, timedelta
from rest_framework import status, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenRefreshView
import logging
from django.shortcuts import render
from django.http import JsonResponse
from django.conf import settings
from django.contrib.auth.hashers import check_password, make_password
from django.core.validators import validate_email as django_validate_email
from django.core.exceptions import ValidationError as DjangoValidationError
from .serializers import (
    LoginSerializer,
    CustomerRegistrationSerializer,
    ProviderRegistrationSerializer,
    UserProfileSerializer,
)
from .models import User
from supabase_config import get_supabase_client

logger = logging.getLogger(__name__)

PROVIDER_VERIFICATION_TABLE = 'seva_provider_verification'
PROVIDER_VERIFICATION_STATUS_PENDING = 'pending'
VALID_ID_DOCUMENT_TYPES = {'national_id', 'citizenship_card', 'passport'}


def _save_registration_file(uploaded_file, provider_id, tag):
    ext = os.path.splitext(getattr(uploaded_file, 'name', '') or '')[1] or '.bin'
    if ext.lower() not in ('.pdf', '.jpg', '.jpeg', '.png', '.webp'):
        ext = '.bin'
    base_name = f"{provider_id}_{tag}_{int(time.time())}{ext}"
    safe_name = "".join(c for c in base_name if c.isalnum() or c in '._-') or f"{provider_id}_{tag}{ext}"
    upload_dir = os.path.join(settings.MEDIA_ROOT, 'verifications')
    os.makedirs(upload_dir, exist_ok=True)
    path = os.path.join(upload_dir, safe_name)
    with open(path, 'wb') as f:
        for chunk in uploaded_file.chunks():
            f.write(chunk)
    return f"{settings.MEDIA_URL}verifications/{safe_name}"


def _safe_update_auth_user(supabase, user_id, payload):
    """
    Update seva_auth_user while tolerating optional/missing columns on older schemas.
    Retries after dropping unknown columns reported by PostgREST (PGRST204).
    """
    data = dict(payload or {})
    while data:
        try:
            return supabase.table('seva_auth_user').update(data).eq('id', user_id).execute()
        except Exception as e:
            msg = str(e)
            if 'PGRST204' not in msg or "Could not find the '" not in msg:
                raise
            missing = msg.split("Could not find the '", 1)[1].split("' column", 1)[0]
            if missing not in data:
                raise
            data.pop(missing, None)
    return None

from .password_reset_otp import (
    generate_numeric_otp,
    is_expired,
    otp_expires_at,
    otp_storage_hash,
)
from .password_reset_delivery import send_password_reset_email
from .password_reset_delivery import send_registration_verification_email

# Forgot-password rate limits (in-memory; use Redis in multi-worker production)
_RESET_IP_BUCKETS = defaultdict(list)  # ip -> [unix_ts, ...]
_CONTACT_LAST_SEND = {}  # normalized contact -> unix_ts (after successful OTP queue)

FORGOT_PASSWORD_MESSAGE = (
    "If an account exists for this email, a verification code has been sent."
)

EMAIL_VERIFICATION_TABLE = 'seva_email_verification'
REGISTRATION_OTP_LENGTH = 6
REGISTRATION_OTP_EXPIRY_MINUTES = 10
REGISTRATION_RESEND_COOLDOWN_SECONDS = 60
MAX_REGISTRATION_VERIFY_ATTEMPTS = 5


def _client_ip(request):
    xff = request.META.get('HTTP_X_FORWARDED_FOR')
    if xff:
        return xff.split(',')[0].strip()
    return (request.META.get('REMOTE_ADDR') or '').strip() or 'unknown'


def _ip_forgot_rate_ok(ip: str, max_per_hour: int = 30) -> bool:
    now = time.time()
    bucket = _RESET_IP_BUCKETS[ip]
    bucket[:] = [t for t in bucket if now - t < 3600]
    if len(bucket) >= max_per_hour:
        return False
    bucket.append(now)
    return True


def _contact_resend_cooldown_ok(norm_contact: str, cooldown_sec: int = 60) -> bool:
    last = _CONTACT_LAST_SEND.get(norm_contact)
    if last is None:
        return True
    return time.time() - last >= cooldown_sec


def _mark_contact_sent(norm_contact: str):
    _CONTACT_LAST_SEND[norm_contact] = time.time()


def _normalize_email(email: str) -> str:
    return (email or '').strip().lower()


def _validate_email_format(email: str):
    try:
        django_validate_email(email)
    except DjangoValidationError:
        raise ValueError('Invalid email format.')


def _load_latest_registration_verification(supabase, email: str, role: str | None = None):
    q = supabase.table(EMAIL_VERIFICATION_TABLE).select('*').eq('email', email)
    if role:
        q = q.eq('role', role)
    res = q.order('id', desc=True).limit(1).execute()
    return res.data[0] if res.data else None


def _seconds_until_resend(last_sent_at) -> int:
    if not last_sent_at:
        return 0
    try:
        s = (last_sent_at if isinstance(last_sent_at, str) else str(last_sent_at)).replace('Z', '+00:00')
        dt = datetime.fromisoformat(s)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        remaining = REGISTRATION_RESEND_COOLDOWN_SECONDS - int((datetime.now(timezone.utc) - dt).total_seconds())
        return max(0, remaining)
    except Exception:
        return 0


def _registration_response_payload(email: str, role: str):
    return {
        'message': 'Verification code sent to your email.',
        'email': email,
        'role': role,
        'verification_required': True,
        'expires_in_seconds': REGISTRATION_OTP_EXPIRY_MINUTES * 60,
        'resend_cooldown_seconds': REGISTRATION_RESEND_COOLDOWN_SECONDS,
    }


def _build_pending_registration_payload(role: str, validated_data: dict, initial_data: dict):
    payload = {
        'username': (validated_data.get('username') or '').strip(),
        'email': _normalize_email(validated_data.get('email') or ''),
        'phone': (validated_data.get('phone') or '').strip(),
        'district': (validated_data.get('district') or '').strip(),
        'city': (validated_data.get('city') or '').strip(),
        'password_hash': make_password(validated_data.get('password') or ''),
        'role': role,
    }
    if role == 'customer':
        referral_code = (initial_data.get('referral_code') or '').strip()
        if referral_code:
            payload['referral_code'] = referral_code
    else:
        payload['profession'] = (validated_data.get('profession') or '').strip()
        raw_services = initial_data.get('services_offered')
        if isinstance(raw_services, str):
            try:
                raw_services = json.loads(raw_services)
            except Exception:
                raw_services = None
        if raw_services is not None:
            payload['services_offered'] = ProviderRegistrationSerializer._normalize_services_offered(raw_services)
    return payload


def _persist_pending_registration(supabase, email: str, role: str, code_hash: str, payload: dict):
    now_iso = datetime.now(timezone.utc).isoformat()
    row = {
        'email': email,
        'role': role,
        'code_hash': code_hash,
        'registration_payload': payload,
        'created_at': now_iso,
        'expires_at': otp_expires_at(minutes=REGISTRATION_OTP_EXPIRY_MINUTES),
        'verification_status': 'pending',
        'is_verified': False,
        'verified_at': None,
        'last_sent_at': now_iso,
        'verify_attempts': 0,
        'send_count': 1,
    }
    try:
        supabase.table(EMAIL_VERIFICATION_TABLE).delete().eq('email', email).eq('role', role).execute()
    except Exception:
        pass
    try:
        supabase.table(EMAIL_VERIFICATION_TABLE).insert(row).execute()
    except Exception as e:
        # Fallback for partially migrated schemas.
        fallback = {
            'email': email,
            'role': role,
            'code_hash': code_hash,
            'registration_payload': payload,
            'expires_at': otp_expires_at(minutes=REGISTRATION_OTP_EXPIRY_MINUTES),
            'verification_status': 'pending',
            'is_verified': False,
        }
        try:
            supabase.table(EMAIL_VERIFICATION_TABLE).insert(fallback).execute()
        except Exception:
            raise e


def _create_customer_from_pending(payload: dict):
    referral_code_input = (payload.get('referral_code') or '').strip()
    referred_by_id = None
    if referral_code_input:
        try:
            supabase = get_supabase_client()
            r = (
                supabase
                .table('seva_auth_user')
                .select('id')
                .ilike('referral_code', referral_code_input)
                .limit(1)
                .execute()
            )
            if r.data and len(r.data) > 0:
                referred_by_id = r.data[0]['id']
        except Exception:
            referred_by_id = None

    user = User.objects.create_user(
        username=(payload.get('username') or '').strip(),
        email=(payload.get('email') or '').strip(),
        phone=(payload.get('phone') or '').strip() or None,
        district=(payload.get('district') or '').strip(),
        city=(payload.get('city') or '').strip(),
        password=payload.get('password_hash') or '',
        _password_hashed=True,
        role='customer',
        verification_status='unverified',
        is_verified=False,
        is_active_provider=False,
        email_verified=True,
        referred_by_id=referred_by_id,
    )

    if referred_by_id is not None and getattr(user, 'id', None):
        try:
            supabase = get_supabase_client()
            supabase.table('seva_referral').insert({
                'referrer_id': referred_by_id,
                'referred_user_id': user.id,
                'status': 'signed_up',
                'points_referrer': 0,
                'points_referred': 0,
            }).execute()
        except Exception:
            pass

    return user


def _create_provider_from_pending(payload: dict):
    user = User.objects.create_user(
        username=(payload.get('username') or '').strip() or (payload.get('email') or '').strip(),
        email=(payload.get('email') or '').strip(),
        phone=(payload.get('phone') or '').strip() or None,
        district=(payload.get('district') or '').strip(),
        city=(payload.get('city') or '').strip(),
        profession=(payload.get('profession') or '').strip(),
        password=payload.get('password_hash') or '',
        _password_hashed=True,
        role='provider',
        verification_status='unverified',
        is_verified=False,
        is_active_provider=False,
        email_verified=True,
    )

    services_offered = payload.get('services_offered') or []
    if services_offered:
        try:
            titles = sorted({
                (s.get('title') or '').strip()
                for s in services_offered
                if isinstance(s, dict) and (s.get('title') or '').strip()
            })
            if titles:
                supabase = get_supabase_client()
                supabase.table('seva_auth_user').update({
                    'qualification': ', '.join(titles)[:1000],
                }).eq('id', user.id).execute()
        except Exception:
            pass

    return user


def _start_registration_verification(request, serializer_cls, role: str):
    serializer = serializer_cls(data=request.data)
    if not serializer.is_valid():
        return Response(
            {'message': _errors_to_message(serializer.errors), **serializer.errors},
            status=status.HTTP_400_BAD_REQUEST,
        )

    validated = serializer.validated_data
    email = _normalize_email(validated.get('email') or '')
    try:
        _validate_email_format(email)
    except ValueError as e:
        return Response({'message': str(e)}, status=status.HTTP_400_BAD_REQUEST)

    try:
        User.objects.get(email=email)
        return Response({'message': 'This email is already registered.'}, status=status.HTTP_400_BAD_REQUEST)
    except User.DoesNotExist:
        pass

    supabase = get_supabase_client()
    existing = _load_latest_registration_verification(supabase, email, role)
    if existing and not bool(existing.get('is_verified')):
        remaining = _seconds_until_resend(existing.get('last_sent_at'))
        if remaining > 0 and not is_expired(existing.get('expires_at')):
            return Response(
                {
                    'message': 'Please wait before requesting another code.',
                    'retry_after_seconds': remaining,
                },
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

    payload = _build_pending_registration_payload(role, validated, request.data)
    code = generate_numeric_otp(REGISTRATION_OTP_LENGTH)
    code_hash = otp_storage_hash(email, code)

    ok, _err = send_registration_verification_email(email, code)
    if not ok:
        logger.warning('Registration email verification send failed: %s', _err or 'unknown')
        return Response(
            {'message': 'Failed to send verification code. Please try again.'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    try:
        _persist_pending_registration(supabase, email, role, code_hash, payload)
    except Exception:
        return Response(
            {'message': 'Could not start email verification. Please try again.'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    return Response(_registration_response_payload(email, role), status=status.HTTP_200_OK)


def _errors_to_message(errors):
    """Turn DRF serializer errors into a single string for the app."""
    if not errors:
        return "Invalid request"
    parts = []
    for key, value in errors.items():
        if isinstance(value, list):
            parts.append(f"{key}: {'; '.join(str(v) for v in value)}")
        else:
            parts.append(f"{key}: {value}")
    return " ".join(parts)


def health(request):
    return JsonResponse({"status": "ok", "project": "Hamro Sewa"})

@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def debug_password_check(request):
    """Debug endpoint to test password verification (development only)."""
    if not settings.DEBUG:
        return Response(
            {'message': 'Debug endpoint not available in production.'},
            status=status.HTTP_403_FORBIDDEN,
        )
    
    user_id = getattr(request.user, 'id', None)
    if not user_id:
        return Response({'message': 'Not authenticated.'}, status=status.HTTP_401_UNAUTHORIZED)
    
    password = (request.data.get('password') or '').strip()
    if not password:
        return Response({'message': 'Password required.'}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        user = User.objects.get(id=user_id)
    except User.DoesNotExist:
        return Response({'message': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)
    
    # Fetch from Supabase
    supabase = get_supabase_client()
    try:
        sb_user = supabase.table('seva_auth_user').select('password, username, email').eq('id', user_id).limit(1).execute()
        sb_data = sb_user.data[0] if sb_user.data else {}
    except Exception as e:
        sb_data = {'error': str(e)}
    
    # Django user info
    django_password = getattr(user, 'password', None)
    
    # Test password check
    try:
        is_valid_django = user.check_password(password)
    except Exception as e:
        is_valid_django = f"Error: {e}"
    
    try:
        sb_password = sb_data.get('password')
        is_valid_sb = check_password(password, sb_password) if sb_password else False
    except Exception as e:
        is_valid_sb = f"Error: {e}"
    
    return Response({
        'user_id': user_id,
        'django': {
            'has_password': bool(django_password),
            'password_valid': is_valid_django,
            'password_hash_preview': django_password[:20] + '...' if django_password and len(django_password) > 20 else django_password,
        },
        'supabase': {
            'user_data': {
                'username': sb_data.get('username'),
                'email': sb_data.get('email'),
                'has_password': bool(sb_data.get('password')),
            },
            'password_valid': is_valid_sb,
            'password_hash_preview': sb_data.get('password', '')[:20] + '...' if sb_data.get('password') and len(sb_data.get('password', '')) > 20 else sb_data.get('password'),
        },
    }, status=status.HTTP_200_OK)

@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def login(request):
    username = (request.data.get('username') or '').strip()
    password = request.data.get('password') or ''

    if not username or not password:
        return Response(
            {'message': 'Username and password are required.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user = None
    try:
        if '@' in username:
            try:
                user = User.objects.get(email__iexact=username)
            except Exception:
                user = User.objects.get(email=username)
        elif username.isdigit():
            user = User.objects.get(phone=username)
        else:
            try:
                user = User.objects.get_by_username_ignore_case(username)
            except User.DoesNotExist:
                try:
                    user = User.objects.get(email__iexact=username)
                except Exception:
                    user = User.objects.get(email=username)
    except User.DoesNotExist:
        return Response(
            {'message': 'No user found with this username or email.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if str(getattr(user, 'username', '') or '').startswith('deleted_'):
        return Response(
            {'message': 'User account is disabled.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if not bool(getattr(user, 'is_active', True)):
        try:
            user.is_active = True
            user.save()
        except Exception:
            pass

    stored_password = getattr(user, 'password', None) or ''
    password_ok = False
    try:
        password_ok = check_password(password, stored_password)
    except Exception:
        password_ok = False
    if not password_ok and '$' not in str(stored_password) and str(stored_password).strip() == password:
        password_ok = True

    if not password_ok:
        return Response(
            {'message': 'Invalid password.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if not bool(getattr(user, 'email_verified', False)):
        try:
            user.email_verified = True
            user.save()
        except Exception:
            pass

    refresh = RefreshToken.for_user(user)

    return Response({
        'user': UserProfileSerializer(user).data,
        'tokens': {
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        }
    })


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def register_customer(request):
    return _start_registration_verification(
        request,
        serializer_cls=CustomerRegistrationSerializer,
        role='customer',
    )


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def register_provider(request):
    return _start_registration_verification(
        request,
        serializer_cls=ProviderRegistrationSerializer,
        role='provider',
    )


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def send_registration_otp(request):
    role = (request.data.get('role') or '').strip().lower()
    if role == 'customer':
        serializer_cls = CustomerRegistrationSerializer
    elif role == 'provider':
        serializer_cls = ProviderRegistrationSerializer
    else:
        return Response(
            {'message': 'role must be either customer or provider.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    return _start_registration_verification(request, serializer_cls=serializer_cls, role=role)


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def resend_registration_otp(request):
    email = _normalize_email(request.data.get('email') or '')
    role = (request.data.get('role') or '').strip().lower()
    if role not in ('customer', 'provider'):
        return Response({'message': 'role must be customer or provider.'}, status=status.HTTP_400_BAD_REQUEST)
    if not email:
        return Response({'message': 'email is required.'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        _validate_email_format(email)
    except ValueError as e:
        return Response({'message': str(e)}, status=status.HTTP_400_BAD_REQUEST)

    try:
        User.objects.get(email=email)
        return Response({'message': 'This email is already registered.'}, status=status.HTTP_400_BAD_REQUEST)
    except User.DoesNotExist:
        pass

    supabase = get_supabase_client()
    row = _load_latest_registration_verification(supabase, email, role)
    if not row or bool(row.get('is_verified')):
        return Response(
            {'message': 'No pending registration found for this email. Please register again.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    remaining = _seconds_until_resend(row.get('last_sent_at'))
    if remaining > 0:
        return Response(
            {'message': 'Please wait before requesting another code.', 'retry_after_seconds': remaining},
            status=status.HTTP_429_TOO_MANY_REQUESTS,
        )

    code = generate_numeric_otp(REGISTRATION_OTP_LENGTH)
    code_hash = otp_storage_hash(email, code)
    ok, _err = send_registration_verification_email(email, code)
    if not ok:
        logger.warning('Resend registration OTP failed: %s', _err or 'unknown')
        return Response(
            {'message': 'Failed to send verification code. Please try again.'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    now_iso = datetime.now(timezone.utc).isoformat()
    update_payload = {
        'code_hash': code_hash,
        'expires_at': otp_expires_at(minutes=REGISTRATION_OTP_EXPIRY_MINUTES),
        'verification_status': 'pending',
        'last_sent_at': now_iso,
        'verify_attempts': 0,
        'send_count': int(row.get('send_count') or 0) + 1,
    }
    try:
        supabase.table(EMAIL_VERIFICATION_TABLE).update(update_payload).eq('id', row['id']).execute()
    except Exception:
        # Fallback for old schemas without optional columns.
        supabase.table(EMAIL_VERIFICATION_TABLE).update({
            'code_hash': code_hash,
            'expires_at': otp_expires_at(minutes=REGISTRATION_OTP_EXPIRY_MINUTES),
            'verification_status': 'pending',
        }).eq('id', row['id']).execute()

    data = _registration_response_payload(email, role)
    data['message'] = 'A new verification code has been sent.'
    return Response(data, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def verify_registration_otp(request):
    email = _normalize_email(request.data.get('email') or '')
    role = (request.data.get('role') or '').strip().lower()
    code = (request.data.get('code') or '').strip()
    if role not in ('customer', 'provider'):
        return Response({'message': 'role must be customer or provider.'}, status=status.HTTP_400_BAD_REQUEST)
    if not email:
        return Response({'message': 'email is required.'}, status=status.HTTP_400_BAD_REQUEST)
    if not code:
        return Response({'message': 'code is required.'}, status=status.HTTP_400_BAD_REQUEST)
    if not re.fullmatch(r'\d{6}', code):
        return Response({'message': 'Verification code must be a 6-digit number.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        _validate_email_format(email)
    except ValueError as e:
        return Response({'message': str(e)}, status=status.HTTP_400_BAD_REQUEST)

    supabase = get_supabase_client()
    row = _load_latest_registration_verification(supabase, email, role)
    if not row or bool(row.get('is_verified')):
        return Response(
            {'message': 'Verification code is missing. Please register again.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if is_expired(row.get('expires_at')):
        try:
            supabase.table(EMAIL_VERIFICATION_TABLE).update({'verification_status': 'expired'}).eq('id', row['id']).execute()
        except Exception:
            pass
        return Response({'message': 'Verification code has expired. Please resend a new code.'}, status=status.HTTP_400_BAD_REQUEST)

    attempts = int(row.get('verify_attempts') or 0)
    if attempts >= MAX_REGISTRATION_VERIFY_ATTEMPTS:
        return Response(
            {'message': 'Too many wrong attempts. Please resend a new code.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    expected = row.get('code_hash') or ''
    supplied = otp_storage_hash(email, code)
    if not expected or not hmac.compare_digest(str(expected), supplied):
        try:
            supabase.table(EMAIL_VERIFICATION_TABLE).update({
                'verify_attempts': attempts + 1,
            }).eq('id', row['id']).execute()
        except Exception:
            pass
        return Response({'message': 'Wrong verification code.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        User.objects.get(email=email)
        return Response({'message': 'This email is already registered.'}, status=status.HTTP_400_BAD_REQUEST)
    except User.DoesNotExist:
        pass

    payload = row.get('registration_payload') or {}
    if not isinstance(payload, dict):
        return Response({'message': 'Registration data is invalid. Please register again.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        if role == 'customer':
            user = _create_customer_from_pending(payload)
        else:
            user = _create_provider_from_pending(payload)
    except ValueError as e:
        return Response({'message': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.exception('Account creation after OTP verification failed')
        return Response(
            {'message': 'Failed to complete registration. Please try again.'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    try:
        supabase.table(EMAIL_VERIFICATION_TABLE).update({
            'is_verified': True,
            'verification_status': 'verified',
            'verified_at': datetime.now(timezone.utc).isoformat(),
            'code_hash': None,
            'registration_payload': None,
        }).eq('id', row['id']).execute()
    except Exception:
        pass

    return Response(
        {
            'message': 'Email verified successfully. Your account has been created.',
            'user': UserProfileSerializer(user).data,
            'registration_success': True,
        },
        status=status.HTTP_201_CREATED,
    )


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def me(request):
    serializer = UserProfileSerializer(request.user)
    return Response(serializer.data)

@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def logout(request):
    try:
        refresh_token = request.data.get("refresh")
        if refresh_token:
            token = RefreshToken(refresh_token)
            token.blacklist()
        return Response({"message": "Successfully logged out"}, status=status.HTTP_200_OK)
    except Exception as e:
        return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def change_password(request):
    """Change the current user's password.

    Body: { "current_password": "...", "new_password": "..." }
    """
    current = (request.data.get('current_password') or '').strip()
    new_password = (request.data.get('new_password') or '').strip()

    if not current or not new_password:
        return Response(
            {'message': 'current_password and new_password are required.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if len(new_password) < 6:
        return Response(
            {'message': 'New password must be at least 6 characters.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user = request.user
    if not user.check_password(current):
        return Response(
            {'message': 'Current password is incorrect.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user.set_password(new_password)
    user.save()
    return Response({'message': 'Password updated successfully.'}, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def delete_account(request):
    """Deactivate the current user account.

    Body: { "password": "..." } (required for password-protected accounts).
    """
    user_id = getattr(request.user, 'id', None)
    if not user_id:
        return Response(
            {'message': 'User not authenticated.'},
            status=status.HTTP_401_UNAUTHORIZED,
        )
    
    # Fetch fresh user from database to ensure password field is loaded
    try:
        user = User.objects.get(id=user_id)
    except User.DoesNotExist:
        return Response(
            {'message': 'User not found.'},
            status=status.HTTP_404_NOT_FOUND,
        )
    
    password = (request.data.get('password') or '').strip()
    
    # Fetch password from Supabase to ensure we have the correct hash
    supabase = get_supabase_client()
    try:
        supabase_user = supabase.table('seva_auth_user').select('password').eq('id', user_id).limit(1).execute()
        supabase_password_hash = supabase_user.data[0].get('password') if supabase_user.data else None
    except Exception as e:
        logger.warning(f"Could not fetch password from Supabase for user {user_id}: {e}")
        supabase_password_hash = None
    
    # Get password from Django ORM as fallback
    django_password_hash = getattr(user, 'password', None) or ''
    
    # Use Supabase password if available, otherwise Django password
    password_hash_to_check = supabase_password_hash or django_password_hash
    
    # Check if user has a usable password
    has_usable_password = bool(password_hash_to_check and '$' in str(password_hash_to_check))
    
    if has_usable_password:
        # Password is required for accounts with passwords
        if not password:
            return Response(
                {'message': 'Password is required to delete this account.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        # Verify the password using Django's check_password
        try:
            password_valid = check_password(password, password_hash_to_check)
        except Exception as e:
            logger.error(f"Password verification failed for user {user_id}: {e}")
            password_valid = False
        
        if not password_valid:
            logger.warning(f"Invalid password attempt for delete_account by user {user_id}")
            return Response(
                {'message': 'Password is incorrect.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
    elif password:
        # User doesn't have password (social login) but provided one - still accept
        pass

    try:
        original_id = user.id
        user.is_active = False
        # Anonymize key fields so the account can't be reused and doesn't conflict with new signups.
        user.username = f"deleted_{original_id}_{int(datetime.now(timezone.utc).timestamp())}"
        user.email = f"deleted_{original_id}@hamroseva.local"
        user.phone = None
        user.set_unusable_password()
        user.save()
        
        # Also update Supabase if record exists there
        try:
            supabase.table('seva_auth_user').update({
                'is_active': False,
                'username': user.username,
                'email': user.email,
                'phone': None,
            }).eq('id', original_id).execute()
        except Exception as e:
            logger.warning(f"Supabase update for delete_account failed: {e}")
            # Supabase update is optional; proceed if it fails
            pass
        
        logger.info(f"User {original_id} account deleted successfully")
        return Response({'message': 'Account deleted successfully.'}, status=status.HTTP_200_OK)
    except Exception as e:
        logger.exception("Account deletion failed")
        return Response({'message': 'Failed to delete account.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# --- Social login (Facebook, Google) ---

def _verify_facebook_token(access_token):
    """Verify Facebook access token and return dict with email, name. Raises ValueError on failure."""
    try:
        r = requests.get(
            'https://graph.facebook.com/me',
            params={'access_token': access_token, 'fields': 'id,name,email'},
            timeout=10,
        )
        if r.status_code != 200:
            raise ValueError('Invalid or expired Facebook token')
        data = r.json()
        email = (data.get('email') or '').strip()
        if not email:
            raise ValueError('Facebook did not provide an email. Please allow email permission.')
        name = (data.get('name') or email.split('@')[0] or 'User').strip()
        return {'email': email, 'name': name}
    except requests.RequestException as e:
        raise ValueError(f'Facebook verification failed: {e}') from e


def _verify_google_token(id_token):
    """Verify Google ID token and return dict with email, name. Raises ValueError on failure."""
    try:
        r = requests.get(
            'https://oauth2.googleapis.com/tokeninfo',
            params={'id_token': id_token},
            timeout=10,
        )
        if r.status_code != 200:
            raise ValueError('Invalid or expired Google token')
        data = r.json()
        email = (data.get('email') or '').strip()
        if not email:
            raise ValueError('Google did not provide an email.')
        name = (data.get('name') or data.get('given_name') or email.split('@')[0] or 'User').strip()
        return {'email': email, 'name': name}
    except requests.RequestException as e:
        raise ValueError(f'Google verification failed: {e}') from e


def _sanitize_username(name):
    """Make a safe username from display name."""
    base = re.sub(r'[^a-zA-Z0-9\s]', '', (name or 'user')).replace(' ', '_').strip('_')[:25]
    return base.lower() or 'user'


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def social_login(request):
    """
    POST body: { "provider": "facebook"|"google", "token": "<access_token or id_token>" }
    Verifies token with provider, gets or creates user by email, returns same JWT as login.
    """
    provider = (request.data.get('provider') or '').strip().lower()
    token = (request.data.get('token') or '').strip()
    if not provider or not token:
        return Response(
            {'message': 'provider and token are required'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if provider not in ('facebook', 'google'):
        return Response(
            {'message': 'provider must be facebook or google'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        if provider == 'facebook':
            info = _verify_facebook_token(token)
        else:
            info = _verify_google_token(token)
    except ValueError as e:
        return Response({'message': str(e)}, status=status.HTTP_400_BAD_REQUEST)

    email = info['email']
    name = info['name']
    username_base = _sanitize_username(name)
    username = username_base
    counter = 0
    is_new_user = False
    
    while True:
        try:
            user = User.objects.get(email=email)
            break
        except User.DoesNotExist:
            try:
                # Create user with unusable password for social login
                # They can only log in via social provider
                user = User.objects.create_user(
                    username=username,
                    email=email,
                    password=None,  # No password for social-only users
                    role='customer',
                    email_verified=True,
                    verification_status='unverified',
                    is_verified=False,
                    is_active_provider=False,
                )
                # Explicitly mark password as unusable for social users
                user.set_unusable_password()
                user.save()
                is_new_user = True
                break
            except Exception as create_err:
                if 'duplicate key' in str(create_err).lower() or 'unique' in str(create_err).lower():
                    counter += 1
                    username = f"{username_base}{counter}"
                    continue
                return Response(
                    {'message': 'Could not create account. Try again or sign up with email.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

    refresh = RefreshToken.for_user(user)
    if not bool(getattr(user, 'email_verified', False)):
        try:
            user.email_verified = True
            user.save()
        except Exception:
            pass
    user_data = UserProfileSerializer(user).data
    
    return Response({
        'user': user_data,
        'tokens': {
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        },
        'is_new_user': is_new_user,
    }, status=status.HTTP_200_OK)


# --- Forgot password flow ---

MAX_OTP_VERIFY_ATTEMPTS = 5


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def forgot_password(request):
    """
    POST body: { "contact_value": "...", "is_email": true/false }.
    Sends OTP by email when the account exists. Never returns the OTP.
    """
    contact_value = (
        request.data.get('contact_value')
        or request.data.get('email')
        or request.data.get('username')
        or ''
    ).strip()
    is_email_raw = request.data.get('is_email')
    is_email = True if is_email_raw is None else str(is_email_raw).strip().lower() in ('1', 'true', 'yes')
    if not contact_value:
        return Response(
            {'message': 'Please enter your username or registered email address.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    phone = (request.data.get('phone') or '').strip()
    if phone:
        return Response(
            {'message': 'Password reset uses email only. Enter the email registered on your account.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    ip = _client_ip(request)
    if not _ip_forgot_rate_ok(ip):
        return Response(
            {'message': 'Too many requests. Please try again later.', 'retry_after_seconds': 3600},
            status=status.HTTP_429_TOO_MANY_REQUESTS,
        )

    contact_type = 'email' if is_email else 'username'
    contact_value = _normalize_email(contact_value) if is_email else contact_value.strip()

    if not _contact_resend_cooldown_ok(contact_value):
        remaining = int(60 - (time.time() - _CONTACT_LAST_SEND.get(contact_value, 0)))
        remaining = max(1, remaining)
        return Response(
            {
                'message': 'Please wait before requesting another code.',
                'retry_after_seconds': remaining,
            },
            status=status.HTTP_429_TOO_MANY_REQUESTS,
        )

    user = None
    try:
        if contact_type == 'email':
            user = User.objects.get(email=contact_value)
        else:
            try:
                user = User.objects.get(username__iexact=contact_value)
            except User.DoesNotExist:
                user = User.objects.get(username=contact_value)
    except User.DoesNotExist:
        # Same response as success — do not reveal whether the account exists
        return Response({'message': FORGOT_PASSWORD_MESSAGE}, status=status.HTTP_200_OK)

    code = generate_numeric_otp(4)
    code_hash = otp_storage_hash(contact_value, code)
    expires_at = otp_expires_at(minutes=10)
    supabase = get_supabase_client()

    ok, _err = send_password_reset_email(user.email, code)

    if not ok:
        # Do not persist OTP if delivery failed. Same message as "unknown account" to avoid enumeration.
        logger.warning(
            "Password reset email failed reason=%s — check EMAIL_* in .env (docs/GMAIL_SMTP_PASSWORD_RESET.md)",
            _err or "unknown",
        )
        return Response({'message': FORGOT_PASSWORD_MESSAGE}, status=status.HTTP_200_OK)

    try:
        try:
            supabase.table('seva_password_reset').delete().eq('contact_type', contact_type).eq(
                'contact_value', contact_value
            ).execute()
        except Exception:
            pass
        insert_payload = {
            'contact_type': contact_type,
            'contact_value': contact_value,
            'code': '-',
            'code_hash': code_hash,
            'expires_at': expires_at,
            'verify_attempts': 0,
        }
        try:
            supabase.table('seva_password_reset').insert(insert_payload).execute()
        except Exception as ins_err:
            try:
                supabase.table('seva_password_reset').insert({
                    'contact_type': contact_type,
                    'contact_value': contact_value,
                    'code': '-',
                    'code_hash': code_hash,
                    'expires_at': expires_at,
                }).execute()
            except Exception:
                try:
                    supabase.table('seva_password_reset').insert({
                        'contact_type': contact_type,
                        'contact_value': contact_value,
                        'code': code,
                        'expires_at': expires_at,
                    }).execute()
                except Exception:
                    logger.exception("seva_password_reset insert failed: %s", ins_err)
                    raise
    except Exception:
        return Response({'message': 'Could not create reset code. Try again.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    _mark_contact_sent(contact_value)
    return Response({'message': FORGOT_PASSWORD_MESSAGE}, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def verify_reset_code(request):
    """
    POST body: { "contact_value": "<email or username>", "is_email": true/false, "code": "1234" }.
    Returns { "reset_token": "..." } on success. Never logs the submitted code.
    """
    contact_value = (request.data.get('contact_value') or '').strip()
    is_email_raw = request.data.get('is_email')
    is_email = True if is_email_raw is None else str(is_email_raw).strip().lower() in ('1', 'true', 'yes')
    if is_email:
        contact_value = _normalize_email(contact_value)
    code = (request.data.get('code') or '').strip()
    if not contact_value or not code:
        return Response({'message': 'contact_value and code are required.'}, status=status.HTTP_400_BAD_REQUEST)

    contact_type = 'email' if is_email else 'username'
    supabase = get_supabase_client()
    try:
        r = supabase.table('seva_password_reset').select('*').eq(
            'contact_type', contact_type
        ).eq('contact_value', contact_value).order('id', desc=True).limit(5).execute()
    except Exception:
        return Response({'message': 'Verification failed.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    rows = list(r.data or [])
    row = None
    for candidate in rows:
        if candidate.get('reset_token'):
            continue
        if is_expired(candidate.get('expires_at')):
            continue
        attempts = int(candidate.get('verify_attempts') or 0)
        if attempts >= MAX_OTP_VERIFY_ATTEMPTS:
            continue
        stored_hash = (candidate.get('code_hash') or '').strip()
        legacy_code = (candidate.get('code') or '').strip()
        match = False
        if len(stored_hash) >= 32:
            match = hmac.compare_digest(stored_hash, otp_storage_hash(contact_value, code))
        elif legacy_code and legacy_code not in ('-', ''):
            if len(legacy_code) == len(code):
                match = secrets.compare_digest(legacy_code, code)
        if match:
            row = candidate
            break

    if row is None:
        # Increment attempts on latest non-expired row
        for candidate in rows:
            if candidate.get('reset_token') or is_expired(candidate.get('expires_at')):
                continue
            try:
                aid = candidate.get('id')
                att = int(candidate.get('verify_attempts') or 0) + 1
                supabase.table('seva_password_reset').update({'verify_attempts': att}).eq('id', aid).execute()
            except Exception:
                pass
            break
        return Response({'message': 'Invalid or expired code.'}, status=status.HTTP_400_BAD_REQUEST)

    reset_token = secrets.token_urlsafe(32)
    try:
        supabase.table('seva_password_reset').update({
            'reset_token': reset_token,
        }).eq('id', row['id']).execute()
    except Exception:
        return Response({'message': 'Verification failed.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    return Response({'reset_token': reset_token}, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def set_new_password(request):
    """
    POST body: { "reset_token": "...", "new_password": "..." }
    Validates token, finds user, sets new password.
    """
    reset_token = (request.data.get('reset_token') or '').strip()
    new_password = request.data.get('new_password') or ''
    if not reset_token:
        return Response({'message': 'reset_token is required.'}, status=status.HTTP_400_BAD_REQUEST)
    if len(new_password) < 8:
        return Response({'message': 'Password must be at least 8 characters.'}, status=status.HTTP_400_BAD_REQUEST)

    supabase = get_supabase_client()
    try:
        r = supabase.table('seva_password_reset').select('*').eq('reset_token', reset_token).execute()
    except Exception as e:
        return Response({'message': 'Failed to verify token.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    if not r.data or len(r.data) == 0:
        return Response({'message': 'Invalid or expired reset link.'}, status=status.HTTP_400_BAD_REQUEST)
    row = r.data[0]
    contact_type = row.get('contact_type')
    contact_value = (row.get('contact_value') or '').strip()

    try:
        if contact_type == 'email':
            user = User.objects.get(email=contact_value)
        elif contact_type == 'username':
            try:
                user = User.objects.get(username__iexact=contact_value)
            except User.DoesNotExist:
                user = User.objects.get(username=contact_value)
        else:
            user = User.objects.get(phone=contact_value)
    except User.DoesNotExist:
        return Response({'message': 'User not found.'}, status=status.HTTP_400_BAD_REQUEST)

    user.set_password(new_password)
    user.save()

    try:
        supabase.table('seva_password_reset').delete().eq('id', row['id']).execute()
    except Exception:
        pass

    return Response({'message': 'Password updated. You can log in with your new password.'}, status=status.HTTP_200_OK)


@api_view(['PATCH'])
@permission_classes([permissions.IsAuthenticated])
def accept_terms(request):
    """
    PATCH endpoint to mark terms and conditions as accepted by the user.
    Request body: { "terms_accepted": true }
    """
    try:
        user = request.user
        supabase = get_supabase_client()
        
        # Update user's terms acceptance
        update_data = {
            'terms_accepted': True,
            'terms_accepted_at': datetime.now(timezone.utc).isoformat(),
        }
        
        supabase.table('seva_auth_user').update(update_data).eq('id', user.id).execute()
        
        return Response(
            {'message': 'Terms and conditions accepted successfully.'},
            status=status.HTTP_200_OK
        )
    except Exception as e:
        logger.error(f"Error accepting terms: {e}")
        return Response(
            {'message': 'Failed to accept terms.'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

