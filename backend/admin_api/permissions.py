from rest_framework import permissions


class IsHamroAdmin(permissions.BasePermission):
    """Allow only users with role admin (or Django superuser)."""

    message = 'Admin access required.'

    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated:
            return False
        if getattr(user, 'is_superuser', False):
            return True
        role = (getattr(user, 'role', None) or '').strip().lower()
        return role == 'admin'
