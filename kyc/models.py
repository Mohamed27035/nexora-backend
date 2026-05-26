from django.db import models

from users.models import Utilisateur


class KYCRequest(models.Model):

    # ==========================
    # STATUS
    # ==========================
    STATUS_CHOICES = [

        ("PENDING", "Pending"),

        ("APPROVED", "Approved"),

        ("REJECTED", "Rejected"),
    ]

    # ==========================
    # USER
    # ==========================
    utilisateur = models.ForeignKey(

        Utilisateur,

        on_delete=models.CASCADE,

        related_name="kyc_requests"
    )

    # ==========================
    # FILES
    # ==========================
    id_document = models.ImageField(

        upload_to="kyc/id_documents/"
    )

    selfie = models.ImageField(

        upload_to="kyc/selfies/"
    )

    # ==========================
    # REVIEW
    # ==========================
    status = models.CharField(

        max_length=20,

        choices=STATUS_CHOICES,

        default="PENDING"
    )

    review_note = models.TextField(

        blank=True,

        null=True
    )

    reviewed_by = models.ForeignKey(

        Utilisateur,

        on_delete=models.SET_NULL,

        null=True,

        blank=True,

        related_name="reviewed_kyc"
    )

    # ==========================
    # OCR DATA
    # ==========================
    ocr_text = models.TextField(

        blank=True,

        null=True
    )

    nni = models.CharField(

        max_length=50,

        blank=True,

        null=True
    )

    prenom = models.CharField(

        max_length=255,

        blank=True,

        null=True
    )

    prenom_pere = models.CharField(

        max_length=255,

        blank=True,

        null=True
    )

    nom_famille = models.CharField(

        max_length=255,

        blank=True,

        null=True
    )

    sexe = models.CharField(

        max_length=10,

        blank=True,

        null=True
    )

    date_naissance = models.CharField(

        max_length=100,

        blank=True,

        null=True
    )

    lieu_naissance = models.CharField(

        max_length=255,

        blank=True,

        null=True
    )

    # ==========================
    # DATES
    # ==========================
    submitted_at = models.DateTimeField(

        auto_now_add=True
    )

    reviewed_at = models.DateTimeField(

        null=True,

        blank=True
    )

    # ==========================
    # STRING
    # ==========================
    def __str__(self):

        return (

            f"{self.utilisateur.nom} "

            f"- {self.status}"
        )