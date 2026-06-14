from rest_framework.decorators import api_view
from rest_framework.response import Response
from django.http import HttpResponse
from email_service.services import send_system_email, EmailServiceError, has_email_provider_configured
from django.conf import settings
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth.hashers import (check_password, make_password)
from django.utils.crypto import get_random_string
from django.utils import timezone
from rest_framework_simplejwt.tokens import (AccessToken)

from datetime import timedelta

from users.models import Utilisateur

import random

OTP_EXPIRY_MINUTES = 10


def _normalize_phone(value):
    return "".join(ch for ch in str(value or "").strip() if ch.isdigit())


def _is_valid_mauritanian_phone(value):
    phone = _normalize_phone(value)
    return len(phone) == 8 and phone[0] in {"2", "3", "4"}


def _generate_otp():

    return str(
        random.randint(
            100000,
            999999
        )
    )


def _set_user_otp(user, otp):

    user.otp_code = otp
    user.otp_created_at = timezone.now()
    user.save(
        update_fields=[
            "otp_code",
            "otp_created_at",
        ]
    )


def _is_user_otp_valid(user, otp):

    if not user or not user.otp_code or not user.otp_created_at:
        return False, "OTP not found"

    expires_at = user.otp_created_at + timedelta(
        minutes=OTP_EXPIRY_MINUTES
    )

    if timezone.now() > expires_at:
        return False, "OTP expired"

    if user.otp_code != otp:
        return False, "OTP incorrect"

    return True, None


def _clear_user_otp(user):

    user.otp_code = None
    user.otp_created_at = None
    user.save(
        update_fields=[
            "otp_code",
            "otp_created_at",
        ]
    )


# ==========================================
# LOGIN
# ==========================================

@api_view(['POST'])
def logine(request):

    email = request.data.get(
        "email",
        ""
    ).strip().lower()

    password = request.data.get(
        "password",
        ""
    )

    user = Utilisateur.objects.filter(
        email__iexact=email
    ).first()

    if not user:

        return Response({

            "error":
            "User not found"

        }, status=404)

    if user.is_banned:

     return Response({

        "error":
        "Compte banni"

    }, status=403)

    if user.is_suspended:

     return Response({

        "error":
        "Compte suspendu"

    }, status=403)
    if not check_password(
        password,
        user.password
    ):

        return Response({

            "error":
            "Password incorrect"

        }, status=400)

    if user.role == "ADMIN" and not user.is_verified:
        user.is_verified = True
        user.save(update_fields=["is_verified"])

    # JWT
    refresh = RefreshToken.for_user(
        user
    )

    return Response({

        "access":
        str(refresh.access_token),

        "refresh":
        str(refresh),

        "user": {

            "id":
            user.id,

            "nom":
            user.nom,

            "prenom":
            user.prenom,

            "email":
            user.email,

            "role":
            user.role,
        }
    })


@api_view(['POST'])
def register_admin(request):

    try:
        if Utilisateur.objects.filter(role="ADMIN").exists():
            return Response({"error": "Admin already exists"}, status=403)

        email = str(request.data.get("email", "")).strip().lower()
        telephone = _normalize_phone(request.data.get("telephone", ""))

        if not _is_valid_mauritanian_phone(telephone):
            return Response(
                {
                    "error": (
                        "Numéro de téléphone invalide. Il doit contenir 8 chiffres "
                        "et commencer par 2, 3 ou 4."
                    )
                },
                status=400,
            )

        if Utilisateur.objects.filter(email=email).exists():
            return Response({"error": "Email already exists"}, status=400)

        if Utilisateur.objects.filter(telephone=telephone).exists():
            return Response({"error": "Ce numéro de téléphone est déjà utilisé."}, status=400)

        user = Utilisateur.objects.create(
            nom=request.data.get("nom"),
            prenom=request.data.get("prenom"),
            telephone=telephone,
            bio=request.data.get("bio"),
            email=email,
            password=make_password(request.data.get("password")),
            role="ADMIN",
            is_verified=True,
            is_suspended=False,
            is_banned=False,
        )

        return Response(
            {
                "message": "Compte ADMIN créé avec succès.",
                "id": user.id,
            }
        )
    except Exception as e:
        return Response({"error": str(e)}, status=500)


@api_view(['POST'])
def register(request):

    try:
        email = str(request.data.get("email", "")).strip().lower()
        telephone = _normalize_phone(request.data.get("telephone", ""))

        if Utilisateur.objects.filter(email=email).exists():
            return Response({"error": "Email already exists"}, status=400)

        if not _is_valid_mauritanian_phone(telephone):
            return Response(
                {
                    "error": (
                        "Numéro de téléphone invalide. Il doit contenir 8 chiffres "
                        "et commencer par 2, 3 ou 4."
                    )
                },
                status=400,
            )

        if Utilisateur.objects.filter(telephone=telephone).exists():
            return Response({"error": "Ce numéro de téléphone est déjà utilisé."}, status=400)

        user = Utilisateur.objects.create(
            nom=request.data.get("nom"),
            prenom=request.data.get("prenom"),
            telephone=telephone,
            bio=request.data.get("bio"),
            email=email,
            password=make_password(request.data.get("password")),
            role="CLIENT",
        )

        return Response(
            {
                "message": "Compte CLIENT créé avec succès.",
                "id": user.id,
            }
        )
    except Exception as e:
        return Response({"error": str(e)}, status=500)


# ==========================================
# REGISTER ADMIN
# ==========================================

@api_view(['POST'])
def register_admin(request):

    try:
        
            # ==========================
        # ONLY FIRST ADMIN
        # ==========================
        admin_exists = Utilisateur.objects.filter(
            role="ADMIN"
        ).exists()

        if admin_exists:

            return Response({

                "error":
                "Admin already exists"

            }, status=403)

        email = request.data.get(
            "email",
            ""
        ).strip().lower()
        telephone = _normalize_phone(
            request.data.get(
                "telephone",
                ""
            )
        )

        if not _is_valid_mauritanian_phone(telephone):

            return Response({

                "error":
                "Numéro de téléphone invalide. Il doit contenir 8 chiffres et commencer par 2, 3 ou 4."

            }, status=400)

        if Utilisateur.objects.filter(
            email=email
        ).exists():

            return Response({

                "error":
                "Email already exists"

            }, status=400)

        if not _is_valid_mauritanian_phone(telephone):

            return Response({

                "error":
                "Numéro de téléphone invalide. Il doit contenir 8 chiffres et commencer par 2, 3 ou 4."

            }, status=400)

        if Utilisateur.objects.filter(
            telephone=telephone
        ).exists():

            return Response({

                "error":
                "Ce numéro de téléphone est déjà utilisé."

            }, status=400)

        if Utilisateur.objects.filter(
            telephone=telephone
        ).exists():

            return Response({

                "error":
                "Ce numéro de téléphone est déjà utilisé."

            }, status=400)

        user = Utilisateur.objects.create(

            nom=request.data.get(
                "nom"
            ),

            prenom=request.data.get(
                "prenom"
            ),

            telephone=telephone,

            bio=request.data.get(
                "bio"
            ),

            email=email,

            password=make_password(
                request.data.get(
                    "password"
                )
            ),

            role="ADMIN",
            is_verified=True,
            is_suspended=False,
            is_banned=False,
        )

        return Response({

            "message":
            "Compte ADMIN crÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©",

            "id":
            user.id

        })

    except Exception as e:
        print("SEND OTP ERROR => ", e)
        return Response({

            "error":
            str(e)

        }, status=500)


# ==========================================
# FORGOT PASSWORD
# ==========================================

# ==========================================
# REGISTER CLIENT
# ==========================================

@api_view(['POST'])
def register(request):



    try:
        

        email = request.data.get(
            "email",
            ""
        ).strip().lower()
        telephone = _normalize_phone(
            request.data.get(
                "telephone",
                ""
            )
        )

        # ==========================
        # EMAIL EXISTS
        # ==========================
        if Utilisateur.objects.filter(
            email=email
        ).exists():

            return Response({

                "error":
                "Email already exists"

            }, status=400)

        if not _is_valid_mauritanian_phone(telephone):

            return Response({

                "error":
                "Numéro de téléphone invalide. Il doit contenir 8 chiffres et commencer par 2, 3 ou 4."

            }, status=400)

        if Utilisateur.objects.filter(
            telephone=telephone
        ).exists():

            return Response({

                "error":
                "Ce numéro de téléphone est déjà utilisé."

            }, status=400)

        # ==========================
        # CREATE CLIENT
        # ==========================
        user = Utilisateur.objects.create(

            nom=request.data.get(
                "nom"
            ),

            prenom=request.data.get(
                "prenom"
            ),

            telephone=telephone,

            bio=request.data.get(
                "bio"
            ),

            email=email,

            password=make_password(

                request.data.get(
                    "password"
                )
            ),

            role="CLIENT"
        )

        return Response({

            "message":
            "Compte CLIENT crÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©",

            "id":
            user.id

        })

    except Exception as e:

        print(
            "REGISTER ERROR =>",
            e
        )

        return Response({

            "error":
            str(e)

        }, status=500)

@api_view(['POST'])
def forgot_password(request):

    try:

        email = request.data.get(
            "email",
            ""
        ).strip().lower()

        password = request.data.get(
            "password"
        )

        user = Utilisateur.objects.filter(
            email=email
        ).first()

        if not user:

            return Response({

                "error":
                "User not found"

            }, status=404)

        user.password = make_password(
            password
        )

        user.save()

        return Response({

            "message":
            "Password updated"

        })

    except Exception as e:

        return Response({

            "error":
            str(e)

        }, status=500)


# ==========================================
# SEND OTP
# ==========================================

@api_view(['POST'])


def send_otp(request):

    try:

        email = request.data.get(
            "email",
            ""
        ).strip().lower()

        user = Utilisateur.objects.filter(
            email=email
        ).first()

        if not user:

            return Response({

                "error":
                "User not found"

            }, status=404)

        otp = _generate_otp()
        _set_user_otp(
            user,
            otp
        )

        demo_payload = None

        if settings.DEMO_OTP_MODE:

            demo_payload = {

                "message":
                "OTP generated in demo mode",

                "demo_mode":
                True,

                "otp":
                otp

            }

            if not has_email_provider_configured():

                return Response(demo_payload)

        try:

            send_system_email(

                to_email=email,

                subject="Password Reset OTP",

                message=f"Votre code OTP est : {otp}",

                html_message=(
                    f"<div style='font-family:Arial,sans-serif'>"
                    f"<h2>Nexora OTP</h2>"
                    f"<p>Votre code OTP est :</p>"
                    f"<p style='font-size:28px;font-weight:bold;letter-spacing:4px;'>{otp}</p>"
                    f"</div>"
                )
            )

        except EmailServiceError as e:

            return Response({

                "error":
                "OTP email service unavailable",

                "details":
                str(e)

            }, status=503)

        if demo_payload is not None:

            demo_payload["message"] = "OTP sent and returned in demo mode"

            return Response(demo_payload)

        return Response({

            "message":
            "OTP envoyÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©"

        })

    except Exception as e:

        print(
            "SEND OTP ERROR =>",
            str(e)
        )

        return Response({

            "error":
            str(e)

        }, status=500)

# ==========================================
# VERIFY OTP
# ==========================================

@api_view(['POST'])
def verify_otp(request):

    try:

        email = request.data.get(
            "email",
            ""
        ).strip().lower()

        otp = request.data.get(
            "otp"
        )

        password = request.data.get(
            "password"
        )

        user = Utilisateur.objects.filter(
            email=email
        ).first()

        if not user:

            return Response({

                "error":
                "User not found"

            }, status=404)

        is_valid, validation_error = _is_user_otp_valid(
            user,
            otp
        )

        if not is_valid:

            return Response({

                "error":
                validation_error

            }, status=400)

        user.password = make_password(
            password
        )

        user.otp_code = None
        user.otp_created_at = None
        user.save(
            update_fields=[
                "password",
                "otp_code",
                "otp_created_at",
            ]
        )

        return Response({

            "message":
            "Password updated"

        })

    except Exception as e:

        return Response({

            "error":
            str(e)

        }, status=500)

@api_view(['POST'])
def send_welcome_otp(request):

    try:

        email = request.data.get(
            "email",
            ""
        ).strip().lower()

        user = Utilisateur.objects.filter(
            email=email
        ).first()

        if not user:

            return Response({

                "error":
                "User not found"

            }, status=404)

        otp = _generate_otp()
        _set_user_otp(
            user,
            otp
        )

        demo_payload = None

        if settings.DEMO_OTP_MODE:

            demo_payload = {

                "message":
                "OTP generated in demo mode",

                "demo_mode":
                True,

                "otp":
                otp

            }

            if not has_email_provider_configured():

                return Response(demo_payload)

        try:

            send_system_email(

                to_email=email,

                subject="Welcome OTP",

                message=f"Votre code OTP est : {otp}",

                html_message=(
                    f"<div style='font-family:Arial,sans-serif'>"
                    f"<h2>Bienvenue sur Nexora</h2>"
                    f"<p>Votre code OTP est :</p>"
                    f"<p style='font-size:28px;font-weight:bold;letter-spacing:4px;'>{otp}</p>"
                    f"</div>"
                )
            )

        except EmailServiceError as e:

            return Response({

                "error":
                "OTP email service unavailable",

                "details":
                str(e)

            }, status=503)

        if demo_payload is not None:

            demo_payload["message"] = "OTP sent and returned in demo mode"

            return Response(demo_payload)

        return Response({

            "message":
            "OTP envoyÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©"

        })

    except Exception as e:

        return Response({

            "error":
            str(e)

        }, status=500)
    
@api_view(['POST'])
def verify_welcome_otp(request):

    try:

        email = request.data.get(
            "email",
            ""
        ).strip().lower()

        otp = request.data.get(
            "otp"
        )

        user = Utilisateur.objects.filter(
            email=email
        ).first()

        if not user:

            return Response({

                "error":
                "User not found"

            }, status=404)

        is_valid, validation_error = _is_user_otp_valid(
            user,
            otp
        )

        if not is_valid:

            return Response({

                "error":
                validation_error

            }, status=400)

        _clear_user_otp(
            user
        )

        return Response({

            "message":
            "OTP verified"

        })

    except Exception as e:

        return Response({

            "error":
            str(e)

        }, status=500)

# ==========================================
# SSO NOVA (PREPARED PLACEHOLDER)
# ==========================================

@api_view(['POST'])
def sso_nova(request):

    if not getattr(settings, "NOVA_SSO_ENABLED", False):

        return Response({

            "error":
            "Nova SSO non configure pour le moment",

            "details":
            "Ajoutez les parametres NOVA_SSO_* pour activer l'integration entreprise."

        }, status=501)

    return Response({

        "error":
        "Nova SSO pret cote backend, mais le flux OAuth/OIDC final de l'entreprise n'est pas encore branche.",

        "required_config": {
            "client_id": bool(getattr(settings, "NOVA_SSO_CLIENT_ID", "")),
            "client_secret": bool(getattr(settings, "NOVA_SSO_CLIENT_SECRET", "")),
            "authorize_url": bool(getattr(settings, "NOVA_SSO_AUTHORIZE_URL", "")),
            "token_url": bool(getattr(settings, "NOVA_SSO_TOKEN_URL", "")),
            "userinfo_url": bool(getattr(settings, "NOVA_SSO_USERINFO_URL", "")),
            "redirect_uri": bool(getattr(settings, "NOVA_SSO_REDIRECT_URI", "")),
        }

    }, status=501)


@api_view(['GET'])
def sso_nova_callback(request):

    code = request.GET.get("code", "")
    state = request.GET.get("state", "")
    error = request.GET.get("error", "")
    error_description = request.GET.get("error_description", "")

    if error:
        return HttpResponse(
            (
                "<html><body style='font-family:Arial,sans-serif;padding:32px;'>"
                "<h2>Retour Nova SSO</h2>"
                f"<p><strong>Erreur :</strong> {error}</p>"
                f"<p><strong>Description :</strong> {error_description or 'Aucune description'}</p>"
                "<p>Le callback fonctionne, mais l'authentification a ete refusee ou interrompue.</p>"
                "</body></html>"
            ),
            content_type="text/html; charset=utf-8",
            status=400,
        )

    if not code:
        return HttpResponse(
            (
                "<html><body style='font-family:Arial,sans-serif;padding:32px;'>"
                "<h2>Retour Nova SSO</h2>"
                "<p>Aucun code d'autorisation n'a ete recu.</p>"
                "<p>Le callback backend est bien accessible, mais Nova n'a pas renvoye de code OAuth.</p>"
                "</body></html>"
            ),
            content_type="text/html; charset=utf-8",
            status=400,
        )

    return HttpResponse(
        (
            "<html><body style='font-family:Arial,sans-serif;padding:32px;'>"
            "<h2>Retour Nova SSO</h2>"
            "<p>Le callback backend fonctionne correctement.</p>"
            f"<p><strong>Code recu :</strong> {code}</p>"
            f"<p><strong>State :</strong> {state or 'Non fourni'}</p>"
            "<p>Prochaine etape : echanger ce code contre un token OAuth dans l'integration finale.</p>"
            "</body></html>"
        ),
        content_type="text/html; charset=utf-8",
        status=200,
    )
