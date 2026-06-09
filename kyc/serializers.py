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
            "nni",
            "prenom",
            "prenom_pere",
            "nom_famille",
            "sexe",
            "date_naissance",
            "lieu_naissance",
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
            "id_document_url",
            "selfie_url",
            "ocr_complete",
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

