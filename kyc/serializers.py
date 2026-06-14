from rest_framework import serializers

from .models import KYCRequest


class KYCRequestSerializer(serializers.ModelSerializer):
    utilisateur_name = serializers.CharField(
        source="utilisateur.nom",
        read_only=True,
    )
    utilisateur_full_name = serializers.SerializerMethodField()
    reviewed_by_name = serializers.CharField(
        source="reviewed_by.nom",
        read_only=True,
    )
    id_document_url = serializers.SerializerMethodField()
    selfie_url = serializers.SerializerMethodField()
    ocr_complete = serializers.SerializerMethodField()
    ocr_data = serializers.SerializerMethodField()

    class Meta:
        model = KYCRequest
        fields = [
            "id",
            "utilisateur",
            "utilisateur_name",
            "utilisateur_full_name",
            "id_document",
            "id_document_url",
            "selfie",
            "selfie_url",
            "status",
            "review_note",
            "reviewed_by",
            "reviewed_by_name",
            "submitted_at",
            "reviewed_at",
            "ocr_text",
            "ocr_data",
            "nni",
            "prenom",
            "prenom_pere",
            "nom_famille",
            "sexe",
            "date_naissance",
            "lieu_naissance",
            "biometric_status",
            "biometric_score",
            "biometric_message",
            "biometric_reference",
            "biometric_raw",
            "ocr_complete",
        ]
        read_only_fields = [
            "status",
            "reviewed_by",
            "reviewed_at",
            "ocr_text",
            "nni",
            "prenom",
            "prenom_pere",
            "nom_famille",
            "sexe",
            "date_naissance",
            "lieu_naissance",
            "biometric_status",
            "biometric_score",
            "biometric_message",
            "biometric_reference",
            "biometric_raw",
            "id_document_url",
            "selfie_url",
            "ocr_complete",
            "ocr_data",
            "utilisateur_name",
            "utilisateur_full_name",
            "reviewed_by_name",
        ]

    def get_utilisateur_full_name(self, obj):
        parts = [obj.utilisateur.nom, obj.utilisateur.prenom or ""]
        return " ".join(part for part in parts if part).strip()

    def _build_file_url(self, obj, field_name):
        field = getattr(obj, field_name, None)
        if not field:
            return None

        try:
            url = field.url
        except Exception:
            return None

        request = self.context.get("request")
        if request:
            return request.build_absolute_uri(url)
        return url

    def get_id_document_url(self, obj):
        return self._build_file_url(obj, "id_document")

    def get_selfie_url(self, obj):
        return self._build_file_url(obj, "selfie")

    def get_ocr_complete(self, obj):
        return any(
            [
                bool(obj.ocr_text),
                bool(obj.nni),
                bool(obj.prenom),
                bool(obj.nom_famille),
                bool(obj.date_naissance),
            ]
        )

    def get_ocr_data(self, obj):
        values = {
            "nni": obj.nni or "",
            "prenom": obj.prenom or "",
            "prenom_pere": obj.prenom_pere or "",
            "nom_famille": obj.nom_famille or "",
            "sexe": obj.sexe or "",
            "date_naissance": obj.date_naissance or "",
            "lieu_naissance": obj.lieu_naissance or "",
        }

        if any(values.values()):
            return values

        raw_text = (obj.ocr_text or "").strip()
        if not raw_text:
            return values

        try:
            from .ocr_utils import parse_mauritanian_id

            parsed = parse_mauritanian_id(raw_text) or {}
        except Exception:
            parsed = {}

        for key in values.keys():
            values[key] = parsed.get(key, "") or ""

        return values
