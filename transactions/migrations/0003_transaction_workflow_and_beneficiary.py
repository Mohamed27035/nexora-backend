from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0005_emailverificationotp_payload_and_purpose"),
        ("transactions", "0002_transaction_proof"),
    ]

    operations = [
        migrations.AddField(
            model_name="transaction",
            name="accountant_validated_by",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="accountant_validated_transactions",
                to="users.utilisateur",
            ),
        ),
        migrations.AddField(
            model_name="transaction",
            name="accountant_validation_note",
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="transaction",
            name="review_stage",
            field=models.CharField(
                choices=[
                    ("AUTO", "Auto"),
                    ("SUBMITTED", "Submitted"),
                    ("ACCOUNTANT_REVIEW", "Accountant Review"),
                    ("ADMIN_REVIEW", "Admin Review"),
                    ("FINALIZED", "Finalized"),
                    ("REJECTED", "Rejected"),
                ],
                default="SUBMITTED",
                max_length=30,
            ),
        ),
        migrations.AddField(
            model_name="transaction",
            name="requires_admin_approval",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="transaction",
            name="anomaly_detected",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="transaction",
            name="anomaly_reason",
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="transaction",
            name="risk_score",
            field=models.FloatField(default=0),
        ),
        migrations.AddField(
            model_name="transaction",
            name="receipt_reference",
            field=models.CharField(blank=True, max_length=120, null=True),
        ),
        migrations.AlterField(
            model_name="transaction",
            name="status",
            field=models.CharField(
                choices=[
                    ("PENDING", "Pending"),
                    ("SUBMITTED", "Submitted"),
                    ("ACCOUNTANT_APPROVED", "Accountant Approved"),
                    ("APPROVED", "Approved"),
                    ("REJECTED", "Rejected"),
                ],
                default="PENDING",
                max_length=20,
            ),
        ),
        migrations.CreateModel(
            name="Beneficiary",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("nickname", models.CharField(blank=True, max_length=100, null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                (
                    "beneficiary",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="beneficiary_of",
                        to="users.utilisateur",
                    ),
                ),
                (
                    "owner",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="beneficiaries",
                        to="users.utilisateur",
                    ),
                ),
            ],
            options={
                "ordering": ["-created_at"],
                "unique_together": {("owner", "beneficiary")},
            },
        ),
    ]
