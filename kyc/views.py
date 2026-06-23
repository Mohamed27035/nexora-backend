from rest_framework.decorators import api_view
from rest_framework.response import Response
from django.core.files.base import ContentFile
from django.utils import timezone
from django.db.models import Q
import os
import tempfile
from .models import KYCRequest
from .serializers import KYCRequestSerializer
from io import BytesIO
from pathlib import Path

from users.views import (
    get_current_user,
    create_log,
    is_admin
)
from users.models import Utilisateur

from notifications.models import Notification


def _notify_admins_about_kyc(kyc, message):
    try:
        admins = Utilisateur.objects.filter(role__in=["ADMIN", "ADMINISTRATEUR"])
        for admin in admins:
            if admin.id == kyc.utilisateur_id:
                continue
            Notification.objects.create(
                utilisateur=admin,
                title="Nouvelle demande KYC",
                message=message,
                type="info",
            )
    except Exception as e:
        print("ADMIN KYC NOTIFICATION ERROR =>", str(e))


def _save_temp_upload(uploaded_file, prefix):
    suffix = Path(getattr(uploaded_file, "name", "")).suffix or ".jpg"
    temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=suffix, prefix=prefix)
    try:
        for chunk in uploaded_file.chunks():
            temp_file.write(chunk)
    finally:
        temp_file.close()
    return temp_file.name


def _run_biometric_verification(kyc):

    if not kyc.id_document or not kyc.selfie:
        kyc.biometric_status = "SKIPPED"
        kyc.biometric_score = None
        kyc.biometric_message = (
            "Image de carte ou selfie manquant pour la verification biométrique."
        )
        kyc.biometric_reference = ""
        kyc.biometric_raw = None
        kyc.save(
            update_fields=[
                "biometric_status",
                "biometric_score",
                "biometric_message",
                "biometric_reference",
                "biometric_raw",
            ]
        )
        return

    try:
        from .biometric_utils import (
            biometric_is_configured,
            perform_selfie_verification,
        )

        if not biometric_is_configured():
            kyc.biometric_status = "SKIPPED"
            kyc.biometric_score = None
            kyc.biometric_message = (
                "Service biométrique non configuré."
            )
            kyc.biometric_reference = ""
            kyc.biometric_raw = None
        else:
            result = perform_selfie_verification(
                user_id=kyc.utilisateur_id,
                id_document_path=kyc.id_document.path,
                selfie_path=kyc.selfie.path,
                device_id="nexora-kyc",
            )

            kyc.biometric_status = result.get("status", "ERROR")
            kyc.biometric_score = result.get("score")
            kyc.biometric_message = result.get("message", "")
            kyc.biometric_reference = result.get("reference", "")
            kyc.biometric_raw = result.get("raw_payload")

    except Exception as e:
        print("BIOMETRIC VERIFY ERROR =>", str(e))
        kyc.biometric_status = "ERROR"
        kyc.biometric_score = None
        kyc.biometric_message = str(e)
        kyc.biometric_reference = ""
        kyc.biometric_raw = {
            "error": str(e),
        }

    kyc.save(
        update_fields=[
            "biometric_status",
            "biometric_score",
            "biometric_message",
            "biometric_reference",
            "biometric_raw",
        ]
    )


def _apply_automatic_kyc_decision(kyc):
    biometric_status = str(kyc.biometric_status or "").strip().upper()
    biometric_message = str(kyc.biometric_message or "").strip()

    if biometric_status == "VERIFIED":
        kyc.status = "APPROVED"
        kyc.reviewed_by = None
        kyc.reviewed_at = timezone.now()
        kyc.review_note = (
            biometric_message
            or "Verification d'identite approuvee automatiquement."
        )
        kyc.save(
            update_fields=[
                "status",
                "reviewed_by",
                "reviewed_at",
                "review_note",
            ]
        )

        kyc.utilisateur.is_verified = True
        kyc.utilisateur.is_suspended = False
        kyc.utilisateur.save(update_fields=["is_verified", "is_suspended"])

        create_log(
            kyc.utilisateur,
            "APPROVE_KYC",
            f"kyc_id={kyc.id};mode=automatic",
            entity_type="KYC",
            entity_id=kyc.id,
            target_repr=kyc.utilisateur.email,
            metadata={
                "status": "APPROVED",
                "user_id": kyc.utilisateur_id,
                "automatic": True,
                "biometric_status": biometric_status,
                "biometric_score": kyc.biometric_score,
                "review_note": kyc.review_note,
            },
        )

        Notification.objects.create(
            utilisateur=kyc.utilisateur,
            title="Identite approuvee",
            message="Votre identite a ete verifiee automatiquement.",
            type="success",
        )

        return "APPROVED"

    if biometric_status in {"FAILED", "ERROR", "SKIPPED", "PENDING"}:
        kyc.status = "REJECTED"
        kyc.reviewed_by = None
        kyc.reviewed_at = timezone.now()
        kyc.review_note = (
            biometric_message
            or "La verification automatique de l'identite a echoue ou n'a pas pu etre finalisee."
        )
        kyc.save(
            update_fields=[
                "status",
                "reviewed_by",
                "reviewed_at",
                "review_note",
            ]
        )

        create_log(
            kyc.utilisateur,
            "REJECT_KYC",
            f"kyc_id={kyc.id};mode=automatic",
            entity_type="KYC",
            entity_id=kyc.id,
            target_repr=kyc.utilisateur.email,
            metadata={
                "status": "REJECTED",
                "user_id": kyc.utilisateur_id,
                "automatic": True,
                "biometric_status": biometric_status,
                "biometric_score": kyc.biometric_score,
                "review_note": kyc.review_note,
            },
        )

        Notification.objects.create(
            utilisateur=kyc.utilisateur,
            title="Identite refusee",
            message="La verification automatique de votre identite a echoue.",
            type="danger",
        )

        return "REJECTED"
    return "REJECTED"


def _purge_kyc_images(kyc):
    for field_name in ["id_document", "selfie"]:
        field = getattr(kyc, field_name, None)
        if not field:
            continue
        try:
            stored_name = field.name
        except Exception:
            stored_name = ""
        try:
            if stored_name:
                field.storage.delete(stored_name)
        except Exception as e:
            print("KYC IMAGE DELETE ERROR =>", str(e))

    kyc.id_document = ""
    kyc.selfie = ""
    kyc.save(update_fields=["id_document", "selfie"])


def _validate_selfie_requirement_from_result(result):
    face_detected = result.get("face_detected")
    confidence = result.get("score")
    threshold = result.get("threshold", 50.0)
    eligible = bool(result.get("eligible"))
    message = str(result.get("message", "") or "").strip()

    if face_detected is False:
        return False, "Aucun visage humain n'a ete detecte dans le selfie.", {
            "face_detected": face_detected,
            "confidence": confidence,
            "threshold": threshold,
            "eligible": eligible,
            "message": message,
        }

    if confidence is None:
        return False, "La comparaison biométrique n'a pas pu calculer un score fiable.", {
            "face_detected": face_detected,
            "confidence": confidence,
            "threshold": threshold,
            "eligible": eligible,
            "message": message,
        }

    if confidence < threshold or not eligible:
        return False, (
            f"Le selfie ne peut pas etre envoye. "
            f"Le taux de correspondance est {confidence}% et doit etre au moins de {threshold}%."
        ), {
            "face_detected": face_detected,
            "confidence": confidence,
            "threshold": threshold,
            "eligible": eligible,
            "message": message,
        }

    return True, "", {
        "face_detected": face_detected,
        "confidence": confidence,
        "threshold": threshold,
        "eligible": eligible,
        "message": message,
    }


@api_view(['POST'])
def check_selfie(request):
    user, error = get_current_user(request)
    if error:
        return error

    id_document = request.FILES.get("id_document")
    selfie = request.FILES.get("selfie")

    if not id_document or not selfie:
        return Response(
            {"error": "Le document d'identite et le selfie sont requis."},
            status=400,
        )

    id_document_path = None
    selfie_path = None
    try:
        id_document_path = _save_temp_upload(id_document, "kyc-id-")
        selfie_path = _save_temp_upload(selfie, "kyc-selfie-")

        from .biometric_utils import (
            biometric_is_configured,
            perform_selfie_verification,
        )

        if not biometric_is_configured():
            return Response(
                {"error": "Service biometrique non configure."},
                status=503,
            )

        result = perform_selfie_verification(
            user_id=user.id,
            id_document_path=id_document_path,
            selfie_path=selfie_path,
            device_id="nexora-kyc-precheck",
        )
        allowed, reason, summary = _validate_selfie_requirement_from_result(result)
        return Response(
            {
                "allowed": allowed,
                "reason": reason or result.get("message", ""),
                "biometric": result,
                "summary": summary,
            }
        )
    except Exception as e:
        print("CHECK SELFIE ERROR =>", str(e))
        return Response(
            {"error": f"Echec de verification du selfie: {str(e)}"},
            status=500,
        )
    finally:
        for path in [id_document_path, selfie_path]:
            if path and os.path.exists(path):
                try:
                    os.remove(path)
                except Exception:
                    pass


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
    extracted_text = ""
    parsed_data = {
        "nni": "",
        "prenom": "",
        "prenom_pere": "",
        "nom_famille": "",
        "sexe": "",
        "date_naissance": "",
        "lieu_naissance": "",
    }

    try:
        from .ocr_utils import (
            call_external_ocr_api,
            parse_external_ocr_payload,
            extract_text_from_image,
            parse_mauritanian_id
        )

        if kyc.id_document:
            try:
                external_payload = call_external_ocr_api(
                    kyc.id_document.path
                )
                external_result = parse_external_ocr_payload(
                    external_payload
                )
                extracted_text = external_result.get(
                    "ocr_text",
                    ""
                )
                parsed_data = external_result.get(
                    "fields",
                    parsed_data
                )
            except Exception as external_error:
                print(
                    "EXTERNAL OCR ERROR =>",
                    str(external_error)
                )

                extracted_text = extract_text_from_image(
                    kyc.id_document.path
                )

                parsed_data = parse_mauritanian_id(
                    extracted_text
                )

    except Exception as e:

        print(
            "OCR POPULATE ERROR =>",
            str(e)
        )

    source_data = request_data or {}

    kyc.ocr_text = (
        extracted_text or source_data.get(
            "ocr_text",
            ""
        )
    )

    kyc.nni = _request_ocr_value(
        source_data,
        "nni",
        "NNI"
    ) or _fallback_ocr_value(
        parsed_data["nni"],
        source_data,
        "nni"
    )

    kyc.prenom = _request_ocr_value(
        source_data,
        "prenom",
        "first_name"
    ) or _fallback_ocr_value(
        parsed_data["prenom"],
        source_data,
        "prenom"
    )

    kyc.prenom_pere = _request_ocr_value(
        source_data,
        "prenom_pere",
        "father_name"
    ) or _fallback_ocr_value(
        parsed_data["prenom_pere"],
        source_data,
        "prenom_pere"
    )

    kyc.nom_famille = _request_ocr_value(
        source_data,
        "nom_famille",
        "last_name",
        "surname"
    ) or _fallback_ocr_value(
        parsed_data["nom_famille"],
        source_data,
        "nom_famille"
    )

    kyc.sexe = _request_ocr_value(
        source_data,
        "sexe",
        "sex"
    ) or _fallback_ocr_value(
        parsed_data["sexe"],
        source_data,
        "sexe"
    )

    kyc.date_naissance = _request_ocr_value(
        source_data,
        "date_naissance",
        "birth_date"
    ) or _fallback_ocr_value(
        parsed_data["date_naissance"],
        source_data,
        "date_naissance"
    )

    kyc.lieu_naissance = _request_ocr_value(
        source_data,
        "lieu_naissance",
        "birth_place"
    ) or _fallback_ocr_value(
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


def _ensure_kyc_assets_ready(kyc, request_data=None):

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
        bool((request_data or {}).get("nni")),
        bool((request_data or {}).get("prenom")),
        bool((request_data or {}).get("prenom_pere")),
        bool((request_data or {}).get("nom_famille")),
        bool((request_data or {}).get("sexe")),
        bool((request_data or {}).get("date_naissance")),
        bool((request_data or {}).get("lieu_naissance")),
    ])

    if not has_ocr_data:
        try:
            _populate_ocr_fields(kyc, request_data=request_data)
        except Exception as e:
            print(
                "ENSURE KYC ASSETS OCR ERROR =>",
                str(e)
            )

    return changed


def _fallback_ocr_value(primary_value, request_data, key):

    if primary_value not in [None, ""]:
        return primary_value

    value = request_data.get(
        key,
        ""
    )

    return value.strip() if isinstance(value, str) else value


def _request_ocr_value(request_data, *keys):

    for key in keys:
        value = request_data.get(
            key,
            ""
        )

        if isinstance(value, str):
            value = value.strip()

        if value not in [None, ""]:
            return value

    return ""


def _backfill_ocr_fields_from_text(kyc):

    if any([
        bool(kyc.nni),
        bool(kyc.prenom),
        bool(kyc.prenom_pere),
        bool(kyc.nom_famille),
        bool(kyc.sexe),
        bool(kyc.date_naissance),
        bool(kyc.lieu_naissance),
    ]):
        return False

    raw_text = (kyc.ocr_text or "").strip()
    if not raw_text:
        return False

    try:
        from .ocr_utils import parse_mauritanian_id

        parsed = parse_mauritanian_id(
            raw_text
        ) or {}
    except Exception as e:
        print(
            "KYC OCR BACKFILL ERROR =>",
            str(e)
        )
        return False

    kyc.nni = parsed.get("nni", "") or ""
    kyc.prenom = parsed.get("prenom", "") or ""
    kyc.prenom_pere = parsed.get("prenom_pere", "") or ""
    kyc.nom_famille = parsed.get("nom_famille", "") or ""
    kyc.sexe = parsed.get("sexe", "") or ""
    kyc.date_naissance = parsed.get("date_naissance", "") or ""
    kyc.lieu_naissance = parsed.get("lieu_naissance", "") or ""

    kyc.save(
        update_fields=[
            "nni",
            "prenom",
            "prenom_pere",
            "nom_famille",
            "sexe",
            "date_naissance",
            "lieu_naissance",
        ]
    )

    return True


def _validate_selfie_requirement_from_result(result):
    face_detected = result.get("face_detected")
    confidence = result.get("score")
    threshold = result.get("threshold", 50.0)
    eligible = bool(result.get("eligible"))
    message = str(result.get("message", "") or "").strip()
    status = str(result.get("status", "") or "").strip().upper()

    provider_failed = (
        status == "ERROR"
        or "no face detected" in message.lower()
        or "biometric api error" in message.lower()
    )

    if face_detected is False:
        if provider_failed:
            return True, (
                "Le service biométrique n'a pas détecté le visage automatiquement. "
                "La demande sera envoyée pour revue manuelle par l'administrateur."
            ), {
                "face_detected": face_detected,
                "confidence": confidence,
                "threshold": threshold,
                "eligible": eligible,
                "message": message,
                "manual_review_required": True,
            }
        return False, "Aucun visage humain n'a ete detecte dans le selfie.", {
            "face_detected": face_detected,
            "confidence": confidence,
            "threshold": threshold,
            "eligible": eligible,
            "message": message,
            "manual_review_required": False,
        }

    if confidence is None:
        if provider_failed:
            return True, (
                "Le score biométrique n'a pas pu être calculé automatiquement. "
                "La demande sera transmise pour revue manuelle."
            ), {
                "face_detected": face_detected,
                "confidence": confidence,
                "threshold": threshold,
                "eligible": eligible,
                "message": message,
                "manual_review_required": True,
            }
        return False, "La comparaison biométrique n'a pas pu calculer un score fiable.", {
            "face_detected": face_detected,
            "confidence": confidence,
            "threshold": threshold,
            "eligible": eligible,
            "message": message,
            "manual_review_required": False,
        }

    if face_detected is True:
        return True, "", {
            "face_detected": face_detected,
            "confidence": confidence,
            "threshold": threshold,
            "eligible": True,
            "message": message,
            "manual_review_required": False,
        }

    return True, "", {
        "face_detected": face_detected,
        "confidence": confidence,
        "threshold": threshold,
        "eligible": eligible,
        "message": message,
        "manual_review_required": False,
    }


# ==========================
# SUBMIT KYC
# ==========================
@api_view(['POST'])
def submit_kyc(request):
    try:
        user, error = get_current_user(
            request
        )

        if error:
            return error

        existing = KYCRequest.objects.filter(
            utilisateur=user,
            status="PENDING"
        ).first()

        data = request.data.copy()
        data["utilisateur"] = user.id

        serializer = KYCRequestSerializer(
            existing,
            data=data,
            partial=existing is not None,
        )

        if not serializer.is_valid():
            return Response(
                serializer.errors,
                status=400
            )

        kyc = serializer.save()

        if existing:
            kyc.status = "PENDING"
            kyc.review_note = ""
            kyc.reviewed_by = None
            kyc.reviewed_at = None
            kyc.save(
                update_fields=[
                    "status",
                    "review_note",
                    "reviewed_by",
                    "reviewed_at",
                ]
            )

        _ensure_kyc_assets_ready(
            kyc,
            request_data=request.data
        )

        try:
            _populate_ocr_fields(
                kyc,
                request.data
            )
        except Exception as e:
            print(
                "SUBMIT KYC OCR ERROR =>",
                str(e)
            )

        _run_biometric_verification(kyc)
        decision = _apply_automatic_kyc_decision(kyc)
        _purge_kyc_images(kyc)

        create_log(

            user,

            "SUBMIT_KYC",

            f"kyc_id={kyc.id}",
            entity_type="KYC",
            entity_id=kyc.id,
            target_repr=kyc.utilisateur.email,
            metadata={
                "status": kyc.status,
                "user_id": kyc.utilisateur_id,
                "updated_existing": bool(existing),
                "ocr_complete": bool(
                    kyc.nni or kyc.prenom or kyc.nom_famille or kyc.date_naissance
                ),
                "biometric_status": kyc.biometric_status,
                "biometric_score": kyc.biometric_score,
                "automatic_decision": decision,
            },
        )

        return Response({

            "message":
            (
                "Verification d'identite approuvee automatiquement"
                if decision == "APPROVED"
                else "Verification d'identite refusee automatiquement"
                if decision == "REJECTED"
                else "Verification d'identite traitee"
            ),
            "kyc": KYCRequestSerializer(
                kyc,
                context={"request": request}
            ).data

        })
    except Exception as e:
        print(
            "SUBMIT KYC FATAL ERROR =>",
            str(e)
        )
        return Response(
            {
                "error": f"Echec lors de l'envoi du KYC: {str(e)}"
            },
            status=500
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
        try:
            _ensure_kyc_assets_ready(
                item
            )
            _backfill_ocr_fields_from_text(
                item
            )
        except Exception as e:
            print(
                "GET MY KYC ASSET ERROR =>",
                str(e)
            )

    serializer = KYCRequestSerializer(

        kyc,

        many=True,
        context={"request": request}
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

    status_filter = request.GET.get(
        "status",
        "ALL"
    ).strip().upper()

    search = request.GET.get(
        "search",
        ""
    ).strip()

    kyc = KYCRequest.objects.select_related(
        "utilisateur",
        "reviewed_by",
    ).all()

    if status_filter != "ALL":
        kyc = kyc.filter(
            status=status_filter
        )

    if search:
        kyc = kyc.filter(
            Q(utilisateur__nom__icontains=search)
            |
            Q(utilisateur__prenom__icontains=search)
            |
            Q(utilisateur__email__icontains=search)
            |
            Q(nni__icontains=search)
            |
            Q(prenom__icontains=search)
            |
            Q(nom_famille__icontains=search)
        )

    kyc = kyc.order_by("-submitted_at")

    for item in kyc:
        try:
            _ensure_kyc_assets_ready(
                item
            )
            _backfill_ocr_fields_from_text(
                item
            )
        except Exception as e:
            print(
                "GET ALL KYC ASSET ERROR =>",
                str(e)
            )

    serializer = KYCRequestSerializer(

        kyc,

        many=True,
        context={"request": request}
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

        f"kyc_id={kyc.id}",
        entity_type="KYC",
        entity_id=kyc.id,
        target_repr=kyc.utilisateur.email,
        metadata={
            "status": "APPROVED",
            "user_id": kyc.utilisateur_id,
            "reviewed_by": user.id,
            "review_note": kyc.review_note or "",
        },
    )

    Notification.objects.create(

        utilisateur=kyc.utilisateur,

        title="KYC approuvé",

        message=(
            "Votre identité a été vérifiée"
        ),

        type="success"
    )

    return Response({

        "message":
        "KYC approuvé"

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

        f"kyc_id={kyc.id}",
        entity_type="KYC",
        entity_id=kyc.id,
        target_repr=kyc.utilisateur.email,
        metadata={
            "status": "REJECTED",
            "user_id": kyc.utilisateur_id,
            "reviewed_by": user.id,
            "review_note": kyc.review_note or "",
        },
    )

    Notification.objects.create(

        utilisateur=kyc.utilisateur,

        title="KYC rejeté",

        message=(
            "Votre demande KYC a été rejetée"
        ),

        type="danger"
    )

    return Response({

        "message":
        "KYC rejeté"

    })
