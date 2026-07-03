from rest_framework import serializers

from .models import InternalMessage, Notification


class NotificationSerializer(
    serializers.ModelSerializer
):

    class Meta:

        model = Notification

        fields = "__all__"


class InternalMessageSerializer(serializers.ModelSerializer):

    sender_name = serializers.SerializerMethodField()
    recipient_name = serializers.SerializerMethodField()
    sender_role = serializers.CharField(source="sender.role", read_only=True)
    recipient_role = serializers.CharField(source="recipient.role", read_only=True)
    related_transaction_status = serializers.SerializerMethodField()

    class Meta:
        model = InternalMessage
        fields = [
            "id",
            "sender",
            "sender_name",
            "sender_role",
            "recipient",
            "recipient_name",
            "recipient_role",
            "subject",
            "body",
            "category",
            "related_transaction",
            "related_transaction_status",
            "is_read",
            "created_at",
        ]
        read_only_fields = [
            "id",
            "sender",
            "sender_name",
            "sender_role",
            "recipient_name",
            "recipient_role",
            "related_transaction_status",
            "is_read",
            "created_at",
        ]

    def get_sender_name(self, obj):
        return " ".join(
            part for part in [obj.sender.nom, obj.sender.prenom or ""] if part
        ).strip()

    def get_recipient_name(self, obj):
        return " ".join(
            part for part in [obj.recipient.nom, obj.recipient.prenom or ""] if part
        ).strip()

    def get_related_transaction_status(self, obj):
        if not obj.related_transaction:
            return None
        return obj.related_transaction.status
