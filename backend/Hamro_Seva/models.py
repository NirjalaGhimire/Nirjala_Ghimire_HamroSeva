from django.db import models
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
