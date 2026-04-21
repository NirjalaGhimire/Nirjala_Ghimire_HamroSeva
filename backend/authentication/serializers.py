from rest_framework import serializers
from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
import logging
from .models import User


logger = logging.getLogger(__name__)


def _normalize_verification_status(value):
    raw = (value or '').strip().lower()
    aliases = {
        'pending_verification': 'pending',
        'under_review': 'pending',
        'on_hold': 'pending',
        'verified': 'approved',
    }
    return aliases.get(raw, raw if raw in {'unverified', 'pending', 'approved', 'rejected'} else 'unverified')


def _provider_effective_status(provider_id):
    """Derive provider status from uploaded verification docs."""
    if not provider_id:
        return 'unverified'
    try:
        from supabase_config import get_supabase_client
        supabase = get_supabase_client()
        r = supabase.table('seva_provider_verification').select('status').eq('provider_id', provider_id).execute()
    except Exception:
        return 'unverified'
    statuses = {_normalize_verification_status((row.get('status') or 'unverified')) for row in (r.data or [])}
    if 'approved' in statuses:
        return 'approved'
    if 'pending' in statuses:
        return 'pending'
    if 'rejected' in statuses:
        return 'rejected'
    return 'unverified'

class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, validators=[validate_password])
    password_confirm = serializers.CharField(write_only=True)
    district = serializers.CharField(required=True, max_length=120)
    city = serializers.CharField(required=True, max_length=120)

    class Meta:
        model = User
        fields = (
            'username', 'email', 'phone', 'password', 'password_confirm', 'role', 'profession',
            'district', 'city',
        )
        extra_kwargs = {
            'password': {'write_only': True},
            'role': {'required': False},
            'profession': {'required': False},
            'email': {'validators': []},  # Remove default validators
            'username': {'validators': []},  # Remove default validators
        }

    def validate_email(self, value):
        # Check if email already exists
        try:
            existing_user = User.objects.get(email=value)
            if existing_user:
                raise serializers.ValidationError("A user with this email already exists.")
        except User.DoesNotExist:
            pass
        except serializers.ValidationError:
            raise
        return value

    def validate_username(self, value):
        # Check if username already exists
        try:
            existing_user = User.objects.get(username=value)
            if existing_user:
                raise serializers.ValidationError("A user with this username already exists.")
        except User.DoesNotExist:
            pass
        except serializers.ValidationError:
            raise
        return value

    def validate_district(self, value):
        if not (value or '').strip():
            raise serializers.ValidationError('District is required.')
        return value.strip()

    def validate_city(self, value):
        if not (value or '').strip():
            raise serializers.ValidationError('City is required.')
        return value.strip()

    def validate_phone(self, value):
        if not value or not str(value).strip():
            return value
        try:
            existing_user = User.objects.get(phone=value.strip())
            if existing_user:
                raise serializers.ValidationError("This phone number is already registered.")
        except User.DoesNotExist:
            pass
        except serializers.ValidationError:
            raise
        return value

    def validate(self, attrs):
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError("Passwords don't match.")
        return attrs

    def create(self, validated_data):
        validated_data.pop('password_confirm')
        password = validated_data.pop('password')
        
        user = User.objects.create_user(
            password=password,
            **validated_data
        )
        return user

class CustomerRegistrationSerializer(UserRegistrationSerializer):
    referral_code = serializers.CharField(required=False, allow_blank=True)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Set role to customer by removing it from fields and setting it in create
        self.fields.pop('role', None)
    
    class Meta(UserRegistrationSerializer.Meta):
        fields = (
            'username', 'email', 'phone', 'password', 'password_confirm', 'referral_code',
            'district', 'city',
        )
    
    def create(self, validated_data):
        referral_code_input = (validated_data.pop('referral_code', None) or '').strip()
        validated_data['role'] = 'customer'
        validated_data['verification_status'] = 'unverified'
        validated_data['is_verified'] = False
        validated_data['is_active_provider'] = False
        validated_data.pop('password_confirm')
        password = validated_data.pop('password')
        referred_by_id = None
        if referral_code_input:
            try:
                from supabase_config import get_supabase_client
                supabase = get_supabase_client()
                # Accept referral codes regardless of input casing.
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
                    validated_data['referred_by_id'] = referred_by_id
            except Exception as e:
                logger.warning('Referral lookup failed for code %s: %s', referral_code_input, e)
        user = User.objects.create_user(
            password=password,
            **validated_data
        )
        if referred_by_id is not None and getattr(user, 'id', None):
            try:
                from supabase_config import get_supabase_client
                supabase = get_supabase_client()
                supabase.table('seva_referral').insert({
                    'referrer_id': referred_by_id,
                    'referred_user_id': user.id,
                    'status': 'signed_up',
                    'points_referrer': 0,
                    'points_referred': 0,
                }).execute()
            except Exception as e:
                import logging
                logging.getLogger(__name__).warning('Referral insert failed: %s', e)
        return user

class ProviderRegistrationSerializer(UserRegistrationSerializer):
    """Optional JSON key services_offered: [{category_id, title}, ...] — not a User model field."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields.pop('role', None)
        # Username optional for provider; we default it to email in validate
        self.fields['username'].required = False
        self.fields['username'].allow_blank = True
    
    class Meta(UserRegistrationSerializer.Meta):
        fields = (
            'username', 'email', 'phone', 'password', 'password_confirm', 'profession',
            'district', 'city',
        )
    
    def validate(self, attrs):
        attrs = super().validate(attrs)
        # If username is blank, use email so provider registration always has a username
        if not (attrs.get('username') or '').strip():
            attrs['username'] = (attrs.get('email') or '').strip() or 'provider'
        raw = self.initial_data.get('services_offered')
        if isinstance(raw, str):
            import json
            try:
                raw = json.loads(raw)
            except Exception:
                raw = None
        if raw is not None:
            self._normalize_services_offered(raw)
        return attrs

    @staticmethod
    def _normalize_services_offered(raw):
        from services.service_name_utils import dedupe_services_offered_list

        out = []
        if not raw:
            return out
        if not isinstance(raw, list):
            raise serializers.ValidationError(
                {'services_offered': 'Expected a list of {category_id, title} objects.'}
            )
        for item in raw:
            if not isinstance(item, dict):
                continue
            try:
                cid = int(item.get('category_id'))
            except (TypeError, ValueError):
                raise serializers.ValidationError(
                    {'services_offered': 'Each entry needs a numeric category_id and title.'}
                )
            title = (item.get('title') or '').strip()
            if not title:
                raise serializers.ValidationError(
                    {'services_offered': 'Each entry needs a non-empty title.'}
                )
            out.append({'category_id': cid, 'title': title})
        result = dedupe_services_offered_list(out)
        from supabase_config import get_supabase_client
        from services.category_matching import catalog_service_title_matches_category
        from services.models import ServiceCategory

        supabase = get_supabase_client()
        for item in result:
            cid = item['category_id']
            title = item['title']
            r = supabase.table(ServiceCategory._meta.db_table).select('name').eq('id', cid).execute()
            cname = (r.data[0].get('name') or '') if r.data else ''
            if cname and not catalog_service_title_matches_category(title, cname):
                raise serializers.ValidationError(
                    {
                        'services_offered': (
                            f'Service "{title}" cannot be registered under category "{cname}". '
                            'Pick a service that matches the category.'
                        )
                    }
                )
        return result
    
    def create(self, validated_data):
        validated_data['role'] = 'provider'
        validated_data['verification_status'] = 'unverified'
        validated_data['is_verified'] = False
        # Provider account exists, but stays unverified until admin approval.
        validated_data['is_active_provider'] = False
        validated_data.pop('password_confirm')
        password = validated_data.pop('password')
        raw = self.initial_data.get('services_offered')
        if isinstance(raw, str):
            import json
            try:
                raw = json.loads(raw)
            except Exception:
                raw = None
        services_offered = []
        if raw is not None:
            services_offered = self._normalize_services_offered(raw)
        # Ensure profession has a value (primary label for profile)
        if not validated_data.get('profession'):
            validated_data['profession'] = ''
        user = User.objects.create_user(
            password=password,
            **validated_data
        )
        # Store requested service titles for admin review only; provider becomes active after approval.
        if services_offered:
            try:
                from supabase_config import get_supabase_client
                supabase = get_supabase_client()
                supabase.table('seva_auth_user').update({
                    'qualification': ', '.join(
                        sorted({(s.get('title') or '').strip() for s in services_offered if (s.get('title') or '').strip()})
                    )[:1000],
                }).eq('id', user.id).execute()
            except Exception:
                pass
        return user

class LoginSerializer(serializers.Serializer):
    username = serializers.CharField(help_text='Username, email, or phone number')
    password = serializers.CharField()
    
    def validate(self, attrs):
        username = (attrs.get('username') or '').strip()
        password = attrs.get('password')
        
        if not username or not password:
            raise serializers.ValidationError("Username and password are required.")
        
        user_obj = None
        user = None
        
        # CRITICAL: First, check if user exists at all
        # Try to find user by username (case-insensitive), email, or phone
        try:
            if '@' in username:
                try:
                    user_obj = User.objects.get(email__iexact=username)
                except Exception:
                    user_obj = User.objects.get(email=username)
            elif username.isdigit():
                user_obj = User.objects.get(phone=username)
            else:
                try:
                    user_obj = User.objects.get_by_username_ignore_case(username)
                except User.DoesNotExist:
                    # Fallback: try as email (e.g. user types email in "username" field)
                    try:
                        user_obj = User.objects.get(email__iexact=username)
                    except Exception:
                        user_obj = User.objects.get(email=username)
        except User.DoesNotExist:
            # CRITICAL: User does not exist at all
            raise serializers.ValidationError("No user found with this username or email.")
        
        # User exists, now check if account is active
        if not bool(getattr(user_obj, 'is_active', True)):
            if str(getattr(user_obj, 'username', '') or '').startswith('deleted_'):
                raise serializers.ValidationError("User account is disabled.")
            try:
                user_obj.is_active = True
                user_obj.save()
            except Exception:
                pass

        if not bool(getattr(user_obj, 'email_verified', False)):
            # Legacy Supabase accounts may not have passed through the newer email verification flow.
            # Do not block login for existing accounts; mark them verified on successful login.
            try:
                user_obj.email_verified = True
                user_obj.save()
            except Exception:
                pass

        if not bool(getattr(user_obj, 'is_active', True)):
            raise serializers.ValidationError("User account is disabled.")
        
        # CRITICAL: User exists and is active, now verify password
        # Pass exact username from DB so backend can re-fetch and check password
        user = authenticate(username=user_obj.username, password=password)
        if not user:
            # Backward compatibility for older Supabase rows that still store a plain-text password.
            stored_password = getattr(user_obj, 'password', None) or ''
            if '$' not in str(stored_password) and str(stored_password).strip() == password:
                user = user_obj
        
        if not user:
            # User exists but password is wrong
            raise serializers.ValidationError("Invalid password.")
        
        attrs['user'] = user
        return attrs

class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = (
            'id', 'username', 'email', 'phone', 'role', 'profession',
            'qualification', 'profile_image_url',
            'first_name', 'last_name',
            'district', 'city', 'verification_status', 'rejection_reason',
            'email_verified',
            'is_active_provider', 'submitted_at', 'reviewed_at', 'reviewed_by',
            'created_at',
        )
        read_only_fields = ('id', 'created_at')

    def to_representation(self, instance):
        data = super().to_representation(instance)
        role = (data.get('role') or '').strip().lower()
        is_provider_role = role in ('provider', 'prov')
        if is_provider_role:
            status = _provider_effective_status(data.get('id'))
        else:
            status = _normalize_verification_status(data.get('verification_status'))
        data['verification_status'] = status
        data['is_verified'] = is_provider_role and status == 'approved'
        data['is_active_provider'] = is_provider_role and status == 'approved'
        return data
