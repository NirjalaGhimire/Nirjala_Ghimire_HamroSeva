"""
Admin REST API views — JWT + IsHamroAdmin.
Reads: Django ORM (synced SQLite). Writes: Supabase helpers + throttled sync.
"""
from datetime import datetime, timezone
from decimal import Decimal

from django.db.models import Q, Sum
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from authentication.models import User
from services.admin_sync import ensure_admin_data_synced
from services.models import Booking, Payment, Review, Service, ServiceCategory

from .pagination import AdminPageNumberPagination
from .permissions import IsHamroAdmin
from . import queries
from .supabase_admin import (
    fetch_provider_verification_docs,
    supabase_delete_category,
    supabase_delete_review,
    supabase_delete_service,
    supabase_insert_notification,
    supabase_list_notifications,
    supabase_update_booking_status,
    supabase_upsert_category,
    supabase_upsert_service,
    update_provider_verification_rows,
)
from .service_requests import (
    list_requests as list_service_requests,
    review_request as review_service_request,
    parse_image_urls,
)


def _paginate(qs, request):
    paginator = AdminPageNumberPagination()
    page = paginator.paginate_queryset(qs, request)
    return paginator, page


def _provider_q():
    return Q(role='provider') | Q(role='prov')


def _decimal_str(d):
    if d is None:
        return None
    if isinstance(d, Decimal):
        return str(d)
    return str(d)


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def dashboard_overview(request):
    stats = queries.dashboard_stats()
    pulse = queries.market_pulse_score()
    trend = queries.trend_last_n_days(90)
    dist = queries.booking_status_distribution()
    total_b = stats['total_bookings'] or 1
    pipeline = []
    for row in dist:
        pipeline.append(
            {
                'status': row['status'],
                'count': row['count'],
                'percent': round(100.0 * row['count'] / total_b, 2),
            }
        )
    recent = (
        Booking.objects.select_related('customer', 'service')
        .order_by('-created_at')[:12]
    )
    recent_actions = []
    for b in recent:
        recent_actions.append(
            {
                'type': 'booking',
                'id': b.id,
                'summary': f"Booking #{b.id} — {(b.status or '').lower()}",
                'customer': getattr(b.customer, 'email', None),
                'service': getattr(b.service, 'title', None),
                'created_at': b.created_at.isoformat() if b.created_at else None,
            }
        )
    mix_total = max(
        1,
        stats['total_users'] + stats['total_bookings'] + stats['total_services'],
    )
    mix = {
        'users': stats['total_users'],
        'bookings': stats['total_bookings'],
        'services': stats['total_services'],
        'users_pct': round(100 * stats['total_users'] / mix_total, 2),
        'bookings_pct': round(100 * stats['total_bookings'] / mix_total, 2),
        'services_pct': round(100 * stats['total_services'] / mix_total, 2),
    }
    return Response(
        {
            'stats': stats,
            'market_pulse': pulse,
            'trend_7d': trend,
            'pipeline': pipeline,
            'mix': mix,
            'recent_actions': recent_actions,
        }
    )


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def reports_charts(request):
    months = int(request.query_params.get('months', '12'))
    months = max(1, min(months, 36))
    return Response(
        {
            'bookings_by_month': queries.bookings_by_month(months),
            'revenue_by_month': queries.revenue_by_month(months),
            'provider_verification': queries.provider_verification_by_status(),
            'booking_status_distribution': queries.booking_status_distribution(),
        }
    )


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_users(request):
    if request.method == 'GET':
        qs = User.objects.all().order_by('-date_joined')
        role = (request.query_params.get('role') or '').strip().lower()
        if role:
            qs = qs.filter(role=role)
        active = request.query_params.get('is_active')
        if active in ('true', '1', 'yes'):
            qs = qs.filter(is_active=True)
        elif active in ('false', '0', 'no'):
            qs = qs.filter(is_active=False)
        q = (request.query_params.get('search') or '').strip()
        if q:
            qs = qs.filter(
                Q(email__icontains=q)
                | Q(username__icontains=q)
                | Q(phone__icontains=q)
            )
        paginator, page = _paginate(qs, request)
        data = [
            {
                'id': u.id,
                'email': u.email,
                'username': u.username,
                'phone': u.phone,
                'role': u.role,
                'is_active': u.is_active,
                'is_verified': u.is_verified,
                'date_joined': u.date_joined.isoformat() if u.date_joined else None,
                'created_at': u.created_at.isoformat() if getattr(u, 'created_at', None) else None,
            }
            for u in page
        ]
        return paginator.get_paginated_response(data)


@api_view(['GET', 'PATCH', 'DELETE'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_user_detail(request, user_id):
    u = User.objects.filter(id=user_id).first()
    if not u:
        return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        return Response(
            {
                'id': u.id,
                'email': u.email,
                'username': u.username,
                'phone': u.phone,
                'role': u.role,
                'first_name': u.first_name,
                'last_name': u.last_name,
                'is_active': u.is_active,
                'is_staff': u.is_staff,
                'is_verified': u.is_verified,
                'verification_status': u.verification_status,
                'district': getattr(u, 'district', None),
                'city': getattr(u, 'city', None),
                'profession': u.profession,
                'date_joined': u.date_joined.isoformat() if u.date_joined else None,
                'created_at': u.created_at.isoformat() if getattr(u, 'created_at', None) else None,
            }
        )

    if request.method == 'PATCH':
        if 'is_active' in request.data:
            u.is_active = bool(request.data['is_active'])
        if 'is_staff' in request.data and request.user.is_superuser:
            u.is_staff = bool(request.data['is_staff'])
        u.save()
        ensure_admin_data_synced()
        return Response({'detail': 'updated', 'id': u.id})

    # DELETE → deactivate (safer than hard delete)
    u.is_active = False
    u.save()
    ensure_admin_data_synced()
    return Response({'detail': 'deactivated', 'id': u.id}, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_providers(request):
    qs = User.objects.filter(_provider_q()).order_by('-date_joined')
    q = (request.query_params.get('search') or '').strip()
    if q:
        qs = qs.filter(
            Q(email__icontains=q) | Q(username__icontains=q) | Q(phone__icontains=q)
        )
    vstat = (request.query_params.get('verification_status') or '').strip().lower()
    if vstat:
        qs = qs.filter(verification_status=vstat)
    paginator, page = _paginate(qs, request)
    data = []
    for u in page:
        data.append(
            {
                'id': u.id,
                'email': u.email,
                'username': u.username,
                'phone': u.phone,
                'verification_status': u.verification_status,
                'is_verified': u.is_verified,
                'is_active_provider': getattr(u, 'is_active_provider', None),
                'submitted_at': u.submitted_at,
                'reviewed_at': u.reviewed_at,
                'date_joined': u.date_joined.isoformat() if u.date_joined else None,
            }
        )
    return paginator.get_paginated_response(data)


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_provider_detail(request, provider_id):
    u = User.objects.filter(id=provider_id).filter(_provider_q()).first()
    if not u:
        return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
    docs = []
    try:
        r = fetch_provider_verification_docs(provider_id)
        docs = r.data or []
    except Exception as exc:
        docs = [{'error': str(exc)}]
    services = Service.objects.filter(provider_id=provider_id).select_related('category')
    bookings = Booking.objects.filter(service__provider_id=provider_id).select_related(
        'customer', 'service'
    ).order_by('-created_at')[:50]
    reviews = Review.objects.filter(provider_id=provider_id).select_related('customer')[:50]
    return Response(
        {
            'user': {
                'id': u.id,
                'email': u.email,
                'username': u.username,
                'phone': u.phone,
                'verification_status': u.verification_status,
                'is_verified': u.is_verified,
                'rejection_reason': u.rejection_reason,
                'district': u.district,
                'city': u.city,
                'profession': u.profession,
            },
            'verification_documents': docs,
            'services': [
                {
                    'id': s.id,
                    'title': s.title,
                    'category': s.category.name if s.category else None,
                    'status': s.status,
                    'price': _decimal_str(s.price),
                }
                for s in services
            ],
            'recent_bookings': [
                {
                    'id': b.id,
                    'status': b.status,
                    'customer_email': getattr(b.customer, 'email', None),
                    'service_title': getattr(b.service, 'title', None),
                    'booking_date': str(b.booking_date),
                    'total_amount': _decimal_str(b.total_amount),
                }
                for b in bookings
            ],
            'recent_reviews': [
                {
                    'id': r.id,
                    'rating': r.rating,
                    'comment': r.comment,
                    'customer_email': getattr(r.customer, 'email', None),
                    'created_at': r.created_at.isoformat() if r.created_at else None,
                }
                for r in reviews
            ],
        }
    )


@api_view(['POST'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_provider_verification(request, provider_id):
    u = User.objects.filter(id=provider_id).filter(_provider_q()).first()
    if not u:
        return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
    action = (request.data.get('action') or '').strip().lower()
    if action not in ('approve', 'reject'):
        return Response(
            {'detail': 'action must be approve or reject'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    now_iso = datetime.now(timezone.utc).isoformat()
    if action == 'approve':
        u.verification_status = User.VERIFICATION_STATUS_APPROVED
        u.is_verified = True
        u.is_active_provider = True
        u.rejection_reason = None
    else:
        u.verification_status = User.VERIFICATION_STATUS_REJECTED
        u.is_verified = False
        u.rejection_reason = (request.data.get('rejection_reason') or '').strip() or None
    u.reviewed_by = request.user.id
    u.reviewed_at = now_iso
    u.save()
    try:
        update_provider_verification_rows(
            provider_id,
            'approved' if action == 'approve' else 'rejected',
            request.user.id,
            rejection_reason=u.rejection_reason,
        )
    except Exception as exc:
        return Response({'detail': str(exc)}, status=status.HTTP_502_BAD_GATEWAY)
    ensure_admin_data_synced()
    return Response({'detail': 'ok', 'verification_status': u.verification_status})


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_customers(request):
    qs = User.objects.filter(role='customer').order_by('-date_joined')
    q = (request.query_params.get('search') or '').strip()
    if q:
        qs = qs.filter(
            Q(email__icontains=q) | Q(username__icontains=q) | Q(phone__icontains=q)
        )
    paginator, page = _paginate(qs, request)
    data = [
        {
            'id': u.id,
            'email': u.email,
            'username': u.username,
            'phone': u.phone,
            'is_active': u.is_active,
            'date_joined': u.date_joined.isoformat() if u.date_joined else None,
        }
        for u in page
    ]
    return paginator.get_paginated_response(data)


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_customer_detail(request, customer_id):
    u = User.objects.filter(id=customer_id, role='customer').first()
    if not u:
        return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
    bookings = (
        Booking.objects.filter(customer_id=customer_id)
        .select_related('service', 'service__provider')
        .order_by('-created_at')
    )
    paginator, page = _paginate(bookings, request)
    bdata = [
        {
            'id': b.id,
            'status': b.status,
            'service_title': getattr(b.service, 'title', None),
            'provider_email': getattr(b.service.provider, 'email', None)
            if b.service
            else None,
            'booking_date': str(b.booking_date),
            'total_amount': _decimal_str(b.total_amount),
            'created_at': b.created_at.isoformat() if b.created_at else None,
        }
        for b in page
    ]
    resp = paginator.get_paginated_response(bdata)
    resp.data['customer'] = {
        'id': u.id,
        'email': u.email,
        'username': u.username,
        'phone': u.phone,
        'district': u.district,
        'city': u.city,
        'is_active': u.is_active,
    }
    return resp


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_bookings(request):
    qs = Booking.objects.select_related('customer', 'service', 'service__provider').order_by(
        '-created_at'
    )
    st = (request.query_params.get('status') or '').strip().lower()
    if st:
        qs = qs.filter(status__iexact=st)
    q = (request.query_params.get('search') or '').strip()
    if q:
        q_filter = Q(customer__email__icontains=q) | Q(service__title__icontains=q)
        if q.isdigit():
            q_filter |= Q(id=int(q))
        qs = qs.filter(q_filter)
    paginator, page = _paginate(qs, request)
    rows = []
    for b in page:
        pay = (
            Payment.objects.filter(booking_id=b.id)
            .order_by('-created_at')
            .first()
        )
        rows.append(
            {
                'id': b.id,
                'status': b.status,
                'booking_date': str(b.booking_date),
                'booking_time': str(b.booking_time),
                'total_amount': _decimal_str(b.total_amount),
                'quoted_price': _decimal_str(b.quoted_price),
                'customer_email': getattr(b.customer, 'email', None),
                'provider_email': getattr(b.service.provider, 'email', None)
                if b.service
                else None,
                'service_title': getattr(b.service, 'title', None),
                'payment_status': pay.status if pay else None,
                'payment_amount': _decimal_str(pay.amount) if pay else None,
                'created_at': b.created_at.isoformat() if b.created_at else None,
            }
        )
    return paginator.get_paginated_response(rows)


@api_view(['GET', 'PATCH'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_booking_detail(request, booking_id):
    b = (
        Booking.objects.select_related('customer', 'service', 'service__provider')
        .filter(id=booking_id)
        .first()
    )
    if not b:
        return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
    if request.method == 'GET':
        payments = Payment.objects.filter(booking_id=booking_id).order_by('-created_at')
        return Response(
            {
                'id': b.id,
                'status': b.status,
                'notes': b.notes,
                'address': b.address,
                'booking_date': str(b.booking_date),
                'booking_time': str(b.booking_time),
                'total_amount': _decimal_str(b.total_amount),
                'quoted_price': _decimal_str(b.quoted_price),
                'request_image_url': b.request_image_url,
                'customer': {
                    'id': b.customer_id,
                    'email': getattr(b.customer, 'email', None),
                },
                'service': {
                    'id': b.service_id,
                    'title': getattr(b.service, 'title', None),
                    'provider_id': b.service.provider_id if b.service else None,
                    'provider_email': getattr(b.service.provider, 'email', None)
                    if b.service
                    else None,
                },
                'payments': [
                    {
                        'id': p.id,
                        'amount': _decimal_str(p.amount),
                        'status': p.status,
                        'payment_method': p.payment_method,
                        'transaction_id': p.transaction_id,
                        'created_at': p.created_at.isoformat() if p.created_at else None,
                    }
                    for p in payments
                ],
                'created_at': b.created_at.isoformat() if b.created_at else None,
            }
        )

    new_status = (request.data.get('status') or '').strip().lower()
    if not new_status:
        return Response({'detail': 'status required'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        supabase_update_booking_status(booking_id, new_status)
    except Exception as exc:
        return Response({'detail': str(exc)}, status=status.HTTP_502_BAD_GATEWAY)
    ensure_admin_data_synced()
    return Response({'detail': 'updated', 'id': booking_id, 'status': new_status})


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_pending(request):
    booking_requests = (
        Booking.objects.filter(status__in=['pending', 'quoted', 'awaiting_payment'])
        .select_related('customer', 'service', 'service__provider')
        .order_by('-created_at')[:100]
    )
    verifications = (
        User.objects.filter(_provider_q(), verification_status='pending')
        .order_by('-submitted_at')[:100]
    )
    return Response(
        {
            'pending_booking_requests': [
                {
                    'id': b.id,
                    'status': b.status,
                    'customer_email': getattr(b.customer, 'email', None),
                    'provider_email': getattr(b.service.provider, 'email', None)
                    if b.service
                    else None,
                    'service_title': getattr(b.service, 'title', None),
                    'created_at': b.created_at.isoformat() if b.created_at else None,
                }
                for b in booking_requests
            ],
            'pending_provider_verifications': [
                {
                    'id': u.id,
                    'email': u.email,
                    'username': u.username,
                    'submitted_at': u.submitted_at,
                }
                for u in verifications
            ],
            'pending_service_category_requests': [
                {
                    'id': r.get('id'),
                    'customer_id': r.get('customer_id'),
                    'requested_title': r.get('requested_title'),
                    'status': r.get('status'),
                    'created_at': r.get('created_at'),
                    'storage': r.get('storage'),
                }
                for r in list_service_requests(status_filter='pending', limit=100)
            ],
        }
    )


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_service_category_requests(request):
    status_filter = (request.query_params.get('status') or '').strip().lower() or None
    if status_filter and status_filter not in {'pending', 'approved', 'rejected'}:
        return Response({'detail': 'invalid status filter'}, status=status.HTTP_400_BAD_REQUEST)

    rows = list_service_requests(status_filter=status_filter, limit=300)
    customer_ids = set()
    for row in rows:
        cid = row.get('customer_id')
        if cid is not None:
            try:
                customer_ids.add(int(cid))
            except (TypeError, ValueError):
                pass
    users = {
        u.id: u
        for u in User.objects.filter(id__in=list(customer_ids)).only(
            'id', 'email', 'username', 'phone'
        )
    }

    out = []
    for row in rows:
        cid = row.get('customer_id')
        try:
            cid_int = int(cid) if cid is not None else None
        except (TypeError, ValueError):
            cid_int = None
        cu = users.get(cid_int) if cid_int is not None else None
        out.append(
            {
                'id': row.get('id'),
                'customer_id': cid_int,
                'customer_email': getattr(cu, 'email', None),
                'customer_username': getattr(cu, 'username', None),
                'requested_title': row.get('requested_title'),
                'description': row.get('description'),
                'address': row.get('address'),
                'latitude': row.get('latitude'),
                'longitude': row.get('longitude'),
                'image_urls': parse_image_urls(row.get('image_urls')),
                'status': row.get('status') or 'pending',
                'admin_review_note': row.get('admin_review_note'),
                'reviewed_by': row.get('reviewed_by'),
                'reviewed_at': row.get('reviewed_at'),
                'created_at': row.get('created_at'),
                'storage': row.get('storage') or 'supabase',
            }
        )
    return Response({'count': len(out), 'results': out})


@api_view(['PATCH'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_service_category_request_review(request, request_id):
    new_status = (request.data.get('status') or '').strip().lower()
    admin_note = (request.data.get('admin_note') or '').strip()
    if new_status not in {'approved', 'rejected'}:
        return Response(
            {'detail': 'status must be approved or rejected'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        updated = review_service_request(
            request_id=request_id,
            new_status=new_status,
            reviewed_by=request.user.id,
            admin_note=admin_note or None,
        )
    except ValueError as exc:
        return Response({'detail': str(exc)}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as exc:
        return Response({'detail': str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

    if not updated:
        return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)

    # Notify customer about review result when possible.
    customer_id = updated.get('customer_id')
    try:
        if customer_id is not None:
            title = 'Service request reviewed'
            body = f'Your request "{updated.get("requested_title") or "service"}" was {new_status}.'
            if admin_note:
                body += f' Note: {admin_note[:400]}'
            supabase_insert_notification(customer_id, title, body)
    except Exception:
        pass

    return Response({'detail': 'updated', 'result': updated})


@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_services(request):
    if request.method == 'GET':
        qs = Service.objects.select_related('provider', 'category').order_by('-created_at')
        cat = request.query_params.get('category_id')
        if cat:
            qs = qs.filter(category_id=cat)
        pid = request.query_params.get('provider_id')
        if pid:
            qs = qs.filter(provider_id=pid)
        q = (request.query_params.get('search') or '').strip()
        if q:
            qs = qs.filter(Q(title__icontains=q) | Q(description__icontains=q))
        paginator, page = _paginate(qs, request)
        data = [
            {
                'id': s.id,
                'title': s.title,
                'description': s.description,
                'price': _decimal_str(s.price),
                'duration_minutes': s.duration_minutes,
                'location': s.location,
                'status': s.status,
                'image_url': s.image_url,
                'provider_id': s.provider_id,
                'provider_email': getattr(s.provider, 'email', None),
                'category_id': s.category_id,
                'category_name': s.category.name if s.category else None,
                'created_at': s.created_at.isoformat() if s.created_at else None,
            }
            for s in page
        ]
        return paginator.get_paginated_response(data)

    if request.method == 'POST':
        try:
            payload = {
                'provider_id': int(request.data['provider_id']),
                'category_id': int(request.data['category_id']),
                'title': request.data['title'],
                'description': request.data.get('description') or '',
                'price': str(request.data['price']),
                'duration_minutes': int(request.data.get('duration_minutes') or 60),
                'location': request.data.get('location') or '',
                'status': request.data.get('status') or 'active',
                'image_url': request.data.get('image_url') or '',
            }
        except (KeyError, TypeError, ValueError) as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        try:
            supabase_upsert_service(payload)
        except Exception as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_502_BAD_GATEWAY)
        ensure_admin_data_synced()
        return Response({'detail': 'created'}, status=status.HTTP_201_CREATED)


@api_view(['GET', 'PATCH', 'DELETE'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_service_detail(request, service_id):
    s = Service.objects.filter(id=service_id).select_related('provider', 'category').first()
    if request.method == 'GET':
        if not s:
            return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
        return Response(
            {
                'id': s.id,
                'title': s.title,
                'description': s.description,
                'price': _decimal_str(s.price),
                'duration_minutes': s.duration_minutes,
                'location': s.location,
                'status': s.status,
                'image_url': s.image_url,
                'provider_id': s.provider_id,
                'category_id': s.category_id,
            }
        )

    if request.method == 'PATCH':
        if not s:
            return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
        payload = {}
        for key in (
            'title',
            'description',
            'price',
            'duration_minutes',
            'location',
            'status',
            'image_url',
            'category_id',
            'provider_id',
        ):
            if key in request.data:
                val = request.data[key]
                if key in ('duration_minutes', 'category_id', 'provider_id') and val is not None:
                    val = int(val)
                if key == 'price' and val is not None:
                    val = str(val)
                payload[key] = val
        if not payload:
            return Response({'detail': 'No fields'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            supabase_upsert_service(payload, service_id=service_id)
        except Exception as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_502_BAD_GATEWAY)
        ensure_admin_data_synced()
        return Response({'detail': 'updated'})

    if not s:
        return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
    try:
        supabase_delete_service(service_id)
    except Exception as exc:
        return Response({'detail': str(exc)}, status=status.HTTP_502_BAD_GATEWAY)
    ensure_admin_data_synced()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_categories(request):
    if request.method == 'GET':
        qs = ServiceCategory.objects.all().order_by('name')
        q = (request.query_params.get('search') or '').strip()
        if q:
            qs = qs.filter(Q(name__icontains=q) | Q(description__icontains=q))
        paginator, page = _paginate(qs, request)
        data = [
            {
                'id': c.id,
                'name': c.name,
                'description': c.description,
                'icon': c.icon,
                'created_at': c.created_at.isoformat() if c.created_at else None,
            }
            for c in page
        ]
        return paginator.get_paginated_response(data)

    name = (request.data.get('name') or '').strip()
    if not name:
        return Response({'detail': 'name required'}, status=status.HTTP_400_BAD_REQUEST)
    payload = {
        'name': name,
        'description': request.data.get('description') or '',
        'icon': request.data.get('icon') or '',
    }
    try:
        supabase_upsert_category(payload)
    except Exception as exc:
        return Response({'detail': str(exc)}, status=status.HTTP_502_BAD_GATEWAY)
    ensure_admin_data_synced()
    return Response({'detail': 'created'}, status=status.HTTP_201_CREATED)


@api_view(['GET', 'PATCH', 'DELETE'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_category_detail(request, category_id):
    c = ServiceCategory.objects.filter(id=category_id).first()
    if request.method == 'GET':
        if not c:
            return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
        return Response(
            {
                'id': c.id,
                'name': c.name,
                'description': c.description,
                'icon': c.icon,
            }
        )

    if request.method == 'PATCH':
        if not c:
            return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
        payload = {}
        if 'name' in request.data:
            payload['name'] = request.data['name']
        if 'description' in request.data:
            payload['description'] = request.data['description']
        if 'icon' in request.data:
            payload['icon'] = request.data['icon']
        if not payload:
            return Response({'detail': 'No fields'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            supabase_upsert_category(payload, category_id=category_id)
        except Exception as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_502_BAD_GATEWAY)
        ensure_admin_data_synced()
        return Response({'detail': 'updated'})

    if not c:
        return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
    if Service.objects.filter(category_id=category_id).exists():
        return Response(
            {'detail': 'Category has services; reassign or delete services first.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    try:
        supabase_delete_category(category_id)
    except Exception as exc:
        return Response({'detail': str(exc)}, status=status.HTTP_502_BAD_GATEWAY)
    ensure_admin_data_synced()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_payments(request):
    qs = Payment.objects.select_related('customer', 'provider', 'booking').order_by(
        '-created_at'
    )
    st = (request.query_params.get('status') or '').strip().lower()
    if st:
        qs = qs.filter(status__iexact=st)
    df = request.query_params.get('from_date')
    dt = request.query_params.get('to_date')
    if df:
        qs = qs.filter(created_at__date__gte=df)
    if dt:
        qs = qs.filter(created_at__date__lte=dt)
    q = (request.query_params.get('search') or '').strip()
    if q:
        qs = qs.filter(
            Q(customer__email__icontains=q)
            | Q(transaction_id__icontains=q)
            | Q(booking_id__iexact=q)
        )
    summary = (
        qs.filter(status__in=['completed', 'paid', 'success']).aggregate(total=Sum('amount'))['total']
        or Decimal('0')
    )
    paginator, page = _paginate(qs, request)
    rows = [
        {
            'id': p.id,
            'booking_id': p.booking_id,
            'amount': _decimal_str(p.amount),
            'status': p.status,
            'payment_method': p.payment_method,
            'transaction_id': p.transaction_id,
            'customer_email': getattr(p.customer, 'email', None),
            'provider_email': getattr(p.provider, 'email', None) if p.provider else None,
            'created_at': p.created_at.isoformat() if p.created_at else None,
        }
        for p in page
    ]
    resp = paginator.get_paginated_response(rows)
    resp.data['revenue_summary'] = {'completed_total': str(summary)}
    return resp


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_reviews(request):
    qs = Review.objects.select_related('customer', 'provider', 'booking').order_by(
        '-created_at'
    )
    q = (request.query_params.get('search') or '').strip()
    if q:
        qs = qs.filter(
            Q(customer__email__icontains=q)
            | Q(provider__email__icontains=q)
            | Q(comment__icontains=q)
        )
    paginator, page = _paginate(qs, request)
    data = [
        {
            'id': r.id,
            'rating': r.rating,
            'comment': r.comment,
            'customer_email': getattr(r.customer, 'email', None),
            'provider_email': getattr(r.provider, 'email', None),
            'booking_id': r.booking_id,
            'created_at': r.created_at.isoformat() if r.created_at else None,
        }
        for r in page
    ]
    return paginator.get_paginated_response(data)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_review_detail(request, review_id):
    if not Review.objects.filter(id=review_id).exists():
        return Response({'detail': 'Not found'}, status=status.HTTP_404_NOT_FOUND)
    try:
        supabase_delete_review(int(review_id))
    except Exception as exc:
        return Response({'detail': str(exc)}, status=status.HTTP_502_BAD_GATEWAY)
    ensure_admin_data_synced()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_notifications(request):
    if request.method == 'GET':
        try:
            limit = int(request.query_params.get('limit', '100'))
        except ValueError:
            limit = 100
        limit = max(1, min(limit, 500))
        try:
            offset = int(request.query_params.get('offset', '0'))
        except ValueError:
            offset = 0
        try:
            r = supabase_list_notifications(limit=limit, offset=offset)
            rows = r.data or []
        except Exception as exc:
            return Response({'detail': str(exc), 'results': []}, status=status.HTTP_200_OK)
        return Response({'count': len(rows), 'results': rows})

    uid = request.data.get('user_id')
    title = (request.data.get('title') or '').strip()
    body = (request.data.get('body') or '').strip()
    if uid is None or not title:
        return Response(
            {'detail': 'user_id and title required'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    try:
        supabase_insert_notification(
            int(uid),
            title,
            body,
            booking_id=request.data.get('booking_id'),
        )
    except Exception as exc:
        return Response({'detail': str(exc)}, status=status.HTTP_502_BAD_GATEWAY)
    return Response({'detail': 'sent'}, status=status.HTTP_201_CREATED)


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsHamroAdmin])
def admin_settings(request):
    return Response(
        {
            'project': 'Hamro Sewa',
            'admin_panel': 'Use JWT from /api/auth/login/ with an admin account.',
            'sync': 'Data lists use SQLite synced from Supabase; mutations refresh via sync.',
        }
    )
