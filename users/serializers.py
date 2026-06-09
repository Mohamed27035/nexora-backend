from rest_framework import serializers

from .models import Utilisateur


class UtilisateurSerializer(serializers.ModelSerializer):

    class Meta:
        model = Utilisateur
        fields = [
            "id",
            "nom",
            "prenom",
            "email",
            "password",
            "role",
            "telephone",
            "bio",
            "avatar",
            "last_login",
            "last_logout",
            "last_ip",
            "balance",
            "is_verified",
            "is_suspended",
            "is_banned",
        ]
        extra_kwargs = {
            "password": {"write_only": True, "required": False},
            "avatar": {"required": False, "allow_null": True},
        }
        read_only_fields = [
            "id",
            "last_login",
            "last_logout",
            "last_ip",
            "balance",
            "is_verified",
            "is_suspended",
            "is_banned",
        ]

    def validate_email(self, value):
        return value.strip().lower()

