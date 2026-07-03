from django.db import models

from transactions.models import Transaction
from users.models import Utilisateur


class Notification(models.Model):

    utilisateur = models.ForeignKey(

        Utilisateur,

        on_delete=models.CASCADE,

        related_name="notifications"
    )

    title = models.CharField(
        max_length=255
    )

    message = models.TextField()

    type = models.CharField(

        max_length=50,

        default="info"
    )

    is_read = models.BooleanField(
        default=False
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    def __str__(self):

        return self.title


class InternalMessage(models.Model):

    CATEGORY_CHOICES = [
        ("GENERAL", "General"),
        ("SUPPORT", "Support"),
        ("TRANSACTION", "Transaction"),
        ("ALERT", "Alert"),
        ("AUDIT", "Audit"),
    ]

    sender = models.ForeignKey(
        Utilisateur,
        on_delete=models.CASCADE,
        related_name="sent_internal_messages",
    )

    recipient = models.ForeignKey(
        Utilisateur,
        on_delete=models.CASCADE,
        related_name="received_internal_messages",
    )

    subject = models.CharField(
        max_length=255,
        blank=True,
        default="",
    )

    body = models.TextField()

    category = models.CharField(
        max_length=50,
        choices=CATEGORY_CHOICES,
        default="GENERAL",
    )

    related_transaction = models.ForeignKey(
        Transaction,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="internal_messages",
    )

    is_read = models.BooleanField(
        default=False
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.sender_id} -> {self.recipient_id}: {self.subject or 'message'}"
