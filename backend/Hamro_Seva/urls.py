from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from .views import health
from .auth_views import RegisterCustomerView, RegisterProviderView, LoginView, MeView

urlpatterns = [
    # existing health check
    path("health/", health, name="health"),

    # auth endpoints
    path("auth/register/customer/", RegisterCustomerView.as_view(), name="register-customer"),
    path("auth/register/provider/", RegisterProviderView.as_view(), name="register-provider"),
    path("auth/login/", LoginView.as_view(), name="login"),
    path("auth/token/refresh/", TokenRefreshView.as_view(), name="token-refresh"),
    path("auth/me/", MeView.as_view(), name="me"),
]
