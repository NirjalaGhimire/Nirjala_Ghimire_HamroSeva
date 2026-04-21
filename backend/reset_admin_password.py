#!/usr/bin/env python
"""
Quick script to reset admin password by email.
Run from Django shell: python manage.py shell < reset_admin_password.py
Or: exec(open('reset_admin_password.py').read())
"""

from authentication.models import User

# Reset password for admin user
email = 'nirjala6205@gmail.com'
new_password = 'Admin@12345'  # Change this to your new password

try:
    user = User.objects.get(email=email)
    user.set_password(new_password)
    
    # Ensure admin privileges
    user.is_staff = True
    user.is_superuser = True
    user.is_active = True
    
    user.save()
    print(f"✅ Password reset successfully for {email}")
    print(f"   New password: {new_password}")
    print(f"   is_staff: {user.is_staff}")
    print(f"   is_superuser: {user.is_superuser}")
    print(f"   is_active: {user.is_active}")
except User.DoesNotExist:
    print(f"❌ User with email {email} not found!")
    print("   Available users:")
    for u in User.objects.all():
        print(f"   - {u.email}")
except Exception as e:
    print(f"❌ Error: {e}")
