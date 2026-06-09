import re

import pytesseract


def _normalize(value):

    return (
        value.lower()
        .replace("é", "e")
        .replace("è", "e")
        .replace("ê", "e")
        .replace("ë", "e")
        .replace("à", "a")
        .replace("â", "a")
        .replace("î", "i")
        .replace("ï", "i")
        .replace("ô", "o")
        .replace("ù", "u")
        .replace("û", "u")
        .replace("ç", "c")
    )


# =====================================
# EXTRACT TEXT
# =====================================

def extract_text_from_image(
    image_path
):
    from PIL import Image

    try:

        image = Image.open(
            image_path
        )

        text = (
            pytesseract
            .image_to_string(
                image,
                lang="eng"
            )
        )

        return text

    except Exception as e:

        print(
            "OCR ERROR =>",
            str(e)
        )

        return ""


# =====================================
# PARSE MAURITANIAN ID
# =====================================

def parse_mauritanian_id(
    text
):

    data = {

        "nni": "",

        "prenom": "",

        "prenom_pere": "",

        "nom_famille": "",

        "sexe": "",

        "date_naissance": "",

        "lieu_naissance": ""
    }

    try:

        lines = [
            line.strip()
            for line in text.replace(
                "\r",
                "\n"
            ).split("\n")
            if line.strip()
        ]

        normalized_lines = [
            _normalize(line)
            for line in lines
        ]

        joined = " ".join(lines)
        compact_joined = joined.replace(
            " ",
            ""
        )

        def next_value_for(labels):

            normalized_labels = [
                _normalize(label)
                for label in labels
            ]

            for index, line in enumerate(lines):

                normalized_line = normalized_lines[index]

                for raw_label, normalized_label in zip(labels, normalized_labels):

                    label_index = normalized_line.find(
                        normalized_label
                    )

                    if label_index == -1:
                        continue

                    safe_index = min(
                        label_index + len(raw_label),
                        len(line)
                    )

                    remainder = line[
                        safe_index:
                    ].replace(
                        ":",
                        ""
                    ).strip()

                    if remainder and len(remainder) > 1:
                        return remainder

                    for next_index in range(
                        index + 1,
                        len(lines)
                    ):

                        candidate = lines[
                            next_index
                        ].strip()

                        normalized_candidate = normalized_lines[
                            next_index
                        ]

                        if not candidate:
                            continue

                        if any(
                            label in normalized_candidate
                            for label in normalized_labels
                        ):
                            break

                        if (
                            re.match(
                                r"^[A-Za-zÀ-ÿ' -]{2,}$",
                                candidate
                            )
                            or re.match(
                                r"^\d{8,14}$",
                                candidate
                            )
                            or re.match(
                                r"^\d{1,2}\s+[A-Za-z]{3}(?:/[A-Za-z]{3})?\s+\d{4}$",
                                candidate
                            )
                            or re.match(
                                r"^[MF]$",
                                candidate,
                                re.IGNORECASE
                            )
                        ):
                            return candidate

            return ""

        def first_match(pattern):

            match = re.search(
                pattern,
                joined,
                re.IGNORECASE
            )

            return match.group(1).strip() if match else ""

        compact_nni_match = re.search(
            r"(\d{8,14})",
            compact_joined
        )

        data["nni"] = first_match(
            r"\b(\d{8,14})\b"
        ) or first_match(
            r"(\d{8,14})"
        ) or (
            compact_nni_match.group(1)
            if compact_nni_match else ""
        )

        data["prenom"] = next_value_for(
            [
                "Prenom/Given name",
                "Prenom",
                "Given name",
            ]
        ) or first_match(
            r"prenom\/given name\s*([A-Za-zÀ-ÿ' -]{2,})"
        )

        data["prenom_pere"] = next_value_for(
            [
                "Prenom du pere/Father's given name",
                "Father's given name",
                "Prenom du pere",
            ]
        ) or first_match(
            r"(?:father's given name|prenom du pere)\s*([A-Za-zÀ-ÿ' -]{2,})"
        )

        data["nom_famille"] = next_value_for(
            [
                "Nom de famille/Surname",
                "Nom de famille",
                "Surname",
            ]
        ) or first_match(
            r"(?:nom de famille|surname)\s*([A-Za-zÀ-ÿ' -]{2,})"
        )

        data["sexe"] = next_value_for(
            [
                "Sexe/Sex",
                "Sexe",
                "Sex",
            ]
        ) or first_match(
            r"(?:sexe|sex)\s*([MF])"
        )

        data["date_naissance"] = next_value_for(
            [
                "Date de naissance/Date of birth",
                "Date de naissance",
                "Date of birth",
            ]
        ) or first_match(
            r"(\d{1,2}\s+[A-Za-z]{3}(?:/[A-Za-z]{3})?\s+\d{4})"
        )

        data["lieu_naissance"] = next_value_for(
            [
                "Lieu de naissance/Place of birth",
                "Lieu de naissance",
                "Place of birth",
            ]
        ) or first_match(
            r"(?:lieu de naissance|place of birth)\s*([A-Za-zÀ-ÿ' -]{2,})"
        )

        if not data["lieu_naissance"]:
            for line in reversed(lines):
                normalized_line = _normalize(
                    line
                )
                if (
                    re.match(
                        r"^[A-Za-zÀ-ÿ' -]{3,}$",
                        line
                    )
                    and "republique" not in normalized_line
                    and "identification" not in normalized_line
                ):
                    data["lieu_naissance"] = line
                    break

        if not data["sexe"]:
            sex_match = re.search(
                r"\b([MF])\b",
                joined,
                re.IGNORECASE
            )
            if sex_match:
                data["sexe"] = sex_match.group(
                    1
                ).upper()

    except Exception as e:

        print(
            "PARSE ERROR =>",
            str(e)
        )

    return data
