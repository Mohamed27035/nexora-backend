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

        ('TOPUP', 'Top Up'),
    ]

    SERVICE_PROVIDER_CHOICES = [
        ('MAURITEL', 'Mauritel'),
        ('MATTEL', 'Mattel'),
        ('CHINGUITEL', 'Chinguitel'),
    ]

    # ==========================
    # STATUS
    # ==========================
    STATUS_CHOICES = [

        ('PENDING', 'Pending'),

        ('SUBMITTED', 'Submitted'),

        ('ACCOUNTANT_APPROVED', 'Accountant Approved'),

        ('APPROVED', 'Approved'),

        ('REJECTED', 'Rejected'),
    ]

    REVIEW_STAGE_CHOICES = [
        ('AUTO', 'Auto'),
        ('SUBMITTED', 'Submitted'),
        ('ACCOUNTANT_REVIEW', 'Accountant Review'),
        ('ADMIN_REVIEW', 'Admin Review'),
        ('FINALIZED', 'Finalized'),
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

    service_provider = models.CharField(
        max_length=20,
        choices=SERVICE_PROVIDER_CHOICES,
        blank=True,
        null=True,
    )

    service_phone = models.CharField(
        max_length=20,
        blank=True,
        null=True,
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

    accountant_validated_by = models.ForeignKey(

        Utilisateur,

        on_delete=models.SET_NULL,

        null=True,

        blank=True,

        related_name="accountant_validated_transactions"
    )

    accountant_validation_note = models.TextField(

        blank=True,

        null=True
    )

    review_stage = models.CharField(

        max_length=30,

        choices=REVIEW_STAGE_CHOICES,

        default="SUBMITTED"
    )

    requires_admin_approval = models.BooleanField(default=False)

    anomaly_detected = models.BooleanField(default=False)

    anomaly_reason = models.TextField(blank=True, null=True)

    risk_score = models.FloatField(default=0)

    receipt_reference = models.CharField(max_length=120, blank=True, null=True)

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


class Beneficiary(models.Model):
    owner = models.ForeignKey(
        Utilisateur,
        on_delete=models.CASCADE,
        related_name="beneficiaries",
    )
    beneficiary = models.ForeignKey(
        Utilisateur,
        on_delete=models.CASCADE,
        related_name="beneficiary_of",
    )
    nickname = models.CharField(max_length=100, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("owner", "beneficiary")
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.owner_id}->{self.beneficiary_id}"
