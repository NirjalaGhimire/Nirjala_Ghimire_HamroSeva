"""Custom Django admin pages for Hamro Sewa."""
from django.contrib import admin
from django.template.response import TemplateResponse
from django.utils.translation import gettext_lazy as _


def hamro_admin_dashboard(request):
    """Analytics dashboard (same template as admin index)."""
    request.current_app = admin.site.name
    app_list = admin.site.get_app_list(request)
    context = {
        **admin.site.each_context(request),
        'title': _('Dashboard'),
        'subtitle': None,
        'app_list': app_list,
    }
    return TemplateResponse(request, 'admin/hamro_dashboard.html', context)
