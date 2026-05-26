from django.db import models

from users.models import Utilisateur


class Transaction(models.Model):

    # ==========================
    # TYPES
    # ==========================
    TYPE_CHOICES = [

        ('DEPOSIT', 'Deposit'),

        ('WITHDRAW', 'Withdraw'),

        ('TRANSFER', 'Transfer'),
    ]

    # ==========================
    # STATUS
    # ==========================
    STATUS_CHOICES = [

        ('PENDING', 'Pending'),

        ('APPROVED', 'Approved'),

        ('REJECTED', 'Rejected'),
    ]

    # ==========================
    # USERS
    # ==========================
    sender = models.ForeignKey(

        Utilisateur,

        on_delete=models.CASCADE,

        related_name="sent_transactions"
    )

    receiver = models.ForeignKey(

        Utilisateur,

        on_delete=models.SET_NULL,

        null=True,

        blank=True,

        related_name="received_transactions"
    )

    # ==========================
    # TRANSACTION
    # ==========================
    montant = models.FloatField()

    type = models.CharField(

        max_length=20,

        choices=TYPE_CHOICES
    )

    status = models.CharField(

        max_length=20,

        choices=STATUS_CHOICES,

        default="PENDING"
    )

    note = models.TextField(

        blank=True,

        null=True
    )

    # ==========================
    # VALIDATION
    # ==========================
    validated_by = models.ForeignKey(

        Utilisateur,

        on_delete=models.SET_NULL,

        null=True,

        blank=True,

        related_name="validated_transactions"
    )

    validation_note = models.TextField(

        blank=True,

        null=True
    )
    proof = models.FileField(

    upload_to="transactions/",

    null=True,

    blank=True
)
    # ==========================
    # DATES
    # ==========================
    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    # ==========================
    # STRING
    # ==========================
    def __str__(self):

        return (
            f"{self.sender.nom} - "
            f"{self.type} - "
            f"{self.montant}"
        )