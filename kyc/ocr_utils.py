import json
import re
import unicodedata
from pathlib import Path

import pytesseract
import requests
from django.conf import settings


FIELD_ALIASES = {
    "nni": [
        "numero national d'identification",
        "numero national didentification",
        "national identification number",
        "numero national identification",
        "nni",
    ],
    "prenom": [
        "prenom/given name",
        "prenom given name",
        "given name",
        "prenom",
    ],
    "prenom_pere": [
        "prenom du pere/father's given name",
        "prenom du pere father's given name",
        "father's given name",
        "fathers given name",
        "prenom du pere",
    ],
    "nom_famille": [
        "nom de famille/surname",
        "nom de famille surname",
        "surname",
        "nom de famille",
    ],
    "sexe": [
        "sexe/sex",
        "sexe sex",
        "sex",
        "sexe",
    ],
    "date_naissance": [
        "date de naissance/date of birth",
        "date de naissance date of birth",
        "date of birth",
        "date de naissance",
    ],
    "lieu_naissance": [
        "lieu de naissance/place of birth",
        "lieu de naissance place of birth",
        "place of birth",
        "lieu de naissance",
    ],
}

EXTERNAL_FIELD_CANDIDATES = {
    "nni": [
        "nni",
        "numero_national_identification",
        "numero_national_didentification",
        "national_id",
        "id_number",
    ],
    "prenom": [
        "prenom",
        "first_name",
        "given_name",
        "givenName",
    ],
    "prenom_pere": [
        "prenom_pere",
        "father_name",
        "father_given_name",
    ],
    "nom_famille": [
        "nom_famille",
        "last_name",
        "surname",
        "family_name",
    ],
    "sexe": [
        "sexe",
        "sex",
        "gender",
    ],
    "date_naissance": [
        "date_naissance",
        "birth_date",
        "date_of_birth",
    ],
    "lieu_naissance": [
        "lieu_naissance",
        "birth_place",
        "place_of_birth",
    ],
    "ocr_text": [
        "ocr_text",
        "text",
        "raw_text",
        "full_text",
        "extracted_text",
    ],
}


def _strip_accents(value):
    normalized = unicodedata.normalize("NFKD", value)
    return "".join(ch for ch in normalized if not unicodedata.combining(ch))


def _normalize(value):
    cleaned = _strip_accents(str(value).lower())
    replacements = {
        "ÃƒÂ©": "e",
        "ÃƒÂ¨": "e",
        "ÃƒÂª": "e",
        "ÃƒÂ«": "e",
        "ÃƒÂ ": "a",
        "ÃƒÂ¢": "a",
        "ÃƒÂ®": "i",
        "ÃƒÂ¯": "i",
        "ÃƒÂ´": "o",
        "ÃƒÂ¹": "u",
        "ÃƒÂ»": "u",
        "ÃƒÂ§": "c",
        "â€™": "'",
        "ﬁ": "fi",
        "ﬂ": "fl",
    }
    for source, target in replacements.items():
        cleaned = cleaned.replace(source, target)
    cleaned = re.sub(r"[^a-z0-9'/ -]+", " ", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned


def _cleanup_value(value):
    text = str(value).replace("|", "I").replace(" ,", ",")
    text = text.replace("ﬁ", "fi").replace("ﬂ", "fl")
    text = re.sub(r"\s+", " ", text).strip(" :-\t")
    return text.strip()


def _external_ocr_is_configured():
    return bool(
        getattr(settings, "NOVA_OCR_BASE_URL", "").strip()
        and getattr(settings, "NOVA_OCR_API_KEY", "").strip()
    )


def _walk_payload(payload):
    if isinstance(payload, dict):
        yield payload
        for value in payload.values():
            yield from _walk_payload(value)
    elif isinstance(payload, list):
        for item in payload:
            yield from _walk_payload(item)


def _extract_from_payload(payload, keys):
    normalized_keys = {str(key).lower() for key in keys}

    for node in _walk_payload(payload):
        if not isinstance(node, dict):
            continue
        for key, value in node.items():
            if str(key).lower() in normalized_keys and value not in [None, ""]:
                if isinstance(value, (dict, list)):
                    continue
                return _cleanup_value(value)
    return ""


def _coerce_external_payload(raw_payload):
    if isinstance(raw_payload, dict):
        return raw_payload

    if isinstance(raw_payload, str):
        stripped = raw_payload.strip()
        if not stripped:
            return {"ocr_text": ""}
        try:
            parsed = json.loads(stripped)
            if isinstance(parsed, dict):
                return parsed
            return {"ocr_text": stripped, "payload": parsed}
        except Exception:
            return {"ocr_text": stripped}

    return {"payload": raw_payload}


def call_external_ocr_api(image_path):
    if not _external_ocr_is_configured():
        raise RuntimeError("External OCR API not configured.")

    endpoint = f"{settings.NOVA_OCR_BASE_URL.rstrip('/')}/api/ocr"

    with open(image_path, "rb") as image_file:
        response = requests.post(
            endpoint,
            headers={
                "Accept": "application/json",
                "Secure-Nova-Key": settings.NOVA_OCR_API_KEY,
            },
            files={
                "id_card": (
                    Path(image_path).name,
                    image_file,
                    "image/jpeg",
                )
            },
            timeout=getattr(settings, "NOVA_OCR_TIMEOUT", 45),
        )

    if response.status_code >= 400:
        raise RuntimeError(
            f"External OCR API error ({response.status_code}): {response.text[:500]}"
        )

    try:
        payload = response.json()
    except Exception:
        payload = response.text

    return _coerce_external_payload(payload)


def parse_external_ocr_payload(payload):
    source = _coerce_external_payload(payload)
    data = {
        "nni": "",
        "prenom": "",
        "prenom_pere": "",
        "nom_famille": "",
        "sexe": "",
        "date_naissance": "",
        "lieu_naissance": "",
    }

    raw_text = _extract_from_payload(source, EXTERNAL_FIELD_CANDIDATES["ocr_text"])
    if not raw_text:
        raw_text = json.dumps(source, ensure_ascii=False)

    for field_name in data.keys():
        value = _extract_from_payload(
            source,
            EXTERNAL_FIELD_CANDIDATES.get(field_name, []),
        )
        if field_name == "nni" and value:
            value = re.sub(r"\D", "", _normalize_nni_candidate(value))
        if field_name == "sexe" and value:
            value = value.upper()
        data[field_name] = value

    parsed_from_text = parse_mauritanian_id(raw_text)
    for field_name, value in parsed_from_text.items():
        if not data.get(field_name) and value:
            data[field_name] = value

    return {
        "ocr_text": raw_text,
        "fields": data,
        "raw_payload": source,
    }


def _looks_like_label(normalized_line):
    return any(
        alias in normalized_line
        for aliases in FIELD_ALIASES.values()
        for alias in aliases
    )


def _looks_like_name(value):
    compact = _cleanup_value(value)
    if len(compact) < 2:
        return False
    if any(char.isdigit() for char in compact):
        return False
    return bool(re.fullmatch(r"[A-Za-zÀ-ÿ' -]{2,}", compact))


def _looks_like_nni(value):
    compact = re.sub(r"\D", "", _normalize_nni_candidate(value))
    return 8 <= len(compact) <= 14


def _looks_like_date(value):
    cleaned = _cleanup_value(value)
    patterns = [
        r"\d{1,2}\s+[A-Za-z]{3,}(?:/[A-Za-z]{3,})?\s+\d{4}",
        r"\d{1,2}[/-]\d{1,2}[/-]\d{4}",
        r"\d{4}[/-]\d{1,2}[/-]\d{1,2}",
    ]
    return any(re.fullmatch(pattern, cleaned) for pattern in patterns)


def _looks_like_sex(value):
    return _cleanup_value(value).upper() in {"M", "F"}


def _normalize_nni_candidate(value):
    cleaned = _cleanup_value(value).upper()
    substitutions = {
        "O": "0",
        "Q": "0",
        "D": "0",
        "I": "1",
        "L": "1",
        "Z": "2",
        "S": "5",
        "B": "8",
        "G": "9",
    }
    for source, target in substitutions.items():
        cleaned = cleaned.replace(source, target)
    return cleaned


def _line_matches_field_hint(field_name, normalized_line):
    hint_groups = {
        "nni": [["ident"], ["nni", "nation", "num", "numero"]],
        "prenom": [["prenom", "prnom", "given", "gen"], ["name", "nane", "ane"]],
        "prenom_pere": [["pere", "prel", "father", "fath", "athe"], ["name", "nane", "ane"]],
        "nom_famille": [["famille", "fanlle", "surname", "surnae", "sur"]],
        "sexe": [["sex", "sexe", "sees"]],
        "date_naissance": [["date"], ["birth", "naiss", "nance"]],
        "lieu_naissance": [["place", "lieu"], ["birth", "naiss", "nance"]],
    }

    groups = hint_groups.get(field_name, [])
    if not groups:
        return False

    for group in groups:
        if not any(token in normalized_line for token in group):
            return False
    return True


def _value_matches_field(field_name, value):
    if not value:
        return False
    if field_name == "nni":
        return _looks_like_nni(value)
    if field_name in {"prenom", "prenom_pere", "nom_famille", "lieu_naissance"}:
        return _looks_like_name(value)
    if field_name == "date_naissance":
        return _looks_like_date(value)
    if field_name == "sexe":
        return _looks_like_sex(value)
    return False


def _extract_inline_value(line, alias):
    normalized_line = _normalize(line)
    alias_index = normalized_line.find(alias)
    if alias_index == -1:
        return ""

    source_index = min(alias_index + len(alias), len(line))
    remainder = _cleanup_value(line[source_index:])

    if not remainder:
        return ""

    for separator in ["/", "  "]:
        parts = [part.strip() for part in remainder.split(separator) if part.strip()]
        if len(parts) > 1:
            remainder = parts[0]
            break

    return _cleanup_value(remainder)


def _extract_value_after_label(line):
    parts = re.split(r"[:;]\s*", line, maxsplit=1)
    if len(parts) == 2:
        return _cleanup_value(parts[1])
    return ""


def _extract_field_value(field_name, lines, normalized_lines):
    aliases = FIELD_ALIASES[field_name]

    for index, line in enumerate(lines):
        normalized_line = normalized_lines[index]

        for alias in aliases:
            if alias not in normalized_line:
                continue

            inline = _extract_inline_value(line, alias)
            if _value_matches_field(field_name, inline):
                return inline

            after_label = _extract_value_after_label(line)
            if _value_matches_field(field_name, after_label):
                return after_label

            for next_index in range(index + 1, min(index + 4, len(lines))):
                candidate = _cleanup_value(lines[next_index])
                normalized_candidate = normalized_lines[next_index]

                if not candidate:
                    continue
                if _looks_like_label(normalized_candidate):
                    break

                if _value_matches_field(field_name, candidate):
                    return candidate

                if next_index + 1 < len(lines):
                    merged = _cleanup_value(f"{candidate} {lines[next_index + 1]}")
                    if _value_matches_field(field_name, merged):
                        return merged

        if _line_matches_field_hint(field_name, normalized_line):
            for next_index in range(index + 1, min(index + 4, len(lines))):
                candidate = _cleanup_value(lines[next_index])
                if _value_matches_field(field_name, candidate):
                    return candidate

    return ""


def _fallback_search(text, field_name):
    compact = _cleanup_value(text)

    patterns = {
        "nni": [
            r"\b(\d{8,14})\b",
            r"(\d{10})",
        ],
        "prenom": [
            r"(?:prenom|given name)\s*[:\-]?\s*([A-Za-zÀ-ÿ' -]{2,})",
        ],
        "prenom_pere": [
            r"(?:father'?s given name|prenom du pere)\s*[:\-]?\s*([A-Za-zÀ-ÿ' -]{2,})",
        ],
        "nom_famille": [
            r"(?:nom de famille|surname)\s*[:\-]?\s*([A-Za-zÀ-ÿ' -]{2,})",
        ],
        "sexe": [
            r"(?:sexe|sex)\s*[:\-]?\s*([MF])\b",
            r"\b([MF])\b",
        ],
        "date_naissance": [
            r"\b(\d{1,2}\s+[A-Za-z]{3,}(?:/[A-Za-z]{3,})?\s+\d{4})\b",
            r"\b(\d{1,2}[/-]\d{1,2}[/-]\d{4})\b",
            r"\b(\d{4}[/-]\d{1,2}[/-]\d{1,2})\b",
        ],
        "lieu_naissance": [
            r"(?:lieu de naissance|place of birth)\s*[:\-]?\s*([A-Za-zÀ-ÿ' -]{2,})",
        ],
    }

    for pattern in patterns.get(field_name, []):
        match = re.search(pattern, compact, re.IGNORECASE)
        if match:
            value = _cleanup_value(match.group(1))
            if field_name == "nni":
                value = re.sub(r"\D", "", _normalize_nni_candidate(value))
            if _value_matches_field(field_name, value):
                return value

    return ""


def extract_text_from_image(image_path):
    from PIL import Image, ImageFilter, ImageOps

    try:
        source = Image.open(image_path).convert("RGB")
        variants = []

        gray = ImageOps.grayscale(source)
        enhanced = ImageOps.autocontrast(gray)
        sharpened = enhanced.filter(ImageFilter.SHARPEN)

        for base in [gray, enhanced, sharpened]:
            variants.append(base)
            variants.append(base.resize((base.width * 2, base.height * 2)))

        configs = [
            "--oem 3 --psm 6",
            "--oem 3 --psm 11",
            "--oem 3 --psm 4",
        ]

        chunks = []
        for image in variants:
            for config in configs:
                try:
                    text = pytesseract.image_to_string(
                        image,
                        lang="eng",
                        config=config,
                    )
                    if text and text.strip():
                        chunks.append(text)
                except Exception:
                    continue

        return "\n".join(chunks)
    except Exception as exc:
        print("OCR ERROR =>", str(exc))
        return ""


def parse_mauritanian_id(text):
    data = {
        "nni": "",
        "prenom": "",
        "prenom_pere": "",
        "nom_famille": "",
        "sexe": "",
        "date_naissance": "",
        "lieu_naissance": "",
    }

    try:
        lines = [
            _cleanup_value(line)
            for line in text.replace("\r", "\n").split("\n")
            if _cleanup_value(line)
        ]
        normalized_lines = [_normalize(line) for line in lines]
        joined = " ".join(lines)

        for field_name in data.keys():
            value = _extract_field_value(field_name, lines, normalized_lines)
            if not value:
                value = _fallback_search(joined, field_name)
            data[field_name] = value

        for index, normalized_line in enumerate(normalized_lines):
            if not data["nni"] and "identification" in normalized_line:
                for candidate in lines[index:index + 3]:
                    if _looks_like_nni(candidate):
                        data["nni"] = re.sub(r"\D", "", _normalize_nni_candidate(candidate))
                        break

            if not data["prenom"] and ("given name" in normalized_line or normalized_line == "prenom"):
                for candidate in lines[index + 1:index + 3]:
                    if _looks_like_name(candidate):
                        data["prenom"] = candidate
                        break

            if not data["prenom_pere"] and (
                "father" in normalized_line or "prenom du pere" in normalized_line
            ):
                for candidate in lines[index + 1:index + 3]:
                    if _looks_like_name(candidate):
                        data["prenom_pere"] = candidate
                        break

            if not data["nom_famille"] and (
                "surname" in normalized_line or "nom de famille" in normalized_line
            ):
                for candidate in lines[index + 1:index + 3]:
                    if _looks_like_name(candidate):
                        data["nom_famille"] = candidate
                        break

            if not data["sexe"] and ("sex" in normalized_line or normalized_line == "sexe"):
                for candidate in lines[index:index + 3]:
                    cleaned = _cleanup_value(candidate).upper()
                    if cleaned in {"M", "F"}:
                        data["sexe"] = cleaned
                        break

            if not data["date_naissance"] and (
                "date of birth" in normalized_line or "date de naissance" in normalized_line
            ):
                for candidate in lines[index:index + 3]:
                    if _looks_like_date(candidate):
                        data["date_naissance"] = candidate
                        break

            if not data["lieu_naissance"] and (
                "place of birth" in normalized_line or "lieu de naissance" in normalized_line
            ):
                for candidate in lines[index + 1:index + 3]:
                    if _looks_like_name(candidate):
                        data["lieu_naissance"] = candidate
                        break

        if not data["lieu_naissance"]:
            for line in reversed(lines):
                normalized_line = _normalize(line)
                if (
                    _looks_like_name(line)
                    and "republique" not in normalized_line
                    and "identite" not in normalized_line
                    and "carte" not in normalized_line
                ):
                    data["lieu_naissance"] = line
                    break

        if data["nni"]:
            data["nni"] = re.sub(r"\D", "", _normalize_nni_candidate(data["nni"]))

        if data["sexe"]:
            data["sexe"] = data["sexe"].upper()

    except Exception as exc:
        print("PARSE ERROR =>", str(exc))

    return data
