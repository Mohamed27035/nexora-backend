from django.db.models import Count, Q
from rest_framework.decorators import api_view
from rest_framework.response import Response

from logs.models import Log
from logs.views import _apply_log_filters, _serialize_log
from users.views import get_current_user, is_admin, is_auditeur


def _error(message, status=400):
    return Response({"error": message}, status=status)


def _require_audit_access(request):
    current_user, error = get_current_user(request)
    if error:
        return None, error

    if not (is_admin(current_user) or is_auditeur(current_user)):
        return None, _error("Acces refuse", 403)

    return current_user, None


@api_view(["GET"])
def get_audit_summary(request):
    _current_user, error = _require_audit_access(request)
    if error:
        return error

    logs = Log.objects.select_related("utilisateur").all()
    logs = _apply_log_filters(logs, request)

    action_breakdown = list(
        logs.values("action")
        .annotate(count=Count("id"))
        .order_by("-count", "action")[:8]
    )

    entity_breakdown = list(
        logs.exclude(entity_type="")
        .values("entity_type")
        .annotate(count=Count("id"))
        .order_by("-count", "entity_type")
    )

    recent_sensitive = logs.filter(
        Q(is_suspicious=True) | Q(severity="CRITICAL")
    ).order_by("-date")[:8]

    return Response(
        {
            "total_logs": logs.count(),
            "suspicious_actions": logs.filter(is_suspicious=True).count(),
            "critical_actions": logs.filter(severity="CRITICAL").count(),
            "user_actions": logs.filter(entity_type="USER").count(),
            "transaction_actions": logs.filter(entity_type="TRANSACTION").count(),
            "kyc_actions": logs.filter(entity_type="KYC").count(),
            "action_breakdown": action_breakdown,
            "entity_breakdown": entity_breakdown,
            "recent_sensitive": [_serialize_log(log) for log in recent_sensitive],
        }
    )


@api_view(["GET"])
def get_audit_logs(request):
    _current_user, error = _require_audit_access(request)
    if error:
        return error

    logs = Log.objects.select_related("utilisateur").all().order_by("-date")
    logs = _apply_log_filters(logs, request)[:200]
    return Response([_serialize_log(log) for log in logs])


@api_view(["GET"])
def get_audit_log_detail(request, log_id):
    _current_user, error = _require_audit_access(request)
    if error:
        return error

    log = Log.objects.select_related("utilisateur").filter(id=log_id).first()
    if not log:
        return _error("Log introuvable", 404)

    return Response(_serialize_log(log))


@api_view(["GET"])
def get_suspicious_actions(request):
    _current_user, error = _require_audit_access(request)
    if error:
        return error

    logs = Log.objects.select_related("utilisateur").filter(
        Q(is_suspicious=True) | Q(severity="CRITICAL")
    ).order_by("-date")
    logs = _apply_log_filters(logs, request)[:100]
    return Response([_serialize_log(log) for log in logs])
