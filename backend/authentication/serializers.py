from rest_framework import serializers
from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from .models import User

class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, validators=[validate_password])
    password_confirm = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ('username', 'email', 'phone', 'password', 'password_confirm', 'role', 'profession')
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
        fields = ('username', 'email', 'phone', 'password', 'password_confirm', 'referral_code')
    
    def create(self, validated_data):
        referral_code_input = (validated_data.pop('referral_code', None) or '').strip()
        validated_data['role'] = 'customer'
        validated_data.pop('password_confirm')
        password = validated_data.pop('password')
        referred_by_id = None
        if referral_code_input:
            try:
                from supabase_config import get_supabase_client
                supabase = get_supabase_client()
                r = supabase.table('seva_auth_user').select('id').eq('referral_code', referral_code_input).execute()
                if r.data and len(r.data) > 0:
                    referred_by_id = r.data[0]['id']
                    validated_data['referred_by_id'] = referred_by_id
            except Exception:
                pass
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
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields.pop('role', None)
        # Username optional for provider; we default it to email in validate
        self.fields['username'].required = False
        self.fields['username'].allow_blank = True
    
    class Meta(UserRegistrationSerializer.Meta):
        fields = ('username', 'email', 'phone', 'password', 'password_confirm', 'profession')
    
    def validate(self, attrs):
        attrs = super().validate(attrs)
        # If username is blank, use email so provider registration always has a username
        if not (attrs.get('username') or '').strip():
            attrs['username'] = (attrs.get('email') or '').strip() or 'provider'
        return attrs
    
    def create(self, validated_data):
        validated_data['role'] = 'provider'
        validated_data.pop('password_confirm')
        password = validated_data.pop('password')
        # Ensure profession has a value
        if not validated_data.get('profession'):
            validated_data['profession'] = ''
        user = User.objects.create_user(
            password=password,
            **validated_data
        )
        return user

class LoginSerializer(serializers.Serializer):
    username = serializers.CharField(help_text='Username, email, or phone number')
    password = serializers.CharField()
    
    def validate(self, attrs):
        username = (attrs.get('username') or '').strip()
        password = attrs.get('password')
        
        if not username or not password:
            raise serializers.ValidationError("Username and password are required.")
        
        user = None
        
        # Try to find user by username (case-insensitive), email, or phone
        try:
            if '@' in username:
                user_obj = User.objects.get(email=username)
            elif username.isdigit():
                user_obj = User.objects.get(phone=username)
            else:
                try:
                    user_obj = User.objects.get_by_username_ignore_case(username)
                except User.DoesNotExist:
                    # Fallback: try as email (e.g. user types email in "username" field)
                    user_obj = User.objects.get(email=username)
            # Pass exact username from DB so backend can re-fetch and check password
            user = authenticate(username=user_obj.username, password=password)
            
        except User.DoesNotExist:
            pass
        
        if not user:
            raise serializers.ValidationError("Invalid credentials.")
        
        if not user.is_active:
            raise serializers.ValidationError("User account is disabled.")
        
        attrs['user'] = user
        return attrs

class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'phone', 'role', 'profession', 'created_at')
        read_only_fields = ('id', 'created_at')
