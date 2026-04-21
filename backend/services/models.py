from django.db import models
from authentication.models import User

class ServiceCategory(models.Model):
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    icon = models.CharField(max_length=50, blank=True)  # Icon name or emoji
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = 'seva_servicecategory'  # Supabase table name
        verbose_name_plural = 'Service categories'
    
    def __str__(self):
        return self.name

class Service(models.Model):
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('inactive', 'Inactive'),
        ('pending', 'Pending'),
    ]
    
    provider = models.ForeignKey(User, on_delete=models.CASCADE, related_name='services')
    category = models.ForeignKey(ServiceCategory, on_delete=models.CASCADE, related_name='services')
    title = models.CharField(max_length=200)
    description = models.TextField()
    price = models.DecimalField(max_digits=10, decimal_places=2)
    duration_minutes = models.IntegerField(help_text="Duration in minutes")
    location = models.CharField(max_length=255)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active')
    image_url = models.URLField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        managed = False
        db_table = 'seva_service'  # Supabase table name

    def __str__(self):
        return f"{self.title} - {self.provider.username}"

class Booking(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('quoted', 'Quoted'),
        ('confirmed', 'Confirmed'),
        ('cancelled', 'Cancelled'),
        ('rejected', 'Rejected'),
        ('completed', 'Completed'),
    ]
    
    customer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='customer_bookings')
    service = models.ForeignKey(Service, on_delete=models.CASCADE, related_name='bookings')
    booking_date = models.DateField()
    booking_time = models.TimeField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    notes = models.TextField(blank=True)
    total_amount = models.DecimalField(max_digits=10, decimal_places=2)
    quoted_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    request_image_url = models.TextField(blank=True, null=True)
    address = models.TextField(blank=True)
    latitude = models.DecimalField(max_digits=10, decimal_places=8, null=True, blank=True)
    longitude = models.DecimalField(max_digits=11, decimal_places=8, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        managed = False
        db_table = 'seva_booking'  # Supabase table name

    def __str__(self):
        return f"{self.customer.username} - {self.service.title}"


class CustomerProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='customer_profile')
    full_name = models.CharField(max_length=200)
    email = models.EmailField(max_length=254)
    phone = models.CharField(max_length=30)
    location = models.TextField(blank=True, null=True)
    profile_image_url = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'seva_customer_profile'

    def __str__(self):
        return f"CustomerProfile user={self.user_id}"


class ProviderTimeSlot(models.Model):
    provider = models.ForeignKey(User, on_delete=models.CASCADE, related_name='provider_time_slots')
    slot_date = models.DateField()
    start_time = models.TimeField()
    end_time = models.TimeField()
    note = models.TextField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        managed = False
        db_table = 'seva_provider_time_slot'

    def __str__(self):
        return f"{self.provider.username} - {self.slot_date} {self.start_time} to {self.end_time}"

class Review(models.Model):
    RATING_CHOICES = [
        (1, '1 Star'),
        (2, '2 Stars'),
        (3, '3 Stars'),
        (4, '4 Stars'),
        (5, '5 Stars'),
    ]
    
    booking = models.OneToOneField(Booking, on_delete=models.CASCADE, related_name='review')
    customer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reviews_given')
    provider = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reviews_received')
    rating = models.IntegerField(choices=RATING_CHOICES)
    comment = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = 'seva_review'  # Supabase table name

    def __str__(self):
        return f"Review by {self.customer.username} for {self.provider.username}"


class ChatMessage(models.Model):
    """Chat messages between customer and provider, linked to a booking."""
    booking_id = models.IntegerField()
    sender = models.ForeignKey(User, on_delete=models.CASCADE, related_name='chat_messages')
    message = models.TextField()
    attachment_path = models.TextField(blank=True, null=True)
    attachment_mime = models.TextField(blank=True, null=True)
    attachment_name = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    deleted_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'seva_chat_message'

    def __str__(self):
        return f"ChatMessage by {self.sender_id} for booking {self.booking_id}"
    
    @property
    def is_deleted(self):
        return self.deleted_at is not None


class Referral(models.Model):
    """Tracks who referred whom; synced from Supabase seva_referral for admin."""
    referrer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='referrals_made')
    referred_user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='referrals_received')
    status = models.CharField(max_length=30, default='signed_up')
    points_referrer = models.IntegerField(default=0)
    points_referred = models.IntegerField(default=0)
    created_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'seva_referral'

    def __str__(self):
        return f"Referral {self.referrer_id} -> {self.referred_user_id} ({self.status})"


class Payment(models.Model):
    booking = models.ForeignKey(Booking, on_delete=models.CASCADE, related_name='payments')
    customer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='payments')
    provider = models.ForeignKey(User, on_delete=models.CASCADE, related_name='provider_payments', null=True, blank=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    payment_method = models.CharField(max_length=30, blank=True, null=True)
    status = models.CharField(max_length=30, default='pending')
    transaction_id = models.CharField(max_length=120, blank=True, null=True)
    ref_id = models.CharField(max_length=120, blank=True, null=True)
    refund_amount = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    refund_reason = models.TextField(blank=True, null=True)
    refund_reference = models.CharField(max_length=120, blank=True, null=True)
    created_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'seva_payment'

    def __str__(self):
        return f"Payment #{self.id} - booking {self.booking_id} ({self.status})"


class Refund(models.Model):
    booking = models.ForeignKey(Booking, on_delete=models.CASCADE, related_name='refunds')
    payment = models.ForeignKey(Payment, on_delete=models.SET_NULL, null=True, blank=True, related_name='refunds')
    customer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='refunds')
    provider = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='provider_refunds')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=30, default='refund_pending')
    refund_reason = models.TextField(blank=True, null=True)
    system_note = models.TextField(blank=True, null=True)
    admin_note = models.TextField(blank=True, null=True)
    refund_reference = models.CharField(max_length=120, blank=True, null=True)
    requested_by = models.CharField(max_length=20, blank=True, null=True)
    requested_at = models.DateTimeField(null=True, blank=True)
    reviewed_by = models.IntegerField(null=True, blank=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'seva_refund'

    def __str__(self):
        return f"Refund #{self.id} - booking {self.booking_id} ({self.status})"


class Receipt(models.Model):
    receipt_id = models.CharField(max_length=80, unique=True)
    booking = models.ForeignKey(Booking, on_delete=models.CASCADE, related_name='receipts')
    payment = models.ForeignKey(Payment, on_delete=models.SET_NULL, null=True, blank=True, related_name='receipts')
    customer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='receipts')
    provider = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='provider_receipts')
    service_name = models.CharField(max_length=200, blank=True, null=True)
    payment_method = models.CharField(max_length=40, blank=True, null=True)
    paid_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    discount_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    tax_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    service_charge = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    final_total = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    payment_status = models.CharField(max_length=30, default='completed')
    refund_status = models.CharField(max_length=30, blank=True, null=True)
    issued_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'seva_receipt'

    def __str__(self):
        return f"{self.receipt_id} (booking {self.booking_id})"


class ProviderVerification(models.Model):
    provider = models.ForeignKey(User, on_delete=models.CASCADE, related_name='verification_documents')
    document_type = models.CharField(max_length=60)
    document_number = models.CharField(max_length=100, blank=True, null=True)
    document_url = models.TextField(blank=True, null=True)
    status = models.CharField(max_length=30, default='pending_verification')
    upload_status = models.CharField(max_length=30, default='uploaded')
    review_note = models.TextField(blank=True, null=True)
    reviewed_by = models.IntegerField(null=True, blank=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'seva_provider_verification'

    def __str__(self):
        return f"ProviderVerification #{self.id} - provider {self.provider_id} ({self.status})"


class ServiceCategoryRequest(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]
    
    customer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='service_category_requests')
    requested_title = models.CharField(max_length=500)
    description = models.TextField(blank=True, null=True)
    address = models.CharField(max_length=1000, blank=True, null=True)
    latitude = models.DecimalField(max_digits=10, decimal_places=8, blank=True, null=True)
    longitude = models.DecimalField(max_digits=11, decimal_places=8, blank=True, null=True)
    image_urls = models.TextField(blank=True, null=True)  # JSON array stored as text
    status = models.CharField(max_length=32, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'seva_service_category_request'
        verbose_name_plural = 'Service category requests'
        ordering = ['-created_at']

    def __str__(self):
        return f"Request for {self.requested_title} by {self.customer.username} ({self.status})"
