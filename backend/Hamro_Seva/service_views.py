from django.shortcuts import get_object_or_404
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import User, Service, ServiceRequest,ServiceProviderProfile


# ----------------------------
# CUSTOMER/ALL: list services
# GET /api/services/
# ----------------------------
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def list_services(request):
    qs = Service.objects.all().order_by("-id")

    data = []
    for s in qs:
        data.append({
            "id": s.id,
            "title": getattr(s, "title", getattr(s, "name", "Service")),
            "description": getattr(s, "description", ""),
            "price": getattr(s, "price", None),
            # provider username if service has FK provider -> User
            "provider": getattr(getattr(s, "provider", None), "username", None),
        })

    return Response(data, status=200)


# ----------------------------
# CUSTOMER: create request
# POST /api/requests/create/
# body: { "service": <id>, "note": "" }
# ----------------------------
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def create_request(request):
    if getattr(request.user, "role", None) != User.Role.CUSTOMER:
        return Response({"detail": "Only customers can create requests."}, status=403)

    service_id = request.data.get("service")
    note = request.data.get("note", "")

    if not service_id:
        return Response({"detail": "service is required"}, status=400)

    service = get_object_or_404(Service, id=service_id)

    # status safe default
    pending_status = "PENDING"
    if hasattr(ServiceRequest, "Status") and hasattr(ServiceRequest.Status, "PENDING"):
        pending_status = ServiceRequest.Status.PENDING

    r = ServiceRequest.objects.create(
        customer=request.user,
        service=service,
        note=note,
        status=pending_status,
    )

    return Response({
        "id": r.id,
        "service": service.id,
        "status": r.status,
        "note": getattr(r, "note", ""),
    }, status=201)


# ----------------------------
# CUSTOMER: my requests history
# GET /api/requests/
# ----------------------------
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def my_requests(request):
    if getattr(request.user, "role", None) != User.Role.CUSTOMER:
        return Response({"detail": "Only customers can view their requests."}, status=403)

    qs = ServiceRequest.objects.filter(customer=request.user).order_by("-id")

    data = []
    for r in qs:
        service_obj = getattr(r, "service", None)
        service_name = "Service"
        if service_obj is not None:
            service_name = getattr(service_obj, "title", getattr(service_obj, "name", "Service"))

        created_at = getattr(r, "created_at", None)
        data.append({
            "id": r.id,
            "service_name": service_name,
            "status": r.status,
            "note": getattr(r, "note", ""),
            "created_at": created_at.isoformat() if created_at else "",
        })

    return Response(data, status=200)


# ----------------------------
# PROVIDER: incoming requests
# GET /api/requests/incoming/
# ----------------------------
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def provider_incoming_requests(request):
    if request.user.role != User.Role.PROVIDER:
        return Response({"detail": "Only providers can view incoming requests."}, status=403)

    qs = ServiceRequest.objects.filter(service__provider=request.user).order_by("-id")

    data = []
    for r in qs:
        data.append({
            "id": r.id,
            "service_name": getattr(r.service, "title", getattr(r.service, "name", "Service")),
            "customer_name": getattr(r.customer, "username", "Customer"),
            "note": getattr(r, "note", ""),
            "status": r.status,
            "created_at": r.created_at.isoformat() if getattr(r, "created_at", None) else "",
        })

    return Response(data, status=200)

# ----------------------------
# PROVIDER: accept request
# POST /api/requests/<id>/accept/
# ----------------------------
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def accept_request(request, request_id: int):
    if request.user.role != User.Role.PROVIDER:
        return Response({"detail": "Only providers can accept requests."}, status=403)

    r = get_object_or_404(ServiceRequest, id=request_id, service__provider=request.user)
    r.status = "ACCEPTED"
    r.save(update_fields=["status"])
    return Response({"detail": "Accepted"}, status=200)

# ----------------------------
# PROVIDER: reject request
# POST /api/requests/<id>/reject/
# ----------------------------

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def reject_request(request, request_id: int):
    if request.user.role != User.Role.PROVIDER:
        return Response({"detail": "Only providers can reject requests."}, status=403)

    r = get_object_or_404(ServiceRequest, id=request_id, service__provider=request.user)
    r.status = "CANCELLED"
    r.save(update_fields=["status"])
    return Response({"detail": "Rejected"}, status=200)
