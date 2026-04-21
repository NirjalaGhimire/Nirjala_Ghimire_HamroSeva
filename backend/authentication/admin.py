from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.db import connection
from django.core.management import call_command
from datetime import datetime
from django.urls import reverse, path
from django.utils.html import format_html, format_html_join
from django.template.response import TemplateResponse
from django.shortcuts import redirect
from .models import User
def _normalize_verification_status(value):
    raw = (value or '').strip().lower()
    aliases = {
        'pending_verification': 'pending',
        'under_review': 'pending',
        'on_hold': 'pending',
        'verified': 'approved',
    }
    return aliases.get(raw, raw if raw in {'unverified', 'pending', 'approved', 'rejected'} else 'unverified')

from .forms import UserAdminChangeForm
from services.admin_sync import ensure_admin_data_synced

ID_DOCUMENT_TYPES = {'national_id', 'citizenship_card', 'passport'}
QUALIFICATION_DOCUMENT_TYPES = {'service_certificate', 'work_licence', 'qualification_certificate', 'training_certificate'}

def _provider_doc_status_candidates(status_value):
    status_value = (status_value or '').strip().lower()
    if status_value == 'approved':
        return ['approved', 'verified']
    if status_value == 'pending':
        return ['pending', 'pending_verification', 'under_review']
    if status_value == 'rejected':
        return ['rejected']
    return [status_value]

def _update_provider_verification_status(supabase, provider_id, status_value, request_user_id, now_iso, rejection_reason=None):
    base_payload = {
        'review_note': rejection_reason if status_value == 'rejected' else None,
        'reviewed_by': request_user_id,
        'reviewed_at': now_iso,
        'updated_at': now_iso,
    }
    def _safe_update(payload):
        data = dict(payload or {})
        while data:
            try:
                supabase.table('seva_provider_verification').update(data).eq('provider_id', provider_id).execute()
                return
            except Exception as e:
                msg = str(e)
                missing_col = None
                if 'PGRST204' in msg and "Could not find the '" in msg:
                    missing_col = msg.split("Could not find the '", 1)[1].split("' column", 1)[0]
                if not missing_col:
                    import re
                    m = re.search(r"column\s+seva_provider_verification\.([a-zA-Z0-9_]+)\s+does not exist", msg, re.IGNORECASE)
                    if m:
                        missing_col = m.group(1)
                if not missing_col or missing_col not in data:
                    raise
                data.pop(missing_col, None)
    last_error = None
    for candidate in _provider_doc_status_candidates(status_value):
        payload = dict(base_payload)
        payload['status'] = candidate
        try:
            _safe_update(payload)
            return
        except Exception as e:
            last_error = e
            continue
    if last_error:
        raise last_error


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
    form = UserAdminChangeForm
    list_display = (
        'email', 'username', 'role', 'phone', 'is_verified',
        'verification_status', 'is_active_provider',
        'is_active', 'is_staff', 'referral_code', 'loyalty_points', 'created_at',
    )
    list_filter = ('role', 'verification_status', 'is_active_provider', 'is_active', 'is_staff', 'is_verified')
    search_fields = ('email', 'username', 'phone', 'first_name', 'last_name')
    ordering = ('-created_at',)
    readonly_fields = (
        'password_actions',
        'verification_summary',
        'verification_documents_preview',
        'submitted_at',
        'reviewed_at',
        'reviewed_by',
        'created_at',
        'updated_at',
        'referral_code',
    )
    actions = (
        'approve_selected_providers',
        'reject_selected_providers',
        'mark_selected_providers_pending',
    )

    fieldsets = (
        ('Basic account info', {'fields': ('email', 'username', 'password_actions')}),
        ('Profile info', {'fields': ('first_name', 'last_name', 'phone', 'profession', 'district', 'city', 'qualification')}),
        ('Provider verification summary', {'fields': ('verification_summary',)}),
        ('Uploaded documents', {'fields': ('verification_documents_preview',)}),
        ('Verification decision', {'fields': (
            'verification_status', 'rejection_reason', 'submitted_at', 'reviewed_at', 'reviewed_by',
        )}),
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

    change_list_template = 'admin/authentication/user/change_list.html'

    def get_queryset(self, request):
        _ensure_users_synced()
        ensure_admin_data_synced()
        return super().get_queryset(request)

    def get_urls(self):
        urls = super().get_urls()
        custom = [
            path(
                'pending-provider-applications/',
                self.admin_site.admin_view(self.pending_provider_applications_view),
                name='authentication_user_pending_provider_applications',
            ),
            path(
                '<int:user_id>/provider-review/<str:decision>/',
                self.admin_site.admin_view(self.provider_review_action_view),
                name='authentication_user_provider_review_action',
            ),
        ]
        return custom + urls

    def pending_provider_applications_view(self, request):
        from supabase_config import get_supabase_client
        ensure_admin_data_synced()
        supabase = get_supabase_client()
        users_r = supabase.table('seva_auth_user').select(
            'id,username,email,phone,profession,verification_status,is_active_provider,submitted_at,reviewed_at,reviewed_by,role'
        ).execute()
        rows = []
        for u in (users_r.data or []):
            if (u.get('role') or '').strip().lower() not in ('provider', 'prov'):
                continue
            if _normalize_verification_status(u.get('verification_status')) != 'pending':
                continue
            docs_r = supabase.table('seva_provider_verification').select(
                'document_type,document_url,document_number,created_at'
            ).eq('provider_id', u.get('id')).order('created_at', desc=True).execute()
            docs = docs_r.data or []
            rows.append({'provider': u, 'documents': docs})
        rows.sort(key=lambda x: (x['provider'].get('submitted_at') or ''), reverse=True)
        context = dict(
            self.admin_site.each_context(request),
            title='Pending Provider Applications',
            rows=rows,
            opts=self.model._meta,
        )
        return TemplateResponse(request, 'admin/authentication/user/pending_provider_applications.html', context)

    def provider_review_action_view(self, request, user_id, decision):
        if request.method != 'POST':
            return redirect('admin:authentication_user_pending_provider_applications')
        decision = (decision or '').strip().lower()
        if decision not in {'approved', 'rejected'}:
            self.message_user(request, 'Invalid decision.')
            return redirect('admin:authentication_user_pending_provider_applications')
        reason = (request.POST.get('reason') or '').strip()
        if decision == 'rejected' and not reason:
            self.message_user(request, 'Rejection reason is required.')
            return redirect('admin:authentication_user_pending_provider_applications')
        from supabase_config import get_supabase_client
        supabase = get_supabase_client()
        docs = supabase.table('seva_provider_verification').select(
            'document_type,document_url'
        ).eq('provider_id', user_id).execute().data or []
        has_id_doc = any(
            (d.get('document_type') or '').strip().lower() in ID_DOCUMENT_TYPES
            and (d.get('document_url') or '').strip()
            for d in docs
        )
        has_cert = any(
            (d.get('document_type') or '').strip().lower() in QUALIFICATION_DOCUMENT_TYPES
            and (d.get('document_url') or '').strip()
            for d in docs
        )
        if decision == 'approved' and not (has_id_doc and has_cert):
            self.message_user(request, 'Cannot approve: required ID and qualification documents are missing.')
            return redirect('admin:authentication_user_pending_provider_applications')
        now_iso = datetime.now().isoformat()
        if decision == 'approved':
            status_value = 'approved'
            is_active_provider = True
            is_verified = True
            rejection_reason = None
        else:
            status_value = 'rejected'
            is_active_provider = False
            is_verified = False
            rejection_reason = reason
        supabase.table('seva_auth_user').update({
            'verification_status': status_value,
            'is_active_provider': is_active_provider,
            'is_verified': is_verified,
            'rejection_reason': rejection_reason,
            'reviewed_by': request.user.id,
            'reviewed_at': now_iso,
        }).eq('id', user_id).execute()
        _update_provider_verification_status(
            supabase=supabase,
            provider_id=user_id,
            status_value=status_value,
            request_user_id=request.user.id,
            now_iso=now_iso,
            rejection_reason=rejection_reason,
        )
        ensure_admin_data_synced()
        self.message_user(request, f'Provider {user_id} marked as {status_value}.')
        return redirect('admin:authentication_user_pending_provider_applications')

    def get_form(self, request, obj=None, **kwargs):
        request._admin_request_user = request.user
        return super().get_form(request, obj, **kwargs)

    @admin.display(description='Password')
    def password_actions(self, obj):
        if not obj or not getattr(obj, 'id', None):
            return '-'
        url = reverse('admin:auth_user_password_change', args=[obj.id])
        return format_html(
            'Raw password is not shown. <a class="button" href="{}">Reset password</a>',
            url,
        )

    @admin.display(description='Verification summary')
    def verification_summary(self, obj):
        if not obj or (obj.role or '').lower() not in ('provider', 'prov'):
            return 'Not a provider account.'
        return format_html(
            '<strong>Status:</strong> {}<br><strong>Submitted:</strong> {}<br>'
            '<strong>Reviewed at:</strong> {}<br><strong>Reviewed by:</strong> {}',
            _normalize_verification_status(obj.verification_status).replace('_', ' ').title(),
            obj.submitted_at or '-',
            obj.reviewed_at or '-',
            obj.reviewed_by or '-',
        )

    @admin.display(description='Uploaded verification documents')
    def verification_documents_preview(self, obj):
        if not obj or not getattr(obj, 'id', None):
            return '-'
        try:
            from supabase_config import get_supabase_client
            supabase = get_supabase_client()
            r = supabase.table('seva_provider_verification').select(
                'document_type,document_number,document_url,status,created_at'
            ).eq('provider_id', obj.id).order('created_at', desc=True).execute()
            docs = r.data or []
        except Exception as e:
            return f'Could not load documents: {e}'
        if not docs:
            return 'No verification documents uploaded yet.'
        return format_html_join(
            '',
            '<div style="margin-bottom:8px;"><strong>{}</strong> | #{} | status: {} | '
            '<a href="{}" target="_blank" rel="noopener">Open file</a></div>',
            (
                (
                    (d.get('document_type') or 'document').replace('_', ' ').title(),
                    d.get('document_number') or '-',
                    _normalize_verification_status(d.get('status') or 'pending').replace('_', ' '),
                    d.get('document_url') or '#',
                )
                for d in docs if d.get('document_url')
            ),
        ) or 'Documents exist but links are missing.'

    class Media:
        js = ('admin/js/provider_verification_admin.js',)

    def save_model(self, request, obj, form, change):
        if (obj.role or '').strip().lower() not in ('provider', 'prov'):
            super().save_model(request, obj, form, change)
            return
        now_iso = datetime.now().isoformat()
        status_val = _normalize_verification_status(getattr(obj, 'verification_status', '') or 'unverified')
        obj.verification_status = status_val
        if status_val in {'approved', 'rejected'}:
            obj.reviewed_by = request.user.id
            obj.reviewed_at = now_iso
        if not obj.submitted_at and status_val in {'pending', 'approved', 'rejected'}:
            obj.submitted_at = now_iso
        if status_val == 'approved':
            obj.is_active_provider = True
            obj.is_verified = True
            obj.rejection_reason = None
        elif status_val == 'rejected':
            obj.is_active_provider = True
            obj.is_verified = False
        else:
            obj.is_active_provider = True
            obj.is_verified = False
            obj.rejection_reason = None
        super().save_model(request, obj, form, change)
        try:
            from supabase_config import get_supabase_client
            supabase = get_supabase_client()
            _update_provider_verification_status(
                supabase=supabase,
                provider_id=obj.id,
                status_value=status_val,
                request_user_id=request.user.id,
                now_iso=now_iso,
                rejection_reason=obj.rejection_reason,
            )
        except Exception:
            pass

    def _apply_provider_status(self, request, queryset, status_value):
        provider_ids = [u.id for u in queryset if (u.role or '').strip().lower() in ('provider', 'prov')]
        if not provider_ids:
            self.message_user(request, 'No provider users selected.')
            return
        now = datetime.now().isoformat()
        try:
            from supabase_config import get_supabase_client
            supabase = get_supabase_client()
            for pid in provider_ids:
                docs = supabase.table('seva_provider_verification').select('document_type,document_url').eq('provider_id', pid).execute().data or []
                has_id_doc = any((d.get('document_type') or '').strip().lower() in ID_DOCUMENT_TYPES and (d.get('document_url') or '').strip() for d in docs)
                has_cert = any((d.get('document_type') or '').strip().lower() in QUALIFICATION_DOCUMENT_TYPES and (d.get('document_url') or '').strip() for d in docs)
                if status_value == 'approved' and not (has_id_doc and has_cert):
                    continue
                payload = {
                    'verification_status': status_value,
                }
                if status_value in {'approved', 'rejected'}:
                    payload['reviewed_by'] = request.user.id
                    payload['reviewed_at'] = now
                if status_value == 'approved':
                    payload['is_active_provider'] = True
                    payload['is_verified'] = True
                    payload['rejection_reason'] = None
                elif status_value == 'rejected':
                    payload['is_active_provider'] = True
                    payload['is_verified'] = False
                    payload['rejection_reason'] = 'Rejected by admin.'
                else:
                    payload['is_active_provider'] = True
                    payload['is_verified'] = False
                    payload['rejection_reason'] = None
                supabase.table('seva_auth_user').update(payload).eq('id', pid).execute()
                _update_provider_verification_status(
                    supabase=supabase,
                    provider_id=pid,
                    status_value=status_value,
                    request_user_id=request.user.id,
                    now_iso=now,
                    rejection_reason=payload.get('rejection_reason'),
                )
            ensure_admin_data_synced()
            self.message_user(request, f'Updated {len(provider_ids)} provider(s) to {status_value}.')
        except Exception as e:
            self.message_user(request, f'Provider status update failed: {e}')

    @admin.action(description='Approve selected providers')
    def approve_selected_providers(self, request, queryset):
        self._apply_provider_status(request, queryset, 'approved')

    @admin.action(description='Reject selected providers')
    def reject_selected_providers(self, request, queryset):
        self._apply_provider_status(request, queryset, 'rejected')

    @admin.action(description='Mark selected providers pending')
    def mark_selected_providers_pending(self, request, queryset):
        self._apply_provider_status(request, queryset, 'pending')
