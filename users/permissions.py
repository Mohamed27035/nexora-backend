from rest_framework.permissions import BasePermission


class IsAdmin(BasePermission):

    def has_permission(
        self,
        request,
        view
    ):

        return (
            hasattr(request, "user")
            and
            request.user
            and
            str(request.user.role)
            .upper() == "ADMIN"
        )


class IsAuditeur(
    BasePermission
):

    def has_permission(
        self,
        request,
        view
    ):

        return (
            hasattr(request, "user")
            and
            request.user
            and
            str(request.user.role)
            .upper() == "AUDITEUR"
        )


class IsComptable(
    BasePermission
):

    def has_permission(
        self,
        request,
        view
    ):

        return (
            hasattr(request, "user")
            and
            request.user
            and
            str(request.user.role)
            .upper() == "COMPTABLE"
        )


class IsClient(
    BasePermission
):

    def has_permission(
        self,
        request,
        view
    ):

        return (
            hasattr(request, "user")
            and
            request.user
            and
            str(request.user.role)
            .upper() == "CLIENT"
        )