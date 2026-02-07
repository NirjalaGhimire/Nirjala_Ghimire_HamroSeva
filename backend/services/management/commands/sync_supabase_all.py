"""
Sync from Supabase to SQLite for Django admin: service categories, services,
bookings, reviews, and referrals. Run: python manage.py sync_supabase_all
Uses raw sqlite3 connection to avoid Django cursor formatting issues.
"""
from django.core.management.base import BaseCommand
from django.db import connection
from django.utils import timezone


def _scalar(val):
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


def _row_to_tuple(row, keys, default_now=None):
    now = default_now if default_now else timezone.now().isoformat()
    out = []
    for k in keys:
        v = row.get(k)
        if v is None and default_now is not None and k in ('created_at', 'updated_at'):
            v = now
        out.append(_scalar(v))
    return tuple(out)


class Command(BaseCommand):
    help = 'Sync service categories, services, bookings, reviews, and referrals from Supabase to SQLite.'

    def handle(self, *args, **options):
        try:
            from supabase_config import get_supabase_client
        except ImportError:
            self.stderr.write(self.style.ERROR('supabase_config not found.'))
            return
        supabase = get_supabase_client()
        connection.ensure_connection()
        raw = connection.connection
        now = timezone.now().isoformat()
        stats = {}

        # Ensure seva_referral exists in SQLite
        raw.execute("""
            CREATE TABLE IF NOT EXISTS seva_referral (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                referrer_id INTEGER NOT NULL,
                referred_user_id INTEGER NOT NULL,
                status VARCHAR(30) NOT NULL DEFAULT 'signed_up',
                points_referrer INTEGER NOT NULL DEFAULT 0,
                points_referred INTEGER NOT NULL DEFAULT 0,
                created_at DATETIME,
                updated_at DATETIME
            )
        """)

        # 1) Service categories
        try:
            r = supabase.table('seva_servicecategory').select('*').execute()
            if r.data:
                sql = "INSERT OR REPLACE INTO seva_servicecategory (id, name, description, icon, created_at) VALUES (?, ?, ?, ?, ?)"
                for row in r.data:
                    pid = row.get('id')
                    if pid is None:
                        continue
                    params = _row_to_tuple(row, ['id', 'name', 'description', 'icon', 'created_at'], now)
                    raw.execute(sql, params)
            stats['service_categories'] = len(r.data) if r.data else 0
        except Exception as e:
            self.stderr.write(self.style.WARNING(f'Service categories: {e}'))
            stats['service_categories'] = 0

        # 2) Services
        try:
            r = supabase.table('seva_service').select('*').execute()
            if r.data:
                sql = """INSERT OR REPLACE INTO seva_service (
                    id, provider_id, category_id, title, description, price, duration_minutes,
                    location, status, image_url, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"""
                for row in r.data:
                    pid = row.get('id')
                    if pid is None:
                        continue
                    params = _row_to_tuple(row, [
                        'id', 'provider_id', 'category_id', 'title', 'description', 'price',
                        'duration_minutes', 'location', 'status', 'image_url', 'created_at', 'updated_at'
                    ], now)
                    raw.execute(sql, params)
            stats['services'] = len(r.data) if r.data else 0
        except Exception as e:
            self.stderr.write(self.style.WARNING(f'Services: {e}'))
            stats['services'] = 0

        # 3) Bookings
        try:
            r = supabase.table('seva_booking').select('*').execute()
            if r.data:
                sql = """INSERT OR REPLACE INTO seva_booking (
                    id, customer_id, service_id, booking_date, booking_time, status, notes,
                    total_amount, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"""
                for row in r.data:
                    pid = row.get('id')
                    if pid is None:
                        continue
                    params = _row_to_tuple(row, [
                        'id', 'customer_id', 'service_id', 'booking_date', 'booking_time',
                        'status', 'notes', 'total_amount', 'created_at', 'updated_at'
                    ], now)
                    raw.execute(sql, params)
            stats['bookings'] = len(r.data) if r.data else 0
        except Exception as e:
            self.stderr.write(self.style.WARNING(f'Bookings: {e}'))
            stats['bookings'] = 0

        # 4) Reviews
        try:
            r = supabase.table('seva_review').select('*').execute()
            if r.data:
                sql = """INSERT OR REPLACE INTO seva_review (
                    id, booking_id, customer_id, provider_id, rating, comment, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)"""
                for row in r.data:
                    pid = row.get('id')
                    if pid is None:
                        continue
                    params = _row_to_tuple(row, [
                        'id', 'booking_id', 'customer_id', 'provider_id', 'rating', 'comment', 'created_at'
                    ], now)
                    raw.execute(sql, params)
            stats['reviews'] = len(r.data) if r.data else 0
        except Exception as e:
            self.stderr.write(self.style.WARNING(f'Reviews: {e}'))
            stats['reviews'] = 0

        # 5) Referrals
        try:
            r = supabase.table('seva_referral').select('*').execute()
            if r.data:
                sql = """INSERT OR REPLACE INTO seva_referral (
                    id, referrer_id, referred_user_id, status, points_referrer, points_referred,
                    created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"""
                for row in r.data:
                    pid = row.get('id')
                    if pid is None:
                        continue
                    params = _row_to_tuple(row, [
                        'id', 'referrer_id', 'referred_user_id', 'status',
                        'points_referrer', 'points_referred', 'created_at', 'updated_at'
                    ], now)
                    raw.execute(sql, params)
            stats['referrals'] = len(r.data) if r.data else 0
        except Exception as e:
            self.stderr.write(self.style.WARNING(f'Referrals: {e}'))
            stats['referrals'] = 0

        self.stdout.write(self.style.SUCCESS(
            f"Synced: {stats.get('service_categories', 0)} categories, {stats.get('services', 0)} services, "
            f"{stats.get('bookings', 0)} bookings, {stats.get('reviews', 0)} reviews, {stats.get('referrals', 0)} referrals."
        ))
