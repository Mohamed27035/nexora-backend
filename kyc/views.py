from rest_framework.decorators import api_view
from rest_framework.response import Response
from django.utils import timezone
from .models import KYCRequest
from .serializers import KYCRequestSerializer

from users.views import (
    get_current_user,
    create_log,
    is_admin
)

from notifications.models import Notification


def _fallback_ocr_value(primary_value, request_data, key):

    if primary_value not in [None, ""]:
        return primary_value

    value = request_data.get(
        key,
        ""
    )

    return value.strip() if isinstance(value, str) else value


# ==========================
# SUBMIT KYC
# ==========================
@api_view(['POST'])
def submit_kyc(request):

    user, error = get_current_user(
        request
    )

    if error:
        return error

    # already submitted
    existing = KYCRequest.objects.filter(
        utilisateur=user,
        status="PENDING"
    ).first()

    if existing:

        return Response({

            "error":
            "Pending KYC already exists"

        }, status=400)

    data = request.data.copy()

    data["utilisateur"] = user.id

    serializer = KYCRequestSerializer(
        data=data
    )

    if serializer.is_valid():

        kyc = serializer.save()
        from .ocr_utils import (
            extract_text_from_image,
            parse_mauritanian_id
        )
# ==========================
        # OCR EXTRACTION
        # ==========================
        extracted_text = (

            extract_text_from_image(

                kyc.id_document.path
            )
        )

        parsed_data = (

            parse_mauritanian_id(

                extracted_text
            )
        )

        # ==========================
        # SAVE OCR DATA
        # ==========================
        kyc.ocr_text = (
            extracted_text or request.data.get(
                "ocr_text",
                ""
            )
        )

        kyc.nni = (
            _fallback_ocr_value(
                parsed_data["nni"],
                request.data,
                "nni"
            )
        )

        kyc.prenom = (
            _fallback_ocr_value(
                parsed_data["prenom"],
                request.data,
                "prenom"
            )
        )

        kyc.prenom_pere = (
            _fallback_ocr_value(
                parsed_data[
                    "prenom_pere"
                ],
                request.data,
                "prenom_pere"
            )
        )

        kyc.nom_famille = (
            _fallback_ocr_value(
                parsed_data[
                    "nom_famille"
                ],
                request.data,
                "nom_famille"
            )
        )

        kyc.sexe = (
            _fallback_ocr_value(
                parsed_data["sexe"],
                request.data,
                "sexe"
            )
        )

        kyc.date_naissance = (
            _fallback_ocr_value(
                parsed_data[
                    "date_naissance"
                ],
                request.data,
                "date_naissance"
            )
        )

        kyc.lieu_naissance = (
            _fallback_ocr_value(
                parsed_data[
                    "lieu_naissance"
                ],
                request.data,
                "lieu_naissance"
            )
        )

        kyc.save()
        create_log(

            user,

            "SUBMIT_KYC",

            f"kyc_id={kyc.id}"
        )

        Notification.objects.create(

            utilisateur=user,

            title="KYC Submitted",

            message=(
                "Votre demande KYC est en attente"
            ),

            type="info"
        )

        return Response({

            "message":
            "KYC submitted"

        })

    return Response(

        serializer.errors,

        status=400
    )


# ==========================
# GET MY KYC
# ==========================
@api_view(['GET'])
def get_my_kyc(request):

    user, error = get_current_user(
        request
    )

    if error:
        return error

    kyc = KYCRequest.objects.filter(
        utilisateur=user
    ).order_by(
        "-submitted_at"
    )

    serializer = KYCRequestSerializer(

        kyc,

        many=True
    )

    return Response(
        serializer.data
    )


# ==========================
# GET ALL KYC
# ==========================
@api_view(['GET'])
def get_all_kyc(request):

    user, error = get_current_user(
        request
    )

    if error:
        return error

    if not is_admin(user):

        return Response({

            "error":
            "Access denied"

        }, status=403)

    kyc = KYCRequest.objects.all()\
        .order_by("-submitted_at")

    serializer = KYCRequestSerializer(

        kyc,

        many=True
    )

    return Response(
        serializer.data
    )


# ==========================
# APPROVE KYC
# ==========================
@api_view(['POST'])
def approve_kyc(request, kyc_id):

    user, error = get_current_user(
        request
    )

    if error:
        return error

    if not is_admin(user):

        return Response({

            "error":
            "Access denied"

        }, status=403)

    kyc = KYCRequest.objects.filter(
        id=kyc_id
    ).first()

    if not kyc:

        return Response({

            "error":
            "KYC not found"

        }, status=404)

    kyc.status = "APPROVED"

    kyc.reviewed_by = user

    kyc.reviewed_at = timezone.now()

    kyc.review_note = request.data.get(
        "note",
        ""
    )

    kyc.save()

    # verify user
    kyc.utilisateur.is_verified = True

    kyc.utilisateur.save()

    create_log(

        user,

        "APPROVE_KYC",

        f"kyc_id={kyc.id}"
    )

    Notification.objects.create(

        utilisateur=kyc.utilisateur,

        title="KYC Approved",

        message=(
            "Votre identité a été vérifiée"
        ),

        type="success"
    )

    return Response({

        "message":
        "KYC approved"

    })


# ==========================
# REJECT KYC
# ==========================
@api_view(['POST'])
def reject_kyc(request, kyc_id):

    user, error = get_current_user(
        request
    )

    if error:
        return error

    if not is_admin(user):

        return Response({

            "error":
            "Access denied"

        }, status=403)

    kyc = KYCRequest.objects.filter(
        id=kyc_id
    ).first()

    if not kyc:

        return Response({

            "error":
            "KYC not found"

        }, status=404)

    kyc.status = "REJECTED"

    kyc.reviewed_by = user

    kyc.reviewed_at = timezone.now()

    kyc.review_note = request.data.get(
        "note",
        ""
    )

    kyc.save()

    create_log(

        user,

        "REJECT_KYC",

        f"kyc_id={kyc.id}"
    )

    Notification.objects.create(

        utilisateur=kyc.utilisateur,

        title="KYC Rejected",

        message=(
            "Votre demande KYC a été rejetée"
        ),

        type="danger"
    )

    return Response({

        "message":
        "KYC rejected"

    })
