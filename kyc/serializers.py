from rest_framework import serializers

from .models import KYCRequest


class KYCRequestSerializer(serializers.ModelSerializer):
    REQUIRED_OCR_FIELDS = [
        "nni",
        "prenom",
        "prenom_pere",
        "nom_famille",
        "sexe",
        "date_naissance",
        "lieu_naissance",
    ]

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
    ocr_confidence = serializers.SerializerMethodField()
    ocr_extracted_fields = serializers.SerializerMethodField()
    ocr_required_fields = serializers.SerializerMethodField()
    ocr_missing_fields = serializers.SerializerMethodField()
    face_detected = serializers.SerializerMethodField()
    face_confidence = serializers.SerializerMethodField()
    biometric_decision = serializers.SerializerMethodField()
    similarity_threshold = serializers.SerializerMethodField()
    liveness_threshold = serializers.SerializerMethodField()
    liveness_score = serializers.SerializerMethodField()
    confidence_score = serializers.SerializerMethodField()
    risk_score = serializers.SerializerMethodField()
    biometric_summary = serializers.SerializerMethodField()

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
            "ocr_confidence",
            "ocr_extracted_fields",
            "ocr_required_fields",
            "ocr_missing_fields",
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
            "face_detected",
            "face_confidence",
            "biometric_decision",
            "similarity_threshold",
            "liveness_threshold",
            "liveness_score",
            "confidence_score",
            "risk_score",
            "biometric_summary",
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
            "ocr_confidence",
            "ocr_extracted_fields",
            "ocr_required_fields",
            "ocr_missing_fields",
            "face_detected",
            "face_confidence",
            "biometric_decision",
            "similarity_threshold",
            "liveness_threshold",
            "liveness_score",
            "confidence_score",
            "risk_score",
            "biometric_summary",
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
        return self._ocr_extracted_count(obj) > 0

    def _ocr_extracted_count(self, obj):
        return sum(
            1
            for field_name in self.REQUIRED_OCR_FIELDS
            if bool(getattr(obj, field_name, None))
        )

    def _normalize_score(self, value):
        if value in [None, ""]:
            return None

        try:
            score = float(value)
        except Exception:
            return None

        if score <= 1:
            score *= 100

        if score < 0:
            score = 0
        if score > 100:
            score = 100

        return round(score, 2)

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

    def get_ocr_confidence(self, obj):
        required = len(self.REQUIRED_OCR_FIELDS)
        if required == 0:
            return 0.0
        return round((self._ocr_extracted_count(obj) / required) * 100, 2)

    def get_ocr_extracted_fields(self, obj):
        return self._ocr_extracted_count(obj)

    def get_ocr_required_fields(self, obj):
        return len(self.REQUIRED_OCR_FIELDS)

    def get_ocr_missing_fields(self, obj):
        missing = []
        for field_name in self.REQUIRED_OCR_FIELDS:
            if not getattr(obj, field_name, None):
                missing.append(field_name)
        return missing

    def get_face_confidence(self, obj):
        raw = obj.biometric_raw or {}
        assessment = raw.get("assessment") if isinstance(raw, dict) else None
        if isinstance(assessment, dict):
            score = self._normalize_score(
                assessment.get("similarity_score", assessment.get("score"))
            )
            if score is not None:
                return score

        score = self._normalize_score(obj.biometric_score)
        if score is not None:
            return score

        if obj.biometric_status == "VERIFIED":
            return 100.0
        if obj.biometric_status == "FAILED":
            return 0.0
        return None

    def get_face_detected(self, obj):
        raw = obj.biometric_raw or {}
        assessment = raw.get("assessment") if isinstance(raw, dict) else None
        if isinstance(assessment, dict) and assessment.get("face_detected") is not None:
            return bool(assessment.get("face_detected"))

        if obj.biometric_status == "VERIFIED":
            return True

        score = self.get_face_confidence(obj)
        if score is not None:
            return score > 0

        raw = obj.biometric_raw or {}
        if isinstance(raw, dict) and raw:
            if raw.get("error"):
                return False
            return True

        return False

    def get_biometric_decision(self, obj):
        raw = obj.biometric_raw or {}
        assessment = raw.get("assessment") if isinstance(raw, dict) else None
        if isinstance(assessment, dict):
            value = assessment.get("decision")
            if value not in [None, ""]:
                return value
        verify = raw.get("verify") if isinstance(raw, dict) else None
        if isinstance(verify, dict):
            value = verify.get("decision")
            if value not in [None, ""]:
                return value
        return ""

    def get_similarity_threshold(self, obj):
        raw = obj.biometric_raw or {}
        assessment = raw.get("assessment") if isinstance(raw, dict) else None
        if isinstance(assessment, dict):
            return self._normalize_score(assessment.get("similarity_threshold", assessment.get("threshold")))
        return None

    def get_liveness_threshold(self, obj):
        raw = obj.biometric_raw or {}
        assessment = raw.get("assessment") if isinstance(raw, dict) else None
        if isinstance(assessment, dict):
            return self._normalize_score(assessment.get("liveness_threshold"))
        return None

    def get_liveness_score(self, obj):
        raw = obj.biometric_raw or {}
        assessment = raw.get("assessment") if isinstance(raw, dict) else None
        if isinstance(assessment, dict):
            return self._normalize_score(assessment.get("liveness_score"))
        return None

    def get_confidence_score(self, obj):
        raw = obj.biometric_raw or {}
        assessment = raw.get("assessment") if isinstance(raw, dict) else None
        if isinstance(assessment, dict):
            return self._normalize_score(assessment.get("confidence_score"))
        return None

    def get_risk_score(self, obj):
        raw = obj.biometric_raw or {}
        assessment = raw.get("assessment") if isinstance(raw, dict) else None
        if isinstance(assessment, dict):
            return self._normalize_score(assessment.get("risk_score"))
        return None

    def get_biometric_summary(self, obj):
        raw = obj.biometric_raw or {}
        assessment = raw.get("assessment") if isinstance(raw, dict) else None
        return {
            "status": obj.biometric_status,
            "confidence": self.get_face_confidence(obj),
            "face_detected": self.get_face_detected(obj),
            "message": obj.biometric_message or "",
            "reference": obj.biometric_reference or "",
            "eligible": bool(assessment.get("eligible")) if isinstance(assessment, dict) else False,
            "threshold": self.get_similarity_threshold(obj) or 70.0,
            "decision": self.get_biometric_decision(obj),
            "similarity_score": self.get_face_confidence(obj),
            "liveness_score": self.get_liveness_score(obj),
            "confidence_score": self.get_confidence_score(obj),
            "risk_score": self.get_risk_score(obj),
            "liveness_threshold": self.get_liveness_threshold(obj),
        }
