from django.urls import path

from . import views

urlpatterns = [
    path('dashboard/', views.dashboard_overview, name='admin_dashboard'),
    path('reports/charts/', views.reports_charts, name='admin_reports_charts'),
    path('settings/', views.admin_settings, name='admin_settings'),
    path('users/', views.admin_users, name='admin_users'),
    path('users/<int:user_id>/', views.admin_user_detail, name='admin_user_detail'),
    path('providers/', views.admin_providers, name='admin_providers'),
    path('providers/<int:provider_id>/', views.admin_provider_detail, name='admin_provider_detail'),
    path(
        'providers/<int:provider_id>/verification/',
        views.admin_provider_verification,
        name='admin_provider_verification',
    ),
    path('customers/', views.admin_customers, name='admin_customers'),
    path(
        'customers/<int:customer_id>/',
        views.admin_customer_detail,
        name='admin_customer_detail',
    ),
    path('bookings/', views.admin_bookings, name='admin_bookings'),
    path('bookings/<int:booking_id>/', views.admin_booking_detail, name='admin_booking_detail'),
    path('pending/', views.admin_pending, name='admin_pending'),
    path(
        'service-category-requests/',
        views.admin_service_category_requests,
        name='admin_service_category_requests',
    ),
    path(
        'service-category-requests/<int:request_id>/review/',
        views.admin_service_category_request_review,
        name='admin_service_category_request_review',
    ),
    path('services/', views.admin_services, name='admin_services'),
    path('services/<int:service_id>/', views.admin_service_detail, name='admin_service_detail'),
    path('categories/', views.admin_categories, name='admin_categories'),
    path(
        'categories/<int:category_id>/',
        views.admin_category_detail,
        name='admin_category_detail',
    ),
    path('payments/', views.admin_payments, name='admin_payments'),
    path('reviews/', views.admin_reviews, name='admin_reviews'),
    path('reviews/<int:review_id>/', views.admin_review_detail, name='admin_review_detail'),
    path('notifications/', views.admin_notifications, name='admin_notifications'),
]
