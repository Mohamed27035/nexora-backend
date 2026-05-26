# logs/models.py
from django.db import models
from users.models import Utilisateur

class Log(models.Model):
    ACTION_CHOICES = [
        ('LOGIN', 'Connexion'),
        ('LOGOUT', 'Déconnexion'),
        ('CREATE_USER', 'Créer utilisateur'),
        ('UPDATE_USER', 'Modifier utilisateur'),
        ('DELETE_USER', 'Supprimer utilisateur'),
        ('GENERATE_REPORT', 'Générer rapport'),
    ]

    utilisateur = models.ForeignKey(Utilisateur, on_delete=models.SET_NULL, null=True)
    action = models.CharField(max_length=50, choices=ACTION_CHOICES)
    description = models.TextField(blank=True)
    is_suspicious = models.BooleanField(default=False)
    date = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.utilisateur} - {self.action}"