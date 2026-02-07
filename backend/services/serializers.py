from rest_framework import serializers
from .models import ServiceCategory, Service, Booking, Review
from authentication.models import User

class ServiceCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = ServiceCategory
        fields = '__all__'

class ServiceSerializer(serializers.ModelSerializer):
    provider_name = serializers.CharField(source='provider.username', read_only=True)
    provider_email = serializers.CharField(source='provider.email', read_only=True)
    category_name = serializers.CharField(source='category.name', read_only=True)
    
    class Meta:
        model = Service
        fields = '__all__'

class BookingSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.username', read_only=True)
    service_title = serializers.CharField(source='service.title', read_only=True)
    provider_name = serializers.CharField(source='service.provider.username', read_only=True)
    
    class Meta:
        model = Booking
        fields = '__all__'
        read_only_fields = ('customer', 'total_amount')

class CreateBookingSerializer(serializers.Serializer):
    """Validate booking payload without touching Django ORM (data lives in Supabase)."""
    service = serializers.IntegerField(min_value=1)
    booking_date = serializers.DateField()
    booking_time = serializers.TimeField()
    notes = serializers.CharField(required=False, allow_blank=True, default='')
    total_amount = serializers.DecimalField(max_digits=10, decimal_places=2, required=False, allow_null=True)

class ReviewSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.username', read_only=True)
    service_title = serializers.CharField(source='booking.service.title', read_only=True)
    
    class Meta:
        model = Review
        fields = '__all__'
        read_only_fields = ('customer', 'provider', 'booking')

class DashboardStatsSerializer(serializers.Serializer):
    total_services = serializers.IntegerField()
    total_bookings = serializers.IntegerField()
    pending_bookings = serializers.IntegerField()
    completed_bookings = serializers.IntegerField()
    total_earnings = serializers.DecimalField(max_digits=10, decimal_places=2)
    average_rating = serializers.FloatField()
    remaining_payout = serializers.DecimalField(max_digits=10, decimal_places=2, required=False, default=0)
    cash_in_hand = serializers.DecimalField(max_digits=10, decimal_places=2, required=False, default=0)

class UserProfileSerializer(serializers.ModelSerializer):
    total_services = serializers.SerializerMethodField()
    total_bookings = serializers.SerializerMethodField()
    average_rating = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'phone', 'role', 'profession', 'is_verified', 
                 'created_at', 'total_services', 'total_bookings', 'average_rating')
    
    def get_total_services(self, obj):
        if obj.role == 'provider':
            return obj.services.count()
        return 0
    
    def get_total_bookings(self, obj):
        if obj.role == 'customer':
            return obj.customer_bookings.count()
        elif obj.role == 'provider':
            return Booking.objects.filter(service__provider=obj).count()
        return 0
    
    def get_average_rating(self, obj):
        if obj.role == 'provider':
            reviews = Review.objects.filter(provider=obj)
            if reviews.exists():
                return sum(review.rating for review in reviews) / reviews.count()
        return 0
