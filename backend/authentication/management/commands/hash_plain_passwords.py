"""
One-time migration: hash any plain-text passwords in Supabase seva_auth_user.
Run after switching to hashed passwords so existing users can log in with hashed storage.
Usage: python manage.py hash_plain_passwords
"""
from django.core.management.base import BaseCommand
from django.contrib.auth.hashers import make_password

class Command(BaseCommand):
    help = 'Hash plain-text passwords in Supabase seva_auth_user (one-time migration).'

    def handle(self, *args, **options):
        try:
            from supabase_config import get_supabase_client
        except ImportError:
            self.stderr.write(self.style.ERROR('supabase_config not found.'))
            return
        supabase = get_supabase_client()
        try:
            r = supabase.table('seva_auth_user').select('id, password').execute()
        except Exception as e:
            self.stderr.write(self.style.ERROR(f'Supabase error: {e}'))
            return
        if not r.data:
            self.stdout.write('No users in Supabase.')
            return
        updated = 0
        for row in r.data:
            uid = row.get('id')
            pwd = row.get('password') or ''
            if not pwd or ('$' in str(pwd) and 'pbkdf2_sha256' in str(pwd)):
                continue
            try:
                hashed = make_password(pwd)
                supabase.table('seva_auth_user').update({'password': hashed}).eq('id', uid).execute()
                updated += 1
            except Exception as e:
                self.stderr.write(self.style.WARNING(f'Skip user {uid}: {e}'))
        self.stdout.write(self.style.SUCCESS(f'Hashed {updated} plain-text password(s).'))
