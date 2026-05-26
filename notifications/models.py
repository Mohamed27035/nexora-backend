from django.db import models

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