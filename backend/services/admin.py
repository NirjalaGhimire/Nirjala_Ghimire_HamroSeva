from django.contrib import admin
from .models import ServiceCategory, Service, Booking, Review, Referral


@admin.register(ServiceCategory)
class ServiceCategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'icon', 'created_at')
    search_fields = ('name', 'description')
    list_filter = ('created_at',)


@admin.register(Service)
class ServiceAdmin(admin.ModelAdmin):
    list_display = (
        'title', 'category', 'provider', 'price', 'duration_minutes',
        'location', 'status', 'created_at',
    )
    list_filter = ('status', 'category', 'created_at')
    search_fields = ('title', 'description', 'location', 'provider__email')
    raw_id_fields = ('provider', 'category')
    readonly_fields = ('created_at', 'updated_at')


@admin.register(Booking)
class BookingAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'customer', 'service', 'booking_date', 'booking_time',
        'status', 'total_amount', 'created_at',
    )
    list_filter = ('status', 'booking_date', 'created_at')
    search_fields = ('customer__email', 'service__title', 'notes')
    raw_id_fields = ('customer', 'service')
    readonly_fields = ('created_at', 'updated_at')
    date_hierarchy = 'booking_date'


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ('id', 'booking', 'customer', 'provider', 'rating', 'created_at')
    list_filter = ('rating', 'created_at')
    search_fields = ('comment', 'customer__email', 'provider__email')
    raw_id_fields = ('booking', 'customer', 'provider')
    readonly_fields = ('created_at',)


@admin.register(Referral)
class ReferralAdmin(admin.ModelAdmin):
    list_display = ('id', 'referrer', 'referred_user', 'status', 'points_referrer', 'points_referred', 'created_at')
    list_filter = ('status', 'created_at')
    search_fields = ('referrer__email', 'referred_user__email')
    raw_id_fields = ('referrer', 'referred_user')
    readonly_fields = ('created_at', 'updated_at')
