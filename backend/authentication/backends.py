from django.contrib.auth.backends import BaseBackend
from django.contrib.auth import get_user_model
from .models import User

class SupabaseAuthBackend(BaseBackend):
    """
    Custom authentication backend for Supabase users.
    Passwords are stored in Supabase (plain for dev); we compare after normalizing.
    """
    
    def authenticate(self, request, username=None, password=None, **kwargs):
        """
        Authenticate user against Supabase data.
        Uses case-insensitive username/email lookup to match login form behavior.
        """
        UserModel = get_user_model()
        
        if username is None or password is None:
            return None
        
        username = (username or '').strip()
        password = (password or '').strip()
        if not username or not password:
            return None
        
        try:
            # Find user: same logic as LoginSerializer (email, phone, or username case-insensitive)
            if '@' in username:
                user = UserModel.objects.get(email=username)
            elif username.isdigit():
                user = UserModel.objects.get(phone=username)
            else:
                try:
                    user = UserModel.objects.get(username=username)
                except UserModel.DoesNotExist:
                    user = UserModel.objects.get_by_username_ignore_case(username)
            
            # Compare password (stored plain in Supabase for dev; normalize whitespace)
            stored = getattr(user, 'password', None)
            if stored is None:
                stored = ''
            if (str(stored).strip() == password) or (stored == password):
                return user
                    
        except UserModel.DoesNotExist:
            return None
        
        return None
    
    def get_user(self, user_id):
        """
        Retrieve user by ID.
        """
        UserModel = get_user_model()
        try:
            return UserModel.objects.get(pk=user_id)
        except UserModel.DoesNotExist:
            return None
