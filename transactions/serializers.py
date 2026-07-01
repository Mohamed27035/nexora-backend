from rest_framework import serializers

from .models import Beneficiary, Transaction


def _is_valid_topup_phone(provider, phone):
    if len(phone) != 8:
        return False

    prefixes = {
        "MAURITEL": {"4"},
        "MATTEL": {"3"},
        "CHINGUITEL": {"2"},
    }
    return phone[0] in prefixes.get(provider, set())


class TransactionSerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(
        source="sender.nom",
        read_only=True,
    )
    sender_full_name = serializers.SerializerMethodField()
    sender_display = serializers.SerializerMethodField()
    sender_email = serializers.CharField(
        source="sender.email",
        read_only=True,
    )
    sender_phone = serializers.CharField(
        source="sender.telephone",
        read_only=True,
    )
    receiver_name = serializers.CharField(
        source="receiver.nom",
        read_only=True,
    )
    receiver_full_name = serializers.SerializerMethodField()
    receiver_display = serializers.SerializerMethodField()
    receiver_email = serializers.CharField(
        source="receiver.email",
        read_only=True,
    )
    receiver_phone = serializers.CharField(
        source="receiver.telephone",
        read_only=True,
    )
    validated_by_name = serializers.CharField(
        source="validated_by.nom",
        read_only=True,
    )
    validated_by_full_name = serializers.SerializerMethodField()
    accountant_validated_by_name = serializers.CharField(
        source="accountant_validated_by.nom",
        read_only=True,
    )
    accountant_validated_by_full_name = serializers.SerializerMethodField()
    proof_url = serializers.SerializerMethodField()

    class Meta:
        model = Transaction
        fields = [
            "id",
            "sender",
            "sender_name",
            "sender_full_name",
            "sender_display",
            "sender_email",
            "sender_phone",
            "receiver",
            "receiver_name",
            "receiver_full_name",
            "receiver_display",
            "receiver_email",
            "receiver_phone",
            "montant",
            "type",
            "status",
            "note",
            "service_provider",
            "service_phone",
            "proof",
            "proof_url",
            "validation_note",
            "validated_by",
            "validated_by_name",
            "validated_by_full_name",
            "accountant_validated_by",
            "accountant_validated_by_name",
            "accountant_validated_by_full_name",
            "accountant_validation_note",
            "review_stage",
            "requires_admin_approval",
            "anomaly_detected",
            "anomaly_reason",
            "risk_score",
            "receipt_reference",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "status",
            "validated_by",
            "accountant_validated_by",
            "validation_note",
            "accountant_validation_note",
            "created_at",
            "updated_at",
            "proof_url",
            "review_stage",
            "requires_admin_approval",
            "anomaly_detected",
            "anomaly_reason",
            "risk_score",
            "receipt_reference",
        ]
        extra_kwargs = {
            "proof": {"required": False, "allow_null": True},
        }

    def _full_name(self, user):
        if not user:
            return ""
        return " ".join(
            part for part in [user.nom, user.prenom or ""] if part
        ).strip()

    def get_sender_full_name(self, obj):
        return self._full_name(obj.sender)

    def get_receiver_full_name(self, obj):
        return self._full_name(obj.receiver)

    def get_validated_by_full_name(self, obj):
        return self._full_name(obj.validated_by)

    def get_accountant_validated_by_full_name(self, obj):
        return self._full_name(obj.accountant_validated_by)

    def _display_identity(self, user):
        if not user:
            return "-"
        full_name = self._full_name(user)
        phone = (user.telephone or "").strip()
        email = (user.email or "").strip()
        if full_name and phone:
            return f"{full_name} ({phone})"
        if full_name:
            return full_name
        if phone and email:
            return f"{phone} ({email})"
        return phone or email or "-"

    def get_sender_display(self, obj):
        return self._display_identity(obj.sender)

    def get_receiver_display(self, obj):
        return self._display_identity(obj.receiver)

    def get_proof_url(self, obj):
        if not obj.proof:
            return None

        try:
            url = obj.proof.url
        except Exception:
            return None

        request = self.context.get("request")
        if request:
            return request.build_absolute_uri(url)
        return url

    def validate(self, data):
        transaction_type = data.get("type")
        receiver = data.get("receiver")
        sender = data.get("sender")
        montant = data.get("montant")
        service_provider = str(data.get("service_provider") or "").strip().upper()
        service_phone = "".join(ch for ch in str(data.get("service_phone") or "").strip() if ch.isdigit())

        if montant is None or montant <= 0:
            raise serializers.ValidationError("Montant invalide")

        if transaction_type == "TRANSFER":
            if not receiver:
                raise serializers.ValidationError("Destinataire obligatoire")
            if sender and receiver.id == sender.id:
                raise serializers.ValidationError(
                    "Impossible de transférer à soi-même"
                )

        if transaction_type in ["DEPOSIT", "WITHDRAW"] and receiver:
            raise serializers.ValidationError(
                f"{transaction_type.title()} ne doit pas avoir de destinataire"
            )

        if transaction_type == "TOPUP":
            allowed_providers = {
                choice[0] for choice in Transaction.SERVICE_PROVIDER_CHOICES
            }
            if receiver:
                raise serializers.ValidationError(
                    "La recharge mobile ne doit pas avoir de destinataire utilisateur"
                )
            if service_provider not in allowed_providers:
                raise serializers.ValidationError("Operateur invalide")
            if not _is_valid_topup_phone(service_provider, service_phone):
                raise serializers.ValidationError(
                    "Numero de recharge invalide pour l'operateur selectionne"
                )
            data["service_provider"] = service_provider
            data["service_phone"] = service_phone

        return data


class BeneficiarySerializer(serializers.ModelSerializer):
    beneficiary_name = serializers.CharField(source="beneficiary.nom", read_only=True)
    beneficiary_prenom = serializers.CharField(source="beneficiary.prenom", read_only=True)
    beneficiary_email = serializers.CharField(source="beneficiary.email", read_only=True)
    beneficiary_phone = serializers.CharField(source="beneficiary.telephone", read_only=True)
    beneficiary_full_name = serializers.SerializerMethodField()

    class Meta:
        model = Beneficiary
        fields = [
            "id",
            "owner",
            "beneficiary",
            "nickname",
            "beneficiary_name",
            "beneficiary_prenom",
            "beneficiary_email",
            "beneficiary_phone",
            "beneficiary_full_name",
            "created_at",
        ]
        read_only_fields = [
            "owner",
            "created_at",
            "beneficiary_name",
            "beneficiary_prenom",
            "beneficiary_email",
            "beneficiary_phone",
            "beneficiary_full_name",
        ]

    def get_beneficiary_full_name(self, obj):
        if not obj.beneficiary:
            return ""
        return " ".join(
            part for part in [obj.beneficiary.nom, obj.beneficiary.prenom or ""] if part
        ).strip()
