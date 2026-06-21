from rest_framework import serializers

from .models import Transaction


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
            "proof",
            "proof_url",
            "validation_note",
            "validated_by",
            "validated_by_name",
            "validated_by_full_name",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "status",
            "validated_by",
            "validation_note",
            "created_at",
            "updated_at",
            "proof_url",
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

        return data
