from rest_framework.permissions import BasePermission

from .views import has_role


class IsAdmin(BasePermission):
    def has_permission(self, request, view):
        return hasattr(request, "user") and has_role(request.user, "ADMIN")


class IsAuditeur(BasePermission):
    def has_permission(self, request, view):
        return hasattr(request, "user") and has_role(request.user, "AUDITEUR")


class IsComptable(BasePermission):
    def has_permission(self, request, view):
        return hasattr(request, "user") and has_role(request.user, "COMPTABLE")


class IsClient(BasePermission):
    def has_permission(self, request, view):
        return hasattr(request, "user") and has_role(request.user, "CLIENT")

