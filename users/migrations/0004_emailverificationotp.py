from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0003_utilisateur_otp_code_utilisateur_otp_created_at"),
    ]

    operations = [
        migrations.CreateModel(
            name="EmailVerificationOTP",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("email", models.EmailField(max_length=254, unique=True)),
                ("otp_code", models.CharField(max_length=10)),
                ("otp_created_at", models.DateTimeField()),
            ],
        ),
    ]
