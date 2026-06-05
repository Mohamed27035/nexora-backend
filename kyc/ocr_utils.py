import re

import pytesseract


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

        # ==========================
        # NNI
        # ==========================
        nni_match = re.search(

            r"(\\d{10})",

            text
        )

        if nni_match:

            data["nni"] = (
                nni_match.group(1)
            )

        # ==========================
        # PRENOM
        # ==========================
        prenom_match = re.search(

            r"Prenom.*?\\n([A-Za-z' ]+)",

            text,

            re.IGNORECASE
        )

        if prenom_match:

            data["prenom"] = (

                prenom_match
                .group(1)
                .strip()
            )

        # ==========================
        # PRENOM PERE
        # ==========================
        pere_match = re.search(

            r"Father.*?\\n([A-Za-z' ]+)",

            text,

            re.IGNORECASE
        )

        if pere_match:

            data["prenom_pere"] = (

                pere_match
                .group(1)
                .strip()
            )

        # ==========================
        # NOM FAMILLE
        # ==========================
        nom_match = re.search(

            r"Surname.*?\\n([A-Za-z' ]+)",

            text,

            re.IGNORECASE
        )

        if nom_match:

            data["nom_famille"] = (

                nom_match
                .group(1)
                .strip()
            )

        # ==========================
        # SEXE
        # ==========================
        sexe_match = re.search(

            r"Sex.*?\\n([MF])",

            text,

            re.IGNORECASE
        )

        if sexe_match:

            data["sexe"] = (

                sexe_match
                .group(1)
                .strip()
            )

        # ==========================
        # DATE NAISSANCE
        # ==========================
        date_match = re.search(

            r"(\\d{1,2}\\s+[A-Za-z]{3}/[A-Za-z]{3}\\s+\\d{4})",

            text
        )

        if date_match:

            data["date_naissance"] = (

                date_match
                .group(1)
            )

        # ==========================
        # LIEU NAISSANCE
        # ==========================
        lieu_match = re.search(

            r"Place of birth.*?\\n([A-Za-z' ]+)",

            text,

            re.IGNORECASE
        )

        if lieu_match:

            data["lieu_naissance"] = (

                lieu_match
                .group(1)
                .strip()
            )

    except Exception as e:

        print(
            "PARSE ERROR =>",
            str(e)
        )

    return data
