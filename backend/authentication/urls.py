from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    health, login, register_customer, register_provider, me, logout, social_login,
    forgot_password, verify_reset_code, set_new_password,
)

urlpatterns = [
    path("health/", health),
    
    # Authentication endpoints
    path("login/", login),
    path("register/customer/", register_customer),
    path("register/provider/", register_provider),
    path("me/", me),
    path("logout/", logout),
    path("social-login/", social_login),
    path("forgot-password/", forgot_password),
    path("verify-reset-code/", verify_reset_code),
    path("set-new-password/", set_new_password),

    # JWT token refresh
    path("token/refresh/", TokenRefreshView.as_view()),
]
