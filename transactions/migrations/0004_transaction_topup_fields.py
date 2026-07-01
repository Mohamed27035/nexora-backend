from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("transactions", "0003_transaction_workflow_and_beneficiary"),
    ]

    operations = [
        migrations.AlterField(
            model_name="transaction",
            name="type",
            field=models.CharField(
                choices=[
                    ("DEPOSIT", "Deposit"),
                    ("WITHDRAW", "Withdraw"),
                    ("TRANSFER", "Transfer"),
                    ("TOPUP", "Top Up"),
                ],
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name="transaction",
            name="service_phone",
            field=models.CharField(blank=True, max_length=20, null=True),
        ),
        migrations.AddField(
            model_name="transaction",
            name="service_provider",
            field=models.CharField(
                blank=True,
                choices=[
                    ("MAURITEL", "Mauritel"),
                    ("MATTEL", "Mattel"),
                    ("CHINGUITEL", "Chinguitel"),
                ],
                max_length=20,
                null=True,
            ),
        ),
    ]
