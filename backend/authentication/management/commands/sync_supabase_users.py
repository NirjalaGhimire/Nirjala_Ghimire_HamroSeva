"""
Sync users from Supabase seva_auth_user into SQLite authentication_user
so Django admin User list shows them. Run: python manage.py sync_supabase_users
"""
from django.core.management.base import BaseCommand
from django.db import connection
from django.utils import timezone


def _to_sqlite_scalar(val):
    """Ensure value is a scalar (int, str, float, bytes, None) for SQLite parameter binding.
    Django/sqlite3 can raise 'not all arguments converted' if any value is a list/tuple/dict.
    """
    if val is None:
        return None
    if isinstance(val, (list, tuple, dict)):
        return str(val)
    if hasattr(val, 'isoformat'):
        return val.isoformat()
    if isinstance(val, bool):
        return 1 if val else 0
    if isinstance(val, (int, float, str, bytes)):
        return val
    return str(val)


class Command(BaseCommand):
    help = 'Sync users from Supabase to SQLite so admin user list is populated.'

    def handle(self, *args, **options):
        try:
            from supabase_config import get_supabase_client
        except ImportError:
            self.stderr.write(self.style.ERROR('supabase_config not found.'))
            return
        supabase = get_supabase_client()
        try:
            r = supabase.table('seva_auth_user').select('*').execute()
        except Exception as e:
            self.stderr.write(self.style.ERROR(f'Supabase error: {e}'))
            return
        if not r.data:
            self.stdout.write('No users in Supabase.')
            return
        now = timezone.now().isoformat()
        synced = 0
        # Use raw sqlite3 connection to avoid Django cursor's %-formatting path that raises
        # "not all arguments converted during string formatting" when building last_executed_query
        connection.ensure_connection()
        raw_conn = connection.connection
        sql = (
            "INSERT OR REPLACE INTO authentication_user ("
            "id, password, last_login, is_superuser, username, first_name, last_name,"
            "is_staff, is_active, date_joined, email, phone, role, profession,"
            "is_verified, created_at, updated_at, referral_code, loyalty_points, referred_by_id"
            ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
        )
        for row in r.data:
            uid = row.get('id')
            if uid is None:
                continue
            # Force every value to a scalar so sqlite3 never sees list/tuple/dict
            username = _to_sqlite_scalar(row.get('username')) or ''
            username = (username if isinstance(username, str) else str(username))[:150]
            email = _to_sqlite_scalar(row.get('email')) or ''
            email = (email if isinstance(email, str) else str(email))[:254]
            password = _to_sqlite_scalar(row.get('password')) or ''
            password = (password if isinstance(password, str) else str(password))[:128]
            last_login = _to_sqlite_scalar(row.get('last_login'))
            is_superuser = 1 if row.get('role') == 'admin' else 0
            first_name = _to_sqlite_scalar(row.get('first_name')) or ''
            first_name = (first_name if isinstance(first_name, str) else str(first_name))[:150]
            last_name = _to_sqlite_scalar(row.get('last_name')) or ''
            last_name = (last_name if isinstance(last_name, str) else str(last_name))[:150]
            is_staff = 1 if row.get('role') == 'admin' else 0
            is_active = 1 if row.get('is_active', True) else 0
            date_joined = _to_sqlite_scalar(row.get('date_joined') or row.get('created_at') or now)
            phone_raw = row.get('phone')
            phone = (_to_sqlite_scalar(phone_raw) or '')[:20] if phone_raw is not None and phone_raw != '' else None
            role = _to_sqlite_scalar(row.get('role')) or 'customer'
            role = (role if isinstance(role, str) else str(role))[:20]
            profession_raw = row.get('profession')
            profession = (_to_sqlite_scalar(profession_raw) or '')[:100] if profession_raw else None
            is_verified = 1 if row.get('is_verified') else 0
            created_at = _to_sqlite_scalar(row.get('created_at') or now)
            updated_at = _to_sqlite_scalar(row.get('updated_at') or now)
            referral_code_raw = row.get('referral_code')
            referral_code = (_to_sqlite_scalar(referral_code_raw) or '')[:50] if referral_code_raw else None
            loyalty_points = int(row.get('loyalty_points') or 0)
            referred_by_id = row.get('referred_by_id')
            if referred_by_id is not None and not isinstance(referred_by_id, int):
                try:
                    referred_by_id = int(referred_by_id)
                except (TypeError, ValueError):
                    referred_by_id = None
            referred_by_id = _to_sqlite_scalar(referred_by_id)
            if referred_by_id is not None and referred_by_id != '':
                try:
                    referred_by_id = int(referred_by_id)
                except (TypeError, ValueError):
                    referred_by_id = None
            params = (
                int(uid), password, last_login, is_superuser, username, first_name, last_name,
                is_staff, is_active, date_joined, email, phone, role, profession,
                is_verified, created_at, updated_at, referral_code, loyalty_points, referred_by_id
            )
            params = tuple(_to_sqlite_scalar(p) for p in params)
            try:
                raw_conn.execute(sql, params)
                synced += 1
            except Exception as e:
                self.stderr.write(self.style.WARNING(f'Skip user {uid}: {e}'))
        self.stdout.write(self.style.SUCCESS(f'Synced {synced} users to SQLite.'))
