from rest_framework.decorators import api_view
from rest_framework.response import Response
from django.core.files.base import ContentFile
from django.utils import timezone
from .models import KYCRequest
from .serializers import KYCRequestSerializer
from io import BytesIO
from pathlib import Path

from users.views import (
    get_current_user,
    create_log,
    is_admin
)

from notifications.models import Notification


def _normalize_uploaded_image(instance, field_name, target_name):

    image_field = getattr(
        instance,
        field_name,
        None
    )

    if not image_field:
        return False

    current_name = image_field.name
    current_path = image_field.path
    current_suffix = Path(
        current_name
    ).suffix.lower()

    if current_suffix in [
        ".jpg",
        ".jpeg",
        ".png",
    ]:
        return False

    from PIL import Image

    try:

        with Image.open(
            current_path
        ) as image:

            converted = image.convert(
                "RGB"
            )

            buffer = BytesIO()

            converted.save(
                buffer,
                format="JPEG",
                quality=88
            )

        new_name = (
            f"kyc/{target_name}/"
            f"{Path(current_name).stem}_{instance.id}.jpg"
        )

        image_field.save(
            new_name,
            ContentFile(
                buffer.getvalue()
            ),
            save=False
        )

        instance.save(
            update_fields=[
                field_name
            ]
        )

        try:
            image_field.storage.delete(
                current_name
            )
        except Exception:
            pass

        return True

    except Exception as e:

        print(
            "IMAGE NORMALIZE ERROR =>",
            str(e)
        )

        return False


def _populate_ocr_fields(kyc, request_data=None):

    from .ocr_utils import (
        extract_text_from_image,
        parse_mauritanian_id
    )

    extracted_text = extract_text_from_image(
        kyc.id_document.path
    )

    parsed_data = parse_mauritanian_id(
        extracted_text
    )

    source_data = request_data or {}

    kyc.ocr_text = (
        extracted_text or source_data.get(
            "ocr_text",
            ""
        )
    )

    kyc.nni = _fallback_ocr_value(
        parsed_data["nni"],
        source_data,
        "nni"
    )

    kyc.prenom = _fallback_ocr_value(
        parsed_data["prenom"],
        source_data,
        "prenom"
    )

    kyc.prenom_pere = _fallback_ocr_value(
        parsed_data["prenom_pere"],
        source_data,
        "prenom_pere"
    )

    kyc.nom_famille = _fallback_ocr_value(
        parsed_data["nom_famille"],
        source_data,
        "nom_famille"
    )

    kyc.sexe = _fallback_ocr_value(
        parsed_data["sexe"],
        source_data,
        "sexe"
    )

    kyc.date_naissance = _fallback_ocr_value(
        parsed_data["date_naissance"],
        source_data,
        "date_naissance"
    )

    kyc.lieu_naissance = _fallback_ocr_value(
        parsed_data["lieu_naissance"],
        source_data,
        "lieu_naissance"
    )

    kyc.save(
        update_fields=[
            "ocr_text",
            "nni",
            "prenom",
            "prenom_pere",
            "nom_famille",
            "sexe",
            "date_naissance",
            "lieu_naissance",
        ]
    )


def _ensure_kyc_assets_ready(kyc):

    changed = False

    changed = _normalize_uploaded_image(
        kyc,
        "id_document",
        "id_documents"
    ) or changed

    changed = _normalize_uploaded_image(
        kyc,
        "selfie",
        "selfies"
    ) or changed

    has_ocr_data = any([
        bool(kyc.ocr_text),
        bool(kyc.nni),
        bool(kyc.prenom),
        bool(kyc.nom_famille),
        bool(kyc.date_naissance),
    ])

    if not has_ocr_data:
        _populate_ocr_fields(kyc)

    return changed


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
        _ensure_kyc_assets_ready(
            kyc
        )
        _populate_ocr_fields(
            kyc,
            request.data
        )
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

    for item in kyc:
        _ensure_kyc_assets_ready(
            item
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

    for item in kyc:
        _ensure_kyc_assets_ready(
            item
        )

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
