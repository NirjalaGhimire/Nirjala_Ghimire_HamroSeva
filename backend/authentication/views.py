import re
import secrets
import random
import requests
from datetime import datetime, timezone, timedelta
from rest_framework import status, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenRefreshView
from django.conf import settings
from django.shortcuts import render
from django.http import JsonResponse
from .serializers import (
    LoginSerializer,
    CustomerRegistrationSerializer,
    ProviderRegistrationSerializer,
    UserProfileSerializer,
)
from .models import User
from supabase_config import get_supabase_client


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
@permission_classes([permissions.AllowAny])
def login(request):
    serializer = LoginSerializer(data=request.data)
    if serializer.is_valid():
        user = serializer.validated_data['user']
        refresh = RefreshToken.for_user(user)
        
        return Response({
            'user': UserProfileSerializer(user).data,
            'tokens': {
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            }
        })
    return Response(
        {"message": _errors_to_message(serializer.errors), **serializer.errors},
        status=status.HTTP_400_BAD_REQUEST,
    )


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def register_customer(request):
    serializer = CustomerRegistrationSerializer(data=request.data)
    if serializer.is_valid():
        try:
            user = serializer.save()
        except ValueError as e:
            err = str(e).lower()
            if 'duplicate key' in err and 'phone' in err:
                msg = 'This phone number is already registered.'
            elif 'duplicate key' in err and 'email' in err:
                msg = 'This email is already registered.'
            else:
                msg = str(e)
            return Response(
                {'message': msg},
                status=status.HTTP_400_BAD_REQUEST
            )
        refresh = RefreshToken.for_user(user)
        return Response({
            'user': UserProfileSerializer(user).data,
            'tokens': {
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            }
        }, status=status.HTTP_201_CREATED)
    return Response(
        {"message": _errors_to_message(serializer.errors), **serializer.errors},
        status=status.HTTP_400_BAD_REQUEST,
    )


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def register_provider(request):
    serializer = ProviderRegistrationSerializer(data=request.data)
    if serializer.is_valid():
        try:
            user = serializer.save()
        except ValueError as e:
            err = str(e).lower()
            if 'duplicate key' in err and 'phone' in err:
                msg = 'This phone number is already registered.'
            elif 'duplicate key' in err and 'email' in err:
                msg = 'This email is already registered.'
            else:
                msg = str(e)
            return Response(
                {'message': msg},
                status=status.HTTP_400_BAD_REQUEST
            )
        refresh = RefreshToken.for_user(user)
        return Response({
            'user': UserProfileSerializer(user).data,
            'tokens': {
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            }
        }, status=status.HTTP_201_CREATED)
    return Response(
        {"message": _errors_to_message(serializer.errors), **serializer.errors},
        status=status.HTTP_400_BAD_REQUEST,
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
    while True:
        try:
            user = User.objects.get(email=email)
            break
        except User.DoesNotExist:
            try:
                user = User.objects.create_user(
                    username=username,
                    email=email,
                    password=secrets.token_urlsafe(24),
                    role='customer',
                )
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
    return Response({
        'user': UserProfileSerializer(user).data,
        'tokens': {
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        },
    }, status=status.HTTP_200_OK)


# --- Forgot password flow ---

def _generate_reset_code():
    return ''.join(random.choices('0123456789', k=4))


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def forgot_password(request):
    """
    POST body: { "email": "..." } or { "phone": "..." }
    Finds user, creates 4-digit code, stores in seva_password_reset. Returns success (code sent via email/SMS in production).
    """
    email = (request.data.get('email') or '').strip()
    phone = (request.data.get('phone') or '').strip()
    if email and phone:
        return Response({'message': 'Provide either email or phone, not both.'}, status=status.HTTP_400_BAD_REQUEST)
    if not email and not phone:
        return Response({'message': 'Email or phone is required.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        if email:
            user = User.objects.get(email=email)
            contact_type, contact_value = 'email', email
        else:
            user = User.objects.get(phone=phone)
            contact_type, contact_value = 'phone', phone
    except User.DoesNotExist:
        return Response({'message': 'No account found with this email or phone.'}, status=status.HTTP_400_BAD_REQUEST)

    code = _generate_reset_code()
    expires_at = (datetime.now(timezone.utc) + timedelta(minutes=15)).isoformat()
    supabase = get_supabase_client()
    try:
        supabase.table('seva_password_reset').insert({
            'contact_type': contact_type,
            'contact_value': contact_value,
            'code': code,
            'expires_at': expires_at,
        }).execute()
    except Exception as e:
        return Response({'message': 'Could not create reset code. Try again.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    # TODO: send code via email or SMS in production.
    payload = {'message': 'If an account exists, a code has been sent.'}
    if getattr(settings, 'DEBUG', False):
        payload['code'] = code  # only in dev so you can test without email/SMS
    return Response(payload, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def verify_reset_code(request):
    """
    POST body: { "contact_value": "...", "is_email": true|false, "code": "1234" }
    Returns { "reset_token": "..." } on success.
    """
    contact_value = (request.data.get('contact_value') or '').strip()
    is_email = request.data.get('is_email', True)
    code = (request.data.get('code') or '').strip()
    if not contact_value or not code:
        return Response({'message': 'contact_value and code are required.'}, status=status.HTTP_400_BAD_REQUEST)

    contact_type = 'email' if is_email else 'phone'
    supabase = get_supabase_client()
    try:
        r = supabase.table('seva_password_reset').select('*').eq(
            'contact_type', contact_type
        ).eq('contact_value', contact_value).eq('code', code).execute()
    except Exception as e:
        return Response({'message': 'Verification failed.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    if not r.data or len(r.data) == 0:
        return Response({'message': 'Invalid or expired code.'}, status=status.HTTP_400_BAD_REQUEST)
    row = r.data[0]
    expires_at = row.get('expires_at')
    if expires_at:
        try:
            s = expires_at if isinstance(expires_at, str) else str(expires_at)
            s = s.replace('Z', '+00:00')
            exp = datetime.fromisoformat(s)
            if exp.tzinfo is None:
                exp = exp.replace(tzinfo=timezone.utc)
            if datetime.now(timezone.utc) > exp:
                return Response({'message': 'Code has expired.'}, status=status.HTTP_400_BAD_REQUEST)
        except Exception:
            pass

    reset_token = secrets.token_urlsafe(32)
    try:
        supabase.table('seva_password_reset').update({
            'reset_token': reset_token,
        }).eq('id', row['id']).execute()
    except Exception as e:
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
    if len(new_password) < 6:
        return Response({'message': 'Password must be at least 6 characters.'}, status=status.HTTP_400_BAD_REQUEST)

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

