import json
import hashlib
import os
import tempfile
import base64
from pathlib import Path

import requests
from django.conf import settings
from PIL import Image, ImageOps, ImageFilter


SELFIE_MATCH_THRESHOLD = 60.0


def _base_url():
    return (
        getattr(settings, "NOVA_BIOMETRIC_BASE_URL", "").strip()
        or getattr(settings, "NOVA_OCR_BASE_URL", "").strip()
    )


def _api_key():
    return (
        getattr(settings, "NOVA_BIOMETRIC_API_KEY", "").strip()
        or getattr(settings, "NOVA_OCR_API_KEY", "").strip()
    )


def biometric_is_configured():
    return bool(_base_url() and _api_key())


def _timeout():
    return int(
        getattr(settings, "NOVA_BIOMETRIC_TIMEOUT", 45)
        or getattr(settings, "NOVA_OCR_TIMEOUT", 45)
        or 45
    )


def _match_threshold():
    try:
        value = float(
            getattr(settings, "NOVA_BIOMETRIC_MATCH_THRESHOLD", SELFIE_MATCH_THRESHOLD)
            or SELFIE_MATCH_THRESHOLD
        )
    except Exception:
        value = SELFIE_MATCH_THRESHOLD
    return max(0.0, min(100.0, value))


def _tenant_id():
    return (
        getattr(settings, "NOVA_BIOMETRIC_TENANT_ID", "").strip()
        or getattr(settings, "NOVA_OCR_TENANT_ID", "").strip()
        or "nexora"
    )


def _coerce_payload(raw_payload):
    if isinstance(raw_payload, dict):
        return raw_payload

    if isinstance(raw_payload, str):
        stripped = raw_payload.strip()
        if not stripped:
            return {"message": ""}
        try:
            parsed = json.loads(stripped)
            if isinstance(parsed, dict):
                return parsed
            return {"message": stripped, "payload": parsed}
        except Exception:
            return {"message": stripped}

    return {"payload": raw_payload}


def _read_error_text(raw_payload):
    payload = _coerce_payload(raw_payload)
    if not isinstance(payload, dict):
        return str(raw_payload or "").strip()

    detail = payload.get("detail")
    if isinstance(detail, list):
        parts = []
        for item in detail:
            if isinstance(item, dict):
                piece = str(item.get("msg") or item.get("message") or "").strip()
                if piece:
                    parts.append(piece)
            elif item not in [None, ""]:
                parts.append(str(item).strip())
        if parts:
            return " | ".join(parts)
    if detail not in [None, ""]:
        return str(detail).strip()

    for key in ["message", "error", "description", "status", "result"]:
        value = payload.get(key)
        if value not in [None, ""]:
            return str(value).strip()

    return str(raw_payload or "").strip()


def _build_biometric_subject(user_id, id_document_path):
    hasher = hashlib.sha256()
    with open(id_document_path, "rb") as image_file:
        for chunk in iter(lambda: image_file.read(1024 * 1024), b""):
            hasher.update(chunk)
    digest = hasher.hexdigest()[:16]
    return f"{user_id}-{digest}"


def _extract_enrollment_image_from_id_document(id_document_path):
    try:
        from .ocr_utils import call_external_ocr_api, decode_external_face_image

        payload = call_external_ocr_api(id_document_path)
        face_bytes = decode_external_face_image(payload)
        if not face_bytes:
            return None

        temp_file = tempfile.NamedTemporaryFile(
            delete=False,
            suffix=".jpg",
            prefix="kyc-face-",
        )
        try:
            temp_file.write(face_bytes)
        finally:
            temp_file.close()
        return temp_file.name
    except Exception:
        return None


def _call_face_endpoint(endpoint_path, file_path, data):
    endpoint = f"{_base_url().rstrip('/')}{endpoint_path}"

    with open(file_path, "rb") as image_file:
        response = requests.post(
            endpoint,
            headers={
                "Accept": "application/json",
                "Secure-Nova-Key": _api_key(),
            },
            data=data,
            files={
                "file": (
                    Path(file_path).name,
                    image_file,
                    "image/jpeg",
                )
            },
            timeout=_timeout(),
        )

    if response.status_code >= 400:
        raise RuntimeError(
            f"Biometric API error ({response.status_code}): {response.text[:500]}"
        )

    try:
        payload = response.json()
    except Exception:
        payload = response.text

    return _coerce_payload(payload)


def _guess_mime_type(file_path):
    suffix = Path(file_path).suffix.lower()
    if suffix == ".png":
        return "image/png"
    if suffix == ".webp":
        return "image/webp"
    return "image/jpeg"


def _encode_image_base64(file_path):
    with open(file_path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode("utf-8")


def _call_kyc_verify_endpoint(id_document_path, selfie_path):
    endpoint = f"{_base_url().rstrip('/')}/api/kyc/face/verify"
    payload = {
        "document_image": _encode_image_base64(id_document_path),
        "selfie_image": _encode_image_base64(selfie_path),
        "perform_liveness": True,
        "tenant_id": _tenant_id(),
    }

    response = requests.post(
        endpoint,
        headers={
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Secure-Nova-Key": _api_key(),
        },
        json=payload,
        timeout=_timeout(),
    )

    try:
        parsed_payload = response.json()
    except Exception:
        parsed_payload = response.text

    if response.status_code >= 400:
        error_text = _read_error_text(parsed_payload)
        raise RuntimeError(
            f"Biometric API error ({response.status_code}): {error_text or response.text[:500]}"
        )

    return _coerce_payload(parsed_payload)


def _build_image_variant(original_path, suffix, transform):
    temp_file = tempfile.NamedTemporaryFile(
        delete=False,
        suffix=".jpg",
        prefix=f"kyc-{suffix}-",
    )
    temp_path = temp_file.name
    temp_file.close()

    with Image.open(original_path) as source:
        image = source.convert("RGB")
        variant = transform(image)
        variant.save(temp_path, format="JPEG", quality=92)

    return temp_path


def _selfie_variants(image_path):
    created_paths = []

    def _register(path):
        if path != image_path:
            created_paths.append(path)
        return path

    try:
        original = Image.open(image_path)
        width, height = original.size
        original.close()
    except Exception:
        return [image_path], created_paths

    variants = [image_path]

    try:
        variants.append(
            _register(
                _build_image_variant(
                    image_path,
                    "selfie-fit",
                    lambda img: ImageOps.contain(img, (900, 1200)),
                )
            )
        )
    except Exception:
        pass

    try:
        variants.append(
            _register(
                _build_image_variant(
                    image_path,
                    "selfie-enhanced",
                    lambda img: ImageOps.autocontrast(
                        ImageOps.exif_transpose(img)
                    ).filter(ImageFilter.SHARPEN),
                )
            )
        )
    except Exception:
        pass

    try:
        crop_left = int(width * 0.15)
        crop_top = int(height * 0.08)
        crop_right = int(width * 0.85)
        crop_bottom = int(height * 0.78)
        if crop_right > crop_left and crop_bottom > crop_top:
            variants.append(
                _register(
                    _build_image_variant(
                        image_path,
                        "selfie-crop",
                        lambda img: ImageOps.contain(
                            img.crop((crop_left, crop_top, crop_right, crop_bottom)),
                            (900, 1200),
                        ),
                    )
                )
            )
    except Exception:
        pass

    try:
        crop_left = int(width * 0.22)
        crop_top = int(height * 0.05)
        crop_right = int(width * 0.78)
        crop_bottom = int(height * 0.62)
        if crop_right > crop_left and crop_bottom > crop_top:
            variants.append(
                _register(
                    _build_image_variant(
                        image_path,
                        "selfie-tight",
                        lambda img: ImageOps.autocontrast(
                            ImageOps.contain(
                                img.crop((crop_left, crop_top, crop_right, crop_bottom)),
                                (900, 1200),
                            )
                        ).filter(ImageFilter.SHARPEN),
                    )
                )
            )
    except Exception:
        pass

    return variants, created_paths


def _read_first(payload, *keys):
    for key in keys:
        value = payload.get(key)
        if value not in [None, ""]:
            return value
    return None


def _read_nested(payload, *path):
    current = payload
    for key in path:
        if not isinstance(current, dict):
            return None
        current = current.get(key)
        if current in [None, ""]:
            return None
    return current


def _read_number(value):
    if value in [None, ""]:
        return None
    try:
        return float(value)
    except Exception:
        return None


def _read_similarity_score(payload):
    return _read_number(
        _read_first(payload, "similarity", "score", "similarity_score", "match_score")
        or _read_nested(payload, "scores", "similarity_score")
    )


def _read_liveness_score(payload):
    return _read_number(
        _read_first(payload, "liveness_score", "liveness", "livenessScore")
        or _read_nested(payload, "scores", "liveness_score")
    )


def _read_confidence_score(payload):
    return _read_number(
        _read_first(payload, "confidence_score")
        or _read_nested(payload, "scores", "confidence_score")
    )


def _read_risk_score(payload):
    return _read_number(
        _read_first(payload, "risk_score")
        or _read_nested(payload, "scores", "risk_score")
    )


def _read_similarity_threshold(payload):
    return _read_number(_read_nested(payload, "thresholds", "similarity_threshold"))


def _read_liveness_threshold(payload):
    return _read_number(_read_nested(payload, "thresholds", "liveness_threshold"))


def _read_reference(payload):
    value = (
        _read_nested(payload, "audit", "request_id")
        or _read_nested(payload, "audit", "user_id")
        or _read_nested(payload, "metadata", "timestamp")
        or _read_first(payload, "timestamp", "reference", "reference_id")
    )
    return str(value).strip() if value not in [None, ""] else ""


def _read_message(payload):
    if not isinstance(payload, dict):
        return ""

    direct = _read_first(payload, "message", "detail", "description", "document_quality")
    if direct not in [None, ""]:
        return str(direct).strip()

    verified = payload.get("verified")
    decision = str(_read_first(payload, "decision") or "").strip()
    status = str(_read_first(payload, "status") or "").strip()
    if verified is True and not decision:
        decision = "verified"
    elif verified is False and not decision:
        decision = "not_verified"

    factors = _read_nested(payload, "explainability", "decision_factors")

    factor_text = ""
    if isinstance(factors, list) and factors:
        descriptions = []
        for factor in factors[:3]:
            if isinstance(factor, dict):
                part = str(
                    factor.get("description")
                    or factor.get("factor")
                    or ""
                ).strip()
                if part:
                    descriptions.append(part)
        factor_text = " | ".join(descriptions)

    parts = [part for part in [status, decision, factor_text] if part]
    return " - ".join(parts)


def _is_already_enrolled_error(error):
    message = str(error or "").strip().lower()
    return "already enrolled" in message or "deja enrol" in message


def _normalize_percent(score_value):
    if score_value in [None, ""]:
        return None
    try:
        score = float(score_value)
    except Exception:
        return None
    if score <= 1:
        score *= 100
    return max(0.0, min(100.0, round(score, 2)))


def _read_score(payload):
    return _normalize_percent(
        _read_similarity_score(payload)
        or _read_confidence_score(payload)
    )


def _payload_face_detected(payload, similarity_score=None, liveness_score=None, confidence_score=None):
    if not isinstance(payload, dict):
        payload = {}

    status = str(_read_first(payload, "status") or "").strip().lower()
    decision = str(_read_first(payload, "decision") or "").strip().lower()
    message = _read_message(payload).lower()

    if any(
        token in " ".join([status, decision, message])
        for token in ["no face", "face not detected", "aucun visage", "visage non detecte"]
    ):
        return False

    if any(value is not None for value in [similarity_score, liveness_score, confidence_score]):
        return True

    if payload.get("verified") in [True, False]:
        return True

    return None


def _payload_indicates_match(payload, similarity_score=None, threshold=None):
    if not isinstance(payload, dict):
        payload = {}

    decision = str(_read_first(payload, "decision") or "").strip().lower()
    status = str(_read_first(payload, "status") or "").strip().lower()
    verified = payload.get("verified")

    if verified is True:
        return True
    if verified is False:
        return False

    if decision in {"accept", "accepted", "approved", "match", "matched", "verified", "success"}:
        return True
    if decision in {"reject", "rejected", "failed", "mismatch", "deny", "denied"}:
        return False

    if status in {"ok", "success", "verified", "approved"}:
        return True
    if status in {"failed", "error", "rejected", "denied"}:
        return False

    if similarity_score is not None and threshold is not None:
        return similarity_score >= threshold

    return None


def enroll_face(user_id, image_path, device_id="mobile-app"):
    if not biometric_is_configured():
        raise RuntimeError("Biometric API not configured.")

    payload = _call_face_endpoint(
        "/face/enroll",
        image_path,
        {
            "user_id": str(user_id),
            "device_id": str(device_id),
        },
    )

    return {
        "success": _payload_indicates_match(payload),
        "message": _read_message(payload) or "Face enrollment completed.",
        "score": _read_score(payload),
        "reference": _read_reference(payload),
        "raw_payload": payload,
    }


def verify_face(user_id, image_path):
    if not biometric_is_configured():
        raise RuntimeError("Biometric API not configured.")

    payload = _call_face_endpoint(
        "/face/verify",
        image_path,
        {
            "user_id": str(user_id),
        },
    )

    return {
        "success": _payload_indicates_match(payload),
        "message": _read_message(payload) or "Face verification completed.",
        "score": _read_score(payload),
        "reference": _read_reference(payload),
        "raw_payload": payload,
    }


def _verify_face_with_retries(user_id, image_path):
    attempts, temp_paths = _selfie_variants(image_path)
    last_error = None

    try:
        for candidate_path in attempts:
            try:
                result = verify_face(user_id=user_id, image_path=candidate_path)
                face_detected = _payload_face_detected(
                    result.get("raw_payload"),
                    similarity_score=_normalize_percent(result.get("score")),
                )
                if face_detected is False:
                    last_error = RuntimeError("No face detected")
                    continue
                return result
            except Exception as error:
                last_error = error
                if "No face detected" in str(error):
                    continue
                raise
    finally:
        for path in temp_paths:
            if path and os.path.exists(path):
                try:
                    os.remove(path)
                except Exception:
                    pass

    if last_error:
        raise last_error
    raise RuntimeError("No face detected")


def perform_selfie_verification(user_id, id_document_path, selfie_path, device_id="mobile-app"):
    try:
        payload = _call_kyc_verify_endpoint(id_document_path, selfie_path)
    except Exception as error:
        error_text = str(error or "").strip()
        lowered = error_text.lower()
        if any(
            token in lowered
            for token in ["no face", "aucun visage", "face not detected", "visage non detecte"]
        ):
            return {
                "provider": "nova_kyc_face_verify",
                "status": "FAILED",
                "score": 0.0,
                "face_detected": False,
                "eligible": False,
                "threshold": SELFIE_MATCH_THRESHOLD,
                "message": "Aucun visage detecte dans le selfie.",
                "reference": "",
                "raw_payload": {
                    "error": error_text,
                    "assessment": {
                        "face_detected": False,
                        "eligible": False,
                        "threshold": SELFIE_MATCH_THRESHOLD,
                        "score": 0.0,
                    },
                },
            }
        raise

    similarity_score = _normalize_percent(_read_similarity_score(payload))
    liveness_score = _normalize_percent(_read_liveness_score(payload))
    confidence_score = _normalize_percent(_read_confidence_score(payload))
    risk_score = _normalize_percent(_read_risk_score(payload))
    similarity_threshold = _normalize_percent(_read_similarity_threshold(payload))
    liveness_threshold = _normalize_percent(_read_liveness_threshold(payload))
    verified_message = _read_message(payload) or ""
    face_detected = _payload_face_detected(
        payload,
        similarity_score=similarity_score,
        liveness_score=liveness_score,
        confidence_score=confidence_score,
    )
    explicit_match = _payload_indicates_match(
        payload,
        similarity_score=similarity_score,
        threshold=_match_threshold(),
    )

    effective_threshold = _match_threshold()

    eligible = bool(
        face_detected is not False
        and (
            (similarity_score is not None and similarity_score >= effective_threshold)
            or (similarity_score is None and explicit_match is True)
        )
    )

    if face_detected is False and not verified_message:
        verified_message = "Aucun visage detecte dans le selfie."
    elif eligible and not verified_message:
        verified_message = "Verification d'identite automatique reussie."
    elif not eligible and not verified_message:
        verified_message = "La verification automatique de l'identite a echoue."

    return {
        "provider": "nova_kyc_face_verify",
        "status": "VERIFIED" if eligible else "FAILED",
        "score": similarity_score,
        "face_detected": face_detected,
        "eligible": eligible,
        "threshold": effective_threshold,
        "message": verified_message,
        "reference": _read_reference(payload),
        "raw_payload": {
            "verify": payload,
            "assessment": {
                "face_detected": face_detected,
                "eligible": eligible,
                "threshold": effective_threshold,
                "score": similarity_score,
                "matched": explicit_match,
                "decision": _read_first(payload, "decision"),
                "provider_status": _read_first(payload, "status"),
                "similarity_score": similarity_score,
                "liveness_score": liveness_score,
                "confidence_score": confidence_score,
                "risk_score": risk_score,
                "similarity_threshold": effective_threshold,
                "liveness_threshold": liveness_threshold,
            },
        },
    }
