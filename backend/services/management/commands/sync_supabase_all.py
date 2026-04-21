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
        booking_customer_by_id = {}

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
        raw.execute("""
            CREATE TABLE IF NOT EXISTS seva_payment (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                booking_id INTEGER NOT NULL,
                customer_id INTEGER NOT NULL,
                provider_id INTEGER,
                amount DECIMAL(10,2) NOT NULL,
                payment_method VARCHAR(30),
                status VARCHAR(30) NOT NULL DEFAULT 'pending',
                transaction_id VARCHAR(120),
                ref_id VARCHAR(120),
                refund_amount DECIMAL(10,2),
                refund_reason TEXT,
                refund_reference VARCHAR(120),
                created_at DATETIME,
                updated_at DATETIME
            )
        """)
        raw.execute("""
            CREATE TABLE IF NOT EXISTS seva_refund (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                booking_id INTEGER NOT NULL,
                payment_id INTEGER,
                customer_id INTEGER NOT NULL,
                provider_id INTEGER,
                amount DECIMAL(10,2) NOT NULL,
                status VARCHAR(30) NOT NULL DEFAULT 'refund_pending',
                refund_reason TEXT,
                system_note TEXT,
                admin_note TEXT,
                refund_reference VARCHAR(120),
                requested_by VARCHAR(20),
                requested_at DATETIME,
                reviewed_by INTEGER,
                reviewed_at DATETIME,
                created_at DATETIME,
                updated_at DATETIME
            )
        """)
        raw.execute("""
            CREATE TABLE IF NOT EXISTS seva_receipt (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                receipt_id VARCHAR(80) NOT NULL UNIQUE,
                booking_id INTEGER NOT NULL,
                payment_id INTEGER,
                customer_id INTEGER NOT NULL,
                provider_id INTEGER,
                service_name VARCHAR(200),
                payment_method VARCHAR(40),
                paid_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
                discount_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
                tax_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
                service_charge DECIMAL(10,2) NOT NULL DEFAULT 0,
                final_total DECIMAL(10,2) NOT NULL DEFAULT 0,
                payment_status VARCHAR(30) NOT NULL DEFAULT 'completed',
                refund_status VARCHAR(30),
                issued_at DATETIME,
                created_at DATETIME,
                updated_at DATETIME
            )
        """)
        raw.execute("""
            CREATE TABLE IF NOT EXISTS seva_provider_verification (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                provider_id INTEGER NOT NULL,
                document_type VARCHAR(60) NOT NULL,
                document_number VARCHAR(100),
                document_url TEXT,
                status VARCHAR(30) NOT NULL DEFAULT 'pending_verification',
                upload_status VARCHAR(30),
                review_note TEXT,
                reviewed_by INTEGER,
                reviewed_at DATETIME,
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
                booking_customer_by_id = {
                    row.get('id'): row.get('customer_id')
                    for row in r.data
                    if row.get('id') is not None
                }
                sql = """INSERT OR REPLACE INTO seva_booking (
                    id, customer_id, service_id, booking_date, booking_time, status, notes,
                    total_amount, quoted_price, request_image_url, address, latitude, longitude,
                    created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"""
                for row in r.data:
                    pid = row.get('id')
                    if pid is None:
                        continue
                    params = _row_to_tuple(row, [
                        'id', 'customer_id', 'service_id', 'booking_date', 'booking_time',
                        'status', 'notes', 'total_amount', 'quoted_price', 'request_image_url',
                        'address', 'latitude', 'longitude', 'created_at', 'updated_at'
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

        # 6) Payments
        try:
            r = supabase.table('seva_payment').select('*').execute()
            if r.data:
                sql = """INSERT OR REPLACE INTO seva_payment (
                    id, booking_id, customer_id, provider_id, amount, payment_method, status,
                    transaction_id, ref_id, refund_amount, refund_reason, refund_reference,
                    created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"""
                for row in r.data:
                    pid = row.get('id')
                    if pid is None:
                        continue
                    booking_id = row.get('booking_id')
                    customer_id = row.get('customer_id')
                    if customer_id is None and booking_id is not None:
                        customer_id = booking_customer_by_id.get(booking_id)
                    if customer_id is None:
                        # Keep admin sync resilient even if legacy payment row is incomplete.
                        continue
                    row = dict(row)
                    row['customer_id'] = customer_id
                    params = _row_to_tuple(row, [
                        'id', 'booking_id', 'customer_id', 'provider_id', 'amount', 'payment_method',
                        'status', 'transaction_id', 'ref_id', 'refund_amount', 'refund_reason',
                        'refund_reference', 'created_at', 'updated_at'
                    ], now)
                    raw.execute(sql, params)
            stats['payments'] = len(r.data) if r.data else 0
        except Exception as e:
            self.stderr.write(self.style.WARNING(f'Payments: {e}'))
            stats['payments'] = 0

        # 7) Refunds
        try:
            r = supabase.table('seva_refund').select('*').execute()
            if r.data:
                sql = """INSERT OR REPLACE INTO seva_refund (
                    id, booking_id, payment_id, customer_id, provider_id, amount, status,
                    refund_reason, system_note, admin_note, refund_reference, requested_by,
                    requested_at, reviewed_by, reviewed_at, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"""
                for row in r.data:
                    pid = row.get('id')
                    if pid is None:
                        continue
                    params = _row_to_tuple(row, [
                        'id', 'booking_id', 'payment_id', 'customer_id', 'provider_id', 'amount',
                        'status', 'refund_reason', 'system_note', 'admin_note', 'refund_reference',
                        'requested_by', 'requested_at', 'reviewed_by', 'reviewed_at', 'created_at', 'updated_at'
                    ], now)
                    raw.execute(sql, params)
            stats['refunds'] = len(r.data) if r.data else 0
        except Exception as e:
            self.stderr.write(self.style.WARNING(f'Refunds: {e}'))
            stats['refunds'] = 0

        # 8) Provider verification documents
        try:
            r = supabase.table('seva_provider_verification').select('*').execute()
            if r.data:
                sql = """INSERT OR REPLACE INTO seva_provider_verification (
                    id, provider_id, document_type, document_number, document_url, status,
                    upload_status, review_note, reviewed_by, reviewed_at, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"""
                for row in r.data:
                    pid = row.get('id')
                    if pid is None:
                        continue
                    params = _row_to_tuple(row, [
                        'id', 'provider_id', 'document_type', 'document_number', 'document_url',
                        'status', 'upload_status', 'review_note', 'reviewed_by', 'reviewed_at',
                        'created_at', 'updated_at'
                    ], now)
                    raw.execute(sql, params)
            stats['provider_verifications'] = len(r.data) if r.data else 0
        except Exception as e:
            self.stderr.write(self.style.WARNING(f'Provider verification: {e}'))
            stats['provider_verifications'] = 0

        # 9) Receipts
        try:
            r = supabase.table('seva_receipt').select('*').execute()
            if r.data:
                sql = """INSERT OR REPLACE INTO seva_receipt (
                    id, receipt_id, booking_id, payment_id, customer_id, provider_id,
                    service_name, payment_method, paid_amount, discount_amount, tax_amount,
                    service_charge, final_total, payment_status, refund_status, issued_at,
                    created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"""
                for row in r.data:
                    pid = row.get('id')
                    if pid is None:
                        continue
                    params = _row_to_tuple(row, [
                        'id', 'receipt_id', 'booking_id', 'payment_id', 'customer_id', 'provider_id',
                        'service_name', 'payment_method', 'paid_amount', 'discount_amount', 'tax_amount',
                        'service_charge', 'final_total', 'payment_status', 'refund_status', 'issued_at',
                        'created_at', 'updated_at'
                    ], now)
                    raw.execute(sql, params)
            stats['receipts'] = len(r.data) if r.data else 0
        except Exception as e:
            self.stderr.write(self.style.WARNING(f'Receipts: {e}'))
            stats['receipts'] = 0

        self.stdout.write(self.style.SUCCESS(
            f"Synced: {stats.get('service_categories', 0)} categories, {stats.get('services', 0)} services, "
            f"{stats.get('bookings', 0)} bookings, {stats.get('reviews', 0)} reviews, "
            f"{stats.get('referrals', 0)} referrals, {stats.get('payments', 0)} payments, "
            f"{stats.get('refunds', 0)} refunds, {stats.get('provider_verifications', 0)} verifications, "
            f"{stats.get('receipts', 0)} receipts."
        ))
