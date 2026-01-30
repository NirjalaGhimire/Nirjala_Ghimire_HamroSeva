from django.contrib.auth import get_user_model
from rest_framework import serializers
from .models import ServiceProviderProfile

User = get_user_model()

class CustomerRegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)

    class Meta:
        model = User
        fields = ["username", "email", "phone", "password"]

    def create(self, validated_data):
        password = validated_data.pop("password")
        user = User(**validated_data)
        user.role = User.Role.CUSTOMER
        user.set_password(password)
        user.save()
        return user


class ProviderRegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)
    document = serializers.FileField(required=False)

    class Meta:
        model = User
        fields = ["username", "email", "phone", "password", "document"]

    def create(self, validated_data):
        document = validated_data.pop("document", None)
        password = validated_data.pop("password")

        user = User(**validated_data)
        user.role = User.Role.PROVIDER
        user.set_password(password)
        user.save()

        ServiceProviderProfile.objects.create(user=user, document=document)
        return user


class MeSerializer(serializers.ModelSerializer):
    profession = serializers.SerializerMethodField()
    is_verified = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ["id", "username", "email", "role", "profession", "is_verified"]

    def get_profession(self, obj):
        if obj.role == User.Role.PROVIDER:
            try:
                return obj.provider_profile.profession
            except Exception:
                return None
        return None

    def get_is_verified(self, obj):
        if obj.role == User.Role.PROVIDER:
            try:
                return obj.provider_profile.is_verified
            except Exception:
                return False
        return True

