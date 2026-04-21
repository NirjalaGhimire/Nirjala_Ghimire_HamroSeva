"""
Aggregates for admin dashboard and reports (local SQLite, synced from Supabase).
"""
from datetime import datetime, time, timedelta
from decimal import Decimal

from django.db.models import Count, Q, Sum
from django.db.models.functions import TruncMonth
from django.utils import timezone

from authentication.models import User
from services.models import Booking, Payment, Review, Service, ServiceCategory


def _provider_q():
    return Q(role='provider') | Q(role='prov')


def dashboard_stats():
    users_total = User.objects.count()
    customers = User.objects.filter(role='customer').count()
    providers = User.objects.filter(_provider_q()).count()
    admins = User.objects.filter(role='admin').count()

    bookings_total = Booking.objects.count()
    bookings_pending = Booking.objects.filter(
        status__in=['pending', 'quoted', 'awaiting_payment']
    ).count()
    bookings_confirmed = Booking.objects.filter(
        Q(status='confirmed') | Q(status='paid') | Q(status='accepted')
    ).count()
    bookings_completed = Booking.objects.filter(status='completed').count()
    bookings_cancelled = Booking.objects.filter(
        Q(status='cancelled') | Q(status='rejected') | Q(status='cancel_req')
    ).count()

    pending_verification_requests = User.objects.filter(
        _provider_q(), verification_status='pending'
    ).count()

    total_services = Service.objects.count()
    total_categories = ServiceCategory.objects.count()
    total_reviews = Review.objects.count()

    revenue = Payment.objects.filter(
        status__in=['completed', 'paid', 'success']
    ).aggregate(s=Sum('amount'))['s'] or Decimal('0')
    payments_count = Payment.objects.count()

    return {
        'total_users': users_total,
        'total_customers': customers,
        'total_providers': providers,
        'total_admins': admins,
        'total_bookings': bookings_total,
        'pending_bookings': bookings_pending,
        'confirmed_bookings': bookings_confirmed,
        'completed_bookings': bookings_completed,
        'cancelled_bookings': bookings_cancelled,
        'pending_verification_requests': pending_verification_requests,
        'total_services': total_services,
        'total_categories': total_categories,
        'total_reviews': total_reviews,
        'total_payments': payments_count,
        'total_revenue': str(revenue),
    }


def booking_status_distribution():
    rows = (
        Booking.objects.values('status')
        .annotate(c=Count('id'))
        .order_by('-c')
    )
    return [{'status': r['status'] or 'unknown', 'count': r['c']} for r in rows]


def bookings_by_month(months_back=12):
    start = timezone.now() - timedelta(days=30 * months_back)
    qs = (
        Booking.objects.filter(created_at__gte=start)
        .annotate(m=TruncMonth('created_at'))
        .values('m')
        .annotate(count=Count('id'))
        .order_by('m')
    )
    out = []
    for row in qs:
        m = row['m']
        label = m.strftime('%Y-%m') if m else ''
        out.append({'month': label, 'bookings': row['count']})
    return out


def revenue_by_month(months_back=12):
    start = timezone.now() - timedelta(days=30 * months_back)
    qs = (
        Payment.objects.filter(
            created_at__gte=start,
            status__in=['completed', 'paid', 'success'],
        )
        .annotate(m=TruncMonth('created_at'))
        .values('m')
        .annotate(total=Sum('amount'))
        .order_by('m')
    )
    out = []
    for row in qs:
        m = row['m']
        label = m.strftime('%Y-%m') if m else ''
        total = row['total'] or Decimal('0')
        out.append({'month': label, 'revenue': str(total)})
    return out


def provider_verification_by_status():
    rows = (
        User.objects.filter(_provider_q())
        .values('verification_status')
        .annotate(c=Count('id'))
        .order_by('-c')
    )
    return [
        {'status': r['verification_status'] or 'unknown', 'count': r['c']} for r in rows
    ]


def _local_day_bounds(d):
    """Start [d 00:00) and end (exclusive) for ORM range filters (SQLite-safe vs __date)."""
    start = timezone.make_aware(datetime.combine(d, time.min))
    end = start + timedelta(days=1)
    return start, end


def trend_last_n_days(days: int = 90):
    """
    Daily booking/payment counts for the trend chart.

    Bookings: `created_at` in each local calendar day; if `created_at` is null,
    use `booking_date`. Payments: `created_at` in that day, else `updated_at`.

    Uses `[start, end)` range queries instead of `__date` — `created_at__date` can
    match zero rows on SQLite with timezone-aware datetimes.

    Default **90 days** so older synced activity still appears on the chart.
    """
    days = max(7, min(int(days), 366))
    today = timezone.now().date()
    out = []
    for i in range(days - 1, -1, -1):
        d = today - timedelta(days=i)
        day_start, day_end = _local_day_bounds(d)
        bc = Booking.objects.filter(
            Q(created_at__gte=day_start, created_at__lt=day_end)
            | Q(created_at__isnull=True, booking_date=d)
        ).count()
        pc = Payment.objects.filter(
            Q(created_at__gte=day_start, created_at__lt=day_end)
            | Q(
                created_at__isnull=True,
                updated_at__gte=day_start,
                updated_at__lt=day_end,
            )
        ).count()
        out.append(
            {
                'date': d.isoformat(),
                'bookings': bc,
                'payments': pc,
            }
        )
    return out


def trend_last_7_days():
    """Backward-compatible alias: last 7 days only (often sparse for stale DBs)."""
    return trend_last_n_days(7)


def market_pulse_score():
    stats = dashboard_stats()
    total = stats['total_bookings'] or 1
    completed = stats['completed_bookings']
    pending = stats['pending_bookings']
    completion_ratio = completed / total
    pending_pressure = min(1.0, pending / max(total, 1))
    score = max(
        0,
        min(100, int(100 * (0.65 * completion_ratio + 0.35 * (1 - pending_pressure)))),
    )
    return {
        'score': score,
        'completion_ratio': round(completion_ratio, 4),
        'pending_bookings': pending,
        'total_bookings': stats['total_bookings'],
    }
