from rest_framework import serializers

from .models import KYCRequest


class KYCRequestSerializer(
    serializers.ModelSerializer
):

    # ==========================
    # USER NAME
    # ==========================
    utilisateur_name = serializers.CharField(

        source="utilisateur.nom",

        read_only=True
    )

    # ==========================
    # REVIEWER NAME
    # ==========================
    reviewed_by_name = serializers.CharField(

        source="reviewed_by.nom",

        read_only=True
    )

    class Meta:

        model = KYCRequest

        fields = [

            # ==========================
            # BASIC
            # ==========================
            "id",

            "utilisateur",

            "utilisateur_name",

            "id_document",

            "selfie",

            "status",

            "review_note",

            "reviewed_by",

            "reviewed_by_name",

            "submitted_at",

            "reviewed_at",

            # ==========================
            # OCR DATA
            # ==========================
            "ocr_text",

            "nni",

            "prenom",

            "prenom_pere",

            "nom_famille",

            "sexe",

            "date_naissance",

            "lieu_naissance",
        ]

        read_only_fields = [

            "status",

            "reviewed_by",

            "reviewed_at",

            # ==========================
            # OCR READONLY
            # ==========================
            "ocr_text",

            "nni",

            "prenom",

            "prenom_pere",

            "nom_famille",

            "sexe",

            "date_naissance",

            "lieu_naissance",
        ]