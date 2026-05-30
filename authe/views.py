from rest_framework.decorators import api_view
from rest_framework.response import Response
from django.core.mail import send_mail
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth.hashers import (check_password, make_password)
from rest_framework_simplejwt.tokens import (AccessToken)

from datetime import timedelta

from users.models import Utilisateur

import random


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
            "Compte ADMIN créé",

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
            "Compte CLIENT créé",

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

        # ==========================
        # SEND EMAIL
        # ==========================
        send_mail(

            "Password Reset OTP",

            f"Votre code OTP est : {otp}",

            None,

            [email],

            fail_silently=False
        )

        return Response({

            "message":
            "OTP envoyé"

        })

    except Exception as e:

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
            "OTP envoyé",

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