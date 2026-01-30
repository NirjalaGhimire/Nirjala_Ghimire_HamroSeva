from django.db import models
from django.conf import settings
from django.contrib.auth.models import AbstractUser

class User(AbstractUser):
    class Role(models.TextChoices):
        CUSTOMER = "CUSTOMER", "Customer"
        PROVIDER = "PROVIDER", "Service Provider"
        ADMIN = "ADMIN", "Admin"

    role = models.CharField(max_length=20, choices=Role.choices, default=Role.CUSTOMER)
    phone = models.CharField(max_length=20, blank=True, null=True)

class ServiceProviderProfile(models.Model):
    user = models.OneToOneField("Hamro_Seva.User", on_delete=models.CASCADE, related_name="provider_profile")
    is_verified = models.BooleanField(default=False)   # admin will approve later
    document = models.FileField(upload_to="provider_docs/", blank=True, null=True)

    # optional fields
    address = models.CharField(max_length=255, blank=True, null=True)
    bio = models.TextField(blank=True, null=True)

    def __str__(self):
        return f"{self.user.username} (verified={self.is_verified})"

class Service(models.Model):
    title = models.CharField(max_length=120)
    description = models.TextField(blank=True)
    price = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    is_active = models.BooleanField(default=True)
    
     # ✅ ADD THIS (service owner)
    provider = models.ForeignKey(
        "Hamro_Seva.User",
        on_delete=models.CASCADE,
        related_name="services",
        null=True,
        blank=True,
    )


    def __str__(self):
        return self.title


class ServiceRequest(models.Model):
    STATUS_CHOICES = [
        ("PENDING", "Pending"),
        ("ACCEPTED", "Accepted"),
        ("COMPLETED", "Completed"),
        ("CANCELLED", "Cancelled"),
    ]

    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="service_requests",
    )
    service = models.ForeignKey(Service, on_delete=models.CASCADE, related_name="requests")
    note = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="PENDING")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.customer.username} -> {self.service.title} ({self.status})"
    
# models.py (inside ServiceProviderProfile)

from django.db import models
from django.conf import settings

class ServiceProviderProfile(models.Model):
    class Profession(models.TextChoices):
        CARPENTER = "CARPENTER", "Carpenter"
        ELECTRICIAN = "ELECTRICIAN", "Electrician"
        HOUSE_CLEANING = "HOUSE_CLEANING", "House Cleaning"
        PAINTER = "PAINTER", "Painter"
        PLUMBER = "PLUMBER", "Plumber"
        HAIR_STYLIST = "HAIR_STYLIST", "Hair Stylist"

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="provider_profile",
    )

    # ✅ required choice
    profession = models.CharField(
        max_length=30,
        choices=Profession.choices,
        default=Profession.CARPENTER,
    )

    # ✅ add back fields you need
    address = models.CharField(max_length=255, blank=True)
    bio = models.TextField(blank=True)

    # document upload (optional)
    document = models.FileField(upload_to="provider_documents/", blank=True, null=True)

    # verification
    is_verified = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.user.username} ({self.profession})"
