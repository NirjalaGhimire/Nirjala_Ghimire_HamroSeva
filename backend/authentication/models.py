from django.contrib.auth.models import AbstractUser
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


class SupabaseUserManager(models.Manager):
    def create_user(self, username, email, password=None, **extra_fields):
        supabase = get_supabase_client()
        user_data = {
            'username': username,
            'email': email,
            'password': password,  # In production, hash this first
        }
        # Role is always set (customer/provider). Only send profession if set (table may not have column).
        if 'role' in extra_fields:
            user_data['role'] = extra_fields['role']
        if extra_fields.get('phone') not in (None, ''):
            user_data['phone'] = extra_fields.get('phone')
        if extra_fields.get('profession') not in (None, ''):
            user_data['profession'] = extra_fields.get('profession')
        # Referral & loyalty: ensure new user has a unique referral code and optional referred_by_id
        referral_code = extra_fields.get('referral_code')
        if referral_code is None:
            referral_code = _generate_referral_code(supabase, username, email)
        user_data['referral_code'] = referral_code
        user_data['loyalty_points'] = int(extra_fields.get('loyalty_points', 0))
        if extra_fields.get('referred_by_id') is not None:
            user_data['referred_by_id'] = extra_fields['referred_by_id']
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
    is_verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    # Referral & loyalty (columns in Supabase seva_auth_user)
    referral_code = models.CharField(max_length=50, blank=True, null=True)
    loyalty_points = models.IntegerField(default=0)
    referred_by_id = models.IntegerField(null=True, blank=True)
    
    USERNAME_FIELD = 'email'  # Use email as the unique field
    REQUIRED_FIELDS = ['username']
    
    objects = SupabaseUserManager()
    
    class Meta:
        managed = False  # Don't let Django manage this table
    
    def save(self, *args, **kwargs):
        supabase = get_supabase_client()
        
        user_data = {
            'username': self.username,
            'email': self.email,
            'phone': self.phone,
            'role': self.role,
            'profession': self.profession,
            'is_verified': self.is_verified,
            'password': self.password,
            'first_name': self.first_name,
            'last_name': self.last_name,
            'is_staff': self.is_staff,
            'is_active': self.is_active,
            'is_superuser': self.is_superuser,
        }
        
        try:
            if self.id:
                # Update existing user
                supabase.table('seva_auth_user').update(user_data).eq('id', self.id).execute()
            else:
                # Create new user
                response = supabase.table('seva_auth_user').insert(user_data).execute()
                if response.data:
                    self.id = response.data[0]['id']
        except Exception as e:
            print(f"Error saving user to Supabase: {e}")
    
    def __str__(self):
        return f"{self.email} ({self.role})"

