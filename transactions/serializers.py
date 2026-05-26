from rest_framework import serializers

from .models import Transaction

from users.models import Utilisateur


class TransactionSerializer(
    serializers.ModelSerializer
):

    # ==========================
    # NAMES
    # ==========================
    sender_name = serializers.CharField(

        source="sender.nom",

        read_only=True
    )

    receiver_name = serializers.CharField(

        source="receiver.nom",

        read_only=True
    )

    validated_by_name = serializers.CharField(

        source="validated_by.nom",

        read_only=True
    )

    # ==========================
    # PROOF URL
    # ==========================
    proof = serializers.FileField(
        required=False
    )

    # ==========================
    # META
    # ==========================
    class Meta:

        model = Transaction

        fields = [

            "id",

            "sender",

            "sender_name",

            "receiver",

            "receiver_name",

            "montant",

            "type",

            "status",

            "note",

            "proof",

            "validation_note",

            "validated_by",

            "validated_by_name",

            "created_at",

            "updated_at"
        ]

        read_only_fields = [

            "status",

            "validated_by",

            "validation_note",

            "created_at",

            "updated_at"
        ]

    # ==========================
    # VALIDATION
    # ==========================
    def validate(self, data):

        transaction_type = data.get(
            "type"
        )

        receiver = data.get(
            "receiver"
        )

        sender = data.get(
            "sender"
        )

        montant = data.get(
            "montant"
        )

        # ==========================
        # INVALID AMOUNT
        # ==========================
        if montant <= 0:

            raise serializers.ValidationError(

                "Montant invalide"
            )

        # ==========================
        # TRANSFER
        # ==========================
        if transaction_type == "TRANSFER":

            # receiver required
            if not receiver:

                raise serializers.ValidationError(

                    "Receiver obligatoire"
                )

            # cannot transfer to self
            if sender and receiver.id == sender.id:

                raise serializers.ValidationError(

                    "Impossible de transférer à soi-même"
                )

        # ==========================
        # DEPOSIT
        # ==========================
        if transaction_type == "DEPOSIT":

            if receiver:

                raise serializers.ValidationError(

                    "Deposit ne doit pas avoir receiver"
                )

        # ==========================
        # WITHDRAW
        # ==========================
        if transaction_type == "WITHDRAW":

            if receiver:

                raise serializers.ValidationError(

                    "Withdraw ne doit pas avoir receiver"
                )

        return data