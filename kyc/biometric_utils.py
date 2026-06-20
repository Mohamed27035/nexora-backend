import json
from pathlib import Path

import requests
from django.conf import settings


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


def _read_first(payload, *keys):
    for key in keys:
        value = payload.get(key)
        if value not in [None, ""]:
            return value
    return None


def _read_score(payload):
    score_value = _read_first(
        payload,
        "score",
        "similarity",
        "confidence",
        "match_score",
        "probability",
    )
    if score_value in [None, ""]:
        return None

    try:
        return float(score_value)
    except Exception:
        return None


def _read_reference(payload):
    value = _read_first(
        payload,
        "reference",
        "reference_id",
        "face_id",
        "embedding_id",
        "user_id",
    )
    return str(value).strip() if value not in [None, ""] else ""


def _read_message(payload):
    value = _read_first(
        payload,
        "message",
        "detail",
        "status",
        "result",
        "description",
    )
    if value in [None, ""]:
        return ""
    return str(value).strip()


def _is_already_enrolled_error(error):
    message = str(error or "").strip().lower()
    return "already enrolled" in message or "deja enrol" in message


def _payload_indicates_match(payload):
    explicit = _read_first(
        payload,
        "match",
        "matched",
        "verified",
        "success",
        "is_match",
    )

    if isinstance(explicit, bool):
        return explicit

    if explicit is not None:
        normalized = str(explicit).strip().lower()
        if normalized in {"true", "1", "yes", "verified", "match", "matched", "success"}:
            return True
        if normalized in {"false", "0", "no", "failed", "mismatch", "not_matched"}:
            return False

    message = _read_message(payload).lower()
    if any(token in message for token in ["mismatch", "not match", "failed", "rejected"]):
        return False
    if any(token in message for token in ["verified", "matched", "success", "enrolled"]):
        return True

    return True


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


def perform_selfie_verification(user_id, id_document_path, selfie_path, device_id="mobile-app"):
    try:
        enrolled = enroll_face(
            user_id=user_id,
            image_path=id_document_path,
            device_id=device_id,
        )
    except Exception as error:
        if _is_already_enrolled_error(error):
            enrolled = {
                "success": True,
                "message": "User already enrolled.",
                "score": None,
                "reference": str(user_id),
                "raw_payload": {
                    "detail": "User already enrolled",
                },
            }
        else:
            raise

    verified = verify_face(
        user_id=user_id,
        image_path=selfie_path,
    )

    return {
        "enroll": enrolled,
        "verify": verified,
        "status": "VERIFIED" if verified["success"] else "FAILED",
        "score": verified.get("score"),
        "message": verified.get("message") or enrolled.get("message") or "",
        "reference": verified.get("reference") or enrolled.get("reference") or "",
        "raw_payload": {
            "enroll": enrolled.get("raw_payload"),
            "verify": verified.get("raw_payload"),
        },
    }
