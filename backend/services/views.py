import json
import mimetypes
import re
import logging
import time as pytime
from datetime import date, time, datetime
from decimal import Decimal

from django.shortcuts import render
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework import status
from .models import ServiceCategory, Service, Booking, Review, ProviderTimeSlot, CustomerProfile
from .serializers import (
    ServiceCategorySerializer, ServiceSerializer, BookingSerializer,
    CreateBookingSerializer, ReviewSerializer, DashboardStatsSerializer,
    CustomerProfileSerializer, CustomerProfileUpdateSerializer,
)
from .category_matching import (
    provider_profession_matches_catalog_service_title,
    provider_profession_matches_category,
)
from .provider_services import (
    ensure_provider_default_service,
    ensure_provider_service_in_category,
    dedupe_services_by_provider_and_title,
)
from .category_matching import catalog_service_title_matches_category
from .service_name_utils import dedupe_catalog_signup_rows
from authentication.models import User
from authentication.serializers import UserProfileSerializer as AuthUserProfileSerializer
from admin_api.service_requests import create_request as create_service_request_record
from supabase_config import get_supabase_client


logger = logging.getLogger(__name__)


# Process-local cache for heavy services list payloads.
_SERVICES_CACHE = {}
_SERVICES_CACHE_TTL_SECONDS = 20
_PROVIDER_RATING_CACHE = {}
_PROVIDER_RATING_CACHE_TTL_SECONDS = 30


def _services_cache_key(category_id=None, provider_id=None):
    return (
        int(category_id) if category_id is not None else None,
        int(provider_id) if provider_id is not None else None,
    )


def _services_cache_get(category_id=None, provider_id=None):
    key = _services_cache_key(category_id=category_id, provider_id=provider_id)
    entry = _SERVICES_CACHE.get(key)
    if not entry:
        return None
    if entry.get('expires_at', 0) <= pytime.time():
        _SERVICES_CACHE.pop(key, None)
        return None
    data = entry.get('data') or []
    return [dict(item) if isinstance(item, dict) else item for item in data]


def _services_cache_set(category_id, provider_id, data):
    key = _services_cache_key(category_id=category_id, provider_id=provider_id)
    _SERVICES_CACHE[key] = {
        'expires_at': pytime.time() + _SERVICES_CACHE_TTL_SECONDS,
        'data': [dict(item) if isinstance(item, dict) else item for item in (data or [])],
    }


def _provider_rating_cache_get(provider_id):
    pid = _to_int(provider_id)
    if pid is None:
        return None
    entry = _PROVIDER_RATING_CACHE.get(pid)
    if not entry:
        return None
    if entry.get('expires_at', 0) <= pytime.time():
        _PROVIDER_RATING_CACHE.pop(pid, None)
        return None
    return {
        'sum': float(entry.get('sum', 0.0)),
        'count': int(entry.get('count', 0)),
    }


def _provider_rating_cache_set(provider_id, rating_sum, rating_count):
    pid = _to_int(provider_id)
    if pid is None:
        return
    _PROVIDER_RATING_CACHE[pid] = {
        'expires_at': pytime.time() + _PROVIDER_RATING_CACHE_TTL_SECONDS,
        'sum': float(rating_sum or 0.0),
        'count': int(rating_count or 0),
    }


def _get_provider_rating_acc_map(supabase, provider_ids):
    rating_acc = {}
    if not provider_ids:
        return rating_acc

    missing = []
    for pid in provider_ids:
        cached = _provider_rating_cache_get(pid)
        if cached is None:
            missing.append(pid)
        else:
            rating_acc[pid] = cached

    if missing:
        fetched_acc = {pid: {'sum': 0.0, 'count': 0} for pid in missing}
        ratings_r = (
            supabase
            .table('seva_review')
            .select('provider_id,rating')
            .in_('provider_id', missing)
            .execute()
        )
        for item in (ratings_r.data or []):
            pid = _to_int(item.get('provider_id'))
            if pid is None or pid not in fetched_acc:
                continue
            try:
                val = int(item.get('rating'))
            except (TypeError, ValueError):
                continue
            if val < 1 or val > 5:
                continue
            fetched_acc[pid]['sum'] += float(val)
            fetched_acc[pid]['count'] += 1

        for pid, acc in fetched_acc.items():
            _provider_rating_cache_set(pid, acc.get('sum', 0.0), acc.get('count', 0))
            rating_acc[pid] = acc

    return rating_acc


def normalize_verification_status(value):
    raw = (value or '').strip().lower()
    aliases = {
        'pending_verification': 'pending',
        'under_review': 'pending',
        'on_hold': 'pending',
        'verified': 'approved',
    }
    return aliases.get(raw, raw if raw in {'unverified', 'pending', 'approved', 'rejected'} else 'unverified')


def is_provider_verified(row):
    return normalize_verification_status(row.get('verification_status')) == 'approved'


def _provider_status_from_user_row(row):
    return normalize_verification_status(row.get('verification_status') or 'unverified')


def _provider_status_map_from_docs(supabase, provider_ids):
    """
    Build provider_id -> effective verification status from verification docs.
    Priority: approved > pending > rejected > unverified.
    """
    pids = []
    for pid in provider_ids:
        if pid is None:
            continue
        try:
            pids.append(int(pid))
        except (TypeError, ValueError):
            continue
    if not pids:
        return {}
    try:
        r = (
            supabase.table(PROVIDER_VERIFICATION_TABLE)
            .select('provider_id,status')
            .in_('provider_id', pids)
            .execute()
        )
    except Exception:
        return {}
    grouped = {}
    for row in (r.data or []):
        try:
            pid = int(row.get('provider_id'))
        except (TypeError, ValueError):
            continue
        if pid not in pids:
            continue
        status = normalize_verification_status(row.get('status') or 'unverified')
        grouped.setdefault(pid, set()).add(status)
    out = {}
    for pid, statuses in grouped.items():
        if 'approved' in statuses:
            out[pid] = 'approved'
        elif 'pending' in statuses:
            out[pid] = 'pending'
        elif 'rejected' in statuses:
            out[pid] = 'rejected'
        else:
            out[pid] = 'unverified'
    return out


def _safe_update_auth_user(supabase, user_id, payload):
    """
    Update seva_auth_user while tolerating optional/missing columns on older schemas.
    Retries after dropping unknown columns reported by PostgREST (PGRST204).
    """
    data = dict(payload or {})
    while data:
        try:
            return supabase.table('seva_auth_user').update(data).eq('id', user_id).execute()
        except Exception as e:
            msg = str(e)
            if 'PGRST204' not in msg or "Could not find the '" not in msg:
                raise
            missing = msg.split("Could not find the '", 1)[1].split("' column", 1)[0]
            if missing not in data:
                raise
            data.pop(missing, None)
    return None

PAYMENT_TABLE = 'seva_payment'
REFUND_TABLE = 'seva_refund'
RECEIPT_TABLE = 'seva_receipt'

# Booking status vocabulary used across customer/provider/admin views.
BOOKING_STATUS_PENDING = 'pending'
BOOKING_STATUS_QUOTED = 'quoted'
BOOKING_STATUS_AWAITING_PAYMENT = 'awaiting_payment'
BOOKING_STATUS_PAID = 'paid'
BOOKING_STATUS_CANCELLATION_REQUESTED = 'cancel_req'
BOOKING_STATUS_CANCELLED = 'cancelled'
BOOKING_STATUS_REFUND_PENDING = 'refund_pending'
BOOKING_STATUS_REFUND_PROVIDER_APPROVED = 'refund_p_approved'
BOOKING_STATUS_REFUND_PROVIDER_REJECTED = 'refund_p_rejected'
BOOKING_STATUS_REFUNDED = 'refunded'
BOOKING_STATUS_REFUND_REJECTED = 'refund_rejected'
BOOKING_STATUS_COMPLETED = 'completed'

# Payment status vocabulary (stored in seva_payment.status).
PAYMENT_STATUS_PENDING = 'pending'
PAYMENT_STATUS_COMPLETED = 'completed'
PAYMENT_STATUS_FAILED = 'failed'
PAYMENT_STATUS_REFUND_PENDING = 'refund_pending'
PAYMENT_STATUS_REFUNDED = 'refunded'
PAYMENT_STATUS_REFUND_REJECTED = 'refund_rejected'

# Refund status vocabulary (stored in seva_refund.status).
REFUND_STATUS_PENDING = 'refund_pending'
REFUND_STATUS_PROVIDER_APPROVED = 'refund_provider_approved'
REFUND_STATUS_PROVIDER_REJECTED = 'refund_provider_rejected'
REFUND_STATUS_UNDER_REVIEW = 'refund_under_review'
REFUND_STATUS_COMPLETED = 'refunded'
REFUND_STATUS_REJECTED = 'refund_rejected'


def _notify_user(supabase, user_id, title, body, booking_id=None):
    if user_id is None:
        return
    try:
        payload = {
            'user_id': int(user_id),
            'title': title,
            'body': body,
        }
        if booking_id is not None:
            payload['booking_id'] = int(booking_id)
        supabase.table('seva_notification').insert(payload).execute()
    except Exception:
        pass


def _get_admin_user_ids(supabase):
    out = []
    try:
        users_r = supabase.table('seva_auth_user').select('id,role').execute()
        for row in users_r.data or []:
            if (row.get('role') or '').strip().lower() != 'admin':
                continue
            rid = _to_int(row.get('id'))
            if rid is not None:
                out.append(rid)
    except Exception:
        return []
    return out

FAVORITE_PROVIDER_TABLE = 'seva_favorite_provider'
FAVORITE_SERVICE_TABLE = 'seva_favorite_service'
CUSTOMER_PROFILE_TABLE = CustomerProfile._meta.db_table


def _normalized_role(user):
    return (getattr(user, 'role', '') or '').strip().lower()


def _is_customer_user(user):
    return _normalized_role(user) == 'customer'


def _is_provider_user(user):
    return _normalized_role(user) in ('provider', 'prov')


def _customer_profile_table_missing(exc):
    msg = str(exc or '')
    return 'PGRST205' in msg and CUSTOMER_PROFILE_TABLE in msg


def _customer_profile_setup_message():
    return (
        'Customer profile table is missing in Supabase. '
        'Run backend/create_customer_profiles_table.sql in Supabase SQL editor.'
    )


def _full_name_from_auth_row(row):
    first = (row.get('first_name') or '').strip() if isinstance(row, dict) else ''
    last = (row.get('last_name') or '').strip() if isinstance(row, dict) else ''
    full = f'{first} {last}'.strip()
    if full:
        return full
    if isinstance(row, dict):
        return (row.get('username') or row.get('email') or 'Customer').strip()
    return 'Customer'


def _load_auth_user_row(supabase, user_id):
    r = (
        supabase
        .table('seva_auth_user')
        .select('id,username,first_name,last_name,email,phone,profile_image_url')
        .eq('id', int(user_id))
        .limit(1)
        .execute()
    )
    if r.data and len(r.data) > 0:
        return r.data[0]
    return None


def _default_customer_profile_payload(user, auth_row=None):
    base = auth_row or {
        'username': getattr(user, 'username', '') or '',
        'first_name': getattr(user, 'first_name', '') or '',
        'last_name': getattr(user, 'last_name', '') or '',
        'email': getattr(user, 'email', '') or '',
        'phone': getattr(user, 'phone', '') or '',
        'profile_image_url': getattr(user, 'profile_image_url', '') or '',
    }
    return {
        'full_name': _full_name_from_auth_row(base),
        'email': (base.get('email') or '').strip().lower(),
        'phone': (base.get('phone') or '').strip(),
        'location': '',
        'profile_image_url': (base.get('profile_image_url') or '').strip(),
    }


def _profile_from_auth_row(user_id, auth_row):
    return {
        'id': None,
        'user_id': int(user_id),
        'full_name': _full_name_from_auth_row(auth_row),
        'email': (auth_row.get('email') or '').strip().lower(),
        'phone': (auth_row.get('phone') or '').strip(),
        'location': '',
        'profile_image_url': (auth_row.get('profile_image_url') or '').strip(),
        'created_at': None,
        'updated_at': None,
    }


def _get_customer_profile_row(supabase, user_id):
    r = (
        supabase
        .table(CUSTOMER_PROFILE_TABLE)
        .select('*')
        .eq('user_id', int(user_id))
        .limit(1)
        .execute()
    )
    if r.data and len(r.data) > 0:
        return r.data[0]
    return None


def _upsert_customer_profile_row(supabase, user_id, payload):
    now_iso = datetime.now().isoformat()
    row = _get_customer_profile_row(supabase, user_id)
    if row:
        update_payload = dict(payload)
        update_payload['updated_at'] = now_iso
        supabase.table(CUSTOMER_PROFILE_TABLE).update(update_payload).eq('id', row.get('id')).execute()
        refreshed = _get_customer_profile_row(supabase, user_id)
        return refreshed or {**row, **update_payload}

    insert_payload = {
        'user_id': int(user_id),
        **payload,
        'created_at': now_iso,
        'updated_at': now_iso,
    }
    created = supabase.table(CUSTOMER_PROFILE_TABLE).insert(insert_payload).execute()
    if created.data and len(created.data) > 0:
        return created.data[0]
    refreshed = _get_customer_profile_row(supabase, user_id)
    return refreshed or insert_payload


def _is_missing_favorites_table_error(exc):
    msg = str(exc or '')
    if 'PGRST205' not in msg:
        return False
    return FAVORITE_PROVIDER_TABLE in msg or FAVORITE_SERVICE_TABLE in msg


def _favorites_setup_message():
    return (
        'Favorites tables are missing in Supabase. '
        'Run backend/create_favorites_tables.sql in Supabase SQL editor.'
    )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def current_customer_profile(request):
    if not _is_customer_user(request.user):
        return Response({'error': 'Only customers can access customer profile'}, status=status.HTTP_403_FORBIDDEN)
    try:
        supabase = get_supabase_client()
        row = _get_customer_profile_row(supabase, request.user.id)
        if not row:
            auth_row = _load_auth_user_row(supabase, request.user.id)
            if auth_row is None:
                return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)
            defaults = _default_customer_profile_payload(request.user, auth_row)
            row = _upsert_customer_profile_row(supabase, request.user.id, defaults)
        return Response(CustomerProfileSerializer(instance=row).data)
    except Exception as e:
        if _customer_profile_table_missing(e):
            return Response({'error': _customer_profile_setup_message()}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['PATCH', 'PUT'])
@permission_classes([IsAuthenticated])
def current_customer_profile_update(request):
    if not _is_customer_user(request.user):
        return Response({'error': 'Only customers can update customer profile'}, status=status.HTTP_403_FORBIDDEN)
    serializer = CustomerProfileUpdateSerializer(data=request.data)
    if not serializer.is_valid():
        return Response({'error': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)
    try:
        supabase = get_supabase_client()
        payload = {
            'full_name': serializer.validated_data['full_name'],
            'email': serializer.validated_data['email'],
            'phone': serializer.validated_data['phone'],
            'location': (serializer.validated_data.get('location') or '').strip(),
        }
        row = _upsert_customer_profile_row(supabase, request.user.id, payload)
        _safe_update_auth_user(
            supabase,
            request.user.id,
            {
                'email': payload['email'],
                'phone': payload['phone'],
            },
        )
        return Response(CustomerProfileSerializer(instance=row).data)
    except Exception as e:
        if _customer_profile_table_missing(e):
            return Response({'error': _customer_profile_setup_message()}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def customer_profile_upload_image(request):
    if not _is_customer_user(request.user):
        return Response({'error': 'Only customers can upload customer profile image'}, status=status.HTTP_403_FORBIDDEN)
    try:
        uploaded_file = request.FILES.get('file')
        if uploaded_file is None:
            return Response({'error': 'No file uploaded (field name: file)'}, status=status.HTTP_400_BAD_REQUEST)
        supabase = get_supabase_client()
        bucket = 'chat-attachments'
        file_name = getattr(uploaded_file, 'name', '') or 'avatar.jpg'
        content_type = getattr(uploaded_file, 'content_type', None)
        guessed = mimetypes.guess_type(file_name)[0]
        if not content_type or content_type == 'application/octet-stream':
            content_type = guessed or 'image/jpeg'
        safe_name = re.sub(r'[^a-zA-Z0-9._-]', '_', file_name)
        ts = int(datetime.utcnow().timestamp())
        uid = request.user.id
        storage_path = f'customer_profile_avatars/{uid}/{ts}_{safe_name}'
        file_bytes = uploaded_file.read()
        supabase.storage.from_(bucket).upload(
            storage_path,
            file_bytes,
            file_options={'content-type': content_type},
        )
        signed = supabase.storage.from_(bucket).create_signed_url(
            storage_path, expires_in=365 * 24 * 60 * 60
        )
        image_url = signed.get('signedURL') or signed.get('signedUrl')
        if not image_url:
            return Response({'error': 'Could not create image URL'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        row = _get_customer_profile_row(supabase, uid)
        if row:
            payload = {'profile_image_url': image_url}
        else:
            auth_row = _load_auth_user_row(supabase, uid)
            payload = _default_customer_profile_payload(request.user, auth_row)
            payload['profile_image_url'] = image_url
        saved = _upsert_customer_profile_row(supabase, uid, payload)

        _safe_update_auth_user(supabase, uid, {'profile_image_url': image_url})
        out = CustomerProfileSerializer(instance=saved).data
        out['profile_image_url'] = image_url
        return Response(out)
    except Exception as e:
        if _customer_profile_table_missing(e):
            return Response({'error': _customer_profile_setup_message()}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def provider_view_customer_profile(request, booking_id):
    if not _is_provider_user(request.user):
        return Response({'error': 'Only providers can access this endpoint'}, status=status.HTTP_403_FORBIDDEN)
    try:
        supabase = get_supabase_client()
        b_res = (
            supabase
            .table(Booking._meta.db_table)
            .select('id,customer_id,service_id')
            .eq('id', int(booking_id))
            .limit(1)
            .execute()
        )
        if not b_res.data or len(b_res.data) == 0:
            return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)
        booking = b_res.data[0]

        s_res = (
            supabase
            .table(Service._meta.db_table)
            .select('id,provider_id')
            .eq('id', booking.get('service_id'))
            .limit(1)
            .execute()
        )
        if not s_res.data or len(s_res.data) == 0:
            return Response({'error': 'Service not found for booking'}, status=status.HTTP_404_NOT_FOUND)
        provider_id = s_res.data[0].get('provider_id')
        if provider_id != request.user.id:
            return Response({'error': 'Forbidden: customer is not linked to your booking'}, status=status.HTTP_403_FORBIDDEN)

        customer_id = booking.get('customer_id')
        if customer_id is None:
            return Response({'error': 'Booking has no customer'}, status=status.HTTP_400_BAD_REQUEST)

        row = _get_customer_profile_row(supabase, customer_id)
        if not row:
            auth_row = _load_auth_user_row(supabase, customer_id)
            if not auth_row:
                return Response({'error': 'Customer not found'}, status=status.HTTP_404_NOT_FOUND)
            row = _profile_from_auth_row(customer_id, auth_row)

        return Response(CustomerProfileSerializer(instance=row).data)
    except Exception as e:
        if _customer_profile_table_missing(e):
            return Response({'error': _customer_profile_setup_message()}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


def _to_json_serializable(obj):
    """Convert dict/list so Response() can serialize to JSON (Supabase returns date/time/Decimal)."""
    if obj is None:
        return None
    if isinstance(obj, (date, datetime)):
        return obj.isoformat()
    if isinstance(obj, time):
        return str(obj)
    if isinstance(obj, Decimal):
        return str(obj)
    if isinstance(obj, dict):
        return {k: _to_json_serializable(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_to_json_serializable(v) for v in obj]
    return obj


def _to_int(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _is_active_row(row):
    """Treat missing is_active as active for backward compatibility."""
    if not isinstance(row, dict):
        return True
    is_active = row.get('is_active')
    if is_active is None:
        return True
    return bool(is_active)


def _active_favorite_provider_rows(supabase, customer_id):
    r = (
        supabase
        .table(FAVORITE_PROVIDER_TABLE)
        .select('*')
        .eq('customer_id', customer_id)
        .order('created_at', desc=True)
        .execute()
    )
    rows = [row for row in (r.data or []) if _is_active_row(row)]
    # Keep latest row per provider_id if duplicates exist from old data.
    seen = set()
    deduped = []
    for row in rows:
        pid = _to_int(row.get('provider_id'))
        if pid is None or pid in seen:
            continue
        seen.add(pid)
        deduped.append(row)
    return deduped


def _active_favorite_service_rows(supabase, customer_id):
    r = (
        supabase
        .table(FAVORITE_SERVICE_TABLE)
        .select('*')
        .eq('customer_id', customer_id)
        .order('created_at', desc=True)
        .execute()
    )
    rows = [row for row in (r.data or []) if _is_active_row(row)]
    seen = set()
    deduped = []
    for row in rows:
        sid = _to_int(row.get('service_id'))
        if sid is None or sid in seen:
            continue
        seen.add(sid)
        deduped.append(row)
    return deduped

class SupabaseManager:
    @staticmethod
    def get_all(model_class, serializer_class):
        supabase = get_supabase_client()
        table_name = model_class._meta.db_table
        try:
            response = supabase.table(table_name).select('*').execute()
            if response.data:
                return serializer_class(response.data, many=True).data
            return []
        except Exception as e:
            print(f"Error fetching {table_name}: {e}")
            return []
    
    @staticmethod
    def create(model_class, serializer_class, data):
        supabase = get_supabase_client()
        table_name = model_class._meta.db_table
        try:
            response = supabase.table(table_name).insert(data).execute()
            if response.data:
                return serializer_class(response.data[0]).data
            return None
        except Exception as e:
            print(f"Error creating {table_name}: {e}")
            return None
    
    @staticmethod
    def update(model_class, serializer_class, record_id, data):
        supabase = get_supabase_client()
        table_name = model_class._meta.db_table
        try:
            response = supabase.table(table_name).update(data).eq('id', record_id).execute()
            if response.data:
                return serializer_class(response.data[0]).data
            return None
        except Exception as e:
            print(f"Error updating {table_name}: {e}")
            return None
    
    @staticmethod
    def get_filtered(model_class, serializer_class, filters):
        supabase = get_supabase_client()
        table_name = model_class._meta.db_table
        try:
            query = supabase.table(table_name).select('*')
            for field, value in filters.items():
                query = query.eq(field, value)
            response = query.execute()
            if response.data:
                return serializer_class(response.data, many=True).data
            return []
        except Exception as e:
            print(f"Error filtering {table_name}: {e}")
            return []

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def dashboard_stats(request):
    """Get dashboard statistics for the logged-in user (real data from Supabase)."""
    try:
        user = request.user
        if getattr(user, 'role', None) == 'provider':
            services = _get_services_raw_from_supabase(provider_id=user.id)
            service_ids = [s['id'] for s in services if s.get('id') is not None]
            bookings = _get_bookings_raw_from_supabase(service_ids=service_ids) if service_ids else []
            pending = len([b for b in bookings if (b.get('status') or '').lower() == 'pending'])
            completed = len([b for b in bookings if (b.get('status') or '').lower() == 'completed'])
            total_earnings = 0
            for b in bookings:
                if (b.get('status') or '').lower() == 'completed':
                    amt = b.get('total_amount')
                    if amt is not None:
                        try:
                            total_earnings += float(amt)
                        except (TypeError, ValueError):
                            pass
            avg_rating = 0.0
            try:
                supabase = get_supabase_client()
                r = supabase.table('seva_review').select('rating').eq('provider_id', user.id).execute()
                if r.data and len(r.data) > 0:
                    total = sum(float(x.get('rating') or 0) for x in r.data)
                    avg_rating = total / len(r.data)
            except Exception:
                pass
            stats = {
                'total_bookings': len(bookings),
                'pending_bookings': pending,
                'completed_bookings': completed,
                'total_services': len(services),
                'average_rating': round(avg_rating, 1),
                'total_earnings': round(total_earnings, 2),
                'remaining_payout': round(total_earnings, 2),
                'cash_in_hand': round(total_earnings, 2),
            }
        else:
            bookings = _get_bookings_raw_from_supabase(customer_id=user.id)
            stats = {
                'total_bookings': len(bookings),
                'pending_bookings': len([b for b in bookings if (b.get('status') or '').lower() == 'pending']),
                'completed_bookings': len([b for b in bookings if (b.get('status') or '').lower() == 'completed']),
                'total_services': 0,
                'average_rating': 0.0,
                'total_earnings': 0,
                'remaining_payout': 0,
                'cash_in_hand': 0,
            }
        serializer = DashboardStatsSerializer(stats)
        return Response(serializer.data)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def user_profile(request):
    """Get user profile (role, email, etc.). Uses auth serializer - no ORM relations."""
    serializer = AuthUserProfileSerializer(request.user)
    data = dict(serializer.data)
    role = (getattr(request.user, 'role', '') or '').strip().lower()
    if role in ('provider', 'prov'):
        effective_status = _provider_status_from_user_row(data)
        data['verification_status'] = effective_status
        data['is_verified'] = effective_status == 'approved'
        data['is_active_provider'] = effective_status == 'approved'
    return Response(data)


@api_view(['PATCH', 'PUT'])
@permission_classes([IsAuthenticated])
def user_profile_update(request):
    """Update current user profile in Supabase and Django (username, email, phone, profession, qualification, etc)."""
    user = request.user
    data = request.data
    if not isinstance(data, dict):
        return Response({'error': 'Invalid body'}, status=status.HTTP_400_BAD_REQUEST)
    updates = {}
    for key in (
        'username', 'email', 'phone', 'profession',
        'qualification', 'profile_image_url',
        'first_name', 'last_name',
        'district', 'city',
    ):
        if key in data and data[key] is not None:
            val = data[key]
            if isinstance(val, str):
                val = val.strip()
            updates[key] = val
    if not updates:
        serializer = AuthUserProfileSerializer(user)
        return Response(serializer.data)
    try:
        supabase = get_supabase_client()
        supabase_payload = {
            key: val
            for key, val in updates.items()
            if key in {
                'username', 'email', 'phone', 'profession',
                'qualification', 'profile_image_url',
                'first_name', 'last_name',
                'district', 'city',
            }
        }

        # Update Django User model fields for fields that exist in the model
        for key, val in updates.items():
            if hasattr(user, key):
                setattr(user, key, val)
        user.save()  # This also syncs to Supabase via the save() method

        # Write the profile fields explicitly as well so qualification survives even if
        # the model-save fallback skips a column on older schemas.
        if supabase_payload:
            _safe_update_auth_user(supabase, user.id, supabase_payload)
        
        # Fetch the updated user directly from Supabase to ensure we get all fields
        try:
            result = supabase.table('seva_auth_user').select('*').eq('id', user.id).limit(1).execute()
            if result.data and len(result.data) > 0:
                supabase_user = result.data[0]
                # Update Django user with any Supabase fields
                for key, val in supabase_user.items():
                    if hasattr(user, key) and key not in ('created_at', 'updated_at', 'password'):
                        setattr(user, key, val)
        except Exception as e:
            # If Supabase fetch fails, continue with Django user
            pass
        
        serializer = AuthUserProfileSerializer(user)
        return Response(serializer.data)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET'])
@permission_classes([AllowAny])
def service_categories(request):
    """Get all service categories (public so Choose provider can load)."""
    try:
        from .serializers import ServiceCategorySerializer
        categories = SupabaseManager.get_all(ServiceCategory, ServiceCategorySerializer)
        if categories:
            print(f"✅ Found {len(categories)} categories from Supabase")
            return Response(categories)
        else:
            print("⚠️ No categories found in Supabase")
    except Exception as e:
        print(f"❌ Error getting categories from Supabase: {e}")
    return Response([])


@api_view(['GET'])
@permission_classes([AllowAny])
def providers_list(request):
    """List all providers (id, username, profession, district, city) for registration dropdown etc.
    
    CRITICAL: Filters out deleted users and non-provider roles to show ONLY valid providers.
    """
    try:
        supabase = get_supabase_client()
        # Fetch all users with role; DB may use 'prov' or 'provider'
        r = supabase.table('seva_auth_user').select(
            'id,username,profession,role,district,city,verification_status,is_active_provider,is_active,email'
        ).execute()
        data = list(r.data) if r.data else []
        
        # Filter to only valid providers: has provider role, NOT deleted, NOT inactive
        provider_roles = ('prov', 'provider')
        providers = [
            p for p in data
            if (p.get('role') or '').strip().lower() in provider_roles
            and not _is_deleted_user(p)
        ]
        
        docs_status_map = _provider_status_map_from_docs(supabase, [p.get('id') for p in providers])
        out = [{
            'id': p.get('id'),
            'username': p.get('username') or '',
            'profession': (p.get('profession') or '').strip(),
            'district': (p.get('district') or '').strip(),
            'city': (p.get('city') or '').strip(),
            'verification_status': (
                docs_status_map.get(int(p.get('id'))) if p.get('id') is not None else 'unverified'
            ),
            'is_verified': (
                (docs_status_map.get(int(p.get('id'))) if p.get('id') is not None else 'unverified')
                == 'approved'
            ),
        } for p in providers]
        return Response(out)
    except Exception as e:
        print(f"Error fetching providers: {e}")
        return Response([])


@api_view(['GET'])
@permission_classes([AllowAny])
def provider_detail(request, provider_id):
    """Get a single provider profile with live database fields and services."""
    try:
        provider = User.objects.get(id=provider_id)
        provider_data = dict(AuthUserProfileSerializer(provider).data)
        role = (provider_data.get('role') or '').strip().lower()
        if role not in ('provider', 'prov') or _is_deleted_user(provider_data):
            return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)

        services = _get_services_raw_from_supabase(provider_id=provider_id)
        reviews_r = (
            get_supabase_client()
            .table('seva_review')
            .select('rating')
            .eq('provider_id', provider_id)
            .execute()
        )
        ratings = []
        for row in (reviews_r.data or []):
            try:
                value = int(row.get('rating'))
                if 1 <= value <= 5:
                    ratings.append(value)
            except (TypeError, ValueError):
                continue
        rating_count = len(ratings)
        rating_average = round(sum(ratings) / rating_count, 2) if rating_count else 0.0
        categories = []
        seen_category_ids = set()
        for service in services:
            category_id = service.get('category_id')
            category_key = category_id if category_id is not None else service.get('category_name')
            if category_key in seen_category_ids:
                continue
            seen_category_ids.add(category_key)
            category_name = (service.get('category_name') or '').strip()
            if category_name:
                categories.append({
                    'id': category_id,
                    'name': category_name,
                })

        return Response({
            'user': provider_data,
            'services': [
                {
                    'id': service.get('id'),
                    'title': service.get('title'),
                    'category_id': service.get('category_id'),
                    'category_name': service.get('category_name'),
                    'price': service.get('price'),
                    'status': service.get('status'),
                    'location': service.get('location'),
                    'image_url': service.get('image_url'),
                    'created_at': service.get('created_at'),
                }
                for service in services
            ],
            'categories': categories,
            'summary': {
                'total_services': len(services),
                'rating_average': rating_average,
                'rating_count': rating_count,
            },
        })
    except Exception as e:
        print(f"Error fetching provider detail: {e}")
        return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def favorites_summary(request):
    """Quick summary used by cards/search to render correct heart state."""
    try:
        supabase = get_supabase_client()
        provider_rows = _active_favorite_provider_rows(supabase, request.user.id)
        service_rows = _active_favorite_service_rows(supabase, request.user.id)
        provider_ids = [
            pid for pid in [_to_int(row.get('provider_id')) for row in provider_rows]
            if pid is not None
        ]
        service_ids = [
            sid for sid in [_to_int(row.get('service_id')) for row in service_rows]
            if sid is not None
        ]
        return Response({
            'favorite_provider_ids': provider_ids,
            'favorite_service_ids': service_ids,
        })
    except Exception as e:
        if _is_missing_favorites_table_error(e):
            return Response({
                'favorite_provider_ids': [],
                'favorite_service_ids': [],
                'setup_required': True,
                'message': _favorites_setup_message(),
            })
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def favorite_provider_add(request):
    """Add provider to current customer's favorites (idempotent)."""
    provider_id = _to_int(request.data.get('provider_id'))
    if provider_id is None:
        return Response({'error': 'provider_id is required'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        supabase = get_supabase_client()
        pr = (
            supabase
            .table('seva_auth_user')
            .select('id,role,is_active,username')
            .eq('id', provider_id)
            .limit(1)
            .execute()
        )
        if not pr.data:
            return Response({'error': 'Provider not found'}, status=status.HTTP_404_NOT_FOUND)
        row = pr.data[0]
        role = (row.get('role') or '').strip().lower()
        if role not in ('provider', 'prov'):
            return Response({'error': 'Selected user is not a provider'}, status=status.HTTP_400_BAD_REQUEST)
        if row.get('is_active') is False:
            return Response({'error': 'Provider is unavailable'}, status=status.HTTP_400_BAD_REQUEST)

        existing = (
            supabase
            .table(FAVORITE_PROVIDER_TABLE)
            .select('*')
            .eq('customer_id', request.user.id)
            .eq('provider_id', provider_id)
            .order('id', desc=True)
            .limit(1)
            .execute()
        )
        if existing.data:
            ex = existing.data[0]
            if ex.get('is_active') is False:
                updated = (
                    supabase
                    .table(FAVORITE_PROVIDER_TABLE)
                    .update({'is_active': True, 'updated_at': datetime.now().isoformat()})
                    .eq('id', ex.get('id'))
                    .execute()
                )
                return Response({'success': True, 'favorite': _to_json_serializable((updated.data or [ex])[0])})
            return Response({'success': True, 'favorite': _to_json_serializable(ex)})

        created = (
            supabase
            .table(FAVORITE_PROVIDER_TABLE)
            .insert({
                'customer_id': request.user.id,
                'provider_id': provider_id,
                'is_active': True,
            })
            .execute()
        )
        favorite = (created.data or [{}])[0]
        return Response({'success': True, 'favorite': _to_json_serializable(favorite)}, status=status.HTTP_201_CREATED)
    except Exception as e:
        if _is_missing_favorites_table_error(e):
            return Response({
                'success': False,
                'setup_required': True,
                'message': _favorites_setup_message(),
            })
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def favorite_provider_remove(request, provider_id):
    """Remove provider from current customer's favorites."""
    provider_id_int = _to_int(provider_id)
    if provider_id_int is None:
        return Response({'error': 'Invalid provider id'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        supabase = get_supabase_client()
        (
            supabase
            .table(FAVORITE_PROVIDER_TABLE)
            .delete()
            .eq('customer_id', request.user.id)
            .eq('provider_id', provider_id_int)
            .execute()
        )
        return Response({'success': True})
    except Exception as e:
        if _is_missing_favorites_table_error(e):
            return Response({
                'success': False,
                'setup_required': True,
                'message': _favorites_setup_message(),
            })
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def favorite_providers_list(request):
    """Return current customer's favorite providers with hydrated provider details.
    
    CRITICAL: Filters out deleted providers and non-provider roles.
    """
    try:
        supabase = get_supabase_client()
        favorite_rows = _active_favorite_provider_rows(supabase, request.user.id)
        provider_ids = [
            pid for pid in [_to_int(row.get('provider_id')) for row in favorite_rows]
            if pid is not None
        ]
        if not provider_ids:
            return Response([])

        users_r = (
            supabase
            .table('seva_auth_user')
            .select('id,username,profession,verification_status,is_active,role,district,city,email')
            .in_('id', provider_ids)
            .execute()
        )
        # Filter to only valid providers: not deleted, has provider role
        users_map = {
            _to_int(u.get('id')): u
            for u in (users_r.data or [])
            if _to_int(u.get('id')) is not None
            and not _is_deleted_user(u)
            and _is_valid_provider_user(u)
        }

        reviews_r = (
            supabase
            .table('seva_review')
            .select('provider_id,rating')
            .in_('provider_id', list(users_map.keys()))
            .execute()
        )
        rating_acc = {}
        for row in (reviews_r.data or []):
            pid = _to_int(row.get('provider_id'))
            if pid is None:
                continue
            rating_acc.setdefault(pid, {'sum': 0.0, 'count': 0})
            try:
                rating_acc[pid]['sum'] += float(row.get('rating') or 0)
                rating_acc[pid]['count'] += 1
            except (TypeError, ValueError):
                continue

        service_r = (
            supabase
            .table(Service._meta.db_table)
            .select('provider_id,category_id,status')
            .in_('provider_id', list(users_map.keys()))
            .execute()
        )
        provider_category_id = {}
        category_ids = set()
        for row in (service_r.data or []):
            if (row.get('status') or '').strip().lower() not in ('', 'active'):
                continue
            pid = _to_int(row.get('provider_id'))
            cid = _to_int(row.get('category_id'))
            if pid is None or cid is None or pid in provider_category_id:
                continue
            provider_category_id[pid] = cid
            category_ids.add(cid)

        category_map = {}
        if category_ids:
            cat_r = (
                supabase
                .table(ServiceCategory._meta.db_table)
                .select('id,name')
                .in_('id', list(category_ids))
                .execute()
            )
            category_map = {
                _to_int(c.get('id')): c.get('name')
                for c in (cat_r.data or [])
                if _to_int(c.get('id')) is not None
            }

        out = []
        for fav in favorite_rows:
            pid = _to_int(fav.get('provider_id'))
            if pid is None or pid not in users_map:
                # Skip if provider was deleted or filtered out
                continue
            
            user = users_map.get(pid)
            rating = rating_acc.get(pid, {'sum': 0.0, 'count': 0})
            count = rating.get('count', 0) or 0
            average = round((rating.get('sum', 0.0) / count), 2) if count else None

            cid = provider_category_id.get(pid)
            out.append({
                'favorite_id': fav.get('id'),
                'provider_id': pid,
                'provider_name': (user or {}).get('username') or 'Unavailable provider',
                'provider_profession': (user or {}).get('profession') or '',
                'profile_image_url': (user or {}).get('profile_image_url'),
                'category_id': cid,
                'category_name': category_map.get(cid) or '',
                'rating_average': average,
                'rating_count': count,
                'verification_status': _provider_status_from_user_row(user or {}),
                'is_verified': _provider_status_from_user_row(user or {}) == 'approved',
                'district': (user or {}).get('district') or '',
                'city': (user or {}).get('city') or '',
                'is_available': True,
                'unavailable_reason': None,
                'created_at': fav.get('created_at'),
            })
        return Response(_to_json_serializable(out))
    except Exception as e:
        if _is_missing_favorites_table_error(e):
            return Response([])
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def favorite_service_add(request):
    """Add service to current customer's favorites (idempotent)."""
    service_id = _to_int(request.data.get('service_id'))
    if service_id is None:
        return Response({'error': 'service_id is required'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        supabase = get_supabase_client()
        sr = (
            supabase
            .table(Service._meta.db_table)
            .select('id,status')
            .eq('id', service_id)
            .limit(1)
            .execute()
        )
        if not sr.data:
            return Response({'error': 'Service not found'}, status=status.HTTP_404_NOT_FOUND)

        existing = (
            supabase
            .table(FAVORITE_SERVICE_TABLE)
            .select('*')
            .eq('customer_id', request.user.id)
            .eq('service_id', service_id)
            .order('id', desc=True)
            .limit(1)
            .execute()
        )
        if existing.data:
            ex = existing.data[0]
            if ex.get('is_active') is False:
                updated = (
                    supabase
                    .table(FAVORITE_SERVICE_TABLE)
                    .update({'is_active': True, 'updated_at': datetime.now().isoformat()})
                    .eq('id', ex.get('id'))
                    .execute()
                )
                return Response({'success': True, 'favorite': _to_json_serializable((updated.data or [ex])[0])})
            return Response({'success': True, 'favorite': _to_json_serializable(ex)})

        created = (
            supabase
            .table(FAVORITE_SERVICE_TABLE)
            .insert({
                'customer_id': request.user.id,
                'service_id': service_id,
                'is_active': True,
            })
            .execute()
        )
        favorite = (created.data or [{}])[0]
        return Response({'success': True, 'favorite': _to_json_serializable(favorite)}, status=status.HTTP_201_CREATED)
    except Exception as e:
        if _is_missing_favorites_table_error(e):
            return Response({
                'success': False,
                'setup_required': True,
                'message': _favorites_setup_message(),
            })
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def favorite_service_remove(request, service_id):
    """Remove service from current customer's favorites."""
    service_id_int = _to_int(service_id)
    if service_id_int is None:
        return Response({'error': 'Invalid service id'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        supabase = get_supabase_client()
        (
            supabase
            .table(FAVORITE_SERVICE_TABLE)
            .delete()
            .eq('customer_id', request.user.id)
            .eq('service_id', service_id_int)
            .execute()
        )
        return Response({'success': True})
    except Exception as e:
        if _is_missing_favorites_table_error(e):
            return Response({
                'success': False,
                'setup_required': True,
                'message': _favorites_setup_message(),
            })
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def favorite_services_list(request):
    """Return current customer's favorite services with hydrated service/provider details.
    
    CRITICAL: Filters out deleted providers and corrupted/invalid service rows.
    """
    try:
        supabase = get_supabase_client()
        favorite_rows = _active_favorite_service_rows(supabase, request.user.id)
        service_ids = [
            sid for sid in [_to_int(row.get('service_id')) for row in favorite_rows]
            if sid is not None
        ]
        if not service_ids:
            return Response([])

        service_r = (
            supabase
            .table(Service._meta.db_table)
            .select('id,title,provider_id,category_id,price,status,image_url,description')
            .in_('id', service_ids)
            .execute()
        )
        # Filter to only valid services: not corrupted, has required fields
        service_map = {
            _to_int(s.get('id')): s
            for s in (service_r.data or [])
            if _to_int(s.get('id')) is not None
            and _is_valid_service_row(s)
        }

        provider_ids = {
            _to_int(s.get('provider_id'))
            for s in service_map.values()
            if _to_int(s.get('provider_id')) is not None
        }
        category_ids = {
            _to_int(s.get('category_id'))
            for s in service_map.values()
            if _to_int(s.get('category_id')) is not None
        }

        provider_map = {}
        if provider_ids:
            user_r = (
                supabase
                .table('seva_auth_user')
                .select('id,username,is_active,verification_status,role,email')
                .in_('id', list(provider_ids))
                .execute()
            )
            # Filter to only valid providers: not deleted, has provider role
            provider_map = {
                _to_int(u.get('id')): u
                for u in (user_r.data or [])
                if _to_int(u.get('id')) is not None
                and not _is_deleted_user(u)
                and _is_valid_provider_user(u)
            }

        category_map = {}
        if category_ids:
            cat_r = (
                supabase
                .table(ServiceCategory._meta.db_table)
                .select('id,name')
                .in_('id', list(category_ids))
                .execute()
            )
            category_map = {
                _to_int(c.get('id')): c.get('name')
                for c in (cat_r.data or [])
                if _to_int(c.get('id')) is not None
            }

        out = []
        for fav in favorite_rows:
            sid = _to_int(fav.get('service_id'))
            if sid is None or sid not in service_map:
                # Skip if service not found or was filtered out
                continue
            
            service = service_map.get(sid)
            pid = _to_int(service.get('provider_id'))
            provider = provider_map.get(pid) if pid else None
            
            # Skip if provider was deleted or filtered out
            if pid is None or provider is None:
                continue
            
            cid = _to_int(service.get('category_id'))
            out.append({
                'favorite_id': fav.get('id'),
                'service_id': sid,
                'service_name': (service or {}).get('title') or 'Unavailable service',
                'provider_id': pid,
                'provider_name': provider.get('username') or '',
                'provider_profile_image_url': provider.get('profile_image_url'),
                'provider_verification_status': _provider_status_from_user_row(provider),
                'provider_is_verified': _provider_status_from_user_row(provider) == 'approved',
                'category_id': cid,
                'category_name': category_map.get(cid) or '',
                'price': (service or {}).get('price'),
                'quote_type': 'quoted' if ((service or {}).get('price') in (None, '', 0, '0', '0.0')) else 'fixed',
                'image_url': (service or {}).get('image_url'),
                'is_available': True,
                'unavailable_reason': None,
                'created_at': fav.get('created_at'),
            })
        return Response(_to_json_serializable(out))
    except Exception as e:
        if _is_missing_favorites_table_error(e):
            return Response([])
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([AllowAny])
def location_districts(request):
    """Distinct non-empty district values from registered providers (for filter dropdowns)."""
    try:
        supabase = get_supabase_client()
        r = supabase.table('seva_auth_user').select('district,role,verification_status,is_active_provider').execute()
        districts = set()
        for row in (r.data or []):
            if (row.get('role') or '').strip().lower() not in ('provider', 'prov'):
                continue
            d = (row.get('district') or '').strip()
            if d:
                districts.add(d)
        return Response(sorted(districts))
    except Exception as e:
        print(f"Error fetching districts: {e}")
        return Response([])


@api_view(['GET'])
@permission_classes([AllowAny])
def location_cities(request):
    """Distinct non-empty city values from providers and active services.

    Optional ?district= narrows provider cities directly and narrows service
    locations using each service provider's saved district.
    """
    district_param = (request.query_params.get('district') or '').strip()
    nd = _normalize_location_part(district_param) if district_param else ''
    try:
        supabase = get_supabase_client()
        r = supabase.table('seva_auth_user').select(
            'id,city,district,role,verification_status,is_active_provider'
        ).execute()
        provider_district_map = {}
        cities = set()
        for row in (r.data or []):
            if (row.get('role') or '').strip().lower() not in ('provider', 'prov'):
                continue
            provider_district_map[row.get('id')] = _normalize_location_part(
                row.get('district') or ''
            )
            if nd:
                pd = provider_district_map.get(row.get('id')) or ''
                if pd != nd:
                    continue
            c = (row.get('city') or '').strip()
            if c:
                cities.add(c)
        services_r = supabase.table(Service._meta.db_table).select(
            'location,provider_id,status'
        ).execute()
        for row in (services_r.data or []):
            status_value = _normalize_location_part(row.get('status') or '')
            if status_value and status_value != 'active':
                continue
            if nd:
                provider_district = provider_district_map.get(row.get('provider_id')) or ''
                if provider_district != nd:
                    continue
            raw_location = (row.get('location') or '').strip()
            if not raw_location or _is_generic_service_location(raw_location):
                continue
            cities.add(raw_location)
        return Response(sorted(cities))
    except Exception as e:
        print(f"Error fetching cities: {e}")
        return Response([])


def _is_deleted_user(user_row):
    """Check if a user has been marked as deleted (anonymized username/email pattern)."""
    if not user_row:
        return False
    username = (user_row.get('username') or '').strip()
    email = (user_row.get('email') or '').strip()
    is_active = user_row.get('is_active', True)
    
    # Deleted users have anonymized usernames like "deleted_26_1702123456"
    if username and username.startswith('deleted_'):
        return True
    # Deleted users have email like "deleted_26@hamroseva.local"
    if email and ('@hamroseva.local' in email or email.startswith('deleted_')):
        return True
    # Explicitly inactive users
    if not is_active:
        return True
    return False


def _is_valid_provider_user(user_row):
    """Check if user is a valid provider (has provider role and active)."""
    if not user_row or _is_deleted_user(user_row):
        return False
    role = (user_row.get('role') or '').strip().lower()
    is_provider_role = role in ('provider', 'prov')
    is_active_provider = bool(user_row.get('is_active_provider', False))
    
    # User must have provider role
    if not is_provider_role:
        return False
    # User must be marked as active provider or at least have role=provider
    # (we'll let the enrichment layer decide verification status)
    return True


def _is_valid_service_row(service_row):
    """Check if a service row is valid and not corrupted/placeholder."""
    if not service_row:
        return False
    
    title = (service_row.get('title') or '').strip()
    description = (service_row.get('description') or '').strip()
    category_id = service_row.get('category_id')
    provider_id = service_row.get('provider_id')
    price = service_row.get('price')
    
    # Must have required fields
    if not title or not category_id or not provider_id:
        return False
    
    # Exclude placeholder/corrupted rows
    invalid_patterns = {
        'EMPTY',
        'empty',
        'NULL',
        'null',
        'N/A',
        'n/a',
        'undefined',
        'UNDEFINED',
        'TBD',
        'tbd',
    }
    
    if title in invalid_patterns or description in invalid_patterns:
        return False
    
    # Exclude rows with zero or negative price (unless it's intentionally free)
    if price is not None:
        try:
            price_float = float(price)
            if price_float < 0:
                return False
        except (TypeError, ValueError):
            return False
    
    return True


def _enrich_services_with_category_and_provider_names(services):
    """Add category_name, provider_name, and provider_profession to each service.
    
    CRITICAL: 
    - Excludes deleted users (username like deleted_*, email like *@hamroseva.local)
    - Excludes non-provider roles  
    - Excludes corrupted service rows (EMPTY descriptions, missing required fields, negative prices)
    - Validates provider location and verification status from database
    """
    if not services:
        return services
    
    # First pass: filter out invalid service rows before enrichment
    valid_services = [s for s in services if _is_valid_service_row(s)]
    
    if not valid_services:
        return []
    
    try:
        supabase = get_supabase_client()
        categories = supabase.table(ServiceCategory._meta.db_table).select('id,name').execute()
        category_map = {c['id']: c.get('name') or '' for c in (categories.data or [])}
        provider_ids = list({s.get('provider_id') for s in valid_services if s.get('provider_id') is not None})
        # CRITICAL: provider verification is derived from verification-doc rows, not the auth_user cache.
        docs_status_map = _provider_status_map_from_docs(supabase, provider_ids)
        provider_map = {}  # pid -> {'username': ..., 'profession': ..., 'district', 'city'}
        if provider_ids:
            provider_rows = (
                supabase.table('seva_auth_user')
                .select(
                    'id,username,email,profession,district,city,verification_status,role,is_active_provider,is_active'
                )
                .in_('id', provider_ids)
                .execute()
            )
            for row in (provider_rows.data or []):
                try:
                    pid_int = int(row.get('id'))
                except (TypeError, ValueError):
                    continue

                # CRITICAL: Check if user is deleted
                if _is_deleted_user(row):
                    continue

                # VALIDATION: Only include providers with proper role
                if not _is_valid_provider_user(row):
                    continue

                role = (row.get('role') or '').strip().lower()
                district = (row.get('district') or '').strip()
                city = (row.get('city') or '').strip()

                # Verification status must come from verification documents.
                effective_status = docs_status_map.get(pid_int) if role in ('provider', 'prov') else None
                if not effective_status:
                    effective_status = 'unverified'
                is_verified = role in ('provider', 'prov') and effective_status == 'approved'

                provider_map[pid_int] = {
                    'name': row.get('username') or row.get('email') or 'Provider',
                    'profession': (row.get('profession') or '').strip(),
                    'district': district,
                    'city': city,
                    'verification_status': effective_status,
                    'is_verified': is_verified,  # ONLY true for approved providers
                    'role': role,
                    'is_provider_role': True,
                    'is_active_provider': bool(row.get('is_active_provider', False)),
                }
        
        # Second pass: enrich valid services and filter out those with missing provider info
        enriched_services = []
        for s in valid_services:
            s['category_name'] = category_map.get(s.get('category_id')) or s.get('category_name') or ''
            try:
                pid_int = int(s.get('provider_id')) if s.get('provider_id') is not None else None
            except (TypeError, ValueError):
                pid_int = None
            
            # CRITICAL: If provider not found or is deleted, skip this service
            if pid_int not in provider_map:
                continue
            
            info = provider_map.get(pid_int) or {}
            s['provider_name'] = info.get('name') or 'Provider'
            s['provider_profession'] = info.get('profession') or ''
            # CRITICAL: Location data must come from database, not API defaults
            s['provider_district'] = info.get('district') or ''  # Empty string if no district set
            s['provider_city'] = info.get('city') or ''  # Empty string if no city set
            # CRITICAL: Only 'approved' means verified
            s['provider_verification_status'] = info.get('verification_status') or 'unverified'
            s['provider_is_verified'] = bool(info.get('is_verified'))
            s['provider_role'] = info.get('role') or ''
            s['provider_is_provider'] = bool(info.get('is_provider_role'))
            s['provider_is_active_provider'] = bool(info.get('is_active_provider'))
            
            enriched_services.append(s)
        
        return enriched_services
    except Exception as e:
        print(f"Enrich services warning: {e}")
        import traceback
        traceback.print_exc()
    return []


def _normalize_location_part(value):
    return re.sub(r'\s+', ' ', (value or '').strip().lower()).strip(' ,')


def _split_location_parts(value):
    normalized = _normalize_location_part(value)
    if not normalized:
        return set()
    return {
        part.strip(' ,')
        for part in re.split(r'[,/|]+', normalized)
        if part.strip(' ,')
    }


def _is_generic_service_location(value):
    return _normalize_location_part(value) in {
        'online',
        'remote',
        'virtual',
        'anywhere',
        'nationwide',
        'all nepal',
        'all over nepal',
    }


def _service_matches_city(service, normalized_city):
    service_location = service.get('location') or ''
    normalized_location = _normalize_location_part(service_location)
    if normalized_location:
        if _is_generic_service_location(service_location):
            return False
        return normalized_city in _split_location_parts(service_location)
    provider_city = _normalize_location_part(service.get('provider_city') or '')
    return provider_city == normalized_city


def _filter_services_by_provider_location(services, district_filter, city_filter):
    """Keep services whose saved availability / provider location match filters.

    STRICT MATCHING:
    - Both district & city must match provider's saved location and service location
    - Returns ONLY services/providers that actually belong to the selected location
    - Validates provider_district and provider_city are not empty/null before accepting
    """
    d = (district_filter or '').strip()
    c = (city_filter or '').strip()
    if not d and not c:
        return services
    if not services:
        return services
    
    nd, nc = _normalize_location_part(d), _normalize_location_part(c)
    out = []
    for s in services:
        pd = _normalize_location_part(s.get('provider_district') or '')
        pc = _normalize_location_part(s.get('provider_city') or '')

        service_parts = _split_location_parts(s.get('location') or '')
        district_matches = False
        city_matches = False

        # District filter: prefer provider's saved district; fall back to service location when missing.
        if nd:
            if pd:
                district_matches = pd == nd
            else:
                district_matches = nd in service_parts
        else:
            district_matches = True

        # If city filter is provided, it must match
        if nc:
            if pc:
                # Prefer provider_city if available
                city_matches = pc == nc
            else:
                # Fallback to service location
                city_matches = _service_matches_city(s, nc)
        else:
            city_matches = True

        # Only include if BOTH district and city match
        if district_matches and city_matches:
            out.append(s)
    
    return out


def _add_equivalent_title_rows(services, category_id):
    """
    Previously duplicated rows across "equivalent" catalog titles using fuzzy profession
    matching. That caused unrelated providers (e.g. Electrician) to appear under
    "Appliance Repair Specialist". Disabled — browse uses strict profession↔title matching
    only; each seva_service row stands for itself.
    """
    return services


def _get_services_raw_from_supabase(category_id=None, provider_id=None):
    """
    Fetch services from Supabase as raw dicts (no Django serializer).
    
    CRITICAL: 
    - Filters out deleted providers
    - Filters out corrupted/placeholder service rows
    - Filters out non-provider roles
    - Enriches with provider and category info
    
    Supabase returns provider_id/category_id; ServiceSerializer expects provider/category objects
    and would raise KeyError. So we use raw fetch + enrichment only.
    """
    supabase = get_supabase_client()
    table_name = Service._meta.db_table
    try:
        cached = _services_cache_get(category_id=category_id, provider_id=provider_id)
        if cached is not None:
            return cached

        query = supabase.table(table_name).select('*')
        if category_id is not None:
            query = query.eq('category_id', category_id)
        if provider_id is not None:
            query = query.eq('provider_id', provider_id)
        response = query.execute()
        data = list(response.data) if response.data else []
        
        # Filter out invalid service rows before enrichment
        # This prevents deleted providers and corrupted rows from appearing
        valid_data = [
            s for s in data 
            if _is_valid_service_row(s) and s.get('provider_id')
        ]
        
        if not valid_data:
            return []
        
        # Enrich with provider/category info and filter out deleted providers
        enriched = _enrich_services_with_category_and_provider_names(valid_data)

        _services_cache_set(category_id, provider_id, enriched)
        
        return enriched
    except Exception as e:
        print(f"Error fetching {table_name} (raw): {e}")
        import traceback
        traceback.print_exc()
        return []


def _get_bookings_raw_from_supabase(customer_id=None, service_id=None, service_ids=None):
    """Fetch bookings from Supabase as raw dicts (no serializer)."""
    supabase = get_supabase_client()
    table_name = Booking._meta.db_table
    try:
        if service_ids is not None:
            normalized_service_ids = sorted({
                _to_int(sid) for sid in service_ids if _to_int(sid) is not None
            })
            if not normalized_service_ids:
                return []
            try:
                r = (
                    supabase
                    .table(table_name)
                    .select('*')
                    .in_('service_id', normalized_service_ids)
                    .execute()
                )
                return list(r.data) if r.data else []
            except Exception:
                # Fallback for environments where .in_ is unavailable.
                out = []
                for sid in normalized_service_ids:
                    r = supabase.table(table_name).select('*').eq('service_id', sid).execute()
                    if r.data:
                        out.extend(r.data)
                return out
        query = supabase.table(table_name).select('*')
        if customer_id is not None:
            query = query.eq('customer_id', customer_id)
        if service_id is not None:
            query = query.eq('service_id', service_id)
        response = query.execute()
        return list(response.data) if response.data else []
    except Exception as e:
        print(f"Error fetching {table_name} (raw): {e}")
        return []


def _enrich_bookings_with_names(bookings):
    """Add customer_name, service_title, provider_name to each booking (Supabase returns only IDs)."""
    if not bookings:
        return bookings
    try:
        supabase = get_supabase_client()
        customer_ids = sorted({
            _to_int(b.get('customer_id')) for b in bookings if _to_int(b.get('customer_id')) is not None
        })
        service_ids = sorted({
            _to_int(b.get('service_id')) for b in bookings if _to_int(b.get('service_id')) is not None
        })
        customer_map = {}
        customer_profile_map = {}
        if customer_ids:
            customer_rows = (
                supabase.table('seva_auth_user').select(
                    'id,username,first_name,last_name,email,phone,profile_image_url'
                ).in_('id', customer_ids).execute()
            )
            for row in (customer_rows.data or []):
                cid = _to_int(row.get('id'))
                if cid is None:
                    continue
                customer_map[cid] = {
                    'name': _full_name_from_auth_row(row),
                    'email': row.get('email') or '',
                    'phone': row.get('phone') or '',
                    'profile_image_url': row.get('profile_image_url') or '',
                }

            customer_profiles = (
                supabase.table(CUSTOMER_PROFILE_TABLE).select(
                    'user_id,full_name,email,phone,location,profile_image_url,updated_at,created_at'
                ).in_('user_id', customer_ids).execute()
            )
            for row in (customer_profiles.data or []):
                cid = _to_int(row.get('user_id'))
                if cid is None or cid in customer_profile_map:
                    continue
                customer_profile_map[cid] = row

        service_map = {}  # service_id -> {title, provider_id}
        if service_ids:
            service_rows = (
                supabase.table(Service._meta.db_table)
                .select('id,title,provider_id')
                .in_('id', service_ids)
                .execute()
            )
            for row in (service_rows.data or []):
                sid = _to_int(row.get('id'))
                if sid is None:
                    continue
                service_map[sid] = row

        provider_ids = sorted({
            _to_int(s.get('provider_id')) for s in service_map.values() if _to_int(s.get('provider_id')) is not None
        })
        docs_status_map = _provider_status_map_from_docs(supabase, provider_ids)
        provider_map = {}
        if provider_ids:
            provider_rows = (
                supabase.table('seva_auth_user').select(
                    'id,username,email,phone,verification_status,role'
                ).in_('id', provider_ids).execute()
            )
            for row in (provider_rows.data or []):
                pid = _to_int(row.get('id'))
                if pid is None:
                    continue
                role = (row.get('role') or '').strip().lower()
                is_provider_role = role in ('provider', 'prov')
                effective_status = docs_status_map.get(pid) if is_provider_role else None
                if not effective_status:
                    effective_status = 'unverified'
                provider_map[pid] = {
                    'name': row.get('username') or row.get('email') or 'Provider',
                    'email': row.get('email') or '',
                    'phone': row.get('phone') or '',
                    'verification_status': effective_status,
                    'is_verified': effective_status == 'approved',
                }

        booking_ids = sorted({
            _to_int(b.get('id')) for b in bookings if _to_int(b.get('id')) is not None
        })
        payment_map = {}
        refund_map = {}
        receipt_map = {}
        if booking_ids:
            payment_rows = (
                supabase.table(PAYMENT_TABLE)
                .select('*')
                .in_('booking_id', booking_ids)
                .order('id', desc=True)
                .execute()
            )
            for row in (payment_rows.data or []):
                bid = _to_int(row.get('booking_id'))
                if bid is None or bid in payment_map:
                    continue
                payment_map[bid] = row

            refund_rows = (
                supabase.table(REFUND_TABLE)
                .select('*')
                .in_('booking_id', booking_ids)
                .order('id', desc=True)
                .execute()
            )
            for row in (refund_rows.data or []):
                bid = _to_int(row.get('booking_id'))
                if bid is None or bid in refund_map:
                    continue
                refund_map[bid] = row

            receipt_rows = (
                supabase.table(RECEIPT_TABLE)
                .select('*')
                .in_('booking_id', booking_ids)
                .order('id', desc=True)
                .execute()
            )
            for row in (receipt_rows.data or []):
                bid = _to_int(row.get('booking_id'))
                if bid is None or bid in receipt_map:
                    continue
                receipt_map[bid] = row

        for b in bookings:
            booking_customer_id = _to_int(b.get('customer_id'))
            booking_service_id = _to_int(b.get('service_id'))
            booking_id = _to_int(b.get('id'))

            customer = customer_map.get(booking_customer_id)
            customer_profile = customer_profile_map.get(booking_customer_id)
            if isinstance(customer_profile, dict):
                b['customer_name'] = (
                    (customer_profile.get('full_name') or '').strip()
                    or ((customer or {}).get('name') if isinstance(customer, dict) else 'Customer')
                )
                b['customer_email'] = (
                    (customer_profile.get('email') or '').strip()
                    or ((customer or {}).get('email') if isinstance(customer, dict) else '')
                )
                b['customer_phone'] = (
                    (customer_profile.get('phone') or '').strip()
                    or ((customer or {}).get('phone') if isinstance(customer, dict) else '')
                )
                b['customer_location'] = (customer_profile.get('location') or '').strip()
                b['customer_profile_image_url'] = (
                    (customer_profile.get('profile_image_url') or '').strip()
                    or ((customer or {}).get('profile_image_url') if isinstance(customer, dict) else '')
                )
            else:
                b['customer_name'] = customer.get('name') if isinstance(customer, dict) else 'Customer'
                b['customer_email'] = customer.get('email') if isinstance(customer, dict) else ''
                b['customer_phone'] = customer.get('phone') if isinstance(customer, dict) else ''
                b['customer_location'] = ''
                b['customer_profile_image_url'] = (
                    customer.get('profile_image_url') if isinstance(customer, dict) else ''
                )
            svc = service_map.get(booking_service_id) or {}
            b['service_title'] = svc.get('title') or f"Service #{b.get('service_id')}"
            provider_id = _to_int(svc.get('provider_id'))
            b['provider_id'] = provider_id
            prov = provider_map.get(provider_id) or {}
            b['provider_name'] = prov.get('name', 'Provider') if isinstance(prov, dict) else 'Provider'
            b['provider_email'] = prov.get('email', '') if isinstance(prov, dict) else ''
            b['provider_phone'] = prov.get('phone', '') if isinstance(prov, dict) else ''
            b['provider_verification_status'] = (
                prov.get('verification_status', 'unverified') if isinstance(prov, dict) else 'unverified'
            )
            b['provider_is_verified'] = (b.get('provider_verification_status') or '').strip().lower() == 'approved'
            p = payment_map.get(booking_id) or {}
            b['payment_status'] = (p.get('status') or '').strip().lower()
            b['payment_amount'] = p.get('amount')
            b['payment_transaction_id'] = p.get('transaction_id')
            b['payment_ref_id'] = p.get('ref_id')
            rf = refund_map.get(booking_id) or {}
            b['refund_id'] = rf.get('id')
            b['refund_status'] = (rf.get('status') or '').strip().lower()
            b['refund_amount'] = rf.get('refund_amount')
            b['refund_reason'] = rf.get('refund_reason') or ''
            b['refund_note'] = rf.get('admin_note') or rf.get('system_note') or ''
            rc = receipt_map.get(booking_id) or {}
            b['receipt_id'] = rc.get('id')
            b['receipt_number'] = rc.get('receipt_id')
    except Exception as e:
        print(f"Enrich bookings warning: {e}")
    return bookings


def _latest_payment_for_booking(supabase, booking_id):
    """Return latest payment row for booking_id, or None."""
    try:
        r = (
            supabase
            .table(PAYMENT_TABLE)
            .select('*')
            .eq('booking_id', int(booking_id))
            .order('id', desc=True)
            .limit(1)
            .execute()
        )
        if r.data and len(r.data) > 0:
            return r.data[0]
    except Exception:
        pass
    return None


def _latest_refund_for_booking(supabase, booking_id):
    """Return latest refund row for booking_id, or None."""
    try:
        r = (
            supabase
            .table(REFUND_TABLE)
            .select('*')
            .eq('booking_id', int(booking_id))
            .order('id', desc=True)
            .limit(1)
            .execute()
        )
        if r.data and len(r.data) > 0:
            return r.data[0]
    except Exception:
        pass
    return None


def _is_refund_terminal(status_value):
    status_value = (status_value or '').strip().lower()
    return status_value in {REFUND_STATUS_COMPLETED, REFUND_STATUS_REJECTED}


def _latest_receipt_for_booking(supabase, booking_id):
    try:
        r = (
            supabase
            .table(RECEIPT_TABLE)
            .select('*')
            .eq('booking_id', int(booking_id))
            .order('id', desc=True)
            .limit(1)
            .execute()
        )
        if r.data and len(r.data) > 0:
            return r.data[0]
    except Exception:
        pass
    return None


def _create_or_update_receipt_for_booking(supabase, booking_id, payment=None):
    """Idempotent receipt creation/update after payment/refund transitions."""
    try:
        br = supabase.table(Booking._meta.db_table).select('*').eq('id', int(booking_id)).limit(1).execute()
        if not br.data or len(br.data) == 0:
            return None
        booking = br.data[0]
        payment = payment or _latest_payment_for_booking(supabase, booking_id)
        if not payment:
            return None
        pstatus = (payment.get('status') or '').strip().lower()
        if pstatus not in {
            PAYMENT_STATUS_COMPLETED,
            PAYMENT_STATUS_REFUND_PENDING,
            PAYMENT_STATUS_REFUND_REJECTED,
            PAYMENT_STATUS_REFUNDED,
        }:
            return None

        service_name = f"Service #{booking.get('service_id')}"
        provider_id = None
        try:
            sr = supabase.table(Service._meta.db_table).select('title,provider_id').eq(
                'id', booking.get('service_id')
            ).limit(1).execute()
            if sr.data and len(sr.data) > 0:
                service_name = sr.data[0].get('title') or service_name
                provider_id = sr.data[0].get('provider_id')
        except Exception:
            pass

        rid = f"RCPT-{booking_id}-{payment.get('id') or payment.get('transaction_id')}"
        paid_amount = float(payment.get('amount') or booking.get('total_amount') or 0)
        discount_amount = 0.0
        tax_amount = 0.0
        service_charge = 0.0
        final_total = max(0.0, paid_amount - discount_amount + tax_amount + service_charge)
        latest_refund = _latest_refund_for_booking(supabase, booking_id)
        refund_status = (latest_refund.get('status') or '').strip().lower() if latest_refund else None
        if refund_status == REFUND_STATUS_COMPLETED:
            refund_status = 'refund_successful'
        issued_at = payment.get('updated_at') or payment.get('created_at') or datetime.now().isoformat()

        payload = {
            'receipt_id': rid,
            'booking_id': int(booking_id),
            'payment_id': payment.get('id'),
            'customer_id': booking.get('customer_id'),
            'provider_id': provider_id,
            'service_name': service_name,
            'payment_method': (payment.get('gateway') or payment.get('payment_method') or 'esewa'),
            'paid_amount': str(paid_amount),
            'discount_amount': str(discount_amount),
            'tax_amount': str(tax_amount),
            'service_charge': str(service_charge),
            'final_total': str(final_total),
            'payment_status': pstatus,
            'refund_status': refund_status,
            'issued_at': issued_at,
            'updated_at': datetime.now().isoformat(),
        }
        existing = None
        if payment.get('id') is not None:
            ex = supabase.table(RECEIPT_TABLE).select('*').eq('payment_id', payment.get('id')).limit(1).execute()
            if ex.data and len(ex.data) > 0:
                existing = ex.data[0]
        if not existing:
            ex2 = supabase.table(RECEIPT_TABLE).select('*').eq('receipt_id', rid).limit(1).execute()
            if ex2.data and len(ex2.data) > 0:
                existing = ex2.data[0]
        if existing:
            supabase.table(RECEIPT_TABLE).update(payload).eq('id', existing.get('id')).execute()
            fr = supabase.table(RECEIPT_TABLE).select('*').eq('id', existing.get('id')).limit(1).execute()
            return (fr.data or [existing])[0]

        payload['created_at'] = datetime.now().isoformat()
        cr = supabase.table(RECEIPT_TABLE).insert(payload).execute()
        if cr.data and len(cr.data) > 0:
            return cr.data[0]
    except Exception as e:
        print(f"Receipt generation warning: {e}")
    return None


def _customer_can_cancel(current_status: str) -> bool:
    return current_status in {
        BOOKING_STATUS_PENDING,
        BOOKING_STATUS_QUOTED,
        BOOKING_STATUS_AWAITING_PAYMENT,
        'confirmed',  # backward-compatibility
        'accepted',   # backward-compatibility
        BOOKING_STATUS_PAID,
    }


def _provider_can_cancel(current_status: str) -> bool:
    return current_status in {
        BOOKING_STATUS_PENDING,
        BOOKING_STATUS_QUOTED,
        BOOKING_STATUS_AWAITING_PAYMENT,
        'confirmed',  # backward-compatibility
        'accepted',   # backward-compatibility
    }


def _provider_can_review_refund(current_status: str) -> bool:
    return current_status in {
        BOOKING_STATUS_CANCELLATION_REQUESTED,
        BOOKING_STATUS_REFUND_PENDING,
    }


@api_view(['GET'])
@permission_classes([AllowAny])
def services_list(request):
    """Get all services with optional filtering (public so Choose provider can load).

    Query: district, city — filter by provider's saved location (see registration).
    Skipped when for_signup=1 so signup dropdowns still see all catalog rows.
    """
    category_id = request.query_params.get('category')
    provider_id = request.query_params.get('provider')
    for_signup = request.query_params.get('for_signup', '').lower() in ('1', 'true', 'yes')
    loc_district = (request.query_params.get('district') or '').strip()
    loc_city = (request.query_params.get('city') or '').strip()

    def _sanitize_location_filter_value(value: str) -> str:
        raw = (value or '').strip()
        if not raw:
            return ''
        normalized = _normalize_location_part(raw)
        # Treat common UI placeholders / sentinel values as "no filter".
        if normalized in {
            'any',
            'any district',
            'any city',
            'all',
            'all locations',
            'all services available',
            'select district',
            'select city',
            'none',
            'null',
            'undefined',
        }:
            return ''
        return raw

    loc_district = _sanitize_location_filter_value(loc_district)
    loc_city = _sanitize_location_filter_value(loc_city)

    def _respond(services_payload):
        def _attach_provider_ratings(rows):
            provider_ids = sorted({
                _to_int(row.get('provider_id'))
                for row in rows
                if _to_int(row.get('provider_id')) is not None
            })
            if not provider_ids:
                return rows

            try:
                rating_acc = _get_provider_rating_acc_map(get_supabase_client(), provider_ids)
            except Exception:
                return rows

            out = []
            for row in rows:
                mapped = dict(row)
                pid = _to_int(mapped.get('provider_id'))
                acc = rating_acc.get(pid, {'sum': 0.0, 'count': 0})
                count = int(acc.get('count') or 0)
                mapped['rating_count'] = count
                mapped['rating_average'] = round((acc.get('sum', 0.0) / count), 2) if count else 0.0
                out.append(mapped)
            return out

        if services_payload:
            services_payload = _attach_provider_ratings(services_payload)
        if (
            not for_signup
            and services_payload
            and (loc_district or loc_city)
        ):
            services_payload = _filter_services_by_provider_location(
                services_payload, loc_district, loc_city
            )
        return Response(services_payload)

    cid = None
    if category_id:
        try:
            cid = int(category_id)
        except (TypeError, ValueError):
            pass
    pid = None
    if provider_id:
        try:
            pid = int(provider_id)
        except (TypeError, ValueError):
            pass

    # Backfill is expensive (iterates every provider + potential writes), so keep it opt-in.
    # Use only for maintenance/debug by adding ?backfill=1 to the request.
    should_backfill = request.query_params.get('backfill', '').lower() in ('1', 'true', 'yes')
    if cid is not None and not for_signup and should_backfill:
        try:
            supabase = get_supabase_client()
            cat_row = supabase.table(ServiceCategory._meta.db_table).select('name').eq('id', cid).execute()
            category_name = (cat_row.data[0].get('name') or '') if (cat_row.data and cat_row.data[0]) else ''
            if category_name:
                providers = supabase.table('seva_auth_user').select('id,profession,role').in_(
                    'role', ['provider', 'prov', 'Provider', 'Prov']
                ).execute()
                for row in (providers.data or []):
                    rrole = (row.get('role') or '').strip().lower()
                    if rrole not in ('provider', 'prov'):
                        continue
                    pro = (row.get('profession') or '').strip()
                    if pro and provider_profession_matches_category(pro, category_name):
                        ensure_provider_service_in_category(row.get('id'), pro, cid, category_name)
        except Exception as e:
            print(f"Backfill default services warning: {e}")

    # Fetch from Supabase as raw dicts (no serializer – DB has provider_id/category_id, not provider/category)
    services = _get_services_raw_from_supabase(category_id=cid, provider_id=pid)
    if not for_signup and services:
        # Only show real service providers (role=provider/prov). Verification remains a trust badge.
        if any(isinstance(s, dict) and 'provider_is_provider' in s for s in services):
            services = [s for s in services if s.get('provider_is_provider') is True]
    # Signup / provider registration: one catalog entry per (category, normalized title); consistent Title Case
    if for_signup and services:
        services = dedupe_catalog_signup_rows(services)
        # Drop catalog rows whose title does not belong in this category (fixes mis-seeded DB / old backfill)
        if cid is not None and services:
            category_name = None
            for s in services:
                if s.get('category_name'):
                    category_name = s['category_name']
                    break
            if not category_name:
                try:
                    supabase = get_supabase_client()
                    r = supabase.table(ServiceCategory._meta.db_table).select('name').eq('id', cid).execute()
                    if r.data and r.data[0]:
                        category_name = r.data[0].get('name') or ''
                except Exception:
                    category_name = ''
            if category_name:
                services = [
                    s for s in services
                    if catalog_service_title_matches_category(s.get('title'), category_name)
                ]
    # For signup dropdown: return all services for the category (no profession filter) so every category shows all sub-services
    if not for_signup and cid is not None and services:
        category_name = None
        for s in services:
            if s.get('category_name'):
                category_name = s['category_name']
                break
        if not category_name:
            try:
                supabase = get_supabase_client()
                r = supabase.table(ServiceCategory._meta.db_table).select('name').eq('id', cid).execute()
                if r.data and r.data[0]:
                    category_name = r.data[0].get('name') or ''
            except Exception:
                pass
        if category_name:
            filtered = [s for s in services if provider_profession_matches_category(
                s.get('provider_profession'), category_name)]
            if filtered:
                services = filtered
        # Only show providers whose saved profession exactly matches this catalog title (token or full string)
        services = [s for s in services if provider_profession_matches_catalog_service_title(
            s.get('provider_profession'), s.get('title'))]
        if cid is not None and services:
            services = _add_equivalent_title_rows(services, cid)
            services = dedupe_services_by_provider_and_title(services)
    if services:
        print(f"✅ Found {len(services)} services from Supabase")
        return _respond(services)
    # If filtered by category and got nothing, try all services for this category (filter by category_id in memory)
    if cid is not None and not for_signup:
        services = _get_services_raw_from_supabase()
        if services:
            services = [s for s in services if s.get('category_id') == cid]
            if services:
                category_name = None
                try:
                    supabase = get_supabase_client()
                    r = supabase.table(ServiceCategory._meta.db_table).select('name').eq('id', cid).execute()
                    if r.data and r.data[0]:
                        category_name = r.data[0].get('name') or ''
                except Exception:
                    category_name = ''
                if category_name:
                    filtered = [s for s in services if provider_profession_matches_category(
                        s.get('provider_profession'), category_name)]
                    if filtered:
                        services = filtered
                services = [s for s in services if provider_profession_matches_catalog_service_title(
                    s.get('provider_profession'), s.get('title'))]
                services = _add_equivalent_title_rows(services, cid)
                services = dedupe_services_by_provider_and_title(services)
                print(f"✅ Found {len(services)} services from Supabase (category {cid})")
                return _respond(services)
    print("⚠️ No services found in Supabase")
    return _respond([])

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_booking(request):
    """Create a new booking. Sends notification to the provider (they see it in Bookings and Notifications)."""
    try:
        serializer = CreateBookingSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        booking_data = dict(serializer.validated_data)
        booking_data['customer_id'] = request.user.id
        if 'service' in booking_data:
            booking_data['service_id'] = booking_data.pop('service')
        # Ensure new bookings start as pending until payment is completed and provider accepts.
        booking_data['status'] = 'pending'
        # Request-based pricing: listing/catalog price is not the booking price.
        # Provider quotes after reviewing the request; customer pays that quote.
        booking_data['total_amount'] = Decimal('0')
        # Supabase client needs JSON-serializable payload (no Python date/time/Decimal)
        for key in ('booking_date', 'booking_time'):
            if key in booking_data and booking_data[key] is not None:
                v = booking_data[key]
                if isinstance(v, (date, datetime)):
                    booking_data[key] = v.isoformat()
                elif isinstance(v, time):
                    booking_data[key] = str(v)
        if 'total_amount' in booking_data and booking_data['total_amount'] is not None:
            v = booking_data['total_amount']
            if isinstance(v, Decimal):
                booking_data['total_amount'] = str(v)
        if not booking_data.get('request_image_url'):
            booking_data.pop('request_image_url', None)
        for key in ('latitude', 'longitude'):
            if key in booking_data and booking_data[key] is not None:
                v = booking_data[key]
                if isinstance(v, Decimal):
                    booking_data[key] = float(v)

        supabase = get_supabase_client()
        table_name = Booking._meta.db_table
        try:
            response = supabase.table(table_name).insert(booking_data).execute()
        except Exception as insert_err:
            err_msg = str(insert_err)
            if 'address' in err_msg or 'latitude' in err_msg or 'longitude' in err_msg or 'request_image_url' in err_msg or 'quoted_price' in err_msg or 'PGRST204' in err_msg:
                for key in ('address', 'latitude', 'longitude', 'request_image_url', 'quoted_price'):
                    booking_data.pop(key, None)
                response = supabase.table(table_name).insert(booking_data).execute()
            else:
                raise insert_err
        if response.data:
            created = response.data[0]
            booking_id = created.get('id')
            # Notify the provider about the new booking
            try:
                svc_r = supabase.table(Service._meta.db_table).select('provider_id,title').eq('id', created.get('service_id')).execute()
                if svc_r.data and svc_r.data[0]:
                    provider_id = svc_r.data[0].get('provider_id')
                    service_title = svc_r.data[0].get('title') or 'Service'
                    customer_name = getattr(request.user, 'username', None) or getattr(request.user, 'email', None) or 'A customer'
                    supabase.table('seva_notification').insert({
                        'user_id': provider_id,
                        'title': 'New service request',
                        'body': f'{customer_name} requested "{service_title}". Review details and send a quote.',
                        'booking_id': int(booking_id) if booking_id is not None else None,
                    }).execute()
            except Exception as e:
                print(f"Create booking: failed to notify provider: {e}")
            return Response(_to_json_serializable(created), status=status.HTTP_201_CREATED)
        return Response({'error': 'Failed to create booking'}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        # Always return JSON so the app never sees HTML error pages
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def upload_booking_request_image(request):
    """Upload a reference image for a service request; returns a signed URL for [request_image_url] on create_booking."""
    try:
        uploaded_file = request.FILES.get('file')
        if not uploaded_file:
            return Response({'error': 'file is required'}, status=status.HTTP_400_BAD_REQUEST)
        CHAT_ATTACHMENTS_BUCKET = 'chat-attachments'
        supabase = get_supabase_client()
        file_name = getattr(uploaded_file, 'name', '') or 'image.jpg'
        content_type = getattr(uploaded_file, 'content_type', None)
        guessed = mimetypes.guess_type(file_name)[0]
        if not content_type or content_type == 'application/octet-stream':
            content_type = guessed or 'application/octet-stream'
        safe_name = re.sub(r'[^a-zA-Z0-9._-]', '_', file_name)
        ts = int(datetime.utcnow().timestamp())
        uid = request.user.id
        attachment_path = f'booking_requests/{uid}/{ts}_{safe_name}'
        file_bytes = uploaded_file.read()
        supabase.storage.from_(CHAT_ATTACHMENTS_BUCKET).upload(
            attachment_path,
            file_bytes,
            file_options={'content-type': content_type},
        )
        signed = supabase.storage.from_(CHAT_ATTACHMENTS_BUCKET).create_signed_url(
            attachment_path, expires_in=7 * 24 * 60 * 60
        )
        url = signed.get('signedURL') or signed.get('signedUrl')
        if not url:
            return Response({'error': 'Could not create download URL'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        return Response({'request_image_url': url})
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_service_category_request(request):
    """User asks admins to add a new service type not available in the app (not a booking)."""
    try:
        title = (request.data.get('requested_service_name') or request.data.get('title') or '').strip()
        description = (request.data.get('description') or '').strip()
        address = (request.data.get('address') or '').strip()
        if len(title) < 2:
            return Response(
                {'error': 'Please enter the name of the service you want us to add.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        lat_raw = request.data.get('latitude')
        lng_raw = request.data.get('longitude')
        lat = lng = None
        try:
            if lat_raw is not None and str(lat_raw).strip() != '':
                lat = float(lat_raw)
            if lng_raw is not None and str(lng_raw).strip() != '':
                lng = float(lng_raw)
        except (TypeError, ValueError):
            pass

        image_urls = request.data.get('image_urls')
        if isinstance(image_urls, list):
            image_urls_str = json.dumps([str(u) for u in image_urls if u])
        elif isinstance(image_urls, str) and image_urls.strip():
            image_urls_str = image_urls.strip()
        else:
            image_urls_str = None

        payload = {
            'customer_id': request.user.id,
            'requested_title': title[:500],
            'description': description[:4000] if description else None,
            'address': address[:1000] if address else None,
            'latitude': lat,
            'longitude': lng,
            'image_urls': image_urls_str,
            'status': 'pending',
        }
        for k in ('latitude', 'longitude'):
            if payload[k] is None:
                payload.pop(k, None)
        if not payload.get('description'):
            payload.pop('description', None)
        if not payload.get('address'):
            payload.pop('address', None)
        if not payload.get('image_urls'):
            payload.pop('image_urls', None)

        created = create_service_request_record(payload)
        req_id = created.get('id')

        customer_name = (
            getattr(request.user, 'username', None)
            or getattr(request.user, 'email', None)
            or 'A user'
        )
        body = f'{customer_name} asked to add a new service: "{title}".'
        if description:
            body += f' Notes: {description[:600]}'
        if address:
            body += f' Address: {address[:300]}'
        if req_id is not None:
            body += f' Request #{req_id}.'
        body = body[:1950]

        try:
            supabase = get_supabase_client()
            users_r = supabase.table('seva_auth_user').select('id,role').execute()
            for row in users_r.data or []:
                if (row.get('role') or '').strip().lower() != 'admin':
                    continue
                aid = row.get('id')
                if aid is None:
                    continue
                supabase.table('seva_notification').insert({
                    'user_id': int(aid),
                    'title': 'New service to add',
                    'body': body,
                    'booking_id': None,
                }).execute()
        except Exception as ne:
            print(f'create_service_category_request: admin notify failed: {ne}')

        return Response(_to_json_serializable(created), status=status.HTTP_201_CREATED)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def upload_profile_image(request):
    """Upload avatar to storage and set seva_auth_user.profile_image_url to a signed URL."""
    try:
        uploaded_file = request.FILES.get('file')
        if not uploaded_file:
            return Response({'error': 'file is required'}, status=status.HTTP_400_BAD_REQUEST)
        CHAT_ATTACHMENTS_BUCKET = 'chat-attachments'
        supabase = get_supabase_client()
        file_name = getattr(uploaded_file, 'name', '') or 'avatar.jpg'
        content_type = getattr(uploaded_file, 'content_type', None)
        guessed = mimetypes.guess_type(file_name)[0]
        if not content_type or content_type == 'application/octet-stream':
            content_type = guessed or 'image/jpeg'
        safe_name = re.sub(r'[^a-zA-Z0-9._-]', '_', file_name)
        ts = int(datetime.utcnow().timestamp())
        uid = request.user.id
        path = f'profile_avatars/{uid}/{ts}_{safe_name}'
        file_bytes = uploaded_file.read()
        supabase.storage.from_(CHAT_ATTACHMENTS_BUCKET).upload(
            path,
            file_bytes,
            file_options={'content-type': content_type},
        )
        signed = supabase.storage.from_(CHAT_ATTACHMENTS_BUCKET).create_signed_url(
            path, expires_in=365 * 24 * 60 * 60
        )
        url = signed.get('signedURL') or signed.get('signedUrl')
        if not url:
            return Response({'error': 'Could not create image URL'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        db_ok = True
        try:
            supabase.table('seva_auth_user').update({'profile_image_url': url}).eq('id', uid).execute()
        except Exception as db_err:
            if 'PGRST204' in str(db_err) or 'column' in str(db_err).lower():
                db_ok = False
            else:
                raise
        updated = User.objects.get(id=uid)
        out = dict(AuthUserProfileSerializer(updated).data)
        out['profile_image_url'] = url
        if not db_ok:
            out['warning'] = (
                'profile_image_url not saved; run add_auth_user_qualification_profile_image.sql in Supabase '
                'to add the profile_image_url and qualification columns'
            )
        return Response(out)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def booking_detail(request, booking_id):
    """Get a single booking by id. Caller must be the customer or the provider of that booking."""
    try:
        supabase = get_supabase_client()
        r = supabase.table(Booking._meta.db_table).select('*').eq('id', booking_id).execute()
        if not r.data or len(r.data) == 0:
            return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)
        booking = r.data[0]
        user_id = request.user.id
        is_customer = booking.get('customer_id') == user_id
        if not is_customer:
            svc_r = supabase.table(Service._meta.db_table).select('provider_id').eq('id', booking.get('service_id')).execute()
            if not svc_r.data or svc_r.data[0].get('provider_id') != user_id:
                return Response({'error': 'Not authorized to view this booking'}, status=status.HTTP_403_FORBIDDEN)
        bookings = _enrich_bookings_with_names([booking])
        if not bookings:
            return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)
        detail = _to_json_serializable(bookings[0])
        if not is_customer:
            detail['customer_profile'] = {
                'user_id': detail.get('customer_id'),
                'full_name': detail.get('customer_name') or 'Customer',
                'email': detail.get('customer_email') or '',
                'phone': detail.get('customer_phone') or '',
                'location': detail.get('customer_location') or '',
                'profile_image_url': detail.get('customer_profile_image_url') or '',
            }
        return Response(detail)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def user_bookings(request):
    """Get all bookings for the logged-in user (raw Supabase fetch + enrich, no serializers)."""
    user = request.user
    try:
        if user.role == 'customer':
            bookings = _get_bookings_raw_from_supabase(customer_id=user.id)
        elif user.role == 'provider':
            services = _get_services_raw_from_supabase(provider_id=user.id)
            service_ids = [s['id'] for s in services]
            if not service_ids:
                bookings = []
            else:
                bookings = _get_bookings_raw_from_supabase(service_ids=service_ids)
        else:
            bookings = []
        bookings = _enrich_bookings_with_names(bookings)
        return Response(_to_json_serializable(bookings))
    except Exception as e:
        print(f"user_bookings error: {e}")
    return Response([])


def _review_payload_with_optional_fields(base_payload):
    """Allow review writes to succeed even if optional columns are not present yet."""
    optional_columns = {'service_id', 'updated_at', 'status'}
    return dict(base_payload), optional_columns


def _insert_review_with_fallback(supabase, payload):
    write_payload, optional_columns = _review_payload_with_optional_fields(payload)
    try:
        return supabase.table('seva_review').insert(write_payload).execute()
    except Exception:
        reduced = {k: v for k, v in write_payload.items() if k not in optional_columns}
        return supabase.table('seva_review').insert(reduced).execute()


def _update_review_with_fallback(supabase, review_id, payload):
    write_payload, optional_columns = _review_payload_with_optional_fields(payload)
    try:
        return supabase.table('seva_review').update(write_payload).eq('id', review_id).execute()
    except Exception:
        reduced = {k: v for k, v in write_payload.items() if k not in optional_columns}
        return supabase.table('seva_review').update(reduced).eq('id', review_id).execute()

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_review(request):
    """Create or update (upsert) a review for a review-eligible booking."""
    if (getattr(request.user, 'role', '') or '').strip().lower() != 'customer':
        return Response({'error': 'Only customers can submit reviews'}, status=status.HTTP_403_FORBIDDEN)

    booking_id = _to_int(request.data.get('booking_id'))
    rating = _to_int(request.data.get('rating'))
    comment = (request.data.get('comment') or '').strip()

    if booking_id is None or rating is None:
        return Response({'error': 'booking_id and rating are required'}, status=status.HTTP_400_BAD_REQUEST)
    if rating < 1 or rating > 5:
        return Response({'error': 'rating must be between 1 and 5'}, status=status.HTTP_400_BAD_REQUEST)
    if len(comment) > 2000:
        return Response({'error': 'comment is too long (max 2000 characters)'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        supabase = get_supabase_client()
        try:
            r = (
                supabase
                .table(Booking._meta.db_table)
                .select('id,customer_id,service_id,status,payment_status')
                .eq('id', booking_id)
                .limit(1)
                .execute()
            )
        except Exception as e:
            # Backward-compatible fallback for schemas that still do not have
            # seva_booking.payment_status.
            if 'payment_status' not in str(e):
                raise
            r = (
                supabase
                .table(Booking._meta.db_table)
                .select('id,customer_id,service_id,status')
                .eq('id', booking_id)
                .limit(1)
                .execute()
            )
        if not r.data or len(r.data) == 0:
            return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)
        booking = r.data[0]
        if booking.get('customer_id') != request.user.id:
            return Response({'error': 'You can only review your own booking'}, status=status.HTTP_403_FORBIDDEN)
        booking_status = (booking.get('status') or '').strip().lower()
        payment_status = (booking.get('payment_status') or '').strip().lower()
        if not payment_status:
            latest_payment = _latest_payment_for_booking(supabase, booking_id)
            payment_status = ((latest_payment or {}).get('status') or '').strip().lower()
        reviewable = booking_status == 'completed' or (
            booking_status in {'paid', 'confirmed', 'accepted', 'assigned', 'in progress'} and
            payment_status == 'completed'
        )
        if not reviewable:
            return Response({'error': 'Invalid booking or booking not review-eligible'}, status=status.HTTP_400_BAD_REQUEST)

        service_id = _to_int(booking.get('service_id'))
        if service_id is None:
            return Response({'error': 'Service not found'}, status=status.HTTP_400_BAD_REQUEST)

        svc_r = supabase.table(Service._meta.db_table).select('provider_id,title').eq('id', service_id).limit(1).execute()
        provider_id = svc_r.data[0]['provider_id'] if svc_r.data and svc_r.data[0] else None
        if not provider_id:
            return Response({'error': 'Service not found'}, status=status.HTTP_400_BAD_REQUEST)

        existing = (
            supabase
            .table('seva_review')
            .select('*')
            .eq('booking_id', booking_id)
            .eq('customer_id', request.user.id)
            .order('id', desc=True)
            .limit(1)
            .execute()
        )
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    now_iso = datetime.now().isoformat()
    try:
        if existing.data and len(existing.data) > 0:
            current = existing.data[0]
            review_id = current.get('id')
            if review_id is None:
                return Response({'error': 'Invalid existing review record'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
            updated_r = _update_review_with_fallback(
                supabase,
                review_id,
                {
                    'rating': rating,
                    'comment': comment,
                    'service_id': service_id,
                    'status': 'active',
                    'updated_at': now_iso,
                },
            )
            updated = (updated_r.data or [current])[0]
            return Response({
                'action': 'updated',
                'id': updated.get('id') or review_id,
                'booking_id': booking_id,
                'service_id': service_id,
                'provider_id': provider_id,
                'rating': updated.get('rating') or rating,
                'comment': updated.get('comment') or comment,
                'created_at': _to_json_serializable(updated.get('created_at')),
                'updated_at': _to_json_serializable(updated.get('updated_at') or now_iso),
            })

        created_r = _insert_review_with_fallback(
            supabase,
            {
                'booking_id': booking_id,
                'customer_id': request.user.id,
                'provider_id': provider_id,
                'service_id': service_id,
                'rating': rating,
                'comment': comment,
                'status': 'active',
                'created_at': now_iso,
                'updated_at': now_iso,
            },
        )
        created = (created_r.data or [{}])[0]
        return Response({
            'action': 'created',
            'id': created.get('id'),
            'booking_id': booking_id,
            'service_id': service_id,
            'provider_id': provider_id,
            'rating': created.get('rating') or rating,
            'comment': created.get('comment') or comment,
            'created_at': _to_json_serializable(created.get('created_at') or now_iso),
            'updated_at': _to_json_serializable(created.get('updated_at') or now_iso),
        }, status=status.HTTP_201_CREATED)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def review_for_booking(request, booking_id):
    """Return the logged-in customer's review for a specific booking."""
    if (getattr(request.user, 'role', '') or '').strip().lower() != 'customer':
        return Response({'error': 'Only customers can access this review'}, status=status.HTTP_403_FORBIDDEN)
    try:
        supabase = get_supabase_client()
        booking_r = (
            supabase
            .table(Booking._meta.db_table)
            .select('id,customer_id,service_id')
            .eq('id', booking_id)
            .limit(1)
            .execute()
        )
        if not booking_r.data:
            return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)
        booking = booking_r.data[0]
        if booking.get('customer_id') != request.user.id:
            return Response({'error': 'Not authorized to access this booking review'}, status=status.HTTP_403_FORBIDDEN)

        review_r = (
            supabase
            .table('seva_review')
            .select('*')
            .eq('booking_id', booking_id)
            .eq('customer_id', request.user.id)
            .order('id', desc=True)
            .limit(1)
            .execute()
        )
        if not review_r.data:
            return Response({'exists': False, 'booking_id': booking_id})

        row = review_r.data[0]
        return Response({
            'exists': True,
            'id': row.get('id'),
            'booking_id': row.get('booking_id') or booking_id,
            'provider_id': row.get('provider_id'),
            'service_id': row.get('service_id') or booking.get('service_id'),
            'rating': row.get('rating'),
            'comment': row.get('comment') or '',
            'status': row.get('status') or 'active',
            'created_at': _to_json_serializable(row.get('created_at')),
            'updated_at': _to_json_serializable(row.get('updated_at') or row.get('created_at')),
        })
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def my_reviews(request):
    """List reviews written by the current customer (for My Reviews screen)."""
    try:
        supabase = get_supabase_client()
        r = (
            supabase
            .table('seva_review')
            .select('*')
            .eq('customer_id', request.user.id)
            .order('created_at', desc=True)
            .limit(200)
            .execute()
        )
        rows = list(r.data or [])

        booking_ids = sorted({
            _to_int(row.get('booking_id'))
            for row in rows
            if _to_int(row.get('booking_id')) is not None
        })
        booking_map = {}
        if booking_ids:
            br = (
                supabase
                .table(Booking._meta.db_table)
                .select('id,service_id')
                .in_('id', booking_ids)
                .execute()
            )
            booking_map = {
                _to_int(item.get('id')): item
                for item in (br.data or [])
                if _to_int(item.get('id')) is not None
            }

        service_ids = sorted({
            _to_int(item.get('service_id'))
            for item in booking_map.values()
            if _to_int(item.get('service_id')) is not None
        })
        service_map = {}
        if service_ids:
            sr = (
                supabase
                .table(Service._meta.db_table)
                .select('id,title,provider_id')
                .in_('id', service_ids)
                .execute()
            )
            service_map = {
                _to_int(item.get('id')): item
                for item in (sr.data or [])
                if _to_int(item.get('id')) is not None
            }

        provider_ids = sorted({
            _to_int(item.get('provider_id'))
            for item in service_map.values()
            if _to_int(item.get('provider_id')) is not None
        })
        provider_map = {}
        if provider_ids:
            pr = (
                supabase
                .table('seva_auth_user')
                .select('id,username,email')
                .in_('id', provider_ids)
                .execute()
            )
            provider_map = {
                _to_int(item.get('id')): item
                for item in (pr.data or [])
                if _to_int(item.get('id')) is not None
            }

        out = []
        for row in rows:
            booking_id = _to_int(row.get('booking_id'))
            service_title = 'Service'
            provider_name = 'Provider'
            provider_id = _to_int(row.get('provider_id'))
            service_id = _to_int(row.get('service_id'))
            if booking_id is not None and booking_id in booking_map:
                service_id = _to_int(booking_map[booking_id].get('service_id'))
            if service_id is not None and service_id in service_map:
                service_row = service_map[service_id]
                service_title = service_row.get('title') or service_title
                provider_id = _to_int(service_row.get('provider_id'))
            if provider_id is not None and provider_id in provider_map:
                provider_row = provider_map[provider_id]
                provider_name = provider_row.get('username') or provider_row.get('email') or provider_name

            out.append({
                'id': row.get('id'),
                'booking_id': booking_id,
                'provider_id': provider_id,
                'service_id': service_id,
                'service': service_title,
                'provider': provider_name,
                'rating': row.get('rating'),
                'comment': row.get('comment') or '',
                'date': _to_json_serializable(row.get('created_at')),
                'updated_at': _to_json_serializable(row.get('updated_at') or row.get('created_at')),
                'status': row.get('status') or 'active',
            })
        return Response(out)
    except Exception as e:
        return Response([], status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def provider_reviews(request):
    """List reviews received by the current provider (for provider Ratings & Reviews screen)."""
    try:
        supabase = get_supabase_client()
        r = (
            supabase
            .table('seva_review')
            .select('*')
            .eq('provider_id', request.user.id)
            .order('created_at', desc=True)
            .limit(200)
            .execute()
        )
        rows = list(r.data or [])

        booking_ids = sorted({
            _to_int(row.get('booking_id'))
            for row in rows
            if _to_int(row.get('booking_id')) is not None
        })
        booking_map = {}
        if booking_ids:
            br = (
                supabase
                .table(Booking._meta.db_table)
                .select('id,service_id,customer_id')
                .in_('id', booking_ids)
                .execute()
            )
            booking_map = {
                _to_int(item.get('id')): item
                for item in (br.data or [])
                if _to_int(item.get('id')) is not None
            }

        service_ids = sorted({
            _to_int(item.get('service_id'))
            for item in booking_map.values()
            if _to_int(item.get('service_id')) is not None
        })
        service_map = {}
        if service_ids:
            sr = (
                supabase
                .table(Service._meta.db_table)
                .select('id,title')
                .in_('id', service_ids)
                .execute()
            )
            service_map = {
                _to_int(item.get('id')): item
                for item in (sr.data or [])
                if _to_int(item.get('id')) is not None
            }

        customer_ids = sorted({
            _to_int(item.get('customer_id'))
            for item in booking_map.values()
            if _to_int(item.get('customer_id')) is not None
        })
        customer_map = {}
        if customer_ids:
            cr = (
                supabase
                .table('seva_auth_user')
                .select('id,username,email')
                .in_('id', customer_ids)
                .execute()
            )
            customer_map = {
                _to_int(item.get('id')): item
                for item in (cr.data or [])
                if _to_int(item.get('id')) is not None
            }

        out = []
        distribution = {str(i): 0 for i in range(1, 6)}
        rating_sum = 0.0
        rating_count = 0

        for row in rows:
            booking_id = _to_int(row.get('booking_id'))
            service_title = 'Service'
            customer_name = 'Customer'
            customer_id = None
            if booking_id is not None and booking_id in booking_map:
                booking_row = booking_map[booking_id]
                sid = _to_int(booking_row.get('service_id'))
                customer_id = _to_int(booking_row.get('customer_id'))
                if sid is not None and sid in service_map:
                    service_title = service_map[sid].get('title') or service_title
                if customer_id is not None and customer_id in customer_map:
                    c_row = customer_map[customer_id]
                    customer_name = c_row.get('username') or c_row.get('email') or customer_name

            rating_value = _to_int(row.get('rating'))
            if rating_value is not None and 1 <= rating_value <= 5:
                distribution[str(rating_value)] = distribution[str(rating_value)] + 1
                rating_sum += float(rating_value)
                rating_count += 1

            out.append({
                'id': row.get('id'),
                'booking_id': booking_id,
                'customer_id': customer_id,
                'service_id': _to_int(row.get('service_id')),
                'service': service_title,
                'customer_name': customer_name,
                'rating': rating_value,
                'comment': row.get('comment') or '',
                'date': _to_json_serializable(row.get('created_at')),
                'updated_at': _to_json_serializable(row.get('updated_at') or row.get('created_at')),
                'status': row.get('status') or 'active',
            })
        return Response({
            'summary': {
                'total_reviews': rating_count,
                'average_rating': round((rating_sum / rating_count), 2) if rating_count else 0.0,
                'distribution': distribution,
            },
            'reviews': out,
        })
    except Exception:
        return Response({'summary': {'total_reviews': 0, 'average_rating': 0.0, 'distribution': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0}}, 'reviews': []}, status=status.HTTP_200_OK)


@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def update_booking_status(request, booking_id):
    """Update booking status with cancellation/refund workflow."""
    new_status = (request.data.get('status') or '').strip().lower()
    if not new_status:
        return Response({'error': 'status is required'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        supabase = get_supabase_client()
        r = supabase.table(Booking._meta.db_table).select('*').eq('id', booking_id).execute()
        if not r.data or len(r.data) == 0:
            return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)
        booking = r.data[0]
        current_status = (booking.get('status') or '').strip().lower()

        is_customer = booking.get('customer_id') == request.user.id
        if not is_customer:
            svc_r = supabase.table(Service._meta.db_table).select('provider_id,title').eq('id', booking['service_id']).execute()
            provider_id = (svc_r.data or [{}])[0].get('provider_id')
            if provider_id != request.user.id:
                return Response({'error': 'Unauthorized to update this booking'}, status=status.HTTP_403_FORBIDDEN)
            is_provider = True
        else:
            is_provider = False
            svc_r = supabase.table(Service._meta.db_table).select('provider_id,title').eq('id', booking['service_id']).execute()
            provider_id = (svc_r.data or [{}])[0].get('provider_id')

        service_title = (svc_r.data or [{}])[0].get('title') or 'Service'
        update_payload = {}

        # Provider sends quote -> move to awaiting payment.
        quoted_raw = request.data.get('quoted_price')
        if new_status == BOOKING_STATUS_QUOTED:
            if not is_provider:
                return Response({'error': 'Only provider can send quote'}, status=status.HTTP_403_FORBIDDEN)
            if quoted_raw is None:
                return Response({'error': 'quoted_price is required to send a quote'}, status=status.HTTP_400_BAD_REQUEST)
            try:
                qp = Decimal(str(quoted_raw))
                if qp <= 0:
                    return Response({'error': 'quoted_price must be greater than zero'}, status=status.HTTP_400_BAD_REQUEST)
            except Exception:
                return Response({'error': 'quoted_price must be a number'}, status=status.HTTP_400_BAD_REQUEST)
            update_payload['quoted_price'] = str(qp)
            update_payload['total_amount'] = str(qp)
            update_payload['status'] = BOOKING_STATUS_AWAITING_PAYMENT
            new_status = BOOKING_STATUS_AWAITING_PAYMENT

        # Customer/provider cancellation + refund trigger.
        elif new_status in (BOOKING_STATUS_CANCELLED, 'rejected'):
            if is_customer and not _customer_can_cancel(current_status):
                return Response({
                    'error': f'Cancellation is not allowed at status "{current_status}".',
                }, status=status.HTTP_400_BAD_REQUEST)
            if is_provider and not _provider_can_cancel(current_status):
                return Response({
                    'error': f'Provider cannot cancel at status "{current_status}".',
                }, status=status.HTTP_400_BAD_REQUEST)

            latest_payment = _latest_payment_for_booking(supabase, booking_id)
            payment_status = (latest_payment.get('status') or '').strip().lower() if latest_payment else ''
            paid_like = payment_status in {
                PAYMENT_STATUS_COMPLETED,
                PAYMENT_STATUS_REFUND_PENDING,
                PAYMENT_STATUS_REFUND_REJECTED,
                PAYMENT_STATUS_REFUNDED,
            }

            # If payment exists and was successful, start refund workflow with provider review.
            if latest_payment and paid_like:
                latest_refund = _latest_refund_for_booking(supabase, booking_id)
                latest_refund_status = (latest_refund.get('status') or '').strip().lower() if latest_refund else ''
                if latest_refund and _is_refund_terminal(latest_refund_status):
                    return Response({
                        'error': f'Refund already finalized with status "{latest_refund_status}" for this booking.',
                    }, status=status.HTTP_400_BAD_REQUEST)

                refund_amount = latest_payment.get('amount') or booking.get('total_amount') or 0
                refund_reason = (request.data.get('cancel_reason') or '').strip() or 'Order cancelled by customer'
                if is_provider:
                    refund_reason = (request.data.get('cancel_reason') or '').strip() or 'Order cancelled by provider'
                # Idempotent behavior: reuse active refund request instead of inserting duplicates.
                if latest_refund and latest_refund_status in {
                    REFUND_STATUS_PENDING,
                    REFUND_STATUS_PROVIDER_APPROVED,
                    REFUND_STATUS_PROVIDER_REJECTED,
                    REFUND_STATUS_UNDER_REVIEW,
                }:
                    supabase.table(REFUND_TABLE).update({
                        'payment_id': latest_payment.get('id'),
                        'amount': str(refund_amount),
                        'refund_reason': refund_reason,
                        'requested_by': 'provider' if is_provider else 'customer',
                        'requested_at': datetime.now().isoformat(),
                        'status': REFUND_STATUS_PENDING,
                        'system_note': 'Awaiting provider review.',
                        'updated_at': datetime.now().isoformat(),
                    }).eq('id', latest_refund.get('id')).execute()
                else:
                    refund_payload = {
                        'booking_id': int(booking_id),
                        'payment_id': latest_payment.get('id'),
                        'customer_id': booking.get('customer_id'),
                        'provider_id': provider_id,
                        'amount': str(refund_amount),
                        'status': REFUND_STATUS_PENDING,
                        'refund_reason': refund_reason,
                        'requested_by': 'provider' if is_provider else 'customer',
                        'requested_at': datetime.now().isoformat(),
                        'system_note': 'Awaiting provider review.',
                    }
                    try:
                        supabase.table(REFUND_TABLE).insert(refund_payload).execute()
                    except Exception as refund_err:
                        if 'does not exist' in str(refund_err).lower() or 'relation' in str(refund_err).lower():
                            return Response({
                                'error': 'Refund table missing. Run backend/add_refund_workflow_tables.sql in Supabase.',
                            }, status=status.HTTP_503_SERVICE_UNAVAILABLE)
                        raise
                supabase.table(PAYMENT_TABLE).update({
                    'status': PAYMENT_STATUS_REFUND_PENDING,
                    'updated_at': datetime.now().isoformat(),
                }).eq('id', latest_payment.get('id')).execute()
                update_payload['status'] = BOOKING_STATUS_CANCELLATION_REQUESTED
            else:
                # No paid transaction -> simple cancellation.
                update_payload['status'] = BOOKING_STATUS_CANCELLED

        # Provider review step for cancellation/refund request.
        elif new_status in (
            BOOKING_STATUS_REFUND_PROVIDER_APPROVED,
            BOOKING_STATUS_REFUND_PROVIDER_REJECTED,
        ):
            if not is_provider:
                return Response({'error': 'Only provider can review refund request'}, status=status.HTTP_403_FORBIDDEN)
            if not _provider_can_review_refund(current_status):
                return Response({
                    'error': f'Refund review not allowed at status "{current_status}".',
                }, status=status.HTTP_400_BAD_REQUEST)

            latest_refund = _latest_refund_for_booking(supabase, booking_id)
            if not latest_refund:
                return Response({'error': 'No refund request found for this booking'}, status=status.HTTP_400_BAD_REQUEST)

            note = (request.data.get('provider_note') or '').strip()
            if new_status == BOOKING_STATUS_REFUND_PROVIDER_APPROVED:
                supabase.table(REFUND_TABLE).update({
                    'status': REFUND_STATUS_PROVIDER_APPROVED,
                    'system_note': note or 'Approved by provider. Awaiting admin refund processing.',
                    'updated_at': datetime.now().isoformat(),
                }).eq('id', latest_refund.get('id')).execute()
                update_payload['status'] = BOOKING_STATUS_REFUND_PENDING
            else:
                supabase.table(REFUND_TABLE).update({
                    'status': REFUND_STATUS_PROVIDER_REJECTED,
                    'system_note': note or 'Rejected by provider.',
                    'updated_at': datetime.now().isoformat(),
                }).eq('id', latest_refund.get('id')).execute()
                # If provider rejects refund, keep payment as not refunded/rejected.
                latest_payment = _latest_payment_for_booking(supabase, booking_id)
                if latest_payment:
                    supabase.table(PAYMENT_TABLE).update({
                        'status': PAYMENT_STATUS_REFUND_REJECTED,
                        'updated_at': datetime.now().isoformat(),
                    }).eq('id', latest_payment.get('id')).execute()
                update_payload['status'] = BOOKING_STATUS_REFUND_PROVIDER_REJECTED

        elif new_status == BOOKING_STATUS_COMPLETED:
            if not is_provider:
                return Response({'error': 'Only provider can complete booking'}, status=status.HTTP_403_FORBIDDEN)
            if current_status not in {BOOKING_STATUS_PAID, 'confirmed', 'accepted'}:
                return Response({
                    'error': 'Booking can be completed only after payment.',
                }, status=status.HTTP_400_BAD_REQUEST)
            update_payload['status'] = BOOKING_STATUS_COMPLETED
        else:
            # Backward compatibility: allow plain status update for known legacy values.
            allowed = {
                BOOKING_STATUS_PENDING,
                BOOKING_STATUS_AWAITING_PAYMENT,
                BOOKING_STATUS_PAID,
                BOOKING_STATUS_CANCELLATION_REQUESTED,
                BOOKING_STATUS_CANCELLED,
                BOOKING_STATUS_REFUND_PENDING,
                BOOKING_STATUS_REFUND_PROVIDER_APPROVED,
                BOOKING_STATUS_REFUND_PROVIDER_REJECTED,
                BOOKING_STATUS_REFUNDED,
                BOOKING_STATUS_REFUND_REJECTED,
                BOOKING_STATUS_COMPLETED,
                'confirmed',
                'accepted',
            }
            if new_status not in allowed:
                return Response({'error': f'Unsupported status "{new_status}"'}, status=status.HTTP_400_BAD_REQUEST)
            update_payload['status'] = new_status

        if not update_payload:
            return Response({'error': 'No valid updates'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            supabase.table(Booking._meta.db_table).update(update_payload).eq('id', booking_id).execute()
        except Exception as up_err:
            if 'quoted_price' in str(up_err):
                update_payload.pop('quoted_price', None)
                supabase.table(Booking._meta.db_table).update(update_payload).eq('id', booking_id).execute()
            else:
                raise up_err

        # Notifications
        try:
            actor_name = getattr(request.user, 'username', None) or getattr(request.user, 'email', None) or 'User'
            final_status = update_payload.get('status', '').lower()
            if final_status == BOOKING_STATUS_AWAITING_PAYMENT:
                supabase.table('seva_notification').insert({
                    'user_id': booking['customer_id'],
                    'title': 'Price quote received',
                    'body': f'{actor_name} quoted Rs {quoted_raw} for "{service_title}". Pay to confirm your booking.',
                    'booking_id': int(booking_id),
                }).execute()
            elif final_status == BOOKING_STATUS_CANCELLED:
                supabase.table('seva_notification').insert({
                    'user_id': booking['customer_id'] if is_provider else provider_id,
                    'title': 'Booking cancelled',
                    'body': f'Booking #{booking_id} ({service_title}) was cancelled.',
                    'booking_id': int(booking_id),
                }).execute()
            elif final_status == BOOKING_STATUS_CANCELLATION_REQUESTED:
                # Route refund request to provider dashboard (and admins) - not to customer's own notification feed.
                _notify_user(
                    supabase,
                    provider_id,
                    'Cancellation requested',
                    f'Booking #{booking_id} cancellation requested. Please review the refund request.',
                    booking_id=int(booking_id),
                )
                for aid in _get_admin_user_ids(supabase):
                    _notify_user(
                        supabase,
                        aid,
                        'Refund request created',
                        f'Booking #{booking_id} refund request is pending provider review.',
                        booking_id=int(booking_id),
                    )
            elif final_status == BOOKING_STATUS_REFUND_PROVIDER_APPROVED:
                # Provider approved -> notify customer + admins for final processing.
                _notify_user(
                    supabase,
                    booking.get('customer_id'),
                    'Refund under review',
                    f'Booking #{booking_id} refund was approved by provider and is now under admin review.',
                    booking_id=int(booking_id),
                )
                for aid in _get_admin_user_ids(supabase):
                    _notify_user(
                        supabase,
                        aid,
                        'Refund review required',
                        f'Refund provider-approved for Booking #{booking_id}. Process final refund.',
                        booking_id=int(booking_id),
                    )
            elif final_status == BOOKING_STATUS_REFUND_PROVIDER_REJECTED:
                _notify_user(
                    supabase,
                    booking.get('customer_id'),
                    'Refund rejected',
                    f'Your refund request for Booking #{booking_id} was rejected by provider.',
                    booking_id=int(booking_id),
                )
        except Exception:
            pass

        if update_payload.get('status') in {BOOKING_STATUS_PAID, BOOKING_STATUS_COMPLETED}:
            _award_referral_points_if_eligible(supabase, booking['customer_id'])

        updated = supabase.table(Booking._meta.db_table).select('*').eq('id', booking_id).execute()
        if updated.data and updated.data[0]:
            enriched = _enrich_bookings_with_names([updated.data[0]])
            return Response(_to_json_serializable(enriched[0]), status=status.HTTP_200_OK)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    return Response({'error': 'Failed to update booking'}, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def provider_notifications(request):
    """For providers: list notifications from seva_notification (new booking, payment received, etc.)."""
    if request.user.role != 'provider':
        return Response([], status=status.HTTP_200_OK)
    try:
        supabase = get_supabase_client()
        r = supabase.table('seva_notification').select('*').eq('user_id', request.user.id).order('created_at', desc=True).limit(100).execute()
        out = []
        for row in (r.data or []):
            out.append({
                'id': row.get('id'),
                'title': row.get('title') or '',
                'body': row.get('body') or '',
                'booking_id': row.get('booking_id'),
                'created_at': _to_json_serializable(row.get('created_at')),
            })
        return Response(out)
    except Exception as e:
        return Response([], status=status.HTTP_200_OK)


PROVIDER_TIME_SLOT_TABLE = ProviderTimeSlot._meta.db_table


def _parse_time_value(value):
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    try:
        return time.fromisoformat(text)
    except ValueError:
        try:
            return datetime.fromisoformat(text).time()
        except ValueError:
            return None


def _serialize_provider_time_slot(row):
    slot_date = row.get('slot_date')
    if isinstance(slot_date, date):
        slot_date = slot_date.isoformat()
    elif hasattr(slot_date, 'isoformat'):
        slot_date = slot_date.isoformat()

    start_time = row.get('start_time')
    if isinstance(start_time, time):
        start_time = start_time.isoformat()
    elif hasattr(start_time, 'isoformat'):
        start_time = start_time.isoformat()

    end_time = row.get('end_time')
    if isinstance(end_time, time):
        end_time = end_time.isoformat()
    elif hasattr(end_time, 'isoformat'):
        end_time = end_time.isoformat()

    return {
        'id': row.get('id'),
        'provider_id': row.get('provider_id'),
        'slot_date': slot_date,
        'day_name': row.get('day_name') or '',
        'start_time': start_time,
        'end_time': end_time,
        'note': row.get('note') or '',
        'is_active': bool(row.get('is_active', True)),
        'created_at': _to_json_serializable(row.get('created_at')),
        'updated_at': _to_json_serializable(row.get('updated_at')),
    }


def _time_slot_overlaps(existing_rows, slot_date, start_time, end_time, exclude_id=None):
    slot_date_text = slot_date.isoformat()
    for row in existing_rows:
        row_id = _to_int(row.get('id'))
        if exclude_id is not None and row_id == exclude_id:
            continue
        if str(row.get('slot_date') or '').strip() != slot_date_text:
            continue
        existing_start = _parse_time_value(row.get('start_time'))
        existing_end = _parse_time_value(row.get('end_time'))
        if existing_start is None or existing_end is None:
            continue
        if start_time < existing_end and end_time > existing_start:
            return True
    return False


@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def provider_time_slots(request):
    """List or create provider availability slots."""
    try:
        supabase = get_supabase_client()
        provider_id = _to_int(request.query_params.get('provider_id'))
        if provider_id is None:
            provider_id = getattr(request.user, 'id', None)
        if provider_id is None:
            return Response([], status=status.HTTP_200_OK)

        role = (getattr(request.user, 'role', None) or '').strip().lower()
        if request.method == 'POST' and role not in {'provider', 'admin'}:
            return Response({'error': 'Only providers can manage time slots.'}, status=status.HTTP_403_FORBIDDEN)
        if request.method == 'POST' and role != 'admin' and provider_id != request.user.id:
            return Response({'error': 'You can only manage your own time slots.'}, status=status.HTTP_403_FORBIDDEN)

        if request.method == 'GET':
            slot_date = (request.query_params.get('slot_date') or '').strip()
            active_only = (request.query_params.get('active_only') or '1').strip() != '0'
            query = supabase.table(PROVIDER_TIME_SLOT_TABLE).select('*').eq('provider_id', provider_id)
            if slot_date:
                query = query.eq('slot_date', slot_date)
            if active_only:
                query = query.eq('is_active', True)
            response = query.order('slot_date', desc=True).order('start_time', desc=False).execute()
            return Response([_serialize_provider_time_slot(row) for row in (response.data or [])])

        slot_date_value = (request.data.get('slot_date') or '').strip()
        start_time_value = (request.data.get('start_time') or '').strip()
        end_time_value = (request.data.get('end_time') or '').strip()
        note = (request.data.get('note') or '').strip()
        is_active = request.data.get('is_active', True)

        if not slot_date_value or not start_time_value or not end_time_value:
            return Response({'error': 'slot_date, start_time, and end_time are required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            slot_date = date.fromisoformat(slot_date_value)
        except ValueError:
            return Response({'error': 'slot_date must be YYYY-MM-DD.'}, status=status.HTTP_400_BAD_REQUEST)

        start_time = _parse_time_value(start_time_value)
        end_time = _parse_time_value(end_time_value)
        if start_time is None or end_time is None:
            return Response({'error': 'start_time and end_time must be valid times.'}, status=status.HTTP_400_BAD_REQUEST)
        if end_time <= start_time:
            return Response({'error': 'end_time must be later than start_time.'}, status=status.HTTP_400_BAD_REQUEST)

        existing = (
            supabase.table(PROVIDER_TIME_SLOT_TABLE)
            .select('*')
            .eq('provider_id', provider_id)
            .eq('slot_date', slot_date.isoformat())
            .execute()
        )
        if _time_slot_overlaps(existing.data or [], slot_date, start_time, end_time):
            return Response({'error': 'This time range overlaps an existing slot.'}, status=status.HTTP_400_BAD_REQUEST)

        now_iso = datetime.now().isoformat()
        payload = {
            'provider_id': provider_id,
            'slot_date': slot_date.isoformat(),
            'day_name': slot_date.strftime('%A'),
            'start_time': start_time.isoformat(),
            'end_time': end_time.isoformat(),
            'note': note,
            'is_active': bool(is_active),
            'created_at': now_iso,
            'updated_at': now_iso,
        }
        created = supabase.table(PROVIDER_TIME_SLOT_TABLE).insert(payload).execute()
        if created.data:
            return Response(_serialize_provider_time_slot(created.data[0]), status=status.HTTP_201_CREATED)
        return Response(payload, status=status.HTTP_201_CREATED)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['PATCH', 'DELETE'])
@permission_classes([IsAuthenticated])
def provider_time_slot_detail(request, slot_id):
    """Update or delete a provider availability slot."""
    try:
        supabase = get_supabase_client()
        slot_id_int = _to_int(slot_id)
        if slot_id_int is None:
            return Response({'error': 'Invalid slot id.'}, status=status.HTTP_400_BAD_REQUEST)

        existing_r = supabase.table(PROVIDER_TIME_SLOT_TABLE).select('*').eq('id', slot_id_int).limit(1).execute()
        if not existing_r.data:
            return Response({'error': 'Time slot not found.'}, status=status.HTTP_404_NOT_FOUND)
        existing = existing_r.data[0]
        role = (getattr(request.user, 'role', None) or '').strip().lower()
        owner_id = _to_int(existing.get('provider_id'))
        if role != 'admin' and owner_id != request.user.id:
            return Response({'error': 'You can only manage your own time slots.'}, status=status.HTTP_403_FORBIDDEN)

        if request.method == 'DELETE':
            supabase.table(PROVIDER_TIME_SLOT_TABLE).delete().eq('id', slot_id_int).execute()
            return Response({'success': True})

        updates = {}
        candidate_date = date.fromisoformat(str(existing.get('slot_date')))
        if 'slot_date' in request.data:
            slot_date_value = (request.data.get('slot_date') or '').strip()
            try:
                candidate_date = date.fromisoformat(slot_date_value)
            except ValueError:
                return Response({'error': 'slot_date must be YYYY-MM-DD.'}, status=status.HTTP_400_BAD_REQUEST)
            updates['slot_date'] = candidate_date.isoformat()
            updates['day_name'] = candidate_date.strftime('%A')

        candidate_start = _parse_time_value(existing.get('start_time'))
        if 'start_time' in request.data:
            candidate_start = _parse_time_value(request.data.get('start_time'))
            if candidate_start is None:
                return Response({'error': 'start_time must be valid.'}, status=status.HTTP_400_BAD_REQUEST)
            updates['start_time'] = candidate_start.isoformat()

        candidate_end = _parse_time_value(existing.get('end_time'))
        if 'end_time' in request.data:
            candidate_end = _parse_time_value(request.data.get('end_time'))
            if candidate_end is None:
                return Response({'error': 'end_time must be valid.'}, status=status.HTTP_400_BAD_REQUEST)
            updates['end_time'] = candidate_end.isoformat()

        if candidate_start is not None and candidate_end is not None and candidate_end <= candidate_start:
            return Response({'error': 'end_time must be later than start_time.'}, status=status.HTTP_400_BAD_REQUEST)

        if 'note' in request.data:
            updates['note'] = (request.data.get('note') or '').strip()
        if 'is_active' in request.data:
            updates['is_active'] = bool(request.data.get('is_active'))

        if updates:
            updates['updated_at'] = datetime.now().isoformat()
            peers = (
                supabase.table(PROVIDER_TIME_SLOT_TABLE)
                .select('*')
                .eq('provider_id', owner_id)
                .eq('slot_date', candidate_date.isoformat())
                .execute()
            )
            if _time_slot_overlaps(peers.data or [], candidate_date, candidate_start, candidate_end, exclude_id=slot_id_int):
                return Response({'error': 'This time range overlaps an existing slot.'}, status=status.HTTP_400_BAD_REQUEST)
            supabase.table(PROVIDER_TIME_SLOT_TABLE).update(updates).eq('id', slot_id_int).execute()

        updated_r = supabase.table(PROVIDER_TIME_SLOT_TABLE).select('*').eq('id', slot_id_int).limit(1).execute()
        if updated_r.data:
            return Response(_serialize_provider_time_slot(updated_r.data[0]))
        return Response({'success': True})
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def customer_notifications(request):
    """For customers: list notifications (e.g. booking declined)."""
    try:
        supabase = get_supabase_client()
        r = supabase.table('seva_notification').select('*').eq('user_id', request.user.id).order('created_at', desc=True).limit(100).execute()
        out = []
        for row in (r.data or []):
            out.append({
                'id': row.get('id'),
                'title': row.get('title') or '',
                'body': row.get('body') or '',
                'booking_id': row.get('booking_id'),
                'created_at': _to_json_serializable(row.get('created_at')),
            })
        return Response(out)
    except Exception:
        return Response([], status=status.HTTP_200_OK)


# --- Promotional Banners & Blogs (public) ---
PROMOTIONAL_TABLE = 'seva_promotional_banner'
BLOG_TABLE = 'seva_blog'


@api_view(['GET'])
@permission_classes([AllowAny])
def promotional_banners_list(request):
    """List active promotional banners (public). Optional ?category_id= for category-based visibility."""
    try:
        supabase = get_supabase_client()
        query = supabase.table(PROMOTIONAL_TABLE).select('*').eq('is_active', True).order('sort_order')
        category_id = request.GET.get('category_id')
        if category_id is not None and category_id != '':
            try:
                cid = int(category_id)
                query = query.or_(f'category_id.is.null,category_id.eq.{cid}')
            except (ValueError, Exception):
                pass
        try:
            r = query.execute()
        except Exception:
            r = supabase.table(PROMOTIONAL_TABLE).select('*').eq('is_active', True).order('sort_order').execute()
        out = []
        for row in (r.data or []):
            out.append({
                'id': row.get('id'),
                'title': row.get('title') or '',
                'description': row.get('description') or '',
                'image_url': row.get('image_url'),
                'link_url': row.get('link_url'),
                'category_id': row.get('category_id'),
                'created_at': _to_json_serializable(row.get('created_at')),
            })
        return Response(out)
    except Exception:
        return Response([], status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([AllowAny])
def blog_list(request):
    """List blog posts (public)."""
    try:
        supabase = get_supabase_client()
        r = supabase.table(BLOG_TABLE).select('*').order('created_at', desc=True).execute()
        out = []
        for row in (r.data or []):
            out.append({
                'id': row.get('id'),
                'title': row.get('title') or '',
                'body': row.get('body') or '',
                'excerpt': row.get('excerpt') or '',
                'image_url': row.get('image_url'),
                'created_at': _to_json_serializable(row.get('created_at')),
            })
        return Response(out)
    except Exception:
        return Response([], status=status.HTTP_200_OK)


# --- Referral & Loyalty ---
REFERRAL_TABLE = 'seva_referral'
POINTS_REFERRER_FIRST_BOOKING = 50
POINTS_REFERRED_FIRST_BOOKING = 25


def _award_referral_points_if_eligible(supabase, customer_id):
    """Award referral points after the referred user's first eligible (paid) booking.

    Idempotent: uses a conditional update on the referral row so loyalty points
    are incremented at most once per referred user.
    """
    try:
        u = (
            supabase
            .table('seva_auth_user')
            .select('id,referred_by_id')
            .eq('id', customer_id)
            .limit(1)
            .execute()
        )
        if not u.data or not u.data[0].get('referred_by_id'):
            return

        referrer_id = u.data[0].get('referred_by_id')
        if referrer_id is None:
            return

        ref_r = (
            supabase
            .table(REFERRAL_TABLE)
            .select('*')
            .eq('referred_user_id', customer_id)
            .order('id', desc=True)
            .limit(1)
            .execute()
        )
        if not ref_r.data:
            return
        row = ref_r.data[0]
        if (row.get('status') or '').strip().lower() == 'points_awarded':
            return
        ref_id = row.get('id')
        if ref_id is None:
            return

        # Atomic/idempotent award: only update if points_referrer is still 0.
        now_iso = datetime.now().isoformat()
        upd = (
            supabase
            .table(REFERRAL_TABLE)
            .update({
                'status': 'points_awarded',
                'points_referrer': POINTS_REFERRER_FIRST_BOOKING,
                'points_referred': POINTS_REFERRED_FIRST_BOOKING,
                'updated_at': now_iso,
            })
            .eq('id', ref_id)
            .eq('points_referrer', 0)
            .execute()
        )
        if not upd.data:
            # Already awarded by a concurrent call.
            return

        # Increment referrer's loyalty_points
        rr = (
            supabase
            .table('seva_auth_user')
            .select('loyalty_points')
            .eq('id', referrer_id)
            .limit(1)
            .execute()
        )
        current = int((rr.data or [{}])[0].get('loyalty_points') or 0)
        supabase.table('seva_auth_user').update({
            'loyalty_points': current + POINTS_REFERRER_FIRST_BOOKING,
        }).eq('id', referrer_id).execute()

        # Increment referred user's loyalty_points
        rc = (
            supabase
            .table('seva_auth_user')
            .select('loyalty_points')
            .eq('id', customer_id)
            .limit(1)
            .execute()
        )
        current_c = int((rc.data or [{}])[0].get('loyalty_points') or 0)
        supabase.table('seva_auth_user').update({
            'loyalty_points': current_c + POINTS_REFERRED_FIRST_BOOKING,
        }).eq('id', customer_id).execute()
    except Exception as e:
        logger.warning('Referral award failed for customer_id=%s: %s', customer_id, e)


def _ensure_user_referral_code(supabase, user_id, username, email):
    """If user has no referral_code, generate one and update DB. Return code."""
    r = supabase.table('seva_auth_user').select('referral_code').eq('id', user_id).execute()
    if not r.data or len(r.data) == 0:
        return None
    row = r.data[0]
    code = row.get('referral_code') if row else None
    if code and str(code).strip():
        return code
    from authentication.models import _generate_referral_code
    code = _generate_referral_code(supabase, username, email)
    try:
        supabase.table('seva_auth_user').update({'referral_code': code}).eq('id', user_id).execute()
    except Exception:
        pass
    return code


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def referral_profile(request):
    """Get current user's referral code, loyalty points, and referral history."""
    try:
        supabase = get_supabase_client()
        user = request.user
        user_id = user.id
        # Ensure user has a referral code (for existing users created before referral feature)
        code = _ensure_user_referral_code(supabase, user_id, getattr(user, 'username', ''), getattr(user, 'email', ''))
        if not code:
            r = supabase.table('seva_auth_user').select('referral_code, loyalty_points').eq('id', user_id).execute()
            row = (r.data or [{}])[0] if r.data else {}
            code = row.get('referral_code') or 'HAMRO-USER'
            points = int(row.get('loyalty_points') or 0)
        else:
            r = supabase.table('seva_auth_user').select('loyalty_points').eq('id', user_id).execute()
            points = int((r.data or [{}])[0].get('loyalty_points') or 0) if r.data else 0
        # Referral history: rows where referrer_id = current user
        hist = []
        try:
            ref_r = supabase.table(REFERRAL_TABLE).select('*').eq('referrer_id', user_id).order('created_at', desc=True).execute()
            for row in (ref_r.data or []):
                referred_id = row.get('referred_user_id')
                status_label = (row.get('status') or 'signed_up').replace('_', ' ').title()
                hist.append({
                    'referred_user_id': referred_id,
                    'status': row.get('status') or 'signed_up',
                    'status_label': status_label,
                    'points_earned': int(row.get('points_referrer') or 0),
                    'created_at': _to_json_serializable(row.get('created_at')),
                })
        except Exception:
            pass
        return Response({
            'referral_code': code,
            'loyalty_points': points,
            'referral_history': hist,
        })
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# --- Provider identity verification (Verify Your Id) ---
PROVIDER_VERIFICATION_TABLE = 'seva_provider_verification'
VALID_DOCUMENT_TYPES = {
    'work_licence',
    'passport',
    'citizenship_card',
    'national_id',
    'service_certificate',
    'additional_document',
    'shop_license',
    'business_registration',
    'tax_certificate',
    'shop_photo',
}
ID_DOCUMENT_TYPES = {'national_id', 'citizenship_card', 'passport'}
QUALIFICATION_DOCUMENT_TYPES = {'service_certificate', 'work_licence', 'qualification_certificate', 'training_certificate'}


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def provider_verifications_list(request):
    """List current provider's verification documents (providers only)."""
    if getattr(request.user, 'role', None) != 'provider':
        return Response({'error': 'Provider only'}, status=status.HTTP_403_FORBIDDEN)
    try:
        supabase = get_supabase_client()
        r = supabase.table(PROVIDER_VERIFICATION_TABLE).select('*').eq(
            'provider_id', request.user.id
        ).order('created_at', desc=True).execute()
        out = []
        for row in (r.data or []):
            out.append({
                'id': row.get('id'),
                'document_type': row.get('document_type'),
                'document_number': row.get('document_number'),
                'document_url': row.get('document_url'),
                'status': normalize_verification_status(row.get('status') or 'pending'),
                'created_at': _to_json_serializable(row.get('created_at')),
                'updated_at': _to_json_serializable(row.get('updated_at')),
            })
        return Response(out)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


def _get_request_param(request, key, default=None):
    """Get param from POST (multipart) or data (JSON)."""
    if request.content_type and 'multipart' in request.content_type:
        val = request.POST.get(key)
        return (val or '').strip() or default
    return (request.data.get(key) or '').strip() or default


def _save_verification_file(uploaded_file, provider_id, doc_type):
    """Save uploaded file to media/verifications/; return relative URL path."""
    import os
    from django.conf import settings
    ext = os.path.splitext(getattr(uploaded_file, 'name', '') or '')[1] or '.bin'
    if ext.lower() not in ('.pdf', '.jpg', '.jpeg', '.png', '.gif', '.webp'):
        ext = '.bin'
    safe_name = f"{provider_id}_{doc_type}_{uploaded_file.name[:50]}" if getattr(uploaded_file, 'name', None) else f"{provider_id}_{doc_type}{ext}"
    safe_name = "".join(c for c in safe_name if c.isalnum() or c in '._-') or f"{provider_id}_{doc_type}{ext}"
    upload_dir = os.path.join(settings.MEDIA_ROOT, 'verifications')
    os.makedirs(upload_dir, exist_ok=True)
    path = os.path.join(upload_dir, safe_name)
    with open(path, 'wb') as f:
        for chunk in uploaded_file.chunks():
            f.write(chunk)
    return f"{settings.MEDIA_URL}verifications/{safe_name}"


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def provider_verification_create(request):
    """Add a verification document (providers only).

    A submission must include either a valid uploaded file under `file`
    or a non-empty `document_url`.
    """
    if getattr(request.user, 'role', None) != 'provider':
        return Response({'error': 'Provider only'}, status=status.HTTP_403_FORBIDDEN)
    doc_type = (_get_request_param(request, 'document_type') or request.data.get('document_type') or '').strip().lower().replace(' ', '_')
    if doc_type not in VALID_DOCUMENT_TYPES:
        return Response(
            {'error': f"document_type must be one of: {', '.join(sorted(VALID_DOCUMENT_TYPES))}"},
            status=status.HTTP_400_BAD_REQUEST
        )
    document_number = _get_request_param(request, 'document_number') or (request.data.get('document_number') or '').strip() or None
    document_url = (request.data.get('document_url') or '').strip() or None

    uploaded_file = request.FILES.get('file')
    if not uploaded_file and hasattr(request.data, 'get'):
        maybe_file = request.data.get('file')
        if hasattr(maybe_file, 'chunks'):
            uploaded_file = maybe_file

    if uploaded_file and getattr(uploaded_file, 'size', 0) <= 0:
        return Response({'error': 'Uploaded file is empty.'}, status=status.HTTP_400_BAD_REQUEST)

    if uploaded_file:
        try:
            document_url = _save_verification_file(uploaded_file, request.user.id, doc_type)
        except Exception as e:
            return Response({'error': f'File save failed: {e}'}, status=status.HTTP_400_BAD_REQUEST)

    if not document_url:
        return Response(
            {'error': 'A document file is required. Use form-data key `file` or provide a valid document_url.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    try:
        supabase = get_supabase_client()
        now_iso = datetime.now().isoformat()
        payload = {
            'provider_id': request.user.id,
            'document_type': doc_type,
            'document_number': document_number,
            'document_url': document_url,
            'status': 'pending',
            'created_at': now_iso,
            'updated_at': now_iso,
        }
        r = supabase.table(PROVIDER_VERIFICATION_TABLE).insert(payload).execute()
        # Resubmission path: keep provider in pending queue.
        _safe_update_auth_user(supabase, request.user.id, {
            'verification_status': 'pending',
            'is_active_provider': True,
            'is_verified': False,
            'rejection_reason': None,
            'submitted_at': now_iso,
            'reviewed_at': None,
            'reviewed_by': None,
        })
        if r.data and len(r.data) > 0:
            row = r.data[0]
            return Response({
                'id': row.get('id'),
                'document_type': row.get('document_type'),
                'document_number': row.get('document_number'),
                'document_url': row.get('document_url'),
                'status': row.get('status'),
                'created_at': _to_json_serializable(row.get('created_at')),
            }, status=status.HTTP_201_CREATED)
        return Response({'error': 'Failed to create'}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['DELETE', 'PATCH'])
@permission_classes([IsAuthenticated])
def provider_verification_delete(request, verification_id):
    """Delete one verification document (own only) or update it (PATCH)."""
    if getattr(request.user, 'role', None) != 'provider':
        return Response({'error': 'Provider only'}, status=status.HTTP_403_FORBIDDEN)
    
    # Handle PATCH (update)
    if request.method == 'PATCH':
        try:
            supabase = get_supabase_client()
            # Check if document exists and belongs to user
            r = supabase.table(PROVIDER_VERIFICATION_TABLE).select('*').eq(
                'id', verification_id
            ).eq('provider_id', request.user.id).execute()
            if not r.data or len(r.data) == 0:
                return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
            
            doc = r.data[0]
            updates = {}
            
            # Update document number if provided
            if 'document_number' in request.data:
                doc_num = (request.data.get('document_number') or '').strip() or None
                updates['document_number'] = doc_num
            
            # Handle file upload if provided
            uploaded_file = request.FILES.get('file')
            if uploaded_file:
                try:
                    doc_type = doc.get('document_type', 'unknown')
                    document_url = _save_verification_file(uploaded_file, request.user.id, doc_type)
                    updates['document_url'] = document_url
                except Exception as e:
                    return Response({'error': f'File save failed: {e}'}, status=status.HTTP_400_BAD_REQUEST)
            
            if not updates:
                # No updates provided, return current document
                return Response({
                    'id': doc.get('id'),
                    'document_type': doc.get('document_type'),
                    'document_number': doc.get('document_number'),
                    'document_url': doc.get('document_url'),
                    'status': doc.get('status'),
                    'created_at': _to_json_serializable(doc.get('created_at')),
                })
            
            # Update the document
            updates['updated_at'] = datetime.now().isoformat()
            supabase.table(PROVIDER_VERIFICATION_TABLE).update(updates).eq(
                'id', verification_id
            ).eq('provider_id', request.user.id).execute()
            
            # Fetch and return updated document
            updated_r = supabase.table(PROVIDER_VERIFICATION_TABLE).select('*').eq(
                'id', verification_id
            ).limit(1).execute()
            
            if updated_r.data and len(updated_r.data) > 0:
                row = updated_r.data[0]
                return Response({
                    'id': row.get('id'),
                    'document_type': row.get('document_type'),
                    'document_number': row.get('document_number'),
                    'document_url': row.get('document_url'),
                    'status': row.get('status'),
                    'created_at': _to_json_serializable(row.get('created_at')),
                })
            return Response({'error': 'Failed to update'}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    # Handle DELETE
    try:
        supabase = get_supabase_client()
        r = supabase.table(PROVIDER_VERIFICATION_TABLE).select('id').eq(
            'id', verification_id
        ).eq('provider_id', request.user.id).execute()
        if not r.data or len(r.data) == 0:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
        supabase.table(PROVIDER_VERIFICATION_TABLE).delete().eq(
            'id', verification_id
        ).eq('provider_id', request.user.id).execute()
        return Response(status=status.HTTP_204_NO_CONTENT)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def provider_verification_status(request):
    """Provider sees own verification status and review reason."""
    if getattr(request.user, 'role', None) != 'provider':
        return Response({'error': 'Provider only'}, status=status.HTTP_403_FORBIDDEN)
    try:
        supabase = get_supabase_client()
        ur = supabase.table('seva_auth_user').select(
            'id,verification_status,rejection_reason,submitted_at,reviewed_at,reviewed_by'
        ).eq('id', request.user.id).limit(1).execute()
        row = (ur.data or [{}])[0]
        effective_status = _provider_status_from_user_row(row)
        return Response({
            'provider_id': row.get('id'),
            'verification_status': effective_status,
            'rejection_reason': row.get('rejection_reason') or '',
            'is_active_provider': effective_status == 'approved',
            'submitted_at': _to_json_serializable(row.get('submitted_at')),
            'reviewed_at': _to_json_serializable(row.get('reviewed_at')),
            'reviewed_by': row.get('reviewed_by'),
        })
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def provider_verification_applications(request):
    """Admin list of provider verification applications."""
    role = (getattr(request.user, 'role', None) or '').strip().lower()
    if role != 'admin':
        return Response({'error': 'Admin only'}, status=status.HTTP_403_FORBIDDEN)
    status_filter = (request.query_params.get('status') or '').strip().lower()
    try:
        supabase = get_supabase_client()
        users_r = supabase.table('seva_auth_user').select(
            'id,username,email,phone,profession,qualification,district,city,verification_status,rejection_reason,submitted_at,reviewed_at,reviewed_by,role'
        ).execute()
        providers = [
            u for u in (users_r.data or [])
            if (u.get('role') or '').strip().lower() in ('provider', 'prov')
        ]
        if status_filter:
            providers = [
                p for p in providers
                if (p.get('verification_status') or '').strip().lower() == status_filter
            ]
        out = []
        for p in providers:
            docs_r = supabase.table(PROVIDER_VERIFICATION_TABLE).select(
                'id,document_type,document_number,document_url,status,created_at,updated_at'
            ).eq('provider_id', p.get('id')).order('created_at', desc=True).execute()
            out.append({
                'provider': p,
                'documents': docs_r.data or [],
            })
        out.sort(key=lambda x: (x['provider'].get('submitted_at') or ''), reverse=True)
        return Response(out)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def provider_verification_review(request, provider_id):
    """Admin action: approve / reject / pending provider verification."""
    role = (getattr(request.user, 'role', None) or '').strip().lower()
    if role != 'admin':
        return Response({'error': 'Admin only'}, status=status.HTTP_403_FORBIDDEN)
    action = (request.data.get('action') or '').strip().lower()
    if action not in {'approve', 'reject', 'pending', 'unverified'}:
        return Response({'error': 'action must be approve, reject, or pending'}, status=status.HTTP_400_BAD_REQUEST)
    note = (request.data.get('note') or '').strip()
    try:
        supabase = get_supabase_client()
        ur = supabase.table('seva_auth_user').select('id,role').eq('id', provider_id).limit(1).execute()
        if not ur.data or len(ur.data) == 0:
            return Response({'error': 'Provider not found'}, status=status.HTTP_404_NOT_FOUND)
        prow = ur.data[0]
        if (prow.get('role') or '').strip().lower() not in ('provider', 'prov'):
            return Response({'error': 'Selected user is not a provider'}, status=status.HTTP_400_BAD_REQUEST)

        docs_r = supabase.table(PROVIDER_VERIFICATION_TABLE).select(
            'document_type,document_url'
        ).eq('provider_id', provider_id).execute()
        docs = docs_r.data or []
        has_id_doc = any(
            (d.get('document_type') or '').strip().lower() in ID_DOCUMENT_TYPES
            and (d.get('document_url') or '').strip()
            for d in docs
        )
        has_cert = any(
            (d.get('document_type') or '').strip().lower() in QUALIFICATION_DOCUMENT_TYPES
            and (d.get('document_url') or '').strip()
            for d in docs
        )

        if action == 'approve':
            if not (has_id_doc and has_cert):
                return Response(
                    {'error': 'Cannot approve before required ID and qualification documents are uploaded.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            status_val = 'approved'
            is_active_provider = True
            rejection_reason = None
            is_verified = True
        elif action == 'reject':
            if not note:
                return Response(
                    {'error': 'Rejection reason is required when rejecting a provider.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            status_val = 'rejected'
            is_active_provider = True
            rejection_reason = note
            is_verified = False
        elif action == 'pending':
            status_val = 'pending'
            is_active_provider = True
            rejection_reason = None
            is_verified = False
        else:
            status_val = 'unverified'
            is_active_provider = True
            rejection_reason = None
            is_verified = False

        now_iso = datetime.now().isoformat()
        _safe_update_auth_user(supabase, provider_id, {
            'verification_status': status_val,
            'is_active_provider': is_active_provider,
            'is_verified': is_verified,
            'rejection_reason': rejection_reason,
            'reviewed_at': now_iso,
            'reviewed_by': request.user.id,
        })

        # Sync doc rows to same state for audit visibility (schema-compatible fallback).
        def _safe_update_docs(payload):
            data = dict(payload or {})
            while data:
                try:
                    supabase.table(PROVIDER_VERIFICATION_TABLE).update(data).eq('provider_id', provider_id).execute()
                    return
                except Exception as e:
                    msg = str(e)
                    missing = None
                    if 'PGRST204' in msg and "Could not find the '" in msg:
                        missing = msg.split("Could not find the '", 1)[1].split("' column", 1)[0]
                    if not missing or missing not in data:
                        raise
                    data.pop(missing, None)

        candidate_doc_statuses = [status_val]
        if status_val == 'approved':
            candidate_doc_statuses = ['approved', 'verified']
        elif status_val == 'pending':
            candidate_doc_statuses = ['pending', 'pending_verification', 'under_review']
        for candidate_status in candidate_doc_statuses:
            try:
                _safe_update_docs({
                    'status': candidate_status,
                    'review_note': note or None,
                    'reviewed_at': now_iso,
                    'reviewed_by': request.user.id,
                    'updated_at': now_iso,
                })
                break
            except Exception:
                continue

        try:
            supabase.table('seva_notification').insert({
                'user_id': int(provider_id),
                'title': 'Provider verification update',
                'body': (
                    'Your provider application is approved.'
                    if action == 'approve'
                    else (
                        f'Your provider application is rejected. {note}'.strip()
                        if action == 'reject'
                        else 'Your provider application status was updated.'
                    )
                ),
            }).execute()
        except Exception:
            pass

        return Response({
            'provider_id': int(provider_id),
            'verification_status': status_val,
            'is_active_provider': is_active_provider,
            'rejection_reason': rejection_reason or '',
            'reviewed_at': now_iso,
            'reviewed_by': request.user.id,
        })
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# --- eSewa payment integration ---
ESEWA_MERCHANT_CODE = 'EPAYTEST'
ESEWA_UAT_URL = 'https://uat.esewa.com.np/epay/main'
# Status Check API: verify transaction with eSewa before marking payment complete (recommended)
ESEWA_STATUS_CHECK_UAT = 'https://uat.esewa.com.np/api/epay/transaction/status/'
ESEWA_STATUS_CHECK_LIVE = 'https://epay.esewa.com.np/api/epay/transaction/status/'
# Mobile SDK Transaction Verification API (for esewa_flutter_sdk flow)
# Uses refId from SDK success callback. Test: rc.esewa.com.np, Live: esewa.com.np
ESEWA_MOBILE_TXN_UAT = 'https://rc.esewa.com.np/mobile/transaction'
ESEWA_MOBILE_TXN_LIVE = 'https://esewa.com.np/mobile/transaction'
# Official test credentials for eSewa SDK (from developer.esewa.com.np)
ESEWA_CLIENT_ID_TEST = 'JB0BBQ4aD0UqIThFJwAKBgAXEUkEGQUBBAwdOgABHD4DChwUAB0R'
ESEWA_SECRET_KEY_TEST = 'BhwIWQQADhIYSxILExMcAgFXFhcOBwAKBgAXEQ=='


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def payment_initiate(request):
    """Create a payment record and return eSewa payment URL for the given booking."""
    from django.http import HttpRequest
    booking_id = request.data.get('booking_id')
    amount = request.data.get('amount')
    if not booking_id or amount is None:
        return Response({'error': 'booking_id and amount are required'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        amount_val = float(amount)
        if amount_val <= 0:
            return Response({'error': 'amount must be positive'}, status=status.HTTP_400_BAD_REQUEST)
    except (TypeError, ValueError):
        return Response({'error': 'invalid amount'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        supabase = get_supabase_client()
        r = supabase.table(Booking._meta.db_table).select('*').eq('id', booking_id).execute()
        if not r.data or len(r.data) == 0:
            return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)
        booking = r.data[0]
        if booking['customer_id'] != request.user.id:
            return Response({'error': 'Not your booking'}, status=status.HTTP_403_FORBIDDEN)
        # When provider sends a quote, status becomes awaiting_payment (not "quoted").
        bst = (booking.get('status') or '').strip().lower()
        if bst not in (
            BOOKING_STATUS_QUOTED,
            BOOKING_STATUS_AWAITING_PAYMENT,
        ):
            return Response({
                'error': 'Payment is only available after your provider sends a quote for this request.',
            }, status=status.HTTP_400_BAD_REQUEST)
        try:
            expected = float(booking.get('total_amount') or booking.get('quoted_price') or 0)
        except (TypeError, ValueError):
            expected = 0.0
        if expected <= 0:
            return Response({'error': 'This booking has no quoted amount yet.'}, status=status.HTTP_400_BAD_REQUEST)
        if abs(amount_val - expected) > 0.02:
            return Response({
                'error': f'Amount must match the quoted price (Rs {expected:.2f}).',
            }, status=status.HTTP_400_BAD_REQUEST)
        import time
        transaction_id = f"HS{booking_id}_{int(time.time() * 1000)}"
        payload = {
            'booking_id': int(booking_id),
            'amount': str(amount_val),
            'transaction_id': transaction_id,
            'gateway': 'esewa',
            'status': PAYMENT_STATUS_PENDING,
        }
        supabase.table(PAYMENT_TABLE).insert(payload).execute()
        base_url = request.build_absolute_uri('/').rstrip('/')
        success_url = f"{base_url}/api/payments/esewa-success/"
        failure_url = f"{base_url}/api/payments/esewa-failure/"
        params = {
            'scd': ESEWA_MERCHANT_CODE,
            'amt': str(amount_val),
            'pdc': '0',
            'psc': '0',
            'tAmt': str(amount_val),
            'pid': transaction_id,
            'su': success_url,
            'fu': failure_url,
        }
        from urllib.parse import urlencode
        payment_url = f"{ESEWA_UAT_URL}?{urlencode(params)}"
        return Response({
            'payment_url': payment_url,
            'transaction_id': transaction_id,
            'amount': amount_val,
        }, status=status.HTTP_200_OK)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


def _notify_provider_payment_received(supabase, booking_id):
    """Insert a notification for the provider when payment is completed for a booking."""
    try:
        r = supabase.table(Booking._meta.db_table).select('service_id').eq('id', booking_id).execute()
        if not r.data or not r.data[0]:
            return
        svc_r = supabase.table(Service._meta.db_table).select('provider_id').eq('id', r.data[0]['service_id']).execute()
        if not svc_r.data or not svc_r.data[0]:
            return
        provider_id = svc_r.data[0]['provider_id']
        supabase.table('seva_notification').insert({
            'user_id': provider_id,
            'title': 'Payment received',
            'body': f'Payment received for Booking #{booking_id}. Tap to view.',
            'booking_id': int(booking_id),
        }).execute()
    except Exception as e:
        print(f"Notify provider payment: {e}")


def _esewa_verify_transaction(transaction_uuid, total_amount, use_uat=True):
    """
    Call eSewa Status Check API to verify transaction. Returns dict with 'status' and optional 'refId',
    or None on request/parse error. Only mark payment complete when status == 'COMPLETE'.
    """
    import urllib.request
    import json
    base = ESEWA_STATUS_CHECK_UAT if use_uat else ESEWA_STATUS_CHECK_LIVE
    url = f"{base}?product_code={ESEWA_MERCHANT_CODE}&total_amount={total_amount}&transaction_uuid={transaction_uuid}"
    try:
        req = urllib.request.Request(url, headers={'Accept': 'application/json'})
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode())
            return data
    except Exception as e:
        print(f"eSewa status check error: {e}")
        return None


@api_view(['GET'])
@permission_classes([AllowAny])
def payment_esewa_success(request):
    """
    eSewa redirects here on success. Verify transaction with eSewa Status Check API;
    only then update payment and booking, then redirect to app.
    """
    oid = request.GET.get('oid')
    ref_id = request.GET.get('refId')
    amt = request.GET.get('amt')
    if not oid:
        return Response({'error': 'missing oid'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        supabase = get_supabase_client()
        r = supabase.table(PAYMENT_TABLE).select('*').eq('transaction_id', oid).order('id', desc=True).limit(1).execute()
        if not r.data or len(r.data) == 0:
            return Response({'error': 'Payment not found'}, status=status.HTTP_404_NOT_FOUND)
        payment = r.data[0]
        if (payment.get('status') or '').strip().lower() == PAYMENT_STATUS_COMPLETED:
            booking_id = payment.get('booking_id')
            try:
                br = supabase.table(Booking._meta.db_table).select('customer_id').eq('id', booking_id).limit(1).execute()
                if br.data and br.data[0].get('customer_id') is not None:
                    _award_referral_points_if_eligible(supabase, br.data[0].get('customer_id'))
            except Exception:
                pass
            app_scheme = request.GET.get('app_scheme', 'hamrosewa')
            redirect_url = f"{app_scheme}://payment/success?booking_id={booking_id}&transaction_id={oid}"
            from django.shortcuts import redirect
            return redirect(redirect_url)
        if (payment.get('status') or '').strip().lower() != PAYMENT_STATUS_PENDING:
            return Response({'error': 'Payment is not in pending state'}, status=status.HTTP_400_BAD_REQUEST)
        booking_id = payment['booking_id']
        total_amount = float(payment.get('amount', amt or 0))

        # Verify with eSewa before updating DB (recommended to prevent fraud)
        verification = _esewa_verify_transaction(oid, total_amount, use_uat=True)
        if verification is None:
            # Network/API error: do not mark complete; redirect to failure so user can retry
            from django.shortcuts import redirect
            app_scheme = request.GET.get('app_scheme', 'hamrosewa')
            redirect_url = f"{app_scheme}://payment/failure?booking_id={booking_id}&transaction_id={oid}&reason=verification_failed"
            return redirect(redirect_url)
        status_from_esewa = (verification.get('status') or '').strip().upper()
        if status_from_esewa != 'COMPLETE':
            # PENDING, NOT_FOUND, CANCELED, etc.: redirect to failure
            from django.shortcuts import redirect
            app_scheme = request.GET.get('app_scheme', 'hamrosewa')
            redirect_url = f"{app_scheme}://payment/failure?booking_id={booking_id}&transaction_id={oid}&reason={status_from_esewa}"
            return redirect(redirect_url)

        ref_id_verified = verification.get('refId') or ref_id or ''
        supabase.table(PAYMENT_TABLE).update({
            'status': PAYMENT_STATUS_COMPLETED,
            'ref_id': str(ref_id_verified),
            'updated_at': datetime.now().isoformat(),
        }).eq('id', payment['id']).execute()
        supabase.table(Booking._meta.db_table).update({
            'status': BOOKING_STATUS_PAID,
            'updated_at': datetime.now().isoformat(),
        }).eq('id', booking_id).execute()
        try:
            br = supabase.table(Booking._meta.db_table).select('customer_id').eq('id', booking_id).limit(1).execute()
            if br.data and br.data[0].get('customer_id') is not None:
                _award_referral_points_if_eligible(supabase, br.data[0].get('customer_id'))
        except Exception:
            pass
        _create_or_update_receipt_for_booking(supabase, booking_id)
        _notify_provider_payment_received(supabase, booking_id)
        app_scheme = request.GET.get('app_scheme', 'hamrosewa')
        redirect_url = f"{app_scheme}://payment/success?booking_id={booking_id}&transaction_id={oid}"
        from django.shortcuts import redirect
        return redirect(redirect_url)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([AllowAny])
def payment_esewa_failure(request):
    """eSewa redirects here on failure. Mark payment failed, redirect to app."""
    oid = request.GET.get('oid')
    if not oid:
        return Response({'error': 'missing oid'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        supabase = get_supabase_client()
        r = supabase.table(PAYMENT_TABLE).select('*').eq('transaction_id', oid).execute()
        if r.data and len(r.data) > 0:
            payment = r.data[0]
            supabase.table(PAYMENT_TABLE).update({
                'status': PAYMENT_STATUS_FAILED,
                'updated_at': datetime.now().isoformat(),
            }).eq('id', payment['id']).execute()
            booking_id = payment['booking_id']
        else:
            booking_id = None
        app_scheme = request.GET.get('app_scheme', 'hamrosewa')
        redirect_url = f"{app_scheme}://payment/failure?booking_id={booking_id or ''}&transaction_id={oid}"
        from django.shortcuts import redirect
        return redirect(redirect_url)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def wallet_summary(request):
    """Return wallet summary for the current user.

    Uses completed payments (via bookings) as the transaction history.
    """
    try:
        supabase = get_supabase_client()
        bookings = _get_bookings_raw_from_supabase(customer_id=request.user.id)
        booking_ids = [b.get('id') for b in bookings if b.get('id') is not None]

        transactions = []
        total_spent = 0.0
        if booking_ids:
            for bid in booking_ids:
                r = supabase.table(PAYMENT_TABLE).select('*').eq('booking_id', bid).execute()
                if r.data:
                    for p in r.data:
                        amount = float(p.get('amount') or 0)
                        status_str = (p.get('status') or '').lower()
                        if status_str == PAYMENT_STATUS_COMPLETED:
                            total_spent += amount
                        elif status_str == PAYMENT_STATUS_REFUNDED:
                            total_spent -= amount
                        transactions.append({
                            'id': p.get('id'),
                            'booking_id': p.get('booking_id'),
                            'transaction_id': p.get('transaction_id'),
                            'status': status_str,
                            'gateway': p.get('gateway'),
                            'amount': amount,
                            'ref_id': p.get('ref_id'),
                            'created_at': _to_json_serializable(p.get('created_at')),
                            'updated_at': _to_json_serializable(p.get('updated_at')),
                        })
                        try:
                            rr = supabase.table(RECEIPT_TABLE).select('id,receipt_id').eq('payment_id', p.get('id')).limit(1).execute()
                            if rr.data and rr.data[0]:
                                transactions[-1]['receipt_pk'] = rr.data[0].get('id')
                                transactions[-1]['receipt_id'] = rr.data[0].get('receipt_id')
                        except Exception:
                            pass
        transactions.sort(key=lambda x: x.get('created_at') or '', reverse=True)
        return Response({
            'balance': total_spent,
            'transactions': transactions,
        }, status=status.HTTP_200_OK)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def receipts_list(request):
    """List receipts owned by current user (customer/provider) or all (admin)."""
    try:
        supabase = get_supabase_client()
        role = (getattr(request.user, 'role', None) or '').strip().lower()
        if role == 'admin':
            r = supabase.table(RECEIPT_TABLE).select('*').order('id', desc=True).execute()
            return Response(_to_json_serializable([_decorate_receipt(supabase, x) for x in (r.data or [])]))
        if role == 'provider':
            r = supabase.table(RECEIPT_TABLE).select('*').eq('provider_id', request.user.id).order('id', desc=True).execute()
            return Response(_to_json_serializable([_decorate_receipt(supabase, x) for x in (r.data or [])]))
        r = supabase.table(RECEIPT_TABLE).select('*').eq('customer_id', request.user.id).order('id', desc=True).execute()
        return Response(_to_json_serializable([_decorate_receipt(supabase, x) for x in (r.data or [])]))
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def receipt_detail(request, receipt_id):
    """Get one receipt with ownership check."""
    try:
        supabase = get_supabase_client()
        r = supabase.table(RECEIPT_TABLE).select('*').eq('id', receipt_id).limit(1).execute()
        if not r.data or len(r.data) == 0:
            return Response({'error': 'Receipt not found'}, status=status.HTTP_404_NOT_FOUND)
        row = r.data[0]
        role = (getattr(request.user, 'role', None) or '').strip().lower()
        if role != 'admin' and request.user.id not in {row.get('customer_id'), row.get('provider_id')}:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        return Response(_to_json_serializable(_decorate_receipt(supabase, row)))
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def receipt_by_booking(request, booking_id):
    """Get latest receipt for booking, if requester has access."""
    try:
        supabase = get_supabase_client()
        br = supabase.table(Booking._meta.db_table).select('*').eq('id', booking_id).limit(1).execute()
        if not br.data or len(br.data) == 0:
            return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)
        b = br.data[0]
        role = (getattr(request.user, 'role', None) or '').strip().lower()
        if role != 'admin':
            allowed = False
            if b.get('customer_id') == request.user.id:
                allowed = True
            else:
                sr = supabase.table(Service._meta.db_table).select('provider_id').eq('id', b.get('service_id')).limit(1).execute()
                if sr.data and sr.data[0] and sr.data[0].get('provider_id') == request.user.id:
                    allowed = True
            if not allowed:
                return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        rr = supabase.table(RECEIPT_TABLE).select('*').eq('booking_id', int(booking_id)).order('id', desc=True).limit(1).execute()
        if not rr.data or len(rr.data) == 0:
            return Response({'error': 'Receipt not found'}, status=status.HTTP_404_NOT_FOUND)
        return Response(_to_json_serializable(_decorate_receipt(supabase, rr.data[0])))
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


def _decorate_receipt(supabase, row):
    out = dict(row or {})
    try:
        cid = out.get('customer_id')
        pid = out.get('provider_id')
        if cid is not None:
            cr = supabase.table('seva_auth_user').select('username,email').eq('id', cid).limit(1).execute()
            if cr.data and cr.data[0]:
                out['customer_name'] = cr.data[0].get('username') or cr.data[0].get('email') or ''
        if pid is not None:
            pr = supabase.table('seva_auth_user').select('username,email').eq('id', pid).limit(1).execute()
            if pr.data and pr.data[0]:
                out['provider_name'] = pr.data[0].get('username') or pr.data[0].get('email') or ''
    except Exception:
        pass
    return out


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def refund_list(request):
    """List refunds relevant to current user (admin sees all)."""
    try:
        supabase = get_supabase_client()
        role = (getattr(request.user, 'role', None) or '').strip().lower()
        if role == 'admin':
            r = supabase.table(REFUND_TABLE).select('*').order('id', desc=True).execute()
            return Response(_to_json_serializable(r.data or []))

        query_field = 'customer_id' if role == 'customer' else 'provider_id'
        r = (
            supabase
            .table(REFUND_TABLE)
            .select('*')
            .eq(query_field, request.user.id)
            .order('id', desc=True)
            .execute()
        )
        return Response(_to_json_serializable(r.data or []))
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def refund_provider_review(request, refund_id):
    """Provider decision for refund request: approve or reject."""
    role = (getattr(request.user, 'role', None) or '').strip().lower()
    if role != 'provider':
        return Response({'error': 'Only provider can review refund request'}, status=status.HTTP_403_FORBIDDEN)
    action = (request.data.get('action') or '').strip().lower()
    if action not in ('approve', 'reject'):
        return Response({'error': 'action must be approve or reject'}, status=status.HTTP_400_BAD_REQUEST)
    provider_note = (request.data.get('note') or '').strip()

    try:
        supabase = get_supabase_client()
        rr = supabase.table(REFUND_TABLE).select('*').eq('id', refund_id).execute()
        if not rr.data or len(rr.data) == 0:
            return Response({'error': 'Refund not found'}, status=status.HTTP_404_NOT_FOUND)
        refund = rr.data[0]
        if refund.get('provider_id') != request.user.id:
            return Response({'error': 'Not your refund request'}, status=status.HTTP_403_FORBIDDEN)

        current = (refund.get('status') or '').strip().lower()
        if current not in {REFUND_STATUS_PENDING, REFUND_STATUS_PROVIDER_APPROVED, REFUND_STATUS_PROVIDER_REJECTED}:
            return Response({'error': f'Refund is already finalized ({current})'}, status=status.HTTP_400_BAD_REQUEST)

        booking_id = refund.get('booking_id')
        if action == 'approve':
            refund_status = REFUND_STATUS_PROVIDER_APPROVED
            booking_status = BOOKING_STATUS_REFUND_PENDING
            system_note = provider_note or 'Approved by provider. Awaiting admin refund processing.'
        else:
            refund_status = REFUND_STATUS_PROVIDER_REJECTED
            booking_status = BOOKING_STATUS_REFUND_PROVIDER_REJECTED
            system_note = provider_note or 'Rejected by provider.'

        supabase.table(REFUND_TABLE).update({
            'status': refund_status,
            'system_note': system_note,
            'updated_at': datetime.now().isoformat(),
        }).eq('id', refund_id).execute()

        if booking_id is not None:
            supabase.table(Booking._meta.db_table).update({
                'status': booking_status,
                'updated_at': datetime.now().isoformat(),
            }).eq('id', booking_id).execute()

        latest_payment = _latest_payment_for_booking(supabase, booking_id)
        if latest_payment:
            payment_status = PAYMENT_STATUS_REFUND_PENDING if action == 'approve' else PAYMENT_STATUS_REFUND_REJECTED
            supabase.table(PAYMENT_TABLE).update({
                'status': payment_status,
                'updated_at': datetime.now().isoformat(),
            }).eq('id', latest_payment.get('id')).execute()
            _create_or_update_receipt_for_booking(supabase, booking_id)

        # Notify customer
        customer_id = refund.get('customer_id')
        if customer_id is not None:
            _notify_user(
                supabase,
                customer_id,
                'Refund review updated',
                (
                    f'Provider approved refund for Booking #{booking_id}. Status: Under review by admin.'
                    if action == 'approve'
                    else f'Provider rejected refund request for Booking #{booking_id}. Reason: {provider_note or "Not provided"}'
                ),
                booking_id=int(booking_id) if booking_id is not None else None,
            )

        # Notify admins when provider approved.
        if action == 'approve':
            for aid in _get_admin_user_ids(supabase):
                _notify_user(
                    supabase,
                    aid,
                    'Refund review required',
                    f'Provider approved refund for Booking #{booking_id}.',
                    booking_id=int(booking_id) if booking_id is not None else None,
                )

        fresh = supabase.table(REFUND_TABLE).select('*').eq('id', refund_id).execute()
        return Response(_to_json_serializable((fresh.data or [refund])[0]))
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def refund_review(request, refund_id):
    """Admin decision for refund workflow: approve(refunded) or reject(refund_rejected)."""
    role = (getattr(request.user, 'role', None) or '').strip().lower()
    if role != 'admin':
        return Response({'error': 'Only admin can review refunds'}, status=status.HTTP_403_FORBIDDEN)
    action = (request.data.get('action') or '').strip().lower()
    if action not in ('approve', 'reject'):
        return Response({'error': 'action must be approve or reject'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        supabase = get_supabase_client()
        rr = supabase.table(REFUND_TABLE).select('*').eq('id', refund_id).execute()
        if not rr.data or len(rr.data) == 0:
            return Response({'error': 'Refund not found'}, status=status.HTTP_404_NOT_FOUND)
        refund = rr.data[0]
        current_refund_status = (refund.get('status') or '').strip().lower()
        if current_refund_status in {REFUND_STATUS_COMPLETED, REFUND_STATUS_REJECTED}:
            return Response(_to_json_serializable(refund), status=status.HTTP_200_OK)
        if current_refund_status not in {REFUND_STATUS_PROVIDER_APPROVED, REFUND_STATUS_UNDER_REVIEW}:
            return Response({'error': 'Provider approval required before admin review'}, status=status.HTTP_400_BAD_REQUEST)

        booking_id = refund.get('booking_id')
        payment_id = refund.get('payment_id')
        decision_status = REFUND_STATUS_COMPLETED if action == 'approve' else REFUND_STATUS_REJECTED
        payment_status = PAYMENT_STATUS_REFUNDED if action == 'approve' else PAYMENT_STATUS_REFUND_REJECTED
        booking_status = BOOKING_STATUS_REFUNDED if action == 'approve' else BOOKING_STATUS_REFUND_REJECTED
        admin_note = (request.data.get('note') or request.data.get('admin_note') or '').strip()
        refund_reference = (request.data.get('refund_reference') or '').strip()

        if action == 'approve' and not refund_reference:
            return Response(
                {'error': 'refund_reference is required when approving refund.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        supabase.table(REFUND_TABLE).update({
            'status': decision_status,
            'admin_note': admin_note or None,
            'refund_reference': refund_reference or None,
            'reviewed_by': request.user.id,
            'reviewed_at': datetime.now().isoformat(),
            'updated_at': datetime.now().isoformat(),
        }).eq('id', refund_id).execute()

        if payment_id is not None:
            supabase.table(PAYMENT_TABLE).update({
                'status': payment_status,
                'updated_at': datetime.now().isoformat(),
                'raw_response': (
                    admin_note
                    or (
                        f'Refund completed with reference {refund_reference}.'
                        if action == 'approve'
                        else 'Refund rejected by admin.'
                    )
                ),
            }).eq('id', payment_id).execute()

        if booking_id is not None:
            supabase.table(Booking._meta.db_table).update({
                'status': booking_status,
                'updated_at': datetime.now().isoformat(),
            }).eq('id', booking_id).execute()
            _create_or_update_receipt_for_booking(supabase, booking_id)

        # Notify customer/provider with final outcome and payout confirmation.
        customer_id = refund.get('customer_id')
        provider_id = refund.get('provider_id')

        if action == 'approve':
            _notify_user(
                supabase,
                customer_id,
                'Refund approved',
                (
                    f'Your refund has been approved and the amount has been credited to your account. '
                    f'Booking #{booking_id}. Reference: {refund_reference}.'
                ),
                booking_id=int(booking_id) if booking_id is not None else None,
            )
            _notify_user(
                supabase,
                provider_id,
                'Refund completed',
                f'Refund for Booking #{booking_id} has been completed by admin.',
                booking_id=int(booking_id) if booking_id is not None else None,
            )
        else:
            _notify_user(
                supabase,
                customer_id,
                'Refund rejected',
                (
                    f'Your refund request for Booking #{booking_id} has been rejected. '
                    f'Reason: {admin_note or "Not provided"}.'
                ),
                booking_id=int(booking_id) if booking_id is not None else None,
            )
            _notify_user(
                supabase,
                provider_id,
                'Refund rejected',
                f'Refund for Booking #{booking_id} was rejected by admin.',
                booking_id=int(booking_id) if booking_id is not None else None,
            )

        fresh = supabase.table(REFUND_TABLE).select('*').eq('id', refund_id).execute()
        return Response(_to_json_serializable((fresh.data or [refund])[0]))
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def chat_threads(request):
    """List chat threads (bookings) for the current user."""
    try:
        supabase = get_supabase_client()
        user = request.user
        user_role = (getattr(user, 'role', None) or '').lower().strip()
        is_provider = user_role == 'provider'
        user_id = getattr(user, 'id', None)
        if user_id is None:
            return Response([], status=status.HTTP_200_OK)

        # Determine relevant bookings for customer vs provider
        if is_provider:
            services = _get_services_raw_from_supabase(provider_id=user_id)
            service_ids = [s.get('id') for s in services if s.get('id') is not None]
            bookings = _get_bookings_raw_from_supabase(service_ids=service_ids) if service_ids else []
        else:
            bookings = _get_bookings_raw_from_supabase(customer_id=user_id)

        bookings = _enrich_bookings_with_names(bookings)

        # Get last message per booking
        booking_ids = [b.get('id') for b in bookings if b.get('id') is not None]
        last_messages = {}
        if booking_ids:
            r = supabase.table('seva_chat_message').select('*').in_('booking_id', booking_ids).order('created_at', desc=True).execute()
            if r.data:
                for m in r.data:
                    bid = m.get('booking_id')
                    if bid not in last_messages:
                        last_messages[bid] = m

        # Deduplicate by unique customer-provider account pair.
        # - If logged-in user is provider: 1 thread per customer_id
        # - If logged-in user is customer: 1 thread per provider_id
        grouped = {}
        for b in bookings:
            bid = b.get('id')
            if bid is None:
                continue

            key = (b.get('customer_id') if is_provider else b.get('provider_id'))
            if key is None:
                continue

            last = last_messages.get(bid)
            # Check if the last message is deleted
            if last and last.get('deleted_at') is not None:
                preview = 'Message deleted'
            else:
                preview = (
                    (last.get('message') if last else '') or
                    (last.get('attachment_name') if last else '') or
                    ''
                )

            sort_time = (
                last.get('created_at') if last and last.get('created_at') else b.get('created_at')
            )
            sort_time_json = _to_json_serializable(sort_time) if sort_time else None

            existing = grouped.get(key)
            if existing is None or (sort_time_json or '') > (existing.get('_sort_time') or ''):
                grouped[key] = {
                    '_sort_time': sort_time_json,
                    'booking_id': bid,  # representative booking for this pair
                    'service_title': b.get('service_title'),
                    'provider_name': b.get('provider_name'),
                    'customer_name': b.get('customer_name'),
                    'last_message': preview,
                    'last_message_at': sort_time_json,
                }

        threads = list(grouped.values())
        for t in threads:
            t.pop('_sort_time', None)

        # Sort threads by latest message time descending
        threads.sort(key=lambda t: t.get('last_message_at') or '', reverse=True)
        return Response(threads, status=status.HTTP_200_OK)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def chat_messages(request, booking_id):
    """Get or post chat messages for a booking."""
    try:
        supabase = get_supabase_client()
        user = request.user
        CHAT_ATTACHMENTS_BUCKET = 'chat-attachments'

        # Validate booking and participation
        r = supabase.table(Booking._meta.db_table).select('*').eq('id', booking_id).execute()
        if not r.data or len(r.data) == 0:
            return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)
        booking = r.data[0]
        if getattr(user, 'role', None) == 'provider':
            # Ensure provider owns the service
            svc = supabase.table(Service._meta.db_table).select('provider_id').eq('id', booking.get('service_id')).execute()
            if not svc.data or svc.data[0].get('provider_id') != user.id:
                return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        else:
            if booking.get('customer_id') != user.id:
                return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)

        if request.method == 'GET':
            # Unify conversation across repeated bookings with the same
            # customer-provider pair.
            customer_id = booking.get('customer_id')

            def _to_int(v):
                try:
                    return int(v)
                except (TypeError, ValueError):
                    return None

            # Find provider_id from the service_id of this booking.
            svc_r = supabase.table(Service._meta.db_table).select('provider_id').eq(
                'id', booking.get('service_id')
            ).execute()
            provider_id = (
                svc_r.data[0].get('provider_id')
                if svc_r.data and len(svc_r.data) > 0
                else None
            )

            # If we can't determine the pair, fall back to the single booking.
            pair_booking_ids = [booking_id]
            if customer_id is not None and provider_id is not None:
                services_r = supabase.table(Service._meta.db_table).select('id').eq(
                    'provider_id', provider_id
                ).execute()
                service_ids = [s.get('id') for s in (services_r.data or []) if s.get('id') is not None]
                pair_bookings = _get_bookings_raw_from_supabase(
                    customer_id=customer_id,
                    service_ids=service_ids
                ) if service_ids else []
                pair_booking_ids = [b.get('id') for b in pair_bookings if b.get('id') is not None] or [booking_id]

            msgs = supabase.table('seva_chat_message').select('*').in_(
                'booking_id', pair_booking_ids
            ).order('created_at', desc=False).execute()
            messages = list(msgs.data or [])
            sender_ids = []
            for m in messages:
                sid = _to_int(m.get('sender_id') or m.get('senderId') or m.get('sender'))
                if sid is not None:
                    sender_ids.append(sid)
            sender_ids = list(set(sender_ids))
            sender_map = {}
            if sender_ids:
                users = supabase.table('seva_auth_user').select('id,username,email').in_('id', sender_ids).execute()
                for u in users.data or []:
                    uid = _to_int(u.get('id'))
                    if uid is not None:
                        sender_map[uid] = (u.get('username') or u.get('email') or 'User')
            for m in messages:
                sender_id = _to_int(m.get('sender_id') or m.get('senderId') or m.get('sender'))
                m['sender_id'] = sender_id
                m['senderId'] = sender_id
                m['sender_name'] = sender_map.get(sender_id) or ''
                # If message is deleted, replace content with placeholder
                if m.get('deleted_at') is not None:
                    m['message'] = 'This message was deleted'
                    m['attachment_path'] = None
                    m['attachment_url'] = None
                    m['attachment_mime'] = None
                    m['attachment_name'] = None
                else:
                    attachment_path = m.get('attachment_path')
                    if attachment_path:
                        signed = supabase.storage.from_(CHAT_ATTACHMENTS_BUCKET).create_signed_url(
                            attachment_path, expires_in=24 * 60 * 60
                        )
                        m['attachment_url'] = signed.get('signedURL') or signed.get('signedUrl')
            return Response(_to_json_serializable(messages))

        # POST: send a message
        message = (_get_request_param(request, 'message') or request.data.get('message') or '').strip() if hasattr(request, 'data') else ''
        uploaded_file = request.FILES.get('file') or request.FILES.get('attachment')

        if (not message) and (not uploaded_file):
            return Response({'error': 'Message is required (or upload a file)'}, status=status.HTTP_400_BAD_REQUEST)

        attachment_path = None
        attachment_mime = None
        attachment_name = None
        if uploaded_file:
            file_name = getattr(uploaded_file, 'name', '') or 'attachment'
            content_type = getattr(uploaded_file, 'content_type', None)
            guessed = mimetypes.guess_type(file_name)[0]
            if not content_type or content_type == 'application/octet-stream':
                content_type = guessed or 'application/octet-stream'
            # Sanitize filename so Supabase path is safe.
            safe_name = re.sub(r'[^a-zA-Z0-9._-]', '_', file_name)
            ts = int(datetime.utcnow().timestamp())
            attachment_path = f'chat/{booking_id}/{ts}_{safe_name}'
            attachment_mime = content_type
            attachment_name = safe_name

            file_bytes = uploaded_file.read()
            supabase.storage.from_(CHAT_ATTACHMENTS_BUCKET).upload(
                attachment_path,
                file_bytes,
                file_options={'content-type': content_type},
            )

        new_msg = {
            'booking_id': booking_id,
            'sender_id': user.id,
            'message': message,
            'attachment_path': attachment_path,
            'attachment_mime': attachment_mime,
            'attachment_name': attachment_name,
        }
        created = supabase.table('seva_chat_message').insert(new_msg).execute()
        if created.data and len(created.data) > 0:
            row = created.data[0]
            try:
                row['sender_id'] = int(row.get('sender_id')) if row.get('sender_id') is not None else user.id
            except (TypeError, ValueError):
                row['sender_id'] = user.id
            row['senderId'] = row.get('sender_id')
            row['sender_name'] = getattr(user, 'username', None) or getattr(user, 'email', None) or ''
            if row.get('attachment_path'):
                signed = supabase.storage.from_(CHAT_ATTACHMENTS_BUCKET).create_signed_url(
                    row.get('attachment_path'), expires_in=24 * 60 * 60
                )
                row['attachment_url'] = signed.get('signedURL') or signed.get('signedUrl')
            return Response(_to_json_serializable(row), status=status.HTTP_201_CREATED)
        return Response({'error': 'Could not create message'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_chat_message(request, booking_id, message_id):
    """Delete a chat message. Only the sender can delete their own message."""
    try:
        supabase = get_supabase_client()
        user = request.user

        # Validate booking and participation
        r = supabase.table(Booking._meta.db_table).select('*').eq('id', booking_id).execute()
        if not r.data or len(r.data) == 0:
            return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)
        booking = r.data[0]
        
        if getattr(user, 'role', None) == 'provider':
            # Ensure provider owns the service
            svc = supabase.table(Service._meta.db_table).select('provider_id').eq('id', booking.get('service_id')).execute()
            if not svc.data or svc.data[0].get('provider_id') != user.id:
                return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        else:
            if booking.get('customer_id') != user.id:
                return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)

        # Get the message
        msg_r = supabase.table('seva_chat_message').select('*').eq('id', message_id).execute()
        if not msg_r.data or len(msg_r.data) == 0:
            return Response({'error': 'Message not found'}, status=status.HTTP_404_NOT_FOUND)
        message = msg_r.data[0]

        # Check if message belongs to this booking
        if message.get('booking_id') != booking_id:
            return Response({'error': 'Message does not belong to this booking'}, status=status.HTTP_403_FORBIDDEN)

        # Check if the current user is the message sender
        if message.get('sender_id') != user.id:
            return Response({'error': 'You can only delete your own messages'}, status=status.HTTP_403_FORBIDDEN)

        # Mark message as deleted (soft delete)
        from datetime import datetime
        update_r = supabase.table('seva_chat_message').update({
            'deleted_at': datetime.utcnow().isoformat(),
        }).eq('id', message_id).execute()

        if update_r.data:
            return Response({'success': True, 'message': 'Message deleted'}, status=status.HTTP_200_OK)
        return Response({'error': 'Could not delete message'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


def _esewa_mobile_verify_transaction(ref_id, use_uat=True):
    """
    Call eSewa Mobile Transaction API to verify SDK payment by refId.
    Returns dict with transactionDetails.status, or None on error.
    Uses merchantId and merchantSecret headers.
    """
    import urllib.request
    import json
    base = ESEWA_MOBILE_TXN_UAT if use_uat else ESEWA_MOBILE_TXN_LIVE
    url = f"{base}?txnRefId={ref_id}"
    try:
        req = urllib.request.Request(
            url,
            headers={
                'Accept': 'application/json',
                'merchantId': ESEWA_CLIENT_ID_TEST,
                'merchantSecret': ESEWA_SECRET_KEY_TEST,
                'Content-Type': 'application/json',
            },
            method='GET',
        )
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode())
            return data
    except Exception as e:
        print(f"eSewa mobile transaction verify error: {e}")
        return None


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def payment_verify_complete(request):
    """
    Verify eSewa SDK payment via Mobile Transaction API (refId) and mark complete.
    Called by app after EsewaFlutterSdk.initPayment onPaymentSuccess.
    """
    ref_id = request.data.get('ref_id')
    product_id = request.data.get('product_id')  # transaction_id
    booking_id = request.data.get('booking_id')
    total_amount = request.data.get('total_amount')
    if not ref_id or not product_id or not booking_id:
        return Response({
            'error': 'ref_id, product_id (transaction_id), and booking_id are required',
        }, status=status.HTTP_400_BAD_REQUEST)
    try:
        supabase = get_supabase_client()
        r = supabase.table(Booking._meta.db_table).select('*').eq('id', booking_id).execute()
        if not r.data or len(r.data) == 0:
            return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)
        booking = r.data[0]
        if booking['customer_id'] != request.user.id:
            return Response({'error': 'Not your booking'}, status=status.HTTP_403_FORBIDDEN)
        pay_r = supabase.table(PAYMENT_TABLE).select('*').eq(
            'booking_id', int(booking_id)
        ).eq('transaction_id', product_id).order('id', desc=True).limit(1).execute()
        if not pay_r.data or len(pay_r.data) == 0:
            return Response({'error': 'Payment not found for this booking'}, status=status.HTTP_404_NOT_FOUND)
        payment = pay_r.data[0]
        if (payment.get('status') or '').strip().lower() == PAYMENT_STATUS_COMPLETED:
            receipt = _create_or_update_receipt_for_booking(supabase, booking_id, payment=payment)
            _award_referral_points_if_eligible(supabase, booking.get('customer_id'))
            return Response({
                'success': True,
                'booking_id': str(booking_id),
                'transaction_id': product_id,
                'ref_id': payment.get('ref_id') or ref_id,
                'receipt': _to_json_serializable(receipt),
            }, status=status.HTTP_200_OK)
        if (payment.get('status') or '').strip().lower() != PAYMENT_STATUS_PENDING:
            return Response({'error': 'Payment is not in pending state'}, status=status.HTTP_400_BAD_REQUEST)

        verification = _esewa_mobile_verify_transaction(ref_id, use_uat=True)
        if verification is None:
            return Response({'error': 'Transaction verification failed'}, status=status.HTTP_502_BAD_GATEWAY)

        # API returns list of transaction objects
        items = verification if isinstance(verification, list) else [verification]
        status_ok = False
        for item in items:
            txn_details = item.get('transactionDetails') or item.get('transaction_details') or {}
            st = (txn_details.get('status') or '').strip().upper()
            if st == 'COMPLETE':
                status_ok = True
                break

        if not status_ok:
            return Response({'error': 'Transaction not complete'}, status=status.HTTP_400_BAD_REQUEST)

        supabase.table(PAYMENT_TABLE).update({
            'status': PAYMENT_STATUS_COMPLETED,
            'ref_id': str(ref_id),
            'updated_at': datetime.now().isoformat(),
        }).eq('id', payment['id']).execute()
        supabase.table(Booking._meta.db_table).update({
            'status': BOOKING_STATUS_PAID,
            'updated_at': datetime.now().isoformat(),
        }).eq('id', booking_id).execute()
        _award_referral_points_if_eligible(supabase, booking.get('customer_id'))
        receipt = _create_or_update_receipt_for_booking(supabase, booking_id)
        _notify_provider_payment_received(supabase, booking_id)
        return Response({
            'success': True,
            'booking_id': str(booking_id),
            'transaction_id': product_id,
            'ref_id': ref_id,
            'receipt': _to_json_serializable(receipt),
        }, status=status.HTTP_200_OK)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def payment_demo_complete(request):
    """Mark a payment as completed without eSewa (for testing when gateway is unreachable)."""
    booking_id = request.data.get('booking_id')
    transaction_id = request.data.get('transaction_id')
    if not booking_id:
        return Response({'error': 'booking_id is required'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        supabase = get_supabase_client()
        r = supabase.table(Booking._meta.db_table).select('*').eq('id', booking_id).execute()
        if not r.data or len(r.data) == 0:
            return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)
        booking = r.data[0]
        if booking['customer_id'] != request.user.id:
            return Response({'error': 'Not your booking'}, status=status.HTTP_403_FORBIDDEN)
        if transaction_id:
            pay_r = supabase.table(PAYMENT_TABLE).select('*').eq('booking_id', int(booking_id)).eq('transaction_id', transaction_id).order('id', desc=True).limit(1).execute()
        else:
            pay_r = supabase.table(PAYMENT_TABLE).select('*').eq('booking_id', int(booking_id)).order('id', desc=True).limit(1).execute()
        if not pay_r.data or len(pay_r.data) == 0:
            return Response({'error': 'Payment not found for this booking'}, status=status.HTTP_404_NOT_FOUND)
        payment = pay_r.data[0]
        if (payment.get('status') or '').strip().lower() == PAYMENT_STATUS_COMPLETED:
            receipt = _create_or_update_receipt_for_booking(supabase, booking_id, payment=payment)
            _award_referral_points_if_eligible(supabase, booking.get('customer_id'))
            return Response({
                'success': True,
                'booking_id': str(booking_id),
                'transaction_id': payment.get('transaction_id', ''),
                'receipt': _to_json_serializable(receipt),
            }, status=status.HTTP_200_OK)
        if (payment.get('status') or '').strip().lower() != PAYMENT_STATUS_PENDING:
            return Response({'error': 'Payment is not in pending state'}, status=status.HTTP_400_BAD_REQUEST)
        supabase.table(PAYMENT_TABLE).update({
            'status': PAYMENT_STATUS_COMPLETED,
            'ref_id': 'DEMO',
            'updated_at': datetime.now().isoformat(),
        }).eq('id', payment['id']).execute()
        supabase.table(Booking._meta.db_table).update({
            'status': BOOKING_STATUS_PAID,
            'updated_at': datetime.now().isoformat(),
        }).eq('id', booking_id).execute()
        _award_referral_points_if_eligible(supabase, booking.get('customer_id'))
        receipt = _create_or_update_receipt_for_booking(supabase, booking_id)
        _notify_provider_payment_received(supabase, booking_id)
        return Response({
            'success': True,
            'booking_id': str(booking_id),
            'transaction_id': payment.get('transaction_id', ''),
            'receipt': _to_json_serializable(receipt),
        }, status=status.HTTP_200_OK)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# --- Google Maps / Places proxy (API key stays on server) ---
def _google_maps_key():
    from django.conf import settings
    return getattr(settings, 'GOOGLE_MAPS_API_KEY', None) or ''


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def places_autocomplete(request):
    """Proxy Google Places Autocomplete. ?input=... Returns predictions with place_id and description."""
    key = _google_maps_key()
    if not key:
        return Response({'predictions': []})
    query = (request.GET.get('input') or '').strip()
    if len(query) < 2:
        return Response({'predictions': []})
    try:
        import urllib.parse
        import urllib.request
        # geocode = addresses + cities/regions (e.g. Itahari, Birtamode); components bias to Nepal
        params = {
            'input': query,
            'key': key,
            'types': 'geocode',  # addresses and place names
            'components': 'country:np',  # bias to Nepal
        }
        url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?' + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, headers={'Accept': 'application/json'})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
        status = data.get('status') or ''
        if status != 'OK' and status != 'ZERO_RESULTS':
            err_msg = data.get('error_message', status)
            return Response({
                'predictions': [],
                'error': err_msg,
                'hint': 'Enable Places API and set GOOGLE_MAPS_API_KEY in backend env.',
            })
        predictions = []
        for p in (data.get('predictions') or []):
            predictions.append({
                'place_id': p.get('place_id'),
                'description': p.get('description', ''),
            })
        return Response({'predictions': predictions})
    except Exception as e:
        return Response({'predictions': [], 'error': str(e)})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def place_details(request):
    """Proxy Google Place Details. ?place_id=... Returns formatted_address, lat, lng."""
    key = _google_maps_key()
    if not key:
        return Response({'error': 'Google Maps API key not configured'}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
    place_id = (request.GET.get('place_id') or '').strip()
    if not place_id:
        return Response({'error': 'place_id required'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        import urllib.parse
        import urllib.request
        params = {'place_id': place_id, 'fields': 'formatted_address,geometry', 'key': key}
        url = 'https://maps.googleapis.com/maps/api/place/details/json?' + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, headers={'Accept': 'application/json'})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
        result = data.get('result') or {}
        geometry = result.get('geometry') or {}
        location = geometry.get('location') or {}
        return Response({
            'formatted_address': result.get('formatted_address', ''),
            'latitude': location.get('lat'),
            'longitude': location.get('lng'),
        })
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_502_BAD_GATEWAY)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def reverse_geocode(request):
    """Proxy Google Geocoding (reverse). ?lat=...&lng=... Returns formatted_address."""
    key = _google_maps_key()
    if not key:
        return Response({'formatted_address': ''})
    try:
        lat = request.GET.get('lat')
        lng = request.GET.get('lng')
        if lat is None or lng is None:
            return Response({'formatted_address': ''}, status=status.HTTP_400_BAD_REQUEST)
        import urllib.parse
        import urllib.request
        params = {'latlng': f'{lat},{lng}', 'key': key}
        url = 'https://maps.googleapis.com/maps/api/geocode/json?' + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, headers={'Accept': 'application/json'})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
        results = data.get('results') or []
        formatted = results[0].get('formatted_address', '') if results else ''
        return Response({'formatted_address': formatted})
    except Exception as e:
        return Response({'formatted_address': '', 'error': str(e)})
