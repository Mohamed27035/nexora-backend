from django.db.models import Count, Q
from django.db.models.functions import TruncDate
from rest_framework.decorators import api_view
from rest_framework.response import Response

from users.views import get_current_user, is_admin, is_auditeur

from .models import Log


SENSITIVE_ACTIONS = {
    "DELETE_USER",
    "BAN_USER",
    "RESET_PASSWORD",
    "APPROVE_TRANSACTION",
    "REJECT_TRANSACTION",
    "APPROVE_KYC",
    "REJECT_KYC",
}


def _error(message, status=400):
    return Response({"error": message}, status=status)


def _parse_bool(value):
    if value is None or value == "":
        return None
    return str(value).strip().lower() in {"1", "true", "yes", "oui"}


def _require_audit_access(request):
    current_user, error = get_current_user(request)
    if error:
        return None, error

    if not (is_admin(current_user) or is_auditeur(current_user)):
        return None, _error("Acces refuse", 403)

    return current_user, None


def _is_sensitive(log):
    return bool(log.is_suspicious or log.severity == "CRITICAL" or log.action in SENSITIVE_ACTIONS)


def _serialize_log(log):
    actor = log.utilisateur
    actor_name = ""
    actor_email = ""

    if actor:
        actor_name = " ".join(part for part in [actor.nom, actor.prenom or ""] if part).strip()
        actor_email = actor.email or ""

    return {
        "id": log.id,
        "user": actor_name or actor_email or "Unknown",
        "user_email": actor_email,
        "user_id": actor.id if actor else None,
        "action": log.action,
        "description": log.description,
        "entity_type": log.entity_type or "",
        "entity_id": log.entity_id or "",
        "target_repr": log.target_repr or "",
        "severity": log.severity,
        "metadata": log.metadata or {},
        "is_suspicious": log.is_suspicious,
        "is_sensitive": _is_sensitive(log),
        "date": log.date,
    }


def _apply_log_filters(logs, request):
    start = request.GET.get("start")
    end = request.GET.get("end")
    action = str(request.GET.get("action", "ALL")).strip().upper()
    search = str(request.GET.get("search", "")).strip()
    severity = str(request.GET.get("severity", "ALL")).strip().upper()
    entity_type = str(request.GET.get("entity_type", "ALL")).strip().upper()
    user_id = str(request.GET.get("user_id", "")).strip()
    suspicious = _parse_bool(request.GET.get("suspicious"))
    sensitive = _parse_bool(request.GET.get("sensitive"))

    if start:
        logs = logs.filter(date__date__gte=start)
    if end:
        logs = logs.filter(date__date__lte=end)
    if action and action != "ALL":
        logs = logs.filter(action=action)
    if severity and severity != "ALL":
        logs = logs.filter(severity=severity)
    if entity_type and entity_type != "ALL":
        logs = logs.filter(entity_type=entity_type)
    if user_id:
        logs = logs.filter(utilisateur_id=user_id)
    if suspicious is not None:
        logs = logs.filter(is_suspicious=suspicious)
    if sensitive is True:
        logs = logs.filter(Q(is_suspicious=True) | Q(severity="CRITICAL") | Q(action__in=SENSITIVE_ACTIONS))
    if sensitive is False:
        logs = logs.exclude(Q(is_suspicious=True) | Q(severity="CRITICAL") | Q(action__in=SENSITIVE_ACTIONS))

    if search:
        logs = logs.filter(
            Q(action__icontains=search)
            | Q(description__icontains=search)
            | Q(entity_type__icontains=search)
            | Q(entity_id__icontains=search)
            | Q(target_repr__icontains=search)
            | Q(utilisateur__nom__icontains=search)
            | Q(utilisateur__prenom__icontains=search)
            | Q(utilisateur__email__icontains=search)
        )

    return logs


def _build_summary(logs):
    return {
        "total_logs": logs.count(),
        "suspicious_actions": logs.filter(is_suspicious=True).count(),
        "critical_actions": logs.filter(severity="CRITICAL").count(),
        "sensitive_actions": logs.filter(
            Q(is_suspicious=True) | Q(severity="CRITICAL") | Q(action__in=SENSITIVE_ACTIONS)
        ).count(),
        "login_actions": logs.filter(action="LOGIN").count(),
        "user_actions": logs.filter(entity_type="USER").count(),
        "transaction_actions": logs.filter(entity_type="TRANSACTION").count(),
        "kyc_actions": logs.filter(entity_type="KYC").count(),
        "actors_count": logs.exclude(utilisateur=None).values("utilisateur").distinct().count(),
    }


@api_view(["GET"])
def get_logs(request):
    _current_user, error = _require_audit_access(request)
    if error:
        return error

    logs = Log.objects.select_related("utilisateur").all().order_by("-date")
    logs = _apply_log_filters(logs, request)[:200]
    return Response([_serialize_log(log) for log in logs])


@api_view(["GET"])
def get_log_detail(request, log_id):
    _current_user, error = _require_audit_access(request)
    if error:
        return error

    log = Log.objects.select_related("utilisateur").filter(id=log_id).first()
    if not log:
        return _error("Log introuvable", 404)

    return Response(_serialize_log(log))


@api_view(["GET"])
def get_stats(request):
    _current_user, error = _require_audit_access(request)
    if error:
        return error

    logs = Log.objects.select_related("utilisateur").all()
    logs = _apply_log_filters(logs, request)

    summary = _build_summary(logs)
    top_actions = list(
        logs.values("action")
        .annotate(count=Count("id"))
        .order_by("-count", "action")[:10]
    )
    top_entities = list(
        logs.exclude(entity_type="")
        .values("entity_type")
        .annotate(count=Count("id"))
        .order_by("-count", "entity_type")
    )

    return Response(
        {
            **summary,
            "top_actions": top_actions,
            "top_entities": top_entities,
        }
    )


@api_view(["GET"])
def get_activity_chart(request):
    _current_user, error = _require_audit_access(request)
    if error:
        return error

    logs = Log.objects.all()
    logs = _apply_log_filters(logs, request)

    chart = (
        logs.annotate(day=TruncDate("date"))
        .values("day")
        .annotate(count=Count("id"))
        .order_by("day")
    )

    return Response(
        [
            {
                "label": item["day"].isoformat() if item["day"] else "Unknown",
                "value": item["count"],
            }
            for item in chart
        ]
    )


@api_view(["GET"])
def get_suspicious_logs(request):
    _current_user, error = _require_audit_access(request)
    if error:
        return error

    logs = Log.objects.select_related("utilisateur").filter(
        Q(is_suspicious=True) | Q(severity="CRITICAL") | Q(action__in=SENSITIVE_ACTIONS)
    )
    logs = _apply_log_filters(logs, request).order_by("-date")[:100]
    return Response([_serialize_log(log) for log in logs])
