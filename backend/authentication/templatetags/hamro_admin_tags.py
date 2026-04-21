"""Template tags for Hamro Sewa Django admin dashboard (real SQLite / synced data)."""
import json
import logging
from datetime import datetime

from django import template
from django.utils.safestring import mark_safe

logger = logging.getLogger(__name__)

register = template.Library()


def _empty_stats(message=None):
    empty_trend = mark_safe(json.dumps([]))
    return {
        'users': 0,
        'bookings': 0,
        'payments': 0,
        'services': 0,
        'reviews': 0,
        'refunds': 0,
        'categories': 0,
        'pending_bookings': 0,
        'pending_verification_requests': 0,
        'completed_bookings': 0,
        'confirmed_bookings': 0,
        'cancelled_bookings': 0,
        'providers': 0,
        'customers': 0,
        'market_pulse': 0,
        'total_revenue': '0',
        'trend_labels_json': empty_trend,
        'trend_bookings_json': empty_trend,
        'trend_payments_json': empty_trend,
        'stats_error': message,
    }


@register.simple_tag
def hamro_admin_stats():
    """
    Counts from SQLite (synced from Supabase) for admin dashboard.
    Uses the same logic as admin_api.queries so the SPA and Django admin match.
    """
    try:
        from admin_api import queries
        from services.models import Refund

        s = queries.dashboard_stats()
        trend = queries.trend_last_n_days(90)
        pulse = queries.market_pulse_score()
        refunds = Refund.objects.count()

        labels = []
        for row in trend:
            try:
                d = datetime.fromisoformat(str(row['date']))
                labels.append(d.strftime('%d %b'))
            except Exception:
                labels.append(str(row.get('date', ''))[:16])

        tb = [int(row.get('bookings') or 0) for row in trend]
        tp = [int(row.get('payments') or 0) for row in trend]

        return {
            'users': s['total_users'],
            'bookings': s['total_bookings'],
            'payments': s['total_payments'],
            'services': s['total_services'],
            'reviews': s['total_reviews'],
            'refunds': refunds,
            'categories': s['total_categories'],
            'pending_bookings': s['pending_bookings'],
            'pending_verification_requests': s['pending_verification_requests'],
            'completed_bookings': s['completed_bookings'],
            'confirmed_bookings': s['confirmed_bookings'],
            'cancelled_bookings': s['cancelled_bookings'],
            'providers': s['total_providers'],
            'customers': s['total_customers'],
            'market_pulse': int(pulse.get('score', 0)),
            'total_revenue': s.get('total_revenue', '0'),
            'trend_labels_json': mark_safe(json.dumps(labels)),
            'trend_bookings_json': mark_safe(json.dumps(tb)),
            'trend_payments_json': mark_safe(json.dumps(tp)),
            'stats_error': None,
        }
    except Exception as exc:
        logger.exception('hamro_admin_stats failed')
        return _empty_stats(str(exc))
