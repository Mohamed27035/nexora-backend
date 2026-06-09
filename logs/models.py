from django.db import models

from users.models import Utilisateur


class Log(models.Model):
    ACTION_CHOICES = [
        ("LOGIN", "Connexion"),
        ("LOGOUT", "Déconnexion"),
        ("CREATE_USER", "Créer utilisateur"),
        ("UPDATE_USER", "Modifier utilisateur"),
        ("DELETE_USER", "Supprimer utilisateur"),
        ("SUSPEND_USER", "Suspendre utilisateur"),
        ("ACTIVATE_USER", "Réactiver utilisateur"),
        ("BAN_USER", "Bannir utilisateur"),
        ("CHANGE_ROLE", "Changer rôle"),
        ("RESET_PASSWORD", "Réinitialiser mot de passe"),
        ("UPDATE_PROFILE", "Mettre à jour profil"),
        ("SUBMIT_KYC", "Soumettre KYC"),
        ("APPROVE_KYC", "Approuver KYC"),
        ("REJECT_KYC", "Rejeter KYC"),
        ("CREATE_TRANSACTION", "Créer transaction"),
        ("APPROVE_TRANSACTION", "Approuver transaction"),
        ("REJECT_TRANSACTION", "Rejeter transaction"),
        ("GENERATE_REPORT", "Générer rapport"),
    ]

    SEVERITY_CHOICES = [
        ("INFO", "Info"),
        ("WARNING", "Warning"),
        ("CRITICAL", "Critical"),
    ]

    utilisateur = models.ForeignKey(
        Utilisateur,
        on_delete=models.SET_NULL,
        null=True,
    )
    action = models.CharField(max_length=50, choices=ACTION_CHOICES)
    description = models.TextField(blank=True)
    entity_type = models.CharField(max_length=50, blank=True, default="")
    entity_id = models.CharField(max_length=50, blank=True, default="")
    target_repr = models.CharField(max_length=255, blank=True, default="")
    severity = models.CharField(
        max_length=20,
        choices=SEVERITY_CHOICES,
        default="INFO",
    )
    metadata = models.JSONField(default=dict, blank=True)
    is_suspicious = models.BooleanField(default=False)
    date = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.utilisateur} - {self.action}"

