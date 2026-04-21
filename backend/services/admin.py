from django.contrib import admin
from django import forms
from .models import ServiceCategory, Service, Booking, Review, Referral, Payment, Refund, Receipt, ProviderVerification, ServiceCategoryRequest
from .admin_sync import ensure_admin_data_synced
from supabase_config import get_supabase_client
from django.utils import timezone
from django.utils.html import format_html
from django.db import models as django_models
from django.contrib import messages
import logging

logger = logging.getLogger(__name__)


PAYMENT_TABLE = 'seva_payment'
BOOKING_TABLE = 'seva_booking'
REFUND_TABLE = 'seva_refund'
RECEIPT_TABLE = 'seva_receipt'

PAYMENT_STATUS_REFUNDED = 'refunded'
PAYMENT_STATUS_REFUND_REJECTED = 'refund_rejected'
BOOKING_STATUS_REFUNDED = 'refunded'
BOOKING_STATUS_REFUND_REJECTED = 'refund_rejected'
REFUND_STATUS_COMPLETED = 'refunded'
REFUND_STATUS_REJECTED = 'refund_rejected'


def _normalize_verification_status(value):
    raw = (value or '').strip().lower()
    aliases = {
        'pending_verification': 'pending',
        'under_review': 'pending',
        'on_hold': 'pending',
        'verified': 'approved',
    }
    return aliases.get(raw, raw if raw in {'unverified', 'pending', 'approved', 'rejected'} else 'unverified')


ID_DOCUMENT_TYPES = {'national_id', 'citizenship_card', 'passport'}
QUALIFICATION_DOCUMENT_TYPES = {'service_certificate', 'work_licence', 'qualification_certificate', 'training_certificate'}


@admin.register(ServiceCategory)
class ServiceCategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'icon', 'created_at')
    search_fields = ('name', 'description')
    list_filter = ('created_at',)

    def get_queryset(self, request):
        ensure_admin_data_synced()
        return super().get_queryset(request)


@admin.register(Service)
class ServiceAdmin(admin.ModelAdmin):
    list_display = (
        'title', 'category', 'provider', 'price', 'duration_minutes',
        'location', 'status', 'created_at',
    )
    list_filter = ('status', 'category', 'created_at')
    search_fields = ('title', 'description', 'location', 'provider__email')
    raw_id_fields = ('provider', 'category')
    readonly_fields = ('created_at', 'updated_at')

    def get_queryset(self, request):
        ensure_admin_data_synced()
        return super().get_queryset(request)


@admin.register(Booking)
class BookingAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'customer', 'service', 'booking_date', 'booking_time',
        'status', 'total_amount', 'created_at',
    )
    list_filter = ('status', 'booking_date', 'created_at')
    search_fields = ('customer__email', 'service__title', 'notes')
    raw_id_fields = ('customer', 'service')
    readonly_fields = ('created_at', 'updated_at')
    date_hierarchy = 'booking_date'

    def get_queryset(self, request):
        ensure_admin_data_synced()
        return super().get_queryset(request)


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ('id', 'booking', 'customer', 'provider', 'rating', 'created_at')
    list_filter = ('rating', 'created_at')
    search_fields = ('comment', 'customer__email', 'provider__email')
    raw_id_fields = ('booking', 'customer', 'provider')
    readonly_fields = ('created_at',)

    def get_queryset(self, request):
        ensure_admin_data_synced()
        return super().get_queryset(request)


@admin.register(Referral)
class ReferralAdmin(admin.ModelAdmin):
    list_display = ('id', 'referrer', 'referred_user', 'status', 'points_referrer', 'points_referred', 'created_at')
    list_filter = ('status', 'created_at')
    search_fields = ('referrer__email', 'referred_user__email')
    raw_id_fields = ('referrer', 'referred_user')
    readonly_fields = ('created_at', 'updated_at')

    def get_queryset(self, request):
        ensure_admin_data_synced()
        return super().get_queryset(request)


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'booking', 'customer', 'provider', 'amount', 'payment_method',
        'status', 'transaction_id', 'created_at',
    )
    list_filter = ('status', 'payment_method', 'created_at')
    search_fields = ('transaction_id', 'ref_id', 'customer__email', 'provider__email')
    raw_id_fields = ('booking', 'customer', 'provider')
    readonly_fields = ('created_at', 'updated_at')

    def get_queryset(self, request):
        ensure_admin_data_synced()
        return super().get_queryset(request)


class RefundApprovalForm(forms.ModelForm):
    """Form for approving refunds with validation"""
    class Meta:
        model = Refund
        fields = ['refund_reference', 'admin_note']
        widgets = {
            'refund_reference': forms.TextInput(attrs={
                'placeholder': 'e.g., ESW-12345678 or transaction ID',
                'class': 'vTextField',
            }),
            'admin_note': forms.Textarea(attrs={
                'placeholder': 'Optional notes about this approval',
                'rows': 3,
                'class': 'vLargeTextField',
            }),
        }

    def clean_refund_reference(self):
        data = self.cleaned_data.get('refund_reference', '').strip()
        if not data:
            raise forms.ValidationError('eSewa reference is required for approval.')
        return data


class RefundRejectionForm(forms.ModelForm):
    """Form for rejecting refunds with validation"""
    class Meta:
        model = Refund
        fields = ['admin_note']
        widgets = {
            'admin_note': forms.Textarea(attrs={
                'placeholder': 'Reason for rejection (required)',
                'rows': 3,
                'class': 'vLargeTextField',
            }),
        }

    def clean_admin_note(self):
        data = self.cleaned_data.get('admin_note', '').strip()
        if not data:
            raise forms.ValidationError('Rejection reason is required.')
        return data


@admin.register(Refund)
class RefundAdmin(admin.ModelAdmin):
    """Advanced Refund Management Admin"""
    list_display = (
        'refund_id', 'booking_link', 'customer_link', 'provider_link',
        'amount_display', 'status_badge', 'requested_by', 'created_date',
    )
    list_filter = ('status', 'requested_by', 'created_at')
    search_fields = (
        'id', 'booking__id', 'customer__email', 'provider__email',
        'refund_reference', 'refund_reason',
    )
    raw_id_fields = ('booking', 'payment', 'customer', 'provider')
    
    fieldsets = (
        ('Refund Information', {
            'fields': ('id', 'booking', 'payment', 'amount', 'status')
        }),
        ('User Information', {
            'fields': ('customer', 'provider', 'requested_by')
        }),
        ('Refund Request Details', {
            'fields': ('refund_reason', 'system_note'),
            'classes': ('collapse',)
        }),
        ('Admin Review', {
            'fields': ('admin_note', 'refund_reference', 'reviewed_by', 'reviewed_at'),
            'description': 'Fill these fields when approving or rejecting.'
        }),
        ('Timestamps', {
            'fields': ('requested_at', 'created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    readonly_fields = (
        'id', 'booking', 'payment', 'customer', 'provider', 'amount',
        'requested_by', 'requested_at', 'created_at', 'updated_at', 'reviewed_at',
    )
    
    actions = ['approve_refund_action', 'reject_refund_action', 'mark_processing']
    
    def get_queryset(self, request):
        ensure_admin_data_synced()
        return super().get_queryset(request).select_related(
            'booking', 'customer', 'provider', 'payment'
        )
    
    def refund_id(self, obj):
        """Display refund ID"""
        return f"#{obj.id}"
    refund_id.short_description = 'ID'
    
    def booking_link(self, obj):
        """Link to booking"""
        if obj.booking:
            url = f'/admin/services/booking/{obj.booking.id}/change/'
            return format_html(
                '<a href="{}">{}</a>',
                url, f'Booking #{obj.booking.id}'
            )
        return '-'
    booking_link.short_description = 'Booking'
    
    def customer_link(self, obj):
        """Link to customer"""
        if obj.customer:
            url = f'/admin/authentication/user/{obj.customer.id}/change/'
            return format_html(
                '<a href="{}">{}</a>',
                url, obj.customer.email
            )
        return '-'
    customer_link.short_description = 'Customer'
    
    def provider_link(self, obj):
        """Link to provider"""
        if obj.provider:
            url = f'/admin/authentication/user/{obj.provider.id}/change/'
            return format_html(
                '<a href="{}">{}</a>',
                url, obj.provider.email
            )
        return '-'
    provider_link.short_description = 'Provider'
    
    def amount_display(self, obj):
        """Display amount with formatting"""
        return f"Rs {obj.amount:,.2f}"
    amount_display.short_description = 'Amount'
    
    def status_badge(self, obj):
        """Display status as colored badge"""
        colors = {
            'refund_pending': '#FFA500',  # Orange
            'refund_provider_approved': '#4169E1',  # Royal Blue
            'refund_provider_rejected': '#DC143C',  # Crimson
            'refunded': '#228B22',  # Forest Green
            'refund_rejected': '#DC143C',  # Crimson
        }
        color = colors.get(obj.status, '#808080')
        status_label = obj.status.replace('_', ' ').title()
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 10px; '
            'border-radius: 3px; font-weight: bold;">{}</span>',
            color, status_label
        )
    status_badge.short_description = 'Status'
    
    def created_date(self, obj):
        """Display created date"""
        if obj.created_at:
            return obj.created_at.strftime('%Y-%m-%d %H:%M')
        return '-'
    created_date.short_description = 'Created'
    
    def approve_refund_action(self, request, queryset):
        """Admin action to approve refund and finalize downstream state in Supabase."""
        ok_count = 0
        for refund in queryset:
            if refund.status != 'refund_provider_approved':
                messages.error(
                    request,
                    f'Refund #{refund.id} cannot be approved (current status: {refund.status})',
                )
                continue

            reference = (refund.refund_reference or '').strip()
            if not reference:
                messages.error(
                    request,
                    f'Refund #{refund.id} needs refund_reference before approval.',
                )
                continue

            try:
                self._apply_refund_decision(
                    refund=refund,
                    action='approve',
                    reviewer_id=request.user.id,
                    refund_reference=reference,
                    admin_note=(refund.admin_note or '').strip() or None,
                )
                ok_count += 1
                logger.info(f'Admin {request.user.email} approved refund #{refund.id}')
            except Exception as exc:
                logger.exception('Failed approving refund #%s', refund.id)
                messages.error(request, f'Refund #{refund.id} approve failed: {exc}')

        if ok_count:
            messages.success(request, f'{ok_count} refund(s) approved and finalized.')
    approve_refund_action.short_description = '✅ Approve Selected Refunds'
    
    def reject_refund_action(self, request, queryset):
        """Admin action to reject refund with mandatory reason and customer notification."""
        ok_count = 0
        for refund in queryset:
            if refund.status not in ['refund_pending', 'refund_provider_approved']:
                messages.error(
                    request,
                    f'Refund #{refund.id} cannot be rejected (current status: {refund.status})',
                )
                continue

            reason = (refund.admin_note or '').strip()
            if not reason:
                messages.error(
                    request,
                    f'Refund #{refund.id} needs admin_note (rejection reason).',
                )
                continue

            try:
                self._apply_refund_decision(
                    refund=refund,
                    action='reject',
                    reviewer_id=request.user.id,
                    admin_note=reason,
                )
                ok_count += 1
                logger.info(f'Admin {request.user.email} rejected refund #{refund.id}')
            except Exception as exc:
                logger.exception('Failed rejecting refund #%s', refund.id)
                messages.error(request, f'Refund #{refund.id} reject failed: {exc}')

        if ok_count:
            messages.success(request, f'{ok_count} refund(s) rejected.')
    reject_refund_action.short_description = '❌ Reject Selected Refunds'
    
    def mark_processing(self, request, queryset):
        """Mark refunds as processing"""
        updated = queryset.filter(status='refund_provider_approved').update(status='refund_under_review')
        
        messages.success(
            request,
            f'{updated} refund(s) marked as processing.'
        )
    mark_processing.short_description = '⏳ Mark as Processing'

    def save_model(self, request, obj, form, change):
        """When admins edit a refund row directly, enforce proper finalization side-effects."""
        if not change:
            super().save_model(request, obj, form, change)
            return

        old_status = None
        try:
            old_obj = Refund.objects.filter(pk=obj.pk).first()
            old_status = (old_obj.status or '').strip().lower() if old_obj else None
        except Exception:
            old_status = None

        new_status = (obj.status or '').strip().lower()
        finalizing = new_status in {REFUND_STATUS_COMPLETED, REFUND_STATUS_REJECTED}
        status_changed = old_status != new_status

        if finalizing and status_changed:
            if new_status == REFUND_STATUS_COMPLETED and not (obj.refund_reference or '').strip():
                messages.error(request, f'Refund #{obj.id} needs refund_reference before approval.')
                return
            if new_status == REFUND_STATUS_REJECTED and not (obj.admin_note or '').strip():
                messages.error(request, f'Refund #{obj.id} needs admin_note (rejection reason).')
                return

            try:
                self._apply_refund_decision(
                    refund=obj,
                    action='approve' if new_status == REFUND_STATUS_COMPLETED else 'reject',
                    reviewer_id=request.user.id,
                    refund_reference=(obj.refund_reference or '').strip() or None,
                    admin_note=(obj.admin_note or '').strip() or None,
                )
                messages.success(request, f'Refund #{obj.id} saved and workflow finalized.')
            except Exception as exc:
                logger.exception('Refund save_model finalization failed for #%s', obj.id)
                messages.error(request, f'Failed to finalize refund #{obj.id}: {exc}')
                return

        super().save_model(request, obj, form, change)

    def _apply_refund_decision(self, refund, action, reviewer_id, refund_reference=None, admin_note=None):
        supabase = get_supabase_client()
        booking_id = refund.booking_id
        payment_id = refund.payment_id
        now_iso = timezone.now().isoformat()

        decision_status = REFUND_STATUS_COMPLETED if action == 'approve' else REFUND_STATUS_REJECTED
        payment_status = PAYMENT_STATUS_REFUNDED if action == 'approve' else PAYMENT_STATUS_REFUND_REJECTED
        booking_status = BOOKING_STATUS_REFUNDED if action == 'approve' else BOOKING_STATUS_REFUND_REJECTED

        supabase.table(REFUND_TABLE).update({
            'status': decision_status,
            'admin_note': admin_note or None,
            'refund_reference': refund_reference or None,
            'reviewed_by': reviewer_id,
            'reviewed_at': now_iso,
            'updated_at': now_iso,
        }).eq('id', refund.id).execute()

        if payment_id is not None:
            supabase.table(PAYMENT_TABLE).update({
                'status': payment_status,
                'refund_reference': refund_reference or None,
                'updated_at': now_iso,
            }).eq('id', payment_id).execute()

        if booking_id is not None:
            supabase.table(BOOKING_TABLE).update({
                'status': booking_status,
                'updated_at': now_iso,
            }).eq('id', booking_id).execute()

        self._sync_receipt_for_refund(
            supabase=supabase,
            booking_id=booking_id,
            payment_id=payment_id,
            payment_status=payment_status,
            refund_status=('refund_successful' if action == 'approve' else 'refund_rejected'),
            updated_at=now_iso,
        )

        self._send_refund_notification(
            refund=refund,
            action=('approved' if action == 'approve' else 'rejected'),
            reason=(admin_note or '').strip() or None,
            reference=(refund_reference or '').strip() or None,
        )

    def _sync_receipt_for_refund(self, supabase, booking_id, payment_id, payment_status, refund_status, updated_at):
        if booking_id is None:
            return
        existing = None
        try:
            if payment_id is not None:
                q = supabase.table(RECEIPT_TABLE).select('*').eq('payment_id', payment_id).limit(1).execute()
                if q.data:
                    existing = q.data[0]
            if not existing:
                q2 = supabase.table(RECEIPT_TABLE).select('*').eq('booking_id', int(booking_id)).order('id', desc=True).limit(1).execute()
                if q2.data:
                    existing = q2.data[0]
        except Exception:
            existing = None

        if not existing:
            return

        payload = {
            'payment_status': payment_status,
            'refund_status': refund_status,
            'updated_at': updated_at,
        }
        try:
            supabase.table(RECEIPT_TABLE).update(payload).eq('id', existing.get('id')).execute()
        except Exception:
            pass
    
    def _send_refund_notification(self, refund, action, reason=None, reference=None):
        """Send notification to customer and provider"""
        try:
            supabase = get_supabase_client()
            
            # Notify customer
            if action == 'approved':
                customer_body = (
                    f'Your refund request for booking #{refund.booking_id} has been approved and the amount has been credited '
                    f'to your account. Reference: {reference or "N/A"}.'
                )
            else:
                customer_body = (
                    f'Your refund request for booking #{refund.booking_id} has been rejected. '
                    f'Reason: {reason or "Not provided"}.'
                )
            supabase.table('seva_notification').insert({
                'user_id': refund.customer_id,
                'title': f'Refund {action.capitalize()}',
                'body': customer_body,
                'notification_type': f'refund_{action}',
                'related_id': refund.id,
                'created_at': timezone.now().isoformat(),
            }).execute()
            
            # Notify provider if applicable
            if refund.provider:
                provider_body = (
                    f'Refund request for booking #{refund.booking_id} has been approved.'
                    if action == 'approved'
                    else f'Refund request for booking #{refund.booking_id} has been rejected.'
                )
                supabase.table('seva_notification').insert({
                    'user_id': refund.provider_id,
                    'title': f'Refund {action.capitalize()}',
                    'body': provider_body,
                    'notification_type': f'refund_{action}',
                    'related_id': refund.id,
                    'created_at': timezone.now().isoformat(),
                }).execute()
        except Exception as e:
            logger.error(f'Failed to send refund notification: {e}')


@admin.register(Receipt)
class ReceiptAdmin(admin.ModelAdmin):
    list_display = (
        'receipt_id', 'booking', 'customer', 'provider', 'service_name',
        'paid_amount', 'final_total', 'payment_status', 'refund_status', 'issued_at',
    )
    list_filter = ('payment_status', 'refund_status', 'issued_at')
    search_fields = ('receipt_id', 'service_name', 'customer__email', 'provider__email')
    raw_id_fields = ('booking', 'payment', 'customer', 'provider')
    readonly_fields = ('issued_at', 'created_at', 'updated_at')

    def get_queryset(self, request):
        ensure_admin_data_synced()
        return super().get_queryset(request)


@admin.register(ProviderVerification)
class ProviderVerificationAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'provider', 'provider_current_status', 'document_type', 'status', 'document_link', 'upload_status', 'reviewed_by', 'updated_at',
    )
    list_filter = ('status', 'document_type', 'upload_status', 'created_at', 'provider__verification_status')
    search_fields = ('provider__email', 'provider__username', 'document_number', 'document_url')
    raw_id_fields = ('provider',)
    _change_readonly_fields = (
        'provider', 'document_type', 'document_number', 'document_url',
        'created_at', 'updated_at', 'reviewed_at', 'reviewed_by',
    )
    actions = ('mark_pending', 'approve_provider', 'reject_provider')

    def get_readonly_fields(self, request, obj=None):
        if obj is None:
            return ('reviewed_by', 'reviewed_at', 'created_at', 'updated_at')
        return self._change_readonly_fields

    def get_queryset(self, request):
        ensure_admin_data_synced()
        return super().get_queryset(request)

    @admin.display(description='Provider status')
    def provider_current_status(self, obj):
        return _normalize_verification_status(getattr(obj.provider, 'verification_status', None) or 'unverified')

    @admin.display(description='Document')
    def document_link(self, obj):
        url = (getattr(obj, 'document_url', None) or '').strip()
        if not url:
            return '-'
        return format_html('<a href="{}" target="_blank" rel="noopener">Open file</a>', url)

    def _provider_has_required_docs(self, supabase, provider_id):
        docs = supabase.table('seva_provider_verification').select(
            'document_type,document_url'
        ).eq('provider_id', provider_id).execute().data or []
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
        return has_id_doc and has_cert

    def _apply_status(self, request, queryset, status_value):
        supabase = get_supabase_client()
        provider_ids = set()
        now = timezone.now().isoformat()
        for row in queryset:
            provider_ids.add(row.provider_id)
            supabase.table('seva_provider_verification').update({
                'status': status_value,
                'reviewed_by': request.user.id,
                'reviewed_at': now,
                'updated_at': now,
            }).eq('id', row.id).execute()
        for pid in provider_ids:
            if status_value == 'approved' and not self._provider_has_required_docs(supabase, pid):
                continue
            payload = {
                'verification_status': status_value,
                'reviewed_by': request.user.id,
                'reviewed_at': now,
            }
            if status_value == 'approved':
                payload['is_active_provider'] = True
                payload['is_verified'] = True
                payload['rejection_reason'] = None
            elif status_value == 'rejected':
                payload['is_active_provider'] = True
                payload['is_verified'] = False
                payload['rejection_reason'] = 'Rejected by admin review.'
            else:
                payload['is_active_provider'] = True
                payload['is_verified'] = False
                payload['rejection_reason'] = None
            supabase.table('seva_auth_user').update(payload).eq('id', pid).execute()
        self.message_user(request, f'Updated {len(provider_ids)} provider application(s) to {status_value}.')

    @admin.action(description='Set selected applications to pending')
    def mark_pending(self, request, queryset):
        self._apply_status(request, queryset, 'pending')

    @admin.action(description='Approve selected provider applications')
    def approve_provider(self, request, queryset):
        self._apply_status(request, queryset, 'approved')

    @admin.action(description='Reject selected provider applications')
    def reject_provider(self, request, queryset):
        self._apply_status(request, queryset, 'rejected')


@admin.register(ServiceCategoryRequest)
class ServiceCategoryRequestAdmin(admin.ModelAdmin):
    """Admin interface for customer-requested service categories."""
    
    list_display = (
        'request_id', 'customer_link', 'service_title', 'status_badge', 
        'created_date', 'preview'
    )
    list_filter = ('status', 'created_at')
    search_fields = ('requested_title', 'customer__email', 'customer__username', 'description')
    raw_id_fields = ('customer',)
    readonly_fields = ('customer', 'requested_title', 'description', 'address', 
                      'latitude', 'longitude', 'image_urls', 'created_at')
    
    fieldsets = (
        ('Request Information', {
            'fields': ('request_id', 'customer_link', 'requested_title', 'status')
        }),
        ('Details', {
            'fields': ('description', 'address', 'latitude', 'longitude', 'image_urls'),
            'classes': ('collapse',)
        }),
        ('Metadata', {
            'fields': ('created_at',),
            'classes': ('collapse',)
        }),
    )
    
    actions = ['approve_requests', 'reject_requests']
    
    def get_queryset(self, request):
        return super().get_queryset(request).select_related('customer')
    
    @admin.display(description='ID')
    def request_id(self, obj):
        return f"#{obj.id}"
    
    @admin.display(description='Customer')
    def customer_link(self, obj):
        if obj.customer:
            url = f'/admin/authentication/user/{obj.customer.id}/change/'
            return format_html(
                '<a href="{}">{}</a>',
                url, obj.customer.email or obj.customer.username
            )
        return '-'
    
    @admin.display(description='Service Requested')
    def service_title(self, obj):
        return obj.requested_title[:100]
    
    @admin.display(description='Status')
    def status_badge(self, obj):
        colors = {
            'pending': '#FFA500',
            'approved': '#228B22',
            'rejected': '#DC143C',
        }
        color = colors.get(obj.status, '#808080')
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 10px; '
            'border-radius: 3px; font-weight: bold;">{}</span>',
            color, obj.status.upper()
        )
    
    @admin.display(description='Created')
    def created_date(self, obj):
        if obj.created_at:
            return obj.created_at.strftime('%Y-%m-%d %H:%M') if obj.created_at else '-'
        return '-'
    
    @admin.display(description='Preview')
    def preview(self, obj):
        desc = (obj.description or '')[:80]
        if len((obj.description or '')) > 80:
            desc += '...'
        return desc or '(no description)'
    
    @admin.action(description='Mark selected requests as approved')
    def approve_requests(self, request, queryset):
        updated = queryset.update(status='approved')
        self.message_user(request, f'{updated} request(s) approved successfully.')
    
    @admin.action(description='Mark selected requests as rejected')
    def reject_requests(self, request, queryset):
        updated = queryset.update(status='rejected')
        self.message_user(request, f'{updated} request(s) rejected successfully.')

