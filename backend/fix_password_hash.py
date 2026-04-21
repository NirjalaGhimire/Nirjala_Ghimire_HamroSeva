#!/usr/bin/env python
"""
Fix plain text passwords by properly hashing them.
"""
import os
import sys
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
django.setup()

from django.contrib.auth.hashers import make_password, check_password
from authentication.models import User
from supabase_config import get_supabase_client

def fix_password(user_id, plain_password):
    print(f"\n{'='*60}")
    print(f"Fixing password for user ID: {user_id}")
    print(f"{'='*60}\n")
    
    # Get user
    try:
        user = User.objects.get(id=user_id)
        print(f"✓ Found user: {user.username} ({user.email})")
    except User.DoesNotExist:
        print(f"✗ User not found with ID {user_id}")
        return False
    
    # Hash the password
    hashed_password = make_password(plain_password)
    print(f"\nOriginal plain password: {plain_password}")
    print(f"Hashed password: {hashed_password[:50]}...\n")
    
    # Update Django
    user.password = hashed_password
    user.save()
    print(f"✓ Updated Django ORM for user {user_id}")
    
    # Update Supabase
    try:
        supabase = get_supabase_client()
        supabase.table('seva_auth_user').update({'password': hashed_password}).eq('id', user_id).execute()
        print(f"✓ Updated Supabase for user {user_id}")
    except Exception as e:
        print(f"✗ Failed to update Supabase: {e}")
        return False
    
    # Verify
    print(f"\n{'─'*60}")
    print("Verifying fix:")
    print(f"{'─'*60}")
    
    user.refresh_from_db()
    
    if user.check_password(plain_password):
        print(f"✓ Password verification PASSED!")
        print(f"\n✓✓✓ SUCCESS! ✓✓✓")
        print("You can now delete your account with this password!")
        return True
    else:
        print(f"✗ Password verification FAILED!")
        return False

if __name__ == '__main__':
    # Fix for user yulisha
    success = fix_password(26, "NIRJ@L@2005")
    sys.exit(0 if success else 1)
