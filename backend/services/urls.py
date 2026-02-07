from django.urls import path
from . import views

urlpatterns = [
    # Dashboard endpoints
    path('dashboard/stats/', views.dashboard_stats, name='dashboard_stats'),
    path('profile/', views.user_profile, name='user_profile'),
    path('profile/update/', views.user_profile_update, name='user_profile_update'),
    
    # Service endpoints
    path('categories/', views.service_categories, name='service_categories'),
    path('providers/', views.providers_list, name='providers_list'),
    path('services/', views.services_list, name='services_list'),
    path('bookings/create/', views.create_booking, name='create_booking'),
    path('bookings/', views.user_bookings, name='user_bookings'),
    path('bookings/<str:booking_id>/update/', views.update_booking_status, name='update_booking_status'),
    path('reviews/create/', views.create_review, name='create_review'),
    path('reviews/', views.my_reviews, name='my_reviews'),
    path('reviews/received/', views.provider_reviews, name='provider_reviews'),
    path('notifications/', views.provider_notifications, name='provider_notifications'),
    path('customer-notifications/', views.customer_notifications, name='customer_notifications'),
    path('promotional-banners/', views.promotional_banners_list, name='promotional_banners_list'),
    path('blogs/', views.blog_list, name='blog_list'),
    path('referral-profile/', views.referral_profile, name='referral_profile'),
    path('provider-verifications/', views.provider_verifications_list, name='provider_verifications_list'),
    path('provider-verifications/create/', views.provider_verification_create, name='provider_verification_create'),
    path('provider-verifications/<int:verification_id>/', views.provider_verification_delete, name='provider_verification_delete'),
    path('payments/initiate/', views.payment_initiate, name='payment_initiate'),
    path('payments/esewa-success/', views.payment_esewa_success, name='payment_esewa_success'),
    path('payments/esewa-failure/', views.payment_esewa_failure, name='payment_esewa_failure'),
    path('payments/demo-complete/', views.payment_demo_complete, name='payment_demo_complete'),
]
