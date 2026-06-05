from rest_framework.decorators import api_view
from rest_framework.response import Response
from email_service.services import send_system_email, ResendEmailError
from django.conf import settings
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth.hashers import (check_password, make_password)
from django.utils.crypto import get_random_string
from rest_framework_simplejwt.tokens import (AccessToken)

from datetime import timedelta

from users.models import Utilisateur

import random

from google.oauth2 import id_token as google_id_token
from google.auth.transport import requests as google_requests


OTP_STORAGE = {}


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

        if Utilisateur.objects.filter(
            email=email
        ).exists():

            return Response({

                "error":
                "Email already exists"

            }, status=400)

        user = Utilisateur.objects.create(

            nom=request.data.get(
                "nom"
            ),

            prenom=request.data.get(
                "prenom"
            ),

            telephone=request.data.get(
                "telephone"
            ),

            bio=request.data.get(
                "bio"
            ),

            email=email,

            password=make_password(
                request.data.get(
                    "password"
                )
            ),

            role="ADMIN"
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

            telephone=request.data.get(
                "telephone"
            ),

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

        otp = str(

            random.randint(
                100000,
                999999
            )
        )

        OTP_STORAGE[email] = otp

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

        except ResendEmailError as e:

            return Response({

                "error":
                "OTP email service unavailable",

                "details":
                str(e)

            }, status=503)

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

        if email not in OTP_STORAGE:

            return Response({

                "error":
                "OTP not found"

            }, status=400)

        if OTP_STORAGE[email] != otp:

            return Response({

                "error":
                "OTP incorrect"

            }, status=400)

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

        del OTP_STORAGE[email]

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

        otp = str(
            random.randint(
                100000,
                999999
            )
        )

        OTP_STORAGE[email] = otp

        print(
            f"OTP for {email} => {otp}"
        )

        return Response({

            "message":
            "OTP envoyÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â©",

            "otp":
            otp

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

        if email not in OTP_STORAGE:

            return Response({

                "error":
                "OTP not found"

            }, status=400)

        if OTP_STORAGE[email] != otp:

            return Response({

                "error":
                "OTP incorrect"

            }, status=400)

        del OTP_STORAGE[email]

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
# SSO GOOGLE (ID TOKEN -> JWT)
# ==========================================

@api_view(['POST'])
def sso_google(request):

    if not getattr(settings, "GOOGLE_OAUTH2_CLIENT_ID", ""):

        return Response({

            "error":
            "SSO not configured (missing GOOGLE_OAUTH2_CLIENT_ID)"

        }, status=500)

    token = request.data.get(
        "id_token",
        ""
    ).strip()

    if not token:

        return Response({

            "error":
            "id_token is required"

        }, status=400)

    try:

        info = google_id_token.verify_oauth2_token(

            token,

            google_requests.Request(),

            settings.GOOGLE_OAUTH2_CLIENT_ID,
        )

    except Exception:

        return Response({

            "error":
            "Invalid Google token"

        }, status=401)

    email = (info.get(
        "email"
    ) or "").strip().lower()

    if not email:

        return Response({

            "error":
            "Google token missing email"

        }, status=400)

    user = Utilisateur.objects.filter(
        email__iexact=email
    ).first()

    if not user:

        user = Utilisateur.objects.create(

            nom=(info.get(
                "family_name"
            ) or info.get(
                "name"
            ) or "").strip() or "GoogleUser",

            prenom=(info.get(
                "given_name"
            ) or "").strip() or None,

            email=email,

            password=make_password(
                get_random_string(
                    48
                )
            ),

            role="CLIENT",

            is_verified=True,
        )

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