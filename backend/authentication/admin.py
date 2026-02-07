from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.db import connection
from django.core.management import call_command
from .models import User


def _ensure_users_synced():
    """If SQLite has no users, sync from Supabase so admin list shows them."""
    try:
        with connection.cursor() as c:
            c.execute('SELECT COUNT(*) FROM authentication_user')
            if c.fetchone()[0] == 0:
                call_command('sync_supabase_users', verbosity=0)
    except Exception:
        pass


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = (
        'email', 'username', 'role', 'phone', 'is_verified',
        'is_active', 'is_staff', 'referral_code', 'loyalty_points', 'created_at',
    )
    list_filter = ('role', 'is_active', 'is_staff', 'is_verified')
    search_fields = ('email', 'username', 'phone', 'first_name', 'last_name')
    ordering = ('-created_at',)
    readonly_fields = ('created_at', 'updated_at', 'referral_code')

    fieldsets = (
        (None, {'fields': ('email', 'username', 'password')}),
        ('Profile', {'fields': ('first_name', 'last_name', 'phone', 'profession')}),
        ('Role & status', {'fields': ('role', 'is_verified', 'is_active', 'is_staff', 'is_superuser')}),
        ('Referral & loyalty', {'fields': ('referral_code', 'loyalty_points', 'referred_by_id')}),
        ('Dates', {'fields': ('created_at', 'updated_at')}),
    )

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'username', 'password1', 'password2', 'role'),
        }),
    )

    def get_queryset(self, request):
        _ensure_users_synced()
        return super().get_queryset(request)
