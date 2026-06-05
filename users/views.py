# users/views.py

from rest_framework.decorators import api_view
from rest_framework.response import Response
from notifications.models import Notification

from django.contrib.auth.hashers import make_password
from django.utils import timezone
from django.conf import settings
import random
from transactions.models import Transaction
from email_service.services import send_system_email, ResendEmailError, has_email_provider_configured

from .models import Utilisateur
from .serializers import UtilisateurSerializer

from logs.models import Log

from rest_framework_simplejwt.authentication import JWTAuthentication


# =====================================================
# ROLES
# =====================================================

def is_admin(user):

    return (
        user and
        str(user.role).strip().upper()
        in ["ADMIN", "ADMINISTRATEUR"]
    )


def is_auditeur(user):

    return (
        user and
        str(user.role).strip().upper()
        == "AUDITEUR"
    )


def is_comptable(user):

    return (
        user and
        str(user.role).strip().upper()
        == "COMPTABLE"
    )


def is_client(user):

    return (
        user and
        str(user.role).strip().upper()
        == "CLIENT"
    )


# =====================================================
# LOGS
# =====================================================

def create_log(user, action, target=None):

    try:

        suspicious_actions = [

            "DELETE_USER",

            "BAN_USER",

            "RESET_PASSWORD",

            "REJECT_TRANSACTION",

            "SUSPEND_USER"
        ]

        is_suspicious = (
            action in suspicious_actions
        )

        Log.objects.create(

            utilisateur=user,

            action=action,

            description=target,

            is_suspicious=is_suspicious
        )

        # ==========================
        # SECURITY ALERT
        # ==========================
        if is_suspicious:

            Notification.objects.create(

                utilisateur=user,

                title="ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¯ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â Security Alert",

                message=(
                    f"Suspicious action detected: {action}"
                ),

                type="danger"
            )

    except Exception as e:

        print(
            "LOG ERROR =>",
            e
        )
        send_live_notification(
    f"ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¯ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â Suspicious action detected: {action}"
)

# =====================================================
# SEND OTP
# =====================================================

def send_otp_email(user):

    try:

        otp = str(
            random.randint(100000, 999999)
        )

        user.otp_code = otp

        user.save()

        if settings.DEMO_OTP_MODE and not has_email_provider_configured():

            return otp

        send_system_email(
            to_email=user.email,
            subject="Your OTP Code",
            message=f"Your verification code is: {otp}",
            html_message=(
                f"<div style='font-family:Arial,sans-serif'>"
                f"<h2>Nexora verification</h2>"
                f"<p>Your verification code is:</p>"
                f"<p style='font-size:28px;font-weight:bold;letter-spacing:4px;'>{otp}</p>"
                f"</div>"
            )
        )

        return otp

    except ResendEmailError as e:

        print(
            "OTP ERROR =>",
            str(e)
        )

        return None
# =====================================================
# HELPERS
# =====================================================

def get_client_ip(request):

    return request.META.get(
        "REMOTE_ADDR"
    )


# =====================================================
# HELPERS
# =====================================================

def get_client_ip(request):

    return request.META.get(
        "REMOTE_ADDR"
    )

def get_current_user(request):

    try:

        jwt_auth = JWTAuthentication()

        # ==========================
        # GET HEADER
        # ==========================
        header = jwt_auth.get_header(
            request
        )
        print("HEADER =>", header)
        if header is None:

            return None, Response(
                {"error": "Token manquant"},
                status=401
            )

        # ==========================
        # GET RAW TOKEN
        # ==========================
        raw_token = jwt_auth.get_raw_token(
            header
        )
        print("RAW TOKEN =>", raw_token)
        if raw_token is None:

            return None, Response(
                {"error": "Raw token manquant"},
                status=401
            )

        # ==========================
        # VALIDATE TOKEN
        # ==========================
        validated_token = (
            jwt_auth.get_validated_token(
                raw_token
            )
        )
        print(validated_token)
        # ==========================
        # GET USER ID
        # ==========================
        user_id = None

        if "user_id" in validated_token:

            user_id = validated_token[
                "user_id"
            ]

        elif "id" in validated_token:

            user_id = validated_token[
                "id"
            ]

        elif hasattr(
            validated_token,
            "payload"
        ):

            user_id = validated_token.payload.get(
                "user_id"
            )

        if not user_id:

            return None, Response(
                {
                    "error":
                    "Invalid token payload"
                },
                status=401
            )

        # ==========================
        # GET USER
        # ==========================
        user = Utilisateur.objects.filter(
            id=int(user_id)
        ).first()

        if not user:

            return None, Response(
                {
                    "error":
                    "User not found"
                },
                status=401
            )

        # ==========================
        # ATTACH USER
        # ==========================
        request.user = user

        return user, None

    except Exception as e:

        print(
            "JWT ERROR =>",
            str(e)
        )

        return None, Response(
            {
                "error":
                "Token invalide"
            },
            status=401
        )

# =====================================================
# CHECK ADMIN
# =====================================================

@api_view(['GET'])
def check_admin_exists(request):

    exists = Utilisateur.objects.filter(
        role="ADMIN"
    ).exists()

    return Response({
        "exists": exists
    })


# =====================================================
# USERS
# =====================================================

# =====================================================
# USERS
# =====================================================

@api_view(['GET'])
def get_users(request):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    if not is_admin(current_user):

        return Response({
            "error": "AccÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨s refusÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©"
        }, status=403)

    users = Utilisateur.objects.all()

    return Response([

        {
            "id": u.id,

            "nom": u.nom,

            "prenom": getattr(
                u,
                "prenom",
                ""
            ),

            "telephone": getattr(
                u,
                "telephone",
                ""
            ),

            "bio": getattr(
                u,
                "bio",
                ""
            ),

            "avatar": (
                request.build_absolute_uri(
                    u.avatar.url
                )
                if getattr(u, "avatar", None)
                else None
            ),

            "email": u.email,

            "role": u.role,

            "is_suspended": getattr(
                u,
                "is_suspended",
                False
            ),

            "is_banned": getattr(
                u,
                "is_banned",
                False
            ),
        }

        for u in users
    ])


@api_view(['GET'])
def get_user(request, id):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    if not is_admin(current_user):

        return Response({
            "error": "AccÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨s refusÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©"
        }, status=403)

    try:

        user = Utilisateur.objects.get(id=id)

    except Utilisateur.DoesNotExist:

        return Response({
            "error": "Utilisateur introuvable"
        }, status=404)

    return Response({

        "id": user.id,

        "nom": user.nom,

        "prenom": getattr(
            user,
            "prenom",
            ""
        ),

        "telephone": getattr(
            user,
            "telephone",
            ""
        ),

        "bio": getattr(
            user,
            "bio",
            ""
        ),

        "avatar": (
            request.build_absolute_uri(
                user.avatar.url
            )
            if getattr(user, "avatar", None)
            else None
        ),

        "email": user.email,

        "role": user.role,

        "is_suspended": getattr(
            user,
            "is_suspended",
            False
        ),

        "is_banned": getattr(
            user,
            "is_banned",
            False
        ),
    })

# =====================================================
# CREATE USER
# =====================================================

@api_view(['POST'])
def create_user(request):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    if not is_admin(current_user):

        return Response({
            "error": "AccÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨s refusÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©"
        }, status=403)

    data = request.data.copy()

    # normalize email
    if "email" in data:

        data["email"] = (
            data["email"]
            .strip()
            .lower()
        )

    # hash password
    data["password"] = make_password(
        data.get("password")
    )

    serializer = UtilisateurSerializer(
        data=data
    )

    if serializer.is_valid():

        new_user = serializer.save()

        create_log(
            current_user,
            "CREATE_USER",
            f"user_id={new_user.id}"
        )

        return Response(
            serializer.data,
            status=201
        )

    return Response(
        serializer.errors,
        status=400
    )


# =====================================================
# UPDATE USER
# =====================================================

@api_view(['PUT'])
def update_user(request, id):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    if not is_admin(current_user):

        return Response({
            "error": "AccÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨s refusÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©"
        }, status=403)

    user = Utilisateur.objects.filter(
        id=id
    ).first()

    if not user:

        return Response({
            "error": "Utilisateur introuvable"
        }, status=404)

    data = request.data.copy()

    # normalize email
    if "email" in data:

        data["email"] = (
            data["email"]
            .strip()
            .lower()
        )

    # hash password
    if "password" in data and data["password"]:

        data["password"] = make_password(
            data["password"]
        )

    serializer = UtilisateurSerializer(
        user,
        data=data,
        partial=True
    )

    if serializer.is_valid():

        serializer.save()

        create_log(
            current_user,
            "UPDATE_USER",
            f"user_id={user.id}"
        )

        return Response(
            serializer.data
        )

    return Response(
        serializer.errors,
        status=400
    )


# =====================================================
# DELETE USER
# =====================================================

@api_view(['DELETE'])
def delete_user(request, id):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    if not is_admin(current_user):

        return Response({
            "error": "AccÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨s refusÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©"
        }, status=403)

    user = Utilisateur.objects.filter(
        id=id
    ).first()

    if not user:

        return Response({
            "error": "Utilisateur introuvable"
        }, status=404)

    user.delete()

    create_log(
        current_user,
        "DELETE_USER",
        f"user_id={id}"
    )

    return Response({
        "message":
        "Utilisateur supprimÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©"
    })


# =====================================================
# LOGS
# =====================================================

# =====================================================
# LOGS
# =====================================================

@api_view(['GET'])
def get_logs(request):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    if not (
        is_admin(current_user)
        or
        is_auditeur(current_user)
    ):

        return Response({
            "error": "AccÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨s refusÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©"
        }, status=403)

    # ==========================
    # QUERY PARAMS
    # ==========================
    action = request.GET.get(
        "action",
        "ALL"
    )

    start = request.GET.get(
        "start"
    )

    end = request.GET.get(
        "end"
    )

    search = request.GET.get(
        "search",
        ""
    )

    # ==========================
    # BASE QUERY
    # ==========================
    logs = Log.objects.all()

    # ==========================
    # FILTER ACTION
    # ==========================
    if action != "ALL":

        logs = logs.filter(
            action=action
        )

    # ==========================
    # FILTER START DATE
    # ==========================
    if start:

        logs = logs.filter(
            date__date__gte=start
        )

    # ==========================
    # FILTER END DATE
    # ==========================
    if end:

        logs = logs.filter(
            date__date__lte=end
        )

    # ==========================
    # SEARCH
    # ==========================
    if search:

        logs = logs.filter(
            action__icontains=search
        ) | logs.filter(
            description__icontains=search
        ) | logs.filter(
            utilisateur__nom__icontains=search
        )

    # ==========================
    # ORDER
    # ==========================
    logs = logs.order_by(
        '-date'
    )[:200]

    # ==========================
    # RESPONSE
    # ==========================
    return Response([

        {
            "id": l.id,

            "user": (
                l.utilisateur.nom
                if l.utilisateur
                else "Unknown"
            ),

            "action": l.action,

            "description": l.description,

            "date": l.date,

"is_suspicious":
l.is_suspicious
        }

        for l in logs
    ])


# =====================================================
# AUDIT
# =====================================================

@api_view(['GET'])
def get_audit(request):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    if not is_admin(current_user):

        return Response({
            "error": "AccÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨s refusÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©"
        }, status=403)

    logs = Log.objects.all()

    return Response({

        "total_logs": logs.count(),

        "create": logs.filter(
            action="CREATE_USER"
        ).count(),

        "update": logs.filter(
            action="UPDATE_USER"
        ).count(),

        "delete": logs.filter(
            action="DELETE_USER"
        ).count(),
    })


# =====================================================
# PROFILE
# =====================================================

@api_view(['GET'])
def get_my_profile(request):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    return Response({

        "id": current_user.id,

        "nom": current_user.nom,

        "prenom": getattr(
            current_user,
            "prenom",
            ""
        ),

        "telephone": getattr(
            current_user,
            "telephone",
            ""
        ),

        "bio": getattr(
            current_user,
            "bio",
            ""
        ),

        "avatar": (
            request.build_absolute_uri(
                current_user.avatar.url
            )
            if getattr(current_user, "avatar", None)
            else None
        ),

        "email": current_user.email,

        "role": current_user.role,

        "last_login":
        current_user.last_login,

        "last_ip":
        current_user.last_ip
    })


@api_view(['PUT'])
def update_my_profile(request):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    data = request.data.copy()

    # normalize email
    if "email" in data:

        data["email"] = (
            data["email"]
            .strip()
            .lower()
        )

    # hash password
    if "password" in data and data["password"]:

        data["password"] = make_password(
            data["password"]
        )

    serializer = UtilisateurSerializer(
        current_user,
        data=data,
        partial=True
    )

    if serializer.is_valid():

        serializer.save()

        create_log(
            current_user,
            "UPDATE_PROFILE",
            f"user_id={current_user.id}"
        )

        return Response(
            serializer.data
        )

    return Response(
        serializer.errors,
        status=400
    )


# =====================================================
# MY LOGS
# =====================================================

@api_view(['GET'])
def get_my_logs(request):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    logs = Log.objects.filter(
        utilisateur=current_user
    ).order_by('-date')[:50]

    return Response([

        {
            "id": l.id,

            "action": l.action,

            "description": l.description,

            "date": l.date
        }

        for l in logs
    ])


# =====================================================
# LOGIN TRACK
# =====================================================

@api_view(['POST'])
def track_login(request):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    current_user.last_login = timezone.now()

    current_user.last_ip = get_client_ip(
        request
    )

    current_user.save()

    create_log(
        current_user,
        "LOGIN",
        "User login"
    )

    return Response({
        "status": "ok"
    })


# =====================================================
# ALERTS
# =====================================================

@api_view(['GET'])
def get_my_alerts(request):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    logs = Log.objects.filter(
        utilisateur=current_user
    )

    alerts = []

    if logs.count() > 20:

        alerts.append(
            "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¯ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â High activity detected"
        )

    if logs.filter(
        action="DELETE_USER"
    ).count() > 3:

        alerts.append(
            "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â°ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨ Suspicious deletions"
        )

    if logs.filter(
        action="LOGIN"
    ).count() > 10:

        alerts.append(
            "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¯ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â Too many logins"
        )

    return Response({
        "alerts": alerts
    })


# =====================================================
# STATS
# =====================================================

@api_view(['GET'])
def get_my_stats(request):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    logs = Log.objects.filter(
        utilisateur=current_user
    )

    return Response({

        "total": logs.count(),

        "create": logs.filter(
            action="CREATE_USER"
        ).count(),

        "update": logs.filter(
            action="UPDATE_USER"
        ).count(),

        "delete": logs.filter(
            action="DELETE_USER"
        ).count(),

        "login": logs.filter(
            action="LOGIN"
        ).count()
    })


# =====================================================
# ANOMALIES
# =====================================================

@api_view(['GET'])
def detect_anomalies(request):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    if not is_admin(current_user):

        return Response({
            "error": "AccÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨s refusÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©"
        }, status=403)

    logs = Log.objects.all()

    anomalies = []

    if logs.count() > 100:

        anomalies.append(
            "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¯ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â High system activity"
        )

    if logs.filter(
        action="DELETE_USER"
    ).count() > 5:

        anomalies.append(
            "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â°ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨ Too many deletions"
        )

    if logs.filter(
        action="LOGIN"
    ).count() > 20:

        anomalies.append(
            "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¯ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â Too many logins"
        )

    return Response({
        "anomalies": anomalies
    })


# =====================================================
# SUSPICIOUS BEHAVIOR
# =====================================================

@api_view(['GET'])
def detect_suspicious_behavior(request):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    logs = Log.objects.filter(
        utilisateur=current_user
    )

    alerts = []

    total = logs.count()

    deletes = logs.filter(
        action="DELETE_USER"
    ).count()

    logins = logs.filter(
        action="LOGIN"
    ).count()

    if total > 30:

        alerts.append(
            "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¯ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â Unusual high activity"
        )

    if deletes > 3:

        alerts.append(
            "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â°ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨ Suspicious delete behavior"
        )

    if logins > 10:

        alerts.append(
            "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¯ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â Too many login attempts"
        )

    actions = logs.values_list(
        "action",
        flat=True
    )

    if list(actions).count(
        "DELETE_USER"
    ) > list(actions).count(
        "CREATE_USER"
    ):

        alerts.append(
            "ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â°ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨ More deletes than creates"
        )
    # ==========================
    # SECURITY NOTIFICATIONS
    # ==========================
    for alert in alerts:

        Notification.objects.create(

            utilisateur=current_user,

            title="Security Alert",

            message=alert,

            type="danger"
        )
    return Response({

        "alerts": alerts,

        "score": len(alerts)
    })
@api_view(['POST'])
def suspend_user(request, id):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    if not is_admin(current_user):

        return Response({
            "error": "AccÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨s refusÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©"
        }, status=403)

    user = Utilisateur.objects.filter(
        id=id
    ).first()

    if not user:

        return Response({
            "error": "Utilisateur introuvable"
        }, status=404)

    user.is_suspended = True
    user.save()

    Notification.objects.create(

        utilisateur=user,

        title="Compte suspendu",

        message="Votre compte a ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©tÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â© suspendu",

        type="warning"
    )
    from notifications.views import (
    send_live_notification
)
    send_live_notification(
    "Votre compte a ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©tÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â© suspendu"
)
    create_log(
        current_user,
        "SUSPEND_USER",
        f"user_id={user.id}"
    )

    return Response({
        "message": "Utilisateur suspendu"
    })
@api_view(['POST'])
def activate_user(request, id):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    if not is_admin(current_user):

        return Response({
            "error": "AccÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨s refusÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©"
        }, status=403)

    user = Utilisateur.objects.filter(
        id=id
    ).first()

    if not user:

        return Response({
            "error": "Utilisateur introuvable"
        }, status=404)

    user.is_suspended = False
    user.is_banned = False

    user.save()

    Notification.objects.create(

        utilisateur=user,

        title="Compte activÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©",

        message="Votre compte a ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©tÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â© activÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©",

        type="success"
    )

    create_log(
        current_user,
        "ACTIVATE_USER",
        f"user_id={user.id}"
    )

    return Response({
        "message": "Utilisateur activÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©"
    })
from notifications.views import (
    send_live_notification
)
send_live_notification(
    "Votre compte a ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©tÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â© activÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©"
)
@api_view(['POST'])
def ban_user(request, id):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    if not is_admin(current_user):

        return Response({
            "error": "AccÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨s refusÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©"
        }, status=403)

    user = Utilisateur.objects.filter(
        id=id
    ).first()

    if not user:

        return Response({
            "error": "Utilisateur introuvable"
        }, status=404)

    user.is_banned = True

    user.save()

    Notification.objects.create(

        utilisateur=user,

        title="Compte banni",

        message="Votre compte a ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©tÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â© banni",

        type="danger"
    )
    from notifications.views import (
    send_live_notification
)
    send_live_notification(
    "Votre compte a ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©tÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â© banni"
)
    create_log(
        current_user,
        "BAN_USER",
        f"user_id={user.id}"
    )

    return Response({
        "message": "Utilisateur banni"
    })

@api_view(['POST'])
def change_role(request, id):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    if not is_admin(current_user):

        return Response({
            "error": "AccÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨s refusÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©"
        }, status=403)

    user = Utilisateur.objects.filter(
        id=id
    ).first()

    if not user:

        return Response({
            "error": "Utilisateur introuvable"
        }, status=404)

    role = request.data.get(
        "role"
    )

    allowed_roles = [

        "ADMIN",
        "AUDITEUR",
        "COMPTABLE",
        "CLIENT"
    ]

    if role not in allowed_roles:

        return Response({
            "error": "RÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â´le invalide"
        }, status=400)

    user.role = role

    user.save()

    Notification.objects.create(

        utilisateur=user,

        title="RÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â´le modifiÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©",

        message=f"Nouveau rÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â´le: {role}",

        type="info"
    )

    create_log(
        current_user,
        "CHANGE_ROLE",
        f"user_id={user.id}"
    )

    return Response({
        "message": "RÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â´le modifiÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©"
    })

@api_view(['POST'])
def reset_password(request, id):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    if not is_admin(current_user):

        return Response({
            "error": "AccÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¨s refusÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©"
        }, status=403)

    user = Utilisateur.objects.filter(
        id=id
    ).first()

    if not user:

        return Response({
            "error": "Utilisateur introuvable"
        }, status=404)

    new_password = request.data.get(
        "password"
    )

    if not new_password:

        return Response({
            "error": "Password required"
        }, status=400)

    user.password = make_password(
        new_password
    )

    user.save()

    Notification.objects.create(

        utilisateur=user,

        title="Mot de passe modifiÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©",

        message="Votre mot de passe a ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©tÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â© rÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©initialisÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©",

        type="warning"
    )
    from notifications.views import (
    send_live_notification
)
    send_live_notification(
    "Password reset"
)
    create_log(
        current_user,
        "RESET_PASSWORD",
        f"user_id={user.id}"
    )

    return Response({
        "message": "Password reset"
    })

# =====================================================
# FORGOT PASSWORD
# =====================================================

@api_view(['POST'])
def forgot_password(request):

    email = request.data.get(
        "email"
    )

    if not email:

        return Response({

            "error":
            "Email required"

        }, status=400)

    user = Utilisateur.objects.filter(
        email=email
    ).first()

    if not user:

        return Response({

            "error":
            "User not found"

        }, status=404)

    otp = send_otp_email(user)

    if not otp:

        return Response({

            "error":
            "OTP email service unavailable"

        }, status=503)

    payload = {

        "message": "OTP sent to email"

    }

    if settings.DEMO_OTP_MODE:

        payload["message"] = "OTP generated (demo mode)"
        payload["otp"] = otp
        payload["demo_mode"] = True

    return Response(payload)

# =====================================================
# ACTIVITY TIMELINE
# =====================================================

@api_view(['GET'])
def get_activity_timeline(request):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    timeline = []

    # ==========================
    # LOGS
    # ==========================
    logs = Log.objects.filter(

        utilisateur=current_user

    ).order_by('-date')[:20]

    for log in logs:

        timeline.append({

            "type": "LOG",

            "action": log.action,

            "description":
            log.description,

            "date": log.date
        })

    # ==========================
    # TRANSACTIONS
    # ==========================
    transactions = Transaction.objects.filter(

        sender=current_user

    ).order_by('-created_at')[:20]

    for t in transactions:

        timeline.append({

            "type": "TRANSACTION",

            "action": t.type,

            "description":
            f"{t.type} - {t.montant}",

            "status": t.status,

            "date": t.created_at
        })

    # ==========================
    # SORT
    # ==========================
    timeline = sorted(

        timeline,

        key=lambda x: x["date"],

        reverse=True
    )

    return Response(
        timeline[:40]
    )



@api_view(['POST'])
def register_client(request):

    try:

        email = request.data.get(
            "email",
            ""
        ).strip().lower()

        if Utilisateur.objects.filter(
            email=email
        ).exists():

            return Response({
                "error": "Email already exists"
            }, status=400)

        user = Utilisateur.objects.create(

            nom=request.data.get("nom"),

            prenom="",

            telephone="",

            bio="",

            email=email,

            password=make_password(
                request.data.get("password")
            ),

            role="CLIENT"
        )

        return Response({
            "message": "Compte crÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©",
            "id": user.id
        }, status=201)

    except Exception as e:

        return Response({
            "error": str(e)
        }, status=500)
