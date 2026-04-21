from django.contrib.auth.hashers import make_password
from django.contrib.auth.models import AbstractUser
from django.contrib.auth.base_user import BaseUserManager
from django.db import models
from supabase_config import get_supabase_client
import json
import re
import random
import string
from datetime import datetime


def _generate_referral_code(supabase, username, email):
    """Generate a unique referral code: HAMRO-{SANITIZED}-{YEAR}. Collision: append random."""
    base = (username or email or 'user').strip()
    base = re.sub(r'[^a-zA-Z0-9\s]', '', base).replace(' ', '-').upper()[:12] or 'USER'
    year = str(datetime.now().year)
    candidate = f"HAMRO-{base}-{year}"
    try:
        r = supabase.table('seva_auth_user').select('id').eq('referral_code', candidate).execute()
        if r.data and len(r.data) > 0:
            suffix = ''.join(random.choices(string.ascii_uppercase + string.digits, k=4))
            candidate = f"HAMRO-{base}-{year}-{suffix}"
    except Exception:
        pass
    return candidate


class SupabaseUserManager(BaseUserManager):
    def create_user(self, username, email, password=None, **extra_fields):
        supabase = get_supabase_client()
        email = self.normalize_email(email)
        password_is_hashed = bool(extra_fields.pop('_password_hashed', False))
        # Store hashed password in Supabase (PBKDF2 by default); never store plain text.
        hashed = (
            password
            if (password and password_is_hashed)
            else (make_password(password) if password else make_password(None))
        )
        def _normalize_verification_status_value(value):
            raw = (value or '').strip().lower()
            aliases = {
                'pending_verification': 'pending',
                'under_review': 'pending',
                'on_hold': 'pending',
                'verified': 'approved',
            }
            return aliases.get(
                raw,
                raw if raw in {'unverified', 'pending', 'approved', 'rejected'} else 'unverified',
            )

        role_value = (extra_fields.get('role') or 'customer')
        role_normalized = str(role_value).strip().lower() or 'customer'
        is_provider_role = role_normalized in ('provider', 'prov')
        raw_status = extra_fields.get('verification_status')
        status_normalized = _normalize_verification_status_value(raw_status or 'unverified')
        if not is_provider_role:
            # Verification status is provider-only in this app.
            status_normalized = 'unverified'

        user_data = {
            'username': username,
            'email': email,
            'password': hashed,
            'email_verified': bool(extra_fields.get('email_verified', False)),
            'role': role_normalized,
            'verification_status': status_normalized,
            'is_verified': bool(extra_fields.get('is_verified')) if 'is_verified' in extra_fields else (is_provider_role and status_normalized == 'approved'),
            'is_active_provider': bool(extra_fields.get('is_active_provider')) if 'is_active_provider' in extra_fields else (is_provider_role and status_normalized == 'approved'),
        }
        # Only send profession if set (table may not have column).
        if extra_fields.get('phone') not in (None, ''):
            user_data['phone'] = extra_fields.get('phone')
        if extra_fields.get('profession') not in (None, ''):
            user_data['profession'] = extra_fields.get('profession')
        if extra_fields.get('qualification') not in (None, ''):
            user_data['qualification'] = extra_fields.get('qualification')
        if extra_fields.get('profile_image_url') not in (None, ''):
            user_data['profile_image_url'] = extra_fields.get('profile_image_url')
        # Referral & loyalty: ensure new user has a unique referral code and optional referred_by_id
        referral_code = extra_fields.get('referral_code')
        if referral_code is None:
            referral_code = _generate_referral_code(supabase, username, email)
        user_data['referral_code'] = referral_code
        user_data['loyalty_points'] = int(extra_fields.get('loyalty_points', 0))
        if extra_fields.get('referred_by_id') is not None:
            user_data['referred_by_id'] = extra_fields['referred_by_id']
        if 'district' in extra_fields:
            user_data['district'] = (extra_fields.get('district') or '').strip()
        if 'city' in extra_fields:
            user_data['city'] = (extra_fields.get('city') or '').strip()
        if 'rejection_reason' in extra_fields:
            user_data['rejection_reason'] = extra_fields.get('rejection_reason')
        if 'submitted_at' in extra_fields:
            user_data['submitted_at'] = extra_fields.get('submitted_at')
        if 'reviewed_at' in extra_fields:
            user_data['reviewed_at'] = extra_fields.get('reviewed_at')
        if 'reviewed_by' in extra_fields:
            user_data['reviewed_by'] = extra_fields.get('reviewed_by')
        if 'terms_accepted' in extra_fields:
            user_data['terms_accepted'] = bool(extra_fields.get('terms_accepted'))
        if 'terms_accepted_at' in extra_fields:
            user_data['terms_accepted_at'] = extra_fields.get('terms_accepted_at')
        try:
            response = supabase.table('seva_auth_user').insert(user_data).execute()
            if response.data:
                user_data['id'] = response.data[0]['id']
                return self.model(**user_data)
            raise ValueError("Supabase insert returned no data")
        except Exception as e:
            print(f"Error creating user in Supabase: {e}")
            raise ValueError(f"Registration failed: {e!s}") from e

    def create_superuser(self, username=None, email=None, password=None, **extra_fields):
        """Required for Django's createsuperuser command. Creates user with role=admin."""
        if email is None:
            email = username
        if username is None:
            username = email.split('@')[0] if isinstance(email, str) else 'admin'
        extra_fields.setdefault('role', 'admin')
        return self.create_user(username=username, email=email, password=password, **extra_fields)

    def get_by_natural_key(self, username):
        supabase = get_supabase_client()
        try:
            response = supabase.table('seva_auth_user').select('*').eq('username', username).execute()
            if response.data:
                return self.model(**response.data[0])
        except Exception as e:
            print(f"Error getting user from Supabase: {e}")
            raise
        raise self.model.DoesNotExist(f"User with username={username!r} does not exist.")

    def get(self, *args, **kwargs):
        supabase = get_supabase_client()
        try:
            # Django admin uses get(pk=user_id); ensure we query Supabase, not SQLite
            user_id = kwargs.get('id') or kwargs.get('pk')
            if user_id is not None:
                response = supabase.table('seva_auth_user').select('*').eq('id', user_id).execute()
            elif 'email' in kwargs:
                response = supabase.table('seva_auth_user').select('*').eq('email', kwargs['email']).execute()
            elif 'username' in kwargs:
                response = supabase.table('seva_auth_user').select('*').eq('username', kwargs['username']).execute()
            elif 'phone' in kwargs:
                response = supabase.table('seva_auth_user').select('*').eq('phone', kwargs['phone']).execute()
            else:
                return super().get(*args, **kwargs)
            if not response.data or len(response.data) == 0:
                raise self.model.DoesNotExist()
            return self._user_from_row(response.data[0])
        except self.model.DoesNotExist:
            raise
        except Exception as e:
            print(f"Error getting user from Supabase: {e}")
            raise
    
    def filter(self, *args, **kwargs):
        """
        Keep Django ORM compatibility.
        Admin/model validation expects a QuerySet with methods like exclude().
        """
        return super().filter(*args, **kwargs)

    def supabase_filter(self, *args, **kwargs):
        """
        Supabase-backed list fetch (legacy helper for custom flows).
        Not a Django QuerySet.
        """
        supabase = get_supabase_client()
        try:
            response = supabase.table('seva_auth_user').select('*').execute()
            if response.data:
                users = [self._user_from_row(user_data) for user_data in response.data]
                return users
        except Exception as e:
            print(f"Error filtering users from Supabase: {e}")
        return []

    def _user_from_row(self, row):
        """Build User instance from Supabase row, only passing known model field names."""
        if not row or not isinstance(row, dict):
            raise self.model.DoesNotExist()
        allowed = {f.name for f in self.model._meta.concrete_fields}
        kwargs = {k: v for k, v in row.items() if k in allowed}
        # So Django admin allows login: treat role=admin as staff/superuser
        if row.get('role') == 'admin':
            kwargs['is_staff'] = True
            kwargs['is_superuser'] = True
        return self.model(**kwargs)

    def get_by_username_ignore_case(self, username):
        """Find user by username (case-insensitive). Raises User.DoesNotExist if not found."""
        supabase = get_supabase_client()
        try:
            response = supabase.table('seva_auth_user').select('*').execute()
            if response.data:
                want = (username or '').strip().lower()
                for row in response.data:
                    if (row.get('username') or '').lower() == want:
                        return self._user_from_row(row)
        except Exception as e:
            print(f"Error in get_by_username_ignore_case: {e}")
        raise self.model.DoesNotExist()

class User(AbstractUser):
    VERIFICATION_STATUS_UNVERIFIED = 'unverified'
    VERIFICATION_STATUS_PENDING = 'pending'
    VERIFICATION_STATUS_APPROVED = 'approved'
    VERIFICATION_STATUS_REJECTED = 'rejected'
    VERIFICATION_STATUS_CHOICES = [
        (VERIFICATION_STATUS_UNVERIFIED, 'Unverified'),
        (VERIFICATION_STATUS_PENDING, 'Pending Review'),
        (VERIFICATION_STATUS_APPROVED, 'Approved'),
        (VERIFICATION_STATUS_REJECTED, 'Rejected'),
    ]
    ROLE_CHOICES = [
        ('customer', 'Customer'),
        ('provider', 'Service Provider'),
        ('admin', 'Admin'),
    ]
    
    username = models.CharField(max_length=150, unique=False)  # Remove unique constraint
    email = models.EmailField(unique=True)  # Must be unique for USERNAME_FIELD
    phone = models.CharField(max_length=20, unique=False, blank=True, null=True)  # Remove unique constraint for now
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='customer')
    profession = models.CharField(max_length=100, blank=True, null=True)
    qualification = models.TextField(blank=True, null=True)
    profile_image_url = models.TextField(blank=True, null=True)
    email_verified = models.BooleanField(default=False)
    is_verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    # Referral & loyalty (columns in Supabase seva_auth_user)
    referral_code = models.CharField(max_length=50, blank=True, null=True)
    loyalty_points = models.IntegerField(default=0)
    referred_by_id = models.IntegerField(null=True, blank=True)
    # Location (Nepal): district + city — used for provider discovery / future matching
    district = models.CharField(max_length=120, blank=True, null=True)
    city = models.CharField(max_length=120, blank=True, null=True)
    verification_status = models.CharField(
        max_length=30,
        choices=VERIFICATION_STATUS_CHOICES,
        default=VERIFICATION_STATUS_UNVERIFIED,
    )
    rejection_reason = models.TextField(blank=True, null=True)
    is_active_provider = models.BooleanField(default=False)
    submitted_at = models.DateTimeField(null=True, blank=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)
    reviewed_by = models.IntegerField(null=True, blank=True)
    terms_accepted = models.BooleanField(default=False)  # Track T&C acceptance
    terms_accepted_at = models.DateTimeField(null=True, blank=True)  # When user accepted T&C
    
    USERNAME_FIELD = 'email'  # Use email as the unique field
    REQUIRED_FIELDS = ['username']
    
    objects = SupabaseUserManager()
    
    class Meta:
        managed = False  # Don't let Django manage this table
    
    def save(self, *args, **kwargs):
        supabase = get_supabase_client()
        raw_status = (getattr(self, 'verification_status', None) or '').strip().lower()
        role = (getattr(self, 'role', None) or '').strip().lower()
        is_provider_role = role in ('provider', 'prov')
        status_aliases = {
            'pending_verification': self.VERIFICATION_STATUS_PENDING,
            'under_review': self.VERIFICATION_STATUS_PENDING,
            'on_hold': self.VERIFICATION_STATUS_PENDING,
            'verified': self.VERIFICATION_STATUS_APPROVED,
            'unverified': self.VERIFICATION_STATUS_UNVERIFIED,
            'pending': self.VERIFICATION_STATUS_PENDING,
            'approved': self.VERIFICATION_STATUS_APPROVED,
            'rejected': self.VERIFICATION_STATUS_REJECTED,
        }
        normalized_status = status_aliases.get(raw_status, self.VERIFICATION_STATUS_UNVERIFIED)
        if not is_provider_role:
            # Verification status is provider-only.
            normalized_status = self.VERIFICATION_STATUS_UNVERIFIED
        self.verification_status = normalized_status
        self.is_verified = is_provider_role and normalized_status == self.VERIFICATION_STATUS_APPROVED
        self.is_active_provider = is_provider_role and normalized_status == self.VERIFICATION_STATUS_APPROVED
        if normalized_status != self.VERIFICATION_STATUS_REJECTED:
            self.rejection_reason = None
        user_data = {
            'username': self.username,
            'email': self.email,
            'phone': self.phone,
            'role': self.role,
            'profession': self.profession,
            'email_verified': bool(getattr(self, 'email_verified', False)),
            'is_verified': self.is_verified,
            'password': self.password,
            'first_name': self.first_name,
            'last_name': self.last_name,
            'is_staff': self.is_staff,
            'is_active': self.is_active,
            'is_superuser': self.is_superuser,
            'district': getattr(self, 'district', None) or '',
            'city': getattr(self, 'city', None) or '',
            'qualification': getattr(self, 'qualification', None) or '',
            'profile_image_url': getattr(self, 'profile_image_url', None) or '',
            'verification_status': self.verification_status,
            'rejection_reason': getattr(self, 'rejection_reason', None) or '',
            'is_active_provider': bool(getattr(self, 'is_active_provider', False)),
            'submitted_at': getattr(self, 'submitted_at', None),
            'reviewed_at': getattr(self, 'reviewed_at', None),
            'reviewed_by': getattr(self, 'reviewed_by', None),
            'terms_accepted': bool(getattr(self, 'terms_accepted', False)),
            'terms_accepted_at': getattr(self, 'terms_accepted_at', None),
        }
        def _upsert_with_missing_column_fallback(update_payload):
            """
            Supabase schema can lag local code (e.g., missing verification columns).
            Retry update/insert after removing unknown columns so remaining fields persist.
            """
            payload = dict(update_payload)
            while True:
                if not payload:
                    return
                try:
                    if self.id:
                        supabase.table('seva_auth_user').update(payload).eq('id', self.id).execute()
                    else:
                        response = supabase.table('seva_auth_user').insert(payload).execute()
                        if response.data:
                            self.id = response.data[0]['id']
                    return
                except Exception as e:
                    msg = str(e)
                    match = re.search(r"column\s+seva_auth_user\.([a-zA-Z0-9_]+)\s+does not exist", msg, re.IGNORECASE)
                    if not match:
                        match = re.search(r"'([a-zA-Z0-9_]+)'\s+column of 'seva_auth_user'", msg, re.IGNORECASE)
                    if not match:
                        raise
                    missing_col = match.group(1)
                    if missing_col not in payload:
                        raise
                    payload.pop(missing_col, None)
        try:
            _upsert_with_missing_column_fallback(user_data)
        except Exception as e:
            print(f"Error saving user to Supabase: {e}")
    
    def __str__(self):
        return f"{self.email} ({self.role})"

