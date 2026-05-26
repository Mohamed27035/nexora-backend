from django.db import models


class Utilisateur(models.Model):

    # ==========================
    # ROLES
    # ==========================
    ROLE_CHOICES = [

        ('ADMIN', 'Administrateur'),

        ('AUDITEUR', 'Auditeur'),

        ('COMPTABLE', 'Comptable'),

        ('CLIENT', 'Client'),
    ]

    # ==========================
    # BASIC
    # ==========================
    nom = models.CharField(
        max_length=100
    )

    prenom = models.CharField(
        max_length=100,
        blank=True,
        null=True
    )

    email = models.EmailField(
        unique=True
    )

    password = models.CharField(
        max_length=255
    )

    role = models.CharField(
        max_length=20,
        choices=ROLE_CHOICES
    )

    # ==========================
    # PROFILE
    # ==========================
    telephone = models.CharField(
        max_length=30,
        blank=True,
        null=True
    )

    bio = models.TextField(
        blank=True,
        null=True
    )

    avatar = models.ImageField(
        upload_to="avatars/",
        blank=True,
        null=True
    )

    # ==========================
    # SECURITY
    # ==========================
    last_login = models.DateTimeField(
        null=True,
        blank=True
    )

    last_logout = models.DateTimeField(
        null=True,
        blank=True
    )

    last_ip = models.CharField(
        max_length=50,
        null=True,
        blank=True
    )

    # ==========================
    # WALLET
    # ==========================
    balance = models.FloatField(
        default=0
    )

    # ==========================
    # STATUS
    # ==========================
    is_verified = models.BooleanField(
        default=False
    )

    is_suspended = models.BooleanField(
        default=False
    )
    # ==========================
# STATUS
# ==========================
    is_verified = models.BooleanField(
    default=False
    )

    is_suspended = models.BooleanField(
    default=False
    )

    is_banned = models.BooleanField(
    default=False
    )
   # ==========================
# OTP
# ==========================
    otp_code = models.CharField(
    max_length=10,
    blank=True,
    null=True
)

    otp_created_at = models.DateTimeField(
    blank=True,
    null=True
)

    # ==========================
    # STRING
    # ==========================
    def __str__(self):

        return f"{self.nom} {self.prenom or ''}"