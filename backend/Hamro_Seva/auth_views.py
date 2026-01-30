from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from .serializers import CustomerRegisterSerializer, ProviderRegisterSerializer, MeSerializer

User = get_user_model()

def get_tokens_for_user(user):
    refresh = RefreshToken.for_user(user)
    return {"refresh": str(refresh), "access": str(refresh.access_token)}

class RegisterCustomerView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = CustomerRegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        tokens = get_tokens_for_user(user)
        return Response({"user": MeSerializer(user).data, "tokens": tokens}, status=status.HTTP_201_CREATED)

class RegisterProviderView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = ProviderRegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        tokens = get_tokens_for_user(user)
        return Response(
            {
                "user": MeSerializer(user).data,
                "tokens": tokens,
                "message": "Provider registered. Awaiting admin verification.",
            },
            status=status.HTTP_201_CREATED
        )

class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        # login with username + password
        username = request.data.get("username")
        password = request.data.get("password")

        if not username or not password:
            return Response({"detail": "username and password required"}, status=400)

        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            return Response({"detail": "Invalid credentials"}, status=401)

        if not user.check_password(password):
            return Response({"detail": "Invalid credentials"}, status=401)

        tokens = get_tokens_for_user(user)
        return Response({"user": MeSerializer(user).data, "tokens": tokens}, status=200)

class MeView(APIView):
    def get(self, request):
        return Response(MeSerializer(request.user).data, status=200)
