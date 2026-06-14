from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("kyc", "0002_kycrequest_date_naissance_kycrequest_lieu_naissance_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="kycrequest",
            name="biometric_message",
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="kycrequest",
            name="biometric_raw",
            field=models.JSONField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="kycrequest",
            name="biometric_reference",
            field=models.CharField(blank=True, max_length=255, null=True),
        ),
        migrations.AddField(
            model_name="kycrequest",
            name="biometric_score",
            field=models.FloatField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="kycrequest",
            name="biometric_status",
            field=models.CharField(
                choices=[
                    ("PENDING", "Pending"),
                    ("VERIFIED", "Verified"),
                    ("FAILED", "Failed"),
                    ("ERROR", "Error"),
                    ("SKIPPED", "Skipped"),
                ],
                default="PENDING",
                max_length=20,
            ),
        ),
    ]
