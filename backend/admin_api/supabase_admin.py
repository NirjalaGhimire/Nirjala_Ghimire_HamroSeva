"""
Supabase writes for admin actions. SQLite is refreshed via throttled sync.
"""
import re
from datetime import datetime, timezone

from supabase_config import get_supabase_client


def _provider_doc_status_candidates(status_value):
    status_value = (status_value or '').strip().lower()
    if status_value == 'approved':
        return ['approved', 'verified']
    if status_value == 'pending':
        return ['pending', 'pending_verification', 'under_review']
    if status_value == 'rejected':
        return ['rejected']
    return [status_value]


def update_provider_verification_rows(
    provider_id,
    status_value,
    admin_user_id,
    rejection_reason=None,
):
    """Mirror authentication.admin._update_provider_verification_status without importing admin."""
    supabase = get_supabase_client()
    now_iso = datetime.now(timezone.utc).isoformat()
    base_payload = {
        'review_note': rejection_reason if status_value == 'rejected' else None,
        'reviewed_by': admin_user_id,
        'reviewed_at': now_iso,
        'updated_at': now_iso,
    }

    def _safe_update(payload):
        data = dict(payload or {})
        while data:
            try:
                supabase.table('seva_provider_verification').update(data).eq(
                    'provider_id', provider_id
                ).execute()
                return
            except Exception as e:
                msg = str(e)
                missing_col = None
                if 'PGRST204' in msg and "Could not find the '" in msg:
                    missing_col = msg.split("Could not find the '", 1)[1].split("' column", 1)[0]
                if not missing_col:
                    m = re.search(
                        r"column\s+seva_provider_verification\.([a-zA-Z0-9_]+)\s+does not exist",
                        msg,
                        re.IGNORECASE,
                    )
                    if m:
                        missing_col = m.group(1)
                if not missing_col or missing_col not in data:
                    raise
                data.pop(missing_col, None)

    last_error = None
    for candidate in _provider_doc_status_candidates(status_value):
        payload = dict(base_payload)
        payload['status'] = candidate
        try:
            _safe_update(payload)
            return
        except Exception as e:
            last_error = e
            continue
    if last_error:
        raise last_error


def supabase_insert_notification(user_id, title, body, booking_id=None):
    supabase = get_supabase_client()
    row = {
        'user_id': int(user_id),
        'title': (title or '')[:200],
        'body': body or '',
    }
    if booking_id is not None:
        row['booking_id'] = int(booking_id)
    return supabase.table('seva_notification').insert(row).execute()


def supabase_list_notifications(limit=200, offset=0):
    supabase = get_supabase_client()
    return (
        supabase.table('seva_notification')
        .select('*')
        .order('created_at', desc=True)
        .range(offset, offset + limit - 1)
        .execute()
    )


def supabase_update_booking_status(booking_id, status):
    supabase = get_supabase_client()
    now_iso = datetime.now(timezone.utc).isoformat()
    return (
        supabase.table('seva_booking')
        .update({'status': status, 'updated_at': now_iso})
        .eq('id', int(booking_id))
        .execute()
    )


def supabase_delete_review(review_id):
    supabase = get_supabase_client()
    return supabase.table('seva_review').delete().eq('id', int(review_id)).execute()


def supabase_upsert_service(payload, service_id=None):
    """Insert or update seva_service row."""
    supabase = get_supabase_client()
    now_iso = datetime.now(timezone.utc).isoformat()
    data = {k: v for k, v in payload.items() if v is not None}
    data.setdefault('updated_at', now_iso)
    if service_id:
        return supabase.table('seva_service').update(data).eq('id', int(service_id)).execute()
    data.setdefault('created_at', now_iso)
    return supabase.table('seva_service').insert(data).execute()


def supabase_delete_service(service_id):
    supabase = get_supabase_client()
    return supabase.table('seva_service').delete().eq('id', int(service_id)).execute()


def supabase_upsert_category(payload, category_id=None):
    supabase = get_supabase_client()
    now_iso = datetime.now(timezone.utc).isoformat()
    data = {k: v for k, v in payload.items() if v is not None}
    if category_id:
        return supabase.table('seva_servicecategory').update(data).eq('id', int(category_id)).execute()
    data.setdefault('created_at', now_iso)
    return supabase.table('seva_servicecategory').insert(data).execute()


def supabase_delete_category(category_id):
    supabase = get_supabase_client()
    return supabase.table('seva_servicecategory').delete().eq('id', int(category_id)).execute()


def fetch_provider_verification_docs(provider_id):
    supabase = get_supabase_client()
    return (
        supabase.table('seva_provider_verification')
        .select('*')
        .eq('provider_id', int(provider_id))
        .order('created_at', desc=True)
        .execute()
    )
