from datetime import date, time, datetime
from decimal import Decimal

from django.shortcuts import render
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework import status
from .models import ServiceCategory, Service, Booking, Review
from .serializers import (
    ServiceCategorySerializer, ServiceSerializer, BookingSerializer,
    CreateBookingSerializer, ReviewSerializer, DashboardStatsSerializer,
)
from authentication.models import User
from authentication.serializers import UserProfileSerializer as AuthUserProfileSerializer
from supabase_config import get_supabase_client


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
    return Response(serializer.data)


@api_view(['PATCH', 'PUT'])
@permission_classes([IsAuthenticated])
def user_profile_update(request):
    """Update current user profile in Supabase (username, email, phone, profession)."""
    user = request.user
    data = request.data
    if not isinstance(data, dict):
        return Response({'error': 'Invalid body'}, status=status.HTTP_400_BAD_REQUEST)
    updates = {}
    for key in ('username', 'email', 'phone', 'profession'):
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
        supabase.table('seva_auth_user').update(updates).eq('id', user.id).execute()
        updated = User.objects.get(id=user.id)
        serializer = AuthUserProfileSerializer(updated)
        return Response(serializer.data)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET'])
@permission_classes([AllowAny])
def service_categories(request):
    """Get all service categories (public so Choose provider can load)."""
    # Try to get from Supabase first
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
    """List all providers (id, username, profession) for registration dropdown etc."""
    try:
        supabase = get_supabase_client()
        # Fetch all users with role; DB may use 'prov' or 'provider'
        r = supabase.table('seva_auth_user').select('id,username,profession,role').execute()
        data = list(r.data) if r.data else []
        provider_roles = ('prov', 'provider')
        providers = [p for p in data if (p.get('role') or '').strip().lower() in provider_roles]
        out = [{'id': p.get('id'), 'username': p.get('username') or '', 'profession': (p.get('profession') or '').strip()} for p in providers]
        return Response(out)
    except Exception as e:
        print(f"Error fetching providers: {e}")
        return Response([])


def _enrich_services_with_category_and_provider_names(services):
    """Add category_name, provider_name, and provider_profession to each service."""
    if not services:
        return services
    try:
        supabase = get_supabase_client()
        categories = supabase.table(ServiceCategory._meta.db_table).select('id,name').execute()
        category_map = {c['id']: c.get('name') or '' for c in (categories.data or [])}
        provider_ids = list({s.get('provider_id') for s in services if s.get('provider_id') is not None})
        provider_map = {}  # pid -> {'username': ..., 'profession': ...}
        if provider_ids:
            for pid in provider_ids:
                r = supabase.table('seva_auth_user').select('id,username,profession').eq('id', pid).execute()
                if r.data and len(r.data) > 0:
                    row = r.data[0]
                    provider_map[pid] = {
                        'name': row.get('username') or row.get('email') or 'Provider',
                        'profession': (row.get('profession') or '').strip(),
                    }
        for s in services:
            s['category_name'] = category_map.get(s.get('category_id')) or s.get('category_name') or ''
            info = provider_map.get(s.get('provider_id')) or {}
            s['provider_name'] = info.get('name') or s.get('provider_name') or 'Provider'
            s['provider_profession'] = info.get('profession') or ''
    except Exception as e:
        print(f"Enrich services warning: {e}")
    return services


def _provider_profession_matches_service(provider_profession, service_title):
    """Return True only if provider's profession matches the service (e.g. Radha Electrician not for Decorator)."""
    pro = (provider_profession or '').lower().strip()
    svc = (service_title or '').lower().strip()
    if not pro or not svc:
        return False
    if pro in svc or svc in pro:
        return True
    for word in pro.replace('-', ' ').split():
        if len(word) >= 4 and word in svc:
            return True
    for word in svc.replace('-', ' ').split():
        if len(word) >= 4 and word in pro:
            return True
    return False


def _provider_profession_matches_category(provider_profession, category_name):
    """Return True if provider's profession fits the category (so plumber is not shown under Education)."""
    pro = (provider_profession or '').lower()
    cat = (category_name or '').lower()
    if not cat:
        return True
    # Education / Tutoring: only tutor, education, math
    if 'education' in cat or 'tutor' in cat:
        return any(x in pro for x in ('tutor', 'education', 'math', 'teaching', 'teacher'))
    # Plumbing
    if 'plumb' in cat:
        return 'plumb' in pro
    # Electrical
    if 'electric' in cat:
        return 'electric' in pro
    # Cleaning
    if 'clean' in cat or 'home service' in cat:
        return any(x in pro for x in ('clean', 'plumb', 'electric', 'carpenter', 'handyman', 'home'))
    # Beauty / Salon
    if 'beauty' in cat or 'wellness' in cat or 'salon' in cat:
        return any(x in pro for x in ('beauty', 'salon', 'massage', 'hair', 'wellness'))
    # Technology
    if 'tech' in cat:
        return any(x in pro for x in ('tech', 'computer', 'developer', 'web', 'it'))
    # Carpenter
    if 'carpent' in cat:
        return 'carpent' in pro
    # Default: allow if profession is set and category doesn't have a strict rule
    return True


def _get_services_raw_from_supabase(category_id=None, provider_id=None):
    """
    Fetch services from Supabase as raw dicts (no Django serializer).
    Supabase returns provider_id/category_id; ServiceSerializer expects provider/category objects
    and would raise KeyError. So we use raw fetch + enrichment only.
    """
    supabase = get_supabase_client()
    table_name = Service._meta.db_table
    try:
        query = supabase.table(table_name).select('*')
        if category_id is not None:
            query = query.eq('category_id', category_id)
        if provider_id is not None:
            query = query.eq('provider_id', provider_id)
        response = query.execute()
        data = list(response.data) if response.data else []
        return _enrich_services_with_category_and_provider_names(data)
    except Exception as e:
        print(f"Error fetching {table_name} (raw): {e}")
        return []


def _get_bookings_raw_from_supabase(customer_id=None, service_id=None, service_ids=None):
    """Fetch bookings from Supabase as raw dicts (no serializer)."""
    supabase = get_supabase_client()
    table_name = Booking._meta.db_table
    try:
        if service_ids is not None:
            # Fetch per service_id to avoid .in_() API differences
            out = []
            for sid in service_ids:
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
        customer_ids = list({b.get('customer_id') for b in bookings if b.get('customer_id') is not None})
        service_ids = list({b.get('service_id') for b in bookings if b.get('service_id') is not None})
        customer_map = {}
        for cid in customer_ids:
            r = supabase.table('seva_auth_user').select('id,username').eq('id', cid).execute()
            if r.data and r.data[0]:
                customer_map[cid] = r.data[0].get('username') or r.data[0].get('email') or 'Customer'
        service_map = {}  # service_id -> {title, provider_id}
        for sid in service_ids:
            r = supabase.table(Service._meta.db_table).select('id,title,provider_id').eq('id', sid).execute()
            if r.data and r.data[0]:
                service_map[sid] = r.data[0]
        provider_map = {}
        for s in service_map.values():
            pid = s.get('provider_id')
            if pid and pid not in provider_map:
                r = supabase.table('seva_auth_user').select('id,username,email,phone').eq('id', pid).execute()
                if r.data and r.data[0]:
                    row = r.data[0]
                    provider_map[pid] = {
                        'name': row.get('username') or row.get('email') or 'Provider',
                        'email': row.get('email') or '',
                        'phone': row.get('phone') or '',
                    }
        for b in bookings:
            b['customer_name'] = customer_map.get(b.get('customer_id')) or 'Customer'
            svc = service_map.get(b.get('service_id')) or {}
            b['service_title'] = svc.get('title') or f"Service #{b.get('service_id')}"
            prov = provider_map.get(svc.get('provider_id')) or {}
            b['provider_name'] = prov.get('name', 'Provider') if isinstance(prov, dict) else 'Provider'
            b['provider_email'] = prov.get('email', '') if isinstance(prov, dict) else ''
            b['provider_phone'] = prov.get('phone', '') if isinstance(prov, dict) else ''
    except Exception as e:
        print(f"Enrich bookings warning: {e}")
    return bookings


@api_view(['GET'])
@permission_classes([AllowAny])
def services_list(request):
    """Get all services with optional filtering (public so Choose provider can load)."""
    category_id = request.query_params.get('category')
    provider_id = request.query_params.get('provider')
    for_signup = request.query_params.get('for_signup', '').lower() in ('1', 'true', 'yes')

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

    # Fetch from Supabase as raw dicts (no serializer – DB has provider_id/category_id, not provider/category)
    services = _get_services_raw_from_supabase(category_id=cid, provider_id=pid)
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
            filtered = [s for s in services if _provider_profession_matches_category(
                s.get('provider_profession'), category_name)]
            if filtered:
                services = filtered
        # Only show providers whose profession matches the service (e.g. Radha Electrician not for Decorator)
        services = [s for s in services if _provider_profession_matches_service(
            s.get('provider_profession'), s.get('title'))]
    if services:
        print(f"✅ Found {len(services)} services from Supabase")
        return Response(services)
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
                    filtered = [s for s in services if _provider_profession_matches_category(
                        s.get('provider_profession'), category_name)]
                    if filtered:
                        services = filtered
                services = [s for s in services if _provider_profession_matches_service(
                    s.get('provider_profession'), s.get('title'))]
                print(f"✅ Found {len(services)} services from Supabase (category {cid})")
                return Response(services)
    print("⚠️ No services found in Supabase")
    return Response([])

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
        if 'total_amount' not in booking_data or booking_data['total_amount'] is None:
            booking_data['total_amount'] = 0
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

        supabase = get_supabase_client()
        table_name = Booking._meta.db_table
        response = supabase.table(table_name).insert(booking_data).execute()
        if response.data:
            created = response.data[0]
            return Response(_to_json_serializable(created), status=status.HTTP_201_CREATED)
        return Response({'error': 'Failed to create booking'}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        # Always return JSON so the app never sees HTML error pages
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

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_review(request):
    """Create a review for a completed booking"""
    booking_id = request.data.get('booking_id')
    rating = request.data.get('rating')
    comment = request.data.get('comment', '')
    
    if not booking_id or not rating:
        return Response({'error': 'booking_id and rating are required'}, status=status.HTTP_400_BAD_REQUEST)
    
    # Get booking (raw) and service provider_id; ensure one review per booking
    try:
        supabase = get_supabase_client()
        existing = supabase.table('seva_review').select('id').eq('booking_id', booking_id).execute()
        if existing.data and len(existing.data) > 0:
            return Response({'error': 'You have already reviewed this booking'}, status=status.HTTP_400_BAD_REQUEST)
        r = supabase.table(Booking._meta.db_table).select('*').eq('id', booking_id).execute()
        if not r.data or len(r.data) == 0:
            return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)
        booking = r.data[0]
        if booking['customer_id'] != request.user.id or booking.get('status') != 'completed':
            return Response({'error': 'Invalid booking or booking not completed'}, status=status.HTTP_400_BAD_REQUEST)
        svc_r = supabase.table(Service._meta.db_table).select('provider_id').eq('id', booking['service_id']).execute()
        provider_id = svc_r.data[0]['provider_id'] if svc_r.data and svc_r.data[0] else None
        if not provider_id:
            return Response({'error': 'Service not found'}, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    review_data = {
        'booking_id': booking_id,
        'customer_id': request.user.id,
        'provider_id': provider_id,
        'rating': rating,
        'comment': comment
    }
    
    review = SupabaseManager.create(Review, ReviewSerializer, review_data)
    if review:
        return Response(review, status=status.HTTP_201_CREATED)
    return Response({'error': 'Failed to create review'}, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def my_reviews(request):
    """List reviews written by the current customer (for My Reviews screen)."""
    try:
        supabase = get_supabase_client()
        r = supabase.table('seva_review').select('*').eq('customer_id', request.user.id).order('created_at', desc=True).execute()
        out = []
        for row in (r.data or []):
            booking_id = row.get('booking_id')
            service_title = 'Service'
            provider_name = 'Provider'
            if booking_id:
                br = supabase.table(Booking._meta.db_table).select('service_id').eq('id', booking_id).execute()
                if br.data and br.data[0]:
                    sid = br.data[0].get('service_id')
                    sr = supabase.table(Service._meta.db_table).select('title,provider_id').eq('id', sid).execute()
                    if sr.data and sr.data[0]:
                        service_title = sr.data[0].get('title') or service_title
                        pid = sr.data[0].get('provider_id')
                        if pid:
                            pr = supabase.table('seva_auth_user').select('username').eq('id', pid).execute()
                            if pr.data and pr.data[0]:
                                provider_name = pr.data[0].get('username') or pr.data[0].get('email') or provider_name
            out.append({
                'id': row.get('id'),
                'service': service_title,
                'provider': provider_name,
                'rating': row.get('rating'),
                'comment': row.get('comment') or '',
                'date': _to_json_serializable(row.get('created_at')),
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
        r = supabase.table('seva_review').select('*').eq('provider_id', request.user.id).order('created_at', desc=True).limit(100).execute()
        out = []
        for row in (r.data or []):
            booking_id = row.get('booking_id')
            service_title = 'Service'
            customer_name = 'Customer'
            if booking_id:
                br = supabase.table(Booking._meta.db_table).select('service_id,customer_id').eq('id', booking_id).execute()
                if br.data and br.data[0]:
                    sid = br.data[0].get('service_id')
                    cid = br.data[0].get('customer_id')
                    if sid:
                        sr = supabase.table(Service._meta.db_table).select('title').eq('id', sid).execute()
                        if sr.data and sr.data[0]:
                            service_title = sr.data[0].get('title') or service_title
                    if cid:
                        cr = supabase.table('seva_auth_user').select('username').eq('id', cid).execute()
                        if cr.data and cr.data[0]:
                            customer_name = cr.data[0].get('username') or cr.data[0].get('email') or customer_name
            out.append({
                'id': row.get('id'),
                'service': service_title,
                'customer_name': customer_name,
                'rating': row.get('rating'),
                'comment': row.get('comment') or '',
                'date': _to_json_serializable(row.get('created_at')),
            })
        return Response(out)
    except Exception:
        return Response([], status=status.HTTP_200_OK)


@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def update_booking_status(request, booking_id):
    """Update booking status"""
    new_status = request.data.get('status')
    
    if not new_status:
        return Response({'error': 'status is required'}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        supabase = get_supabase_client()
        r = supabase.table(Booking._meta.db_table).select('*').eq('id', booking_id).execute()
        if not r.data or len(r.data) == 0:
            return Response({'error': 'Booking not found'}, status=status.HTTP_404_NOT_FOUND)
        booking = r.data[0]
        is_provider = booking['customer_id'] != request.user.id
        if is_provider:
            svc_r = supabase.table(Service._meta.db_table).select('provider_id').eq('id', booking['service_id']).execute()
            if not svc_r.data or svc_r.data[0].get('provider_id') != request.user.id:
                return Response({'error': 'Unauthorized to update this booking'}, status=status.HTTP_403_FORBIDDEN)
        supabase.table(Booking._meta.db_table).update({'status': new_status}).eq('id', booking_id).execute()
        if new_status.lower() in ('cancelled', 'rejected') and is_provider:
            try:
                svc_r = supabase.table(Service._meta.db_table).select('title').eq('id', booking['service_id']).execute()
                service_title = (svc_r.data or [{}])[0].get('title') or 'Your booking'
                supabase.table('seva_notification').insert({
                    'user_id': booking['customer_id'],
                    'title': 'Booking declined',
                    'body': f"Booking #{booking_id} ({service_title}) was declined by the service provider.",
                    'booking_id': int(booking_id),
                }).execute()
            except Exception:
                pass
        if new_status.lower() == 'completed':
            _award_referral_points_if_eligible(supabase, booking['customer_id'])
        updated = supabase.table(Booking._meta.db_table).select('*').eq('id', booking_id).execute()
        if updated.data and updated.data[0]:
            return Response(_to_json_serializable(updated.data[0]), status=status.HTTP_200_OK)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    return Response({'error': 'Failed to update booking'}, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def provider_notifications(request):
    """For providers: list recent bookings for their services (raw fetch, no serializers)."""
    if request.user.role != 'provider':
        return Response([], status=status.HTTP_200_OK)
    try:
        services = _get_services_raw_from_supabase(provider_id=request.user.id)
        service_ids = [s['id'] for s in services]
        if not service_ids:
            return Response([], status=status.HTTP_200_OK)
        all_bookings = _get_bookings_raw_from_supabase(service_ids=service_ids)
        all_bookings = _enrich_bookings_with_names(all_bookings)
        all_bookings.sort(key=lambda b: b.get('created_at') or '', reverse=True)
        notifications = []
        for b in all_bookings[:50]:
            title = 'Booking assigned!' if b.get('status') in ('accepted', 'confirmed') else 'New booking received'
            customer = b.get('customer_name') or 'A customer'
            service_title = b.get('service_title') or b.get('service_id')
            body = f"{customer} has booked {service_title}" if 'New booking' in title else f"You have been assigned to {service_title}"
            notifications.append({
                'id': b.get('id'),
                'title': title,
                'body': body,
                'booking_id': b.get('id'),
                'created_at': _to_json_serializable(b.get('created_at')),
                'status': b.get('status'),
            })
        return Response(notifications)
    except Exception as e:
        return Response([], status=status.HTTP_200_OK)


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
    """List active promotional banners (public)."""
    try:
        supabase = get_supabase_client()
        r = supabase.table(PROMOTIONAL_TABLE).select('*').eq('is_active', True).order('sort_order').execute()
        out = []
        for row in (r.data or []):
            out.append({
                'id': row.get('id'),
                'title': row.get('title') or '',
                'description': row.get('description') or '',
                'image_url': row.get('image_url'),
                'link_url': row.get('link_url'),
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
    """When a customer completes a booking, if they were referred and points not yet awarded, award points to both."""
    try:
        u = supabase.table('seva_auth_user').select('id, referred_by_id, loyalty_points').eq('id', customer_id).execute()
        if not u.data or not u.data[0].get('referred_by_id'):
            return
        referrer_id = u.data[0]['referred_by_id']
        ref_r = supabase.table(REFERRAL_TABLE).select('*').eq('referred_user_id', customer_id).execute()
        if not ref_r.data or len(ref_r.data) == 0:
            return
        row = ref_r.data[0]
        if (row.get('status') or '') == 'points_awarded':
            return
        ref_id = row['id']
        referrer_points = int(row.get('points_referrer') or 0)
        referred_points = int(row.get('points_referred') or 0)
        if referrer_points > 0:
            return
        # Award points
        supabase.table(REFERRAL_TABLE).update({
            'status': 'points_awarded',
            'points_referrer': POINTS_REFERRER_FIRST_BOOKING,
            'points_referred': POINTS_REFERRED_FIRST_BOOKING,
            'updated_at': datetime.now().isoformat(),
        }).eq('id', ref_id).execute()
        # Increment referrer's loyalty_points
        rr = supabase.table('seva_auth_user').select('loyalty_points').eq('id', referrer_id).execute()
        current = int((rr.data or [{}])[0].get('loyalty_points') or 0)
        supabase.table('seva_auth_user').update({'loyalty_points': current + POINTS_REFERRER_FIRST_BOOKING}).eq('id', referrer_id).execute()
        # Increment referred user's loyalty_points
        rc = supabase.table('seva_auth_user').select('loyalty_points').eq('id', customer_id).execute()
        current_c = int((rc.data or [{}])[0].get('loyalty_points') or 0)
        supabase.table('seva_auth_user').update({'loyalty_points': current_c + POINTS_REFERRED_FIRST_BOOKING}).eq('id', customer_id).execute()
    except Exception:
        pass


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
VALID_DOCUMENT_TYPES = {'work_licence', 'passport', 'citizenship_card', 'national_id'}


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
                'status': row.get('status') or 'pending',
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
    """Add a verification document (providers only). Accepts multipart form with optional file (image or PDF)."""
    if getattr(request.user, 'role', None) != 'provider':
        return Response({'error': 'Provider only'}, status=status.HTTP_403_FORBIDDEN)
    doc_type = (_get_request_param(request, 'document_type') or request.data.get('document_type') or '').strip().lower().replace(' ', '_')
    if doc_type not in VALID_DOCUMENT_TYPES:
        return Response(
            {'error': 'document_type must be one of: work_licence, passport, citizenship_card, national_id'},
            status=status.HTTP_400_BAD_REQUEST
        )
    document_number = _get_request_param(request, 'document_number') or (request.data.get('document_number') or '').strip() or None
    document_url = (request.data.get('document_url') or '').strip() or None
    uploaded_file = request.FILES.get('file') or request.data.get('file') if hasattr(request.data, 'get') else request.FILES.get('file')
    if uploaded_file:
        try:
            document_url = _save_verification_file(uploaded_file, request.user.id, doc_type)
        except Exception as e:
            return Response({'error': f'File save failed: {e}'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        supabase = get_supabase_client()
        payload = {
            'provider_id': request.user.id,
            'document_type': doc_type,
            'document_number': document_number,
            'document_url': document_url,
            'status': 'pending',
        }
        r = supabase.table(PROVIDER_VERIFICATION_TABLE).insert(payload).execute()
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


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def provider_verification_delete(request, verification_id):
    """Delete one verification document (own only)."""
    if getattr(request.user, 'role', None) != 'provider':
        return Response({'error': 'Provider only'}, status=status.HTTP_403_FORBIDDEN)
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


# --- eSewa payment integration ---
PAYMENT_TABLE = 'seva_payment'
ESEWA_MERCHANT_CODE = 'EPAYTEST'
ESEWA_UAT_URL = 'https://uat.esewa.com.np/epay/main'
# Status Check API: verify transaction with eSewa before marking payment complete (recommended)
ESEWA_STATUS_CHECK_UAT = 'https://uat.esewa.com.np/api/epay/transaction/status/'
ESEWA_STATUS_CHECK_LIVE = 'https://epay.esewa.com.np/api/epay/transaction/status/'


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
        import time
        transaction_id = f"HS{booking_id}_{int(time.time() * 1000)}"
        payload = {
            'booking_id': int(booking_id),
            'amount': str(amount_val),
            'transaction_id': transaction_id,
            'gateway': 'esewa',
            'status': 'pending',
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
        r = supabase.table(PAYMENT_TABLE).select('*').eq('transaction_id', oid).eq('status', 'pending').execute()
        if not r.data or len(r.data) == 0:
            return Response({'error': 'Payment not found or already processed'}, status=status.HTTP_400_BAD_REQUEST)
        payment = r.data[0]
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
            'status': 'completed',
            'ref_id': str(ref_id_verified),
            'updated_at': datetime.now().isoformat(),
        }).eq('id', payment['id']).execute()
        supabase.table(Booking._meta.db_table).update({
            'status': 'confirmed',
            'updated_at': datetime.now().isoformat(),
        }).eq('id', booking_id).execute()
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
                'status': 'failed',
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
            pay_r = supabase.table(PAYMENT_TABLE).select('*').eq('booking_id', int(booking_id)).eq('transaction_id', transaction_id).eq('status', 'pending').execute()
        else:
            pay_r = supabase.table(PAYMENT_TABLE).select('*').eq('booking_id', int(booking_id)).eq('status', 'pending').order('id', desc=True).limit(1).execute()
        if not pay_r.data or len(pay_r.data) == 0:
            return Response({'error': 'No pending payment found for this booking'}, status=status.HTTP_400_BAD_REQUEST)
        payment = pay_r.data[0]
        supabase.table(PAYMENT_TABLE).update({
            'status': 'completed',
            'ref_id': 'DEMO',
            'updated_at': datetime.now().isoformat(),
        }).eq('id', payment['id']).execute()
        supabase.table(Booking._meta.db_table).update({
            'status': 'confirmed',
            'updated_at': datetime.now().isoformat(),
        }).eq('id', booking_id).execute()
        return Response({
            'success': True,
            'booking_id': str(booking_id),
            'transaction_id': payment.get('transaction_id', ''),
        }, status=status.HTTP_200_OK)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
