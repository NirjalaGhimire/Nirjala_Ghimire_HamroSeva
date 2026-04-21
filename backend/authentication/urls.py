from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    health, login, register_customer, register_provider, me, logout, social_login,
    forgot_password, verify_reset_code, set_new_password, change_password, delete_account,
    accept_terms, debug_password_check, send_registration_otp,
    resend_registration_otp, verify_registration_otp,
)

urlpatterns = [
    path("health/", health),
    
    # Authentication endpoints
    path("login/", login),
    path("register/customer/", register_customer),
    path("register/provider/", register_provider),
    path("register/send-otp/", send_registration_otp),
    path("register/verify-otp/", verify_registration_otp),
    path("register/resend-otp/", resend_registration_otp),
    path("me/", me),
    path("logout/", logout),
    path("social-login/", social_login),
    path("accept-terms/", accept_terms),
    path("forgot-password/", forgot_password),
    path("verify-reset-code/", verify_reset_code),
    path("set-new-password/", set_new_password),
    path("change-password/", change_password),
    path("delete-account/", delete_account),
    path("debug/password-check/", debug_password_check),  # Debug only (disabled in production)

    # JWT token refresh
    path("token/refresh/", TokenRefreshView.as_view()),
]
