from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from .views import health
from .auth_views import RegisterCustomerView, RegisterProviderView, LoginView, MeView

# ✅ ALL service/customer/provider endpoints are here
from .service_views import (
    list_services,
    create_request,
    my_requests,
    provider_incoming_requests,
    accept_request,
    reject_request,
)

urlpatterns = [
    # health
    path("health/", health, name="health"),

    # auth
    path("auth/register/customer/", RegisterCustomerView.as_view(), name="register-customer"),
    path("auth/register/provider/", RegisterProviderView.as_view(), name="register-provider"),
    path("auth/login/", LoginView.as_view(), name="login"),
    path("auth/token/refresh/", TokenRefreshView.as_view(), name="token-refresh"),
    path("auth/me/", MeView.as_view(), name="me"),

    # customer
    path("services/", list_services, name="services"),
    path("requests/", my_requests, name="my-requests"),
    path("requests/create/", create_request, name="create-request"),

    # provider
    path("requests/incoming/", provider_incoming_requests, name="provider-incoming"),
    path("requests/<int:request_id>/accept/", accept_request, name="request-accept"),
    path("requests/<int:request_id>/reject/", reject_request, name="request-reject"),
]
