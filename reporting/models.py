from django.db import models
from users.models import Utilisateur

class Rapport(models.Model):
    TYPE_CHOICES = [
        ('FINANCIER', 'Financier'),
        ('AUDIT', 'Audit'),
    ]

    utilisateur = models.ForeignKey(Utilisateur, on_delete=models.CASCADE)
    type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    contenu = models.TextField()
    date_creation = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Rapport {self.type} - {self.utilisateur.nom}"