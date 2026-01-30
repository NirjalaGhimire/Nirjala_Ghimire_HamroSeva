from rest_framework import serializers
from .models import Service, ServiceRequest

class ServiceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Service
        fields = ["id", "title", "description", "price", "is_active"]


class ServiceRequestSerializer(serializers.ModelSerializer):
    service_title = serializers.CharField(source="service.title", read_only=True)

    class Meta:
        model = ServiceRequest
        fields = ["id", "service", "service_title", "note", "status", "created_at"]
        read_only_fields = ["status", "created_at"]
