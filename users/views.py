from django.conf import settings
from django.contrib.auth.hashers import make_password
from django.db.models import Q
from django.utils import timezone
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework_simplejwt.authentication import JWTAuthentication

from email_service.services import (
    EmailServiceError,
    has_email_provider_configured,
    send_system_email,
)
from logs.models import Log
from notifications.models import Notification
from transactions.models import Transaction
try:
    from apps.core.security_middleware import (
        get_security_status_snapshot,
        log_security_event,
    )
except Exception:
    get_security_status_snapshot = None
    log_security_event = None

from .models import Utilisateur
from .serializers import UtilisateurSerializer


ROLE_ALIASES = {
    "ADMINISTRATEUR": "ADMIN",
}

MANAGEABLE_ROLES = {
    "ADMIN",
    "AUDITEUR",
    "COMPTABLE",
    "CLIENT",
}

SUSPICIOUS_ACTIONS = {
    "DELETE_USER",
    "BAN_USER",
    "RESET_PASSWORD",
    "REJECT_TRANSACTION",
    "SUSPEND_USER",
}

CRITICAL_ACTIONS = {
    "DELETE_USER",
    "BAN_USER",
    "RESET_PASSWORD",
    "APPROVE_TRANSACTION",
    "REJECT_TRANSACTION",
    "APPROVE_KYC",
    "REJECT_KYC",
}

SOC_MIRRORED_ACTIONS = {
    "DELETE_USER",
    "SUSPEND_USER",
    "BAN_USER",
    "CHANGE_ROLE",
    "RESET_PASSWORD",
    "APPROVE_KYC",
    "REJECT_KYC",
    "CREATE_TRANSACTION",
    "APPROVE_TRANSACTION",
    "REJECT_TRANSACTION",
    "SUBMIT_KYC",
}


def normalize_role(role):
    if role is None:
        return None

    normalized = str(role).strip().upper()
    return ROLE_ALIASES.get(normalized, normalized)


def has_role(user, *roles):
    return bool(user) and normalize_role(getattr(user, "role", None)) in {
        normalize_role(role) for role in roles
    }


def is_admin(user):
    return has_role(user, "ADMIN")


def is_auditeur(user):
    return has_role(user, "AUDITEUR")


def is_comptable(user):
    return has_role(user, "COMPTABLE")


def is_client(user):
    return has_role(user, "CLIENT")


def normalize_phone(value):
    return "".join(ch for ch in str(value or "").strip() if ch.isdigit())


def is_valid_mauritanian_phone(value):
    phone = normalize_phone(value)
    return len(phone) == 8 and phone[0] in {"2", "3", "4"}


def _error(message, status=400):
    return Response({"error": message}, status=status)


def _build_media_url(request, field):
    if not field:
        return None

    try:
        url = field.url
    except Exception:
        return None

    if request is None:
        return url

    return request.build_absolute_uri(url)


def _get_role_label(role):
    for code, label in Utilisateur.ROLE_CHOICES:
        if normalize_role(code) == normalize_role(role):
            return label
    return role


def _get_account_status(user):
    if getattr(user, "is_banned", False):
        return "BANNED"
    if getattr(user, "is_suspended", False):
        return "SUSPENDED"
    if getattr(user, "is_verified", False):
        return "VERIFIED"
    if is_client(user):
        return "INACTIVE"
    return "ACTIVE"


def serialize_user(user, request=None):
    full_name = " ".join(
        part for part in [user.nom, user.prenom or ""] if part
    ).strip()

    return {
        "id": user.id,
        "nom": user.nom,
        "prenom": user.prenom or "",
        "full_name": full_name or user.nom,
        "telephone": user.telephone or "",
        "bio": user.bio or "",
        "avatar": _build_media_url(request, getattr(user, "avatar", None)),
        "email": user.email,
        "role": normalize_role(user.role),
        "role_label": _get_role_label(user.role),
        "balance": user.balance,
        "is_verified": user.is_verified,
        "is_suspended": user.is_suspended,
        "is_banned": user.is_banned,
        "status": _get_account_status(user),
        "can_use_services": (
            not user.is_banned
            and not user.is_suspended
            and (not is_client(user) or user.is_verified)
        ),
        "last_login": user.last_login,
        "last_logout": user.last_logout,
        "last_ip": user.last_ip,
    }


def _send_live_notification(message):
    try:
        from notifications.views import send_live_notification

        send_live_notification(message)
    except Exception:
        pass


def _notify_user(user, title, message, notification_type="info", live_message=None):
    Notification.objects.create(
        utilisateur=user,
        title=title,
        message=message,
        type=notification_type,
    )

    _send_live_notification(live_message or message)


def create_log(
    user,
    action,
    target=None,
    *,
    entity_type="",
    entity_id="",
    target_repr="",
    severity=None,
    metadata=None,
):
    try:
        is_suspicious = action in SUSPICIOUS_ACTIONS
        final_severity = severity or (
            "CRITICAL" if action in CRITICAL_ACTIONS else
            "WARNING" if is_suspicious else
            "INFO"
        )

        payload = metadata or {}

        Log.objects.create(
            utilisateur=user,
            action=action,
            description=target or "",
            entity_type=entity_type,
            entity_id=str(entity_id or ""),
            target_repr=target_repr,
            severity=final_severity,
            metadata=payload,
            is_suspicious=is_suspicious,
        )

        if is_suspicious and user:
            _notify_user(
                user,
                "Security Alert",
                f"Suspicious action detected: {action}",
                "danger",
            )

        should_mirror_to_soc = action in SOC_MIRRORED_ACTIONS or is_suspicious
        if should_mirror_to_soc and log_security_event:
            ip_address = (
                payload.get("ip")
                or payload.get("client_ip")
                or ""
            )
            log_security_event(
                action,
                ip_address or "internal",
                extra={
                    "severity": final_severity,
                    "entity_type": entity_type,
                    "entity_id": str(entity_id or ""),
                    "target": target_repr or "",
                    "description": target or "",
                    "actor_email": getattr(user, "email", "") if user else "",
                    "actor_id": getattr(user, "id", None) if user else None,
                    "metadata": payload,
                },
            )
    except Exception:
        pass


def send_otp_email(user):
    try:
        otp = str(__import__("random").randint(100000, 999999))
        user.otp_code = otp
        user.otp_created_at = timezone.now()
        user.save(update_fields=["otp_code", "otp_created_at"])

        if settings.DEMO_OTP_MODE and not has_email_provider_configured():
            return otp

        send_system_email(
            to_email=user.email,
            subject="Your OTP Code",
            message=f"Your verification code is: {otp}",
            html_message=(
                "<div style='font-family:Arial,sans-serif'>"
                "<h2>Nexora verification</h2>"
                "<p>Your verification code is:</p>"
                f"<p style='font-size:28px;font-weight:bold;letter-spacing:4px;'>{otp}</p>"
                "</div>"
            ),
        )
        return otp
    except EmailServiceError:
        return None


def get_client_ip(request):
    forwarded = request.META.get("HTTP_X_FORWARDED_FOR")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.META.get("REMOTE_ADDR")


def get_current_user(request):
    try:
        jwt_auth = JWTAuthentication()
        header = jwt_auth.get_header(request)
        if header is None:
            return None, _error("Token manquant", 401)

        raw_token = jwt_auth.get_raw_token(header)
        if raw_token is None:
            return None, _error("Token invalide", 401)

        validated_token = jwt_auth.get_validated_token(raw_token)
        user_id = (
            validated_token.get("user_id")
            or validated_token.get("id")
            or getattr(validated_token, "payload", {}).get("user_id")
        )

        if not user_id:
            return None, _error("Token invalide", 401)

        user = Utilisateur.objects.filter(id=int(user_id)).first()
        if not user:
            return None, _error("Utilisateur introuvable", 401)

        request.user = user
        return user, None
    except Exception:
        return None, _error("Token invalide", 401)


def _require_auth(request):
    return get_current_user(request)


def _require_admin(request):
    current_user, error = _require_auth(request)
    if error:
        return None, error
    if not is_admin(current_user):
        return None, _error("Accès refusé", 403)
    return current_user, None


def _get_manageable_roles():
    existing_roles = {
        normalize_role(code) for code, _label in Utilisateur.ROLE_CHOICES
    }
    return sorted(existing_roles.intersection(MANAGEABLE_ROLES))


def _parse_bool(value):
    if value is None:
        return None
    return str(value).strip().lower() in {"1", "true", "yes", "oui"}


def _find_user_or_404(user_id):
    user = Utilisateur.objects.filter(id=user_id).first()
    if not user:
        return None, _error("Utilisateur introuvable", 404)
    return user, None


def _user_search_queryset(search):
    if not search:
        return Q()

    return (
        Q(nom__icontains=search)
        | Q(prenom__icontains=search)
        | Q(email__icontains=search)
        | Q(telephone__icontains=search)
    )


@api_view(["GET"])
def check_admin_exists(request):
    exists = Utilisateur.objects.filter(role__in=["ADMIN", "ADMINISTRATEUR"]).exists()
    return Response({"exists": exists})


@api_view(["GET"])
def get_users(request):
    current_user, error = _require_admin(request)
    if error:
        return error

    search = request.GET.get("search", "").strip()
    role = normalize_role(request.GET.get("role"))
    status = normalize_role(request.GET.get("status"))
    verified = _parse_bool(request.GET.get("verified"))

    users = Utilisateur.objects.all().order_by("-id")

    if search:
        users = users.filter(_user_search_queryset(search))

    if role and role != "ALL":
        users = users.filter(role=role)

    if status and status != "ALL":
        if status == "BANNED":
            users = users.filter(is_banned=True)
        elif status == "SUSPENDED":
            users = users.filter(is_suspended=True, is_banned=False)
        elif status == "VERIFIED":
            users = users.filter(is_verified=True, is_banned=False, is_suspended=False)
        elif status == "ACTIVE":
            users = users.filter(is_banned=False, is_suspended=False)

    if verified is not None:
        users = users.filter(is_verified=verified)

    return Response([serialize_user(user, request) for user in users])


@api_view(["GET"])
def get_user(request, id):
    current_user, error = _require_admin(request)
    if error:
        return error

    user, error = _find_user_or_404(id)
    if error:
        return error

    return Response(serialize_user(user, request))


@api_view(["POST"])
def create_user(request):
    current_user, error = _require_admin(request)
    if error:
        return error

    data = request.data.copy()
    email = str(data.get("email", "")).strip().lower()
    password = data.get("password")
    role = normalize_role(data.get("role"))

    if not email or not password or not data.get("nom"):
        return _error("Les champs nom, email et mot de passe sont obligatoires.", 400)

    if role not in _get_manageable_roles():
        return _error("Rôle invalide.", 400)

    if Utilisateur.objects.filter(email=email).exists():
        return _error("Cet email est déjà utilisé.", 400)

    data["email"] = email
    data["role"] = role
    data["password"] = make_password(password)

    serializer = UtilisateurSerializer(data=data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=400)

    new_user = serializer.save()
    create_log(
        current_user,
        "CREATE_USER",
        f"user_id={new_user.id}",
        entity_type="USER",
        entity_id=new_user.id,
        target_repr=new_user.email,
        metadata={"role": new_user.role},
    )

    return Response(serialize_user(new_user, request), status=201)


@api_view(["PUT"])
def update_user(request, id):
    current_user, error = _require_admin(request)
    if error:
        return error

    user, error = _find_user_or_404(id)
    if error:
        return error

    data = request.data.copy()
    if "email" in data:
        data["email"] = str(data["email"]).strip().lower()

    if "role" in data:
        data["role"] = normalize_role(data["role"])
        if data["role"] not in _get_manageable_roles():
            return _error("Rôle invalide.", 400)

    if data.get("password"):
        data["password"] = make_password(data["password"])
    else:
        data.pop("password", None)

    previous_role = user.role
    previous_email = user.email

    serializer = UtilisateurSerializer(user, data=data, partial=True)
    if not serializer.is_valid():
        return Response(serializer.errors, status=400)

    serializer.save()
    create_log(
        current_user,
        "UPDATE_USER",
        f"user_id={user.id}",
        entity_type="USER",
        entity_id=user.id,
        target_repr=user.email,
        metadata={
            "previous_role": previous_role,
            "new_role": user.role,
            "previous_email": previous_email,
            "new_email": user.email,
        },
    )

    return Response(serialize_user(user, request))


@api_view(["DELETE", "POST"])
def delete_user(request, id):
    current_user, error = _require_admin(request)
    if error:
        return error

    user, error = _find_user_or_404(id)
    if error:
        return error

    if user.id == current_user.id:
        return _error("Vous ne pouvez pas supprimer votre propre compte.", 409)

    if is_admin(user):
        admin_count = Utilisateur.objects.filter(
            role__in=["ADMIN", "ADMINISTRATEUR"]
        ).count()
        if admin_count <= 1:
            return _error(
                "Impossible de supprimer le dernier administrateur de la plateforme.",
                409,
            )

    user.delete()
    create_log(
        current_user,
        "DELETE_USER",
        f"user_id={id}",
        entity_type="USER",
        entity_id=id,
        target_repr=user.email,
    )

    return Response({"message": "Utilisateur supprimé avec succès."})


@api_view(["GET"])
def get_logs(request):
    current_user, error = _require_auth(request)
    if error:
        return error

    if not (is_admin(current_user) or is_auditeur(current_user)):
        return _error("Accès refusé", 403)

    search = request.GET.get("search", "").strip()
    action = request.GET.get("action", "ALL").strip().upper()
    start = request.GET.get("start")
    end = request.GET.get("end")
    suspicious = _parse_bool(request.GET.get("suspicious"))

    logs = Log.objects.select_related("utilisateur").all()

    if action and action != "ALL":
        logs = logs.filter(action=action)
    if start:
        logs = logs.filter(date__date__gte=start)
    if end:
        logs = logs.filter(date__date__lte=end)
    if search:
        logs = logs.filter(
            Q(action__icontains=search)
            | Q(description__icontains=search)
            | Q(utilisateur__nom__icontains=search)
            | Q(utilisateur__email__icontains=search)
        )
    if suspicious is not None:
        logs = logs.filter(is_suspicious=suspicious)

    logs = logs.order_by("-date")[:200]

    return Response(
        [
            {
                "id": log.id,
                "user": log.utilisateur.nom if log.utilisateur else "Unknown",
                "action": log.action,
                "description": log.description,
                "date": log.date,
                "is_suspicious": log.is_suspicious,
            }
            for log in logs
        ]
    )


@api_view(["GET"])
def get_audit(request):
    current_user, error = _require_admin(request)
    if error:
        return error

    logs = Log.objects.all()

    return Response(
        {
            "total_logs": logs.count(),
            "create": logs.filter(action="CREATE_USER").count(),
            "update": logs.filter(action="UPDATE_USER").count(),
            "delete": logs.filter(action="DELETE_USER").count(),
            "suspicious": logs.filter(is_suspicious=True).count(),
            "recent_logins": logs.filter(action="LOGIN").count(),
        }
    )


@api_view(["GET"])
def get_my_profile(request):
    current_user, error = _require_auth(request)
    if error:
        return error

    return Response(serialize_user(current_user, request))


@api_view(["PUT"])
def update_my_profile(request):
    current_user, error = _require_auth(request)
    if error:
        return error

    allowed_fields = {"nom", "prenom", "email", "telephone", "bio", "avatar", "password"}
    data = {key: value for key, value in request.data.items() if key in allowed_fields}

    if "email" in data:
        data["email"] = str(data["email"]).strip().lower()

    if "telephone" in data:
        data["telephone"] = normalize_phone(data["telephone"])
        if data["telephone"] and not is_valid_mauritanian_phone(data["telephone"]):
            return _error(
                "Numéro de téléphone invalide. Il doit contenir 8 chiffres et commencer par 2, 3 ou 4.",
                400,
            )
        if data["telephone"] and Utilisateur.objects.exclude(id=current_user.id).filter(
            telephone=data["telephone"]
        ).exists():
            return _error("Ce numéro de téléphone est déjà utilisé.", 400)

    if data.get("password"):
        data["password"] = make_password(data["password"])
    else:
        data.pop("password", None)

    serializer = UtilisateurSerializer(current_user, data=data, partial=True)
    if not serializer.is_valid():
        return Response(serializer.errors, status=400)

    serializer.save()
    create_log(
        current_user,
        "UPDATE_PROFILE",
        f"user_id={current_user.id}",
        entity_type="USER",
        entity_id=current_user.id,
        target_repr=current_user.email,
    )

    return Response(serialize_user(current_user, request))


@api_view(["GET"])
def get_my_logs(request):
    current_user, error = _require_auth(request)
    if error:
        return error

    logs = Log.objects.filter(utilisateur=current_user).order_by("-date")[:50]
    return Response(
        [
            {
                "id": log.id,
                "action": log.action,
                "description": log.description,
                "date": log.date,
                "is_suspicious": log.is_suspicious,
            }
            for log in logs
        ]
    )


@api_view(["GET"])
def get_my_alerts(request):
    current_user, error = _require_auth(request)
    if error:
        return error

    logs = Log.objects.filter(utilisateur=current_user)
    alerts = []

    if logs.count() > 20:
        alerts.append("Activité élevée détectée sur votre compte.")
    if logs.filter(action="DELETE_USER").count() > 3:
        alerts.append("Plusieurs suppressions ont été détectées.")
    if logs.filter(action="LOGIN").count() > 10:
        alerts.append("Le nombre de connexions est inhabituel.")

    return Response({"alerts": alerts})


@api_view(["GET"])
def get_my_stats(request):
    current_user, error = _require_auth(request)
    if error:
        return error

    logs = Log.objects.filter(utilisateur=current_user)
    return Response(
        {
            "total": logs.count(),
            "create": logs.filter(action="CREATE_USER").count(),
            "update": logs.filter(action="UPDATE_USER").count(),
            "delete": logs.filter(action="DELETE_USER").count(),
            "login": logs.filter(action="LOGIN").count(),
        }
    )


@api_view(["GET"])
def detect_anomalies(request):
    current_user, error = _require_admin(request)
    if error:
        return error

    logs = Log.objects.all()
    anomalies = []

    if logs.count() > 100:
        anomalies.append("L'activité du système est très élevée.")
    if logs.filter(action="DELETE_USER").count() > 5:
        anomalies.append("Le nombre de suppressions est anormalement élevé.")
    if logs.filter(action="LOGIN").count() > 20:
        anomalies.append("Le nombre de connexions est anormalement élevé.")

    return Response({"anomalies": anomalies})


@api_view(["GET"])
def detect_suspicious_behavior(request):
    current_user, error = _require_auth(request)
    if error:
        return error

    logs = Log.objects.filter(utilisateur=current_user)
    alerts = []
    deletes = logs.filter(action="DELETE_USER").count()
    logins = logs.filter(action="LOGIN").count()

    if logs.count() > 30:
        alerts.append("Activité inhabituelle détectée.")
    if deletes > 3:
        alerts.append("Comportement de suppression suspect détecté.")
    if logins > 10:
        alerts.append("Trop de tentatives de connexion détectées.")

    for alert in alerts:
        Notification.objects.create(
            utilisateur=current_user,
            title="Alerte de sécurité",
            message=alert,
            type="danger",
        )

    return Response({"alerts": alerts, "score": len(alerts)})


@api_view(["POST"])
def track_login(request):
    current_user, error = _require_auth(request)
    if error:
        return error

    current_user.last_login = timezone.now()
    current_user.last_ip = get_client_ip(request)
    current_user.save(update_fields=["last_login", "last_ip"])

    create_log(
        current_user,
        "LOGIN",
        "User login",
        entity_type="USER",
        entity_id=current_user.id,
        target_repr=current_user.email,
        metadata={"ip": current_user.last_ip or ""},
    )
    return Response({"status": "ok"})


@api_view(["POST"])
def suspend_user(request, id):
    current_user, error = _require_admin(request)
    if error:
        return error

    user, error = _find_user_or_404(id)
    if error:
        return error

    if user.id == current_user.id:
        return _error("Vous ne pouvez pas suspendre votre propre compte.", 400)

    user.is_suspended = True
    user.save(update_fields=["is_suspended"])

    _notify_user(user, "Compte suspendu", "Votre compte a été suspendu.", "warning")
    create_log(
        current_user,
        "SUSPEND_USER",
        f"user_id={user.id}",
        entity_type="USER",
        entity_id=user.id,
        target_repr=user.email,
        metadata={"user_id": user.id},
    )

    return Response({"message": "Utilisateur suspendu avec succès."})


@api_view(["POST"])
def activate_user(request, id):
    current_user, error = _require_admin(request)
    if error:
        return error

    user, error = _find_user_or_404(id)
    if error:
        return error

    update_fields = ["is_suspended", "is_banned"]
    user.is_suspended = False
    user.is_banned = False

    if is_client(user) and not user.is_verified:
        try:
            from kyc.models import KYCRequest

            has_approved_kyc = KYCRequest.objects.filter(
                utilisateur=user,
                status="APPROVED",
            ).exists()
        except Exception:
            has_approved_kyc = False

        if not has_approved_kyc:
            return _error(
                "Impossible d'activer ce client sans KYC approuvé. Approuvez d'abord sa demande KYC.",
                400,
            )

        user.is_verified = True
        update_fields.append("is_verified")

    user.save(update_fields=update_fields)

    _notify_user(user, "Compte activé", "Votre compte a été réactivé.", "success")
    create_log(
        current_user,
        "ACTIVATE_USER",
        f"user_id={user.id}",
        entity_type="USER",
        entity_id=user.id,
        target_repr=user.email,
        metadata={"user_id": user.id},
    )

    return Response({"message": "Utilisateur réactivé avec succès."})


@api_view(["POST"])
def ban_user(request, id):
    current_user, error = _require_admin(request)
    if error:
        return error

    user, error = _find_user_or_404(id)
    if error:
        return error

    if user.id == current_user.id:
        return _error("Vous ne pouvez pas bannir votre propre compte.", 400)

    user.is_banned = True
    user.save(update_fields=["is_banned"])

    _notify_user(user, "Compte banni", "Votre compte a été banni.", "danger")
    create_log(
        current_user,
        "BAN_USER",
        f"user_id={user.id}",
        entity_type="USER",
        entity_id=user.id,
        target_repr=user.email,
        metadata={"user_id": user.id},
    )

    return Response({"message": "Utilisateur banni avec succès."})


@api_view(["POST"])
def change_role(request, id):
    current_user, error = _require_admin(request)
    if error:
        return error

    user, error = _find_user_or_404(id)
    if error:
        return error

    if user.id == current_user.id:
        return _error("Vous ne pouvez pas modifier votre propre rôle.", 400)

    role = normalize_role(request.data.get("role"))
    if role not in _get_manageable_roles():
        return _error("Rôle invalide.", 400)

    if is_client(user) and not user.is_verified and role != "CLIENT":
        return _error(
            "Impossible de changer le rôle d'un client non vérifié.",
            400,
        )

    previous_role = user.role
    user.role = role
    user.save(update_fields=["role"])

    _notify_user(
        user,
        "Rôle modifié",
        f"Votre rôle est maintenant: {role}.",
        "info",
    )
    create_log(
        current_user,
        "CHANGE_ROLE",
        f"user_id={user.id};role={role}",
        entity_type="USER",
        entity_id=user.id,
        target_repr=user.email,
        metadata={"previous_role": previous_role, "new_role": role},
    )

    return Response({"message": "Rôle modifié avec succès.", "role": role})


@api_view(["POST"])
def reset_password(request, id):
    current_user, error = _require_admin(request)
    if error:
        return error

    user, error = _find_user_or_404(id)
    if error:
        return error

    new_password = request.data.get("password")
    if not new_password:
        return _error("Le nouveau mot de passe est requis.", 400)

    user.password = make_password(new_password)
    user.save(update_fields=["password"])

    _notify_user(
        user,
        "Mot de passe réinitialisé",
        "Votre mot de passe a été réinitialisé par un administrateur.",
        "warning",
        "Password reset",
    )
    create_log(
        current_user,
        "RESET_PASSWORD",
        f"user_id={user.id}",
        entity_type="USER",
        entity_id=user.id,
        target_repr=user.email,
        metadata={"user_id": user.id, "reset_by": current_user.id},
    )

    return Response({"message": "Mot de passe réinitialisé avec succès."})


@api_view(["POST"])
def forgot_password(request):
    email = str(request.data.get("email", "")).strip().lower()
    if not email:
        return _error("Email requis.", 400)

    user = Utilisateur.objects.filter(email=email).first()
    if not user:
        return _error("Utilisateur introuvable.", 404)

    otp = send_otp_email(user)
    if not otp:
        return _error("Le service OTP est indisponible pour le moment.", 503)

    payload = {"message": "OTP envoyé par email."}
    if settings.DEMO_OTP_MODE and not has_email_provider_configured():
        payload.update(
            {
                "message": "OTP généré en mode démonstration.",
                "otp": otp,
                "demo_mode": True,
            }
        )

    return Response(payload)


@api_view(["GET"])
def get_activity_timeline(request):
    current_user, error = _require_auth(request)
    if error:
        return error

    timeline = []

    logs = Log.objects.filter(utilisateur=current_user).order_by("-date")[:20]
    for log in logs:
        timeline.append(
            {
                "type": "LOG",
                "action": log.action,
                "description": log.description,
                "date": log.date,
            }
        )

    transactions = Transaction.objects.filter(
        Q(sender=current_user) | Q(receiver=current_user)
    ).order_by("-created_at")[:20]

    for transaction in transactions:
        timeline.append(
            {
                "type": "TRANSACTION",
                "action": transaction.type,
                "description": f"{transaction.type} - {transaction.montant}",
                "status": transaction.status,
                "date": transaction.created_at,
            }
        )

    timeline.sort(key=lambda item: item["date"], reverse=True)
    return Response(timeline[:40])


@api_view(["GET"])
def get_security_status(request):
    current_user, error = _require_auth(request)
    if error:
        return error

    if not (is_admin(current_user) or is_auditeur(current_user)):
        return _error("Accès refusé", 403)

    logs = Log.objects.all()
    suspicious_logs = logs.filter(is_suspicious=True)
    critical_logs = logs.filter(severity="CRITICAL")
    today = timezone.now().date()

    snapshot = (
        get_security_status_snapshot()
        if get_security_status_snapshot
        else {
            "app_name": "nexora-api",
            "soc_url": "",
            "environment": "unknown",
            "block_attacks": False,
            "ban_duration": 0,
            "local_logs": "",
            "email_alerts": False,
            "active_banned_ips": 0,
            "worker_started": False,
        }
    )

    return Response(
        {
            "soc": snapshot,
            "overview": {
                "total_logs": logs.count(),
                "suspicious_logs": suspicious_logs.count(),
                "critical_logs": critical_logs.count(),
                "today_suspicious": suspicious_logs.filter(date__date=today).count(),
                "today_critical": critical_logs.filter(date__date=today).count(),
            },
            "suspicious_actions": sorted(SUSPICIOUS_ACTIONS),
            "critical_actions": sorted(CRITICAL_ACTIONS),
        }
    )


@api_view(["POST"])
def register_client(request):
    try:
        email = str(request.data.get("email", "")).strip().lower()
        password = request.data.get("password")
        nom = str(request.data.get("nom", "")).strip()
        telephone = normalize_phone(request.data.get("telephone", ""))

        if not nom or not email or not password:
            return _error("Les champs nom, email et mot de passe sont obligatoires.", 400)

        if not is_valid_mauritanian_phone(telephone):
            return _error(
                "Numéro de téléphone invalide. Il doit contenir 8 chiffres et commencer par 2, 3 ou 4.",
                400,
            )

        if Utilisateur.objects.filter(email=email).exists():
            return _error("Cet email est déjà utilisé.", 400)

        if Utilisateur.objects.filter(telephone=telephone).exists():
            return _error("Ce numéro de téléphone est déjà utilisé.", 400)

        user = Utilisateur.objects.create(
            nom=nom,
            prenom=str(request.data.get("prenom", "")).strip(),
            telephone=telephone,
            bio="",
            email=email,
            password=make_password(password),
            role="CLIENT",
        )

        return Response(
            {
                "message": "Compte client créé avec succès.",
                "id": user.id,
            },
            status=201,
        )
    except Exception as exc:
        return _error(str(exc), 500)
