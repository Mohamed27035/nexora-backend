from django.db import models
from users.models import Utilisateur

class Transaction(models.Model):
    STATUT_CHOICES = [
        ('SUCCESS', 'Succès'),
        ('FAILED', 'Échec'),
        ('PENDING', 'En attente'),
    ]

    utilisateur = models.ForeignKey(
    Utilisateur,
    on_delete=models.CASCADE,
    related_name="audit_transactions"  # 🔥 مختلف
)
    montant = models.FloatField()
    date = models.DateTimeField(auto_now_add=True)
    statut = models.CharField(max_length=20, choices=STATUT_CHOICES)

    def __str__(self):
        return f"{self.utilisateur.nom} - {self.montant}"