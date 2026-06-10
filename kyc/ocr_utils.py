import re
import unicodedata

import pytesseract


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
    compact = re.sub(r"\D", "", _cleanup_value(value))
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
                        data["nni"] = re.sub(r"\D", "", candidate)
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
            data["nni"] = re.sub(r"\D", "", data["nni"])

        if data["sexe"]:
            data["sexe"] = data["sexe"].upper()

    except Exception as exc:
        print("PARSE ERROR =>", str(exc))

    return data
