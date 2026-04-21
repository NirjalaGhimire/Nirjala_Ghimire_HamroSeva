from django import forms
from django.core.exceptions import ValidationError
from django.contrib.auth.forms import UserChangeForm
from .models import User
from supabase_config import get_supabase_client

ID_DOCUMENT_TYPES = {'national_id', 'citizenship_card', 'passport'}
QUALIFICATION_DOCUMENT_TYPES = {'service_certificate', 'work_licence', 'qualification_certificate', 'training_certificate'}


class UserAdminChangeForm(UserChangeForm):
    class Meta:
        model = User
        fields = '__all__'

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if 'password' in self.fields:
            # Keep password hash field out of the form to avoid confusing hash-format warnings.
            del self.fields['password']
        if 'verification_status' in self.fields:
            self.fields['verification_status'].choices = (
                ('unverified', 'Unverified'),
                ('pending', 'Pending Review'),
                ('approved', 'Approved'),
                ('rejected', 'Rejected'),
            )
            self.fields['verification_status'].help_text = (
                'Unverified = no approval yet, Pending = documents submitted, '
                'Approved = verified, Rejected = reviewed but not approved.'
            )

    def _required_docs_present(self, provider_id):
        if not provider_id:
            return False
        supabase = get_supabase_client()
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

    def clean(self):
        cleaned = super().clean()
        role = (cleaned.get('role') or '').strip().lower()
        status = (cleaned.get('verification_status') or 'unverified').strip().lower()
        reason = (cleaned.get('rejection_reason') or '').strip()
        if role not in ('provider', 'prov'):
            return cleaned
        if status == 'rejected' and not reason:
            raise ValidationError({'rejection_reason': 'Rejection reason is required when status is Rejected.'})
        if status in ('approved', 'pending', 'unverified'):
            cleaned['rejection_reason'] = None
        if status == 'approved':
            provider_id = getattr(self.instance, 'id', None)
            if not self._required_docs_present(provider_id):
                raise ValidationError(
                    'Cannot approve provider before required documents are uploaded '
                    '(ID card/citizenship/passport and qualification document such as work licence/certificate).'
                )
        return cleaned
