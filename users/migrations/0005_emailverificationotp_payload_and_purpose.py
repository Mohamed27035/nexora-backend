from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0004_emailverificationotp"),
    ]

    operations = [
        migrations.AddField(
            model_name="emailverificationotp",
            name="payload",
            field=models.JSONField(blank=True, default=dict),
        ),
        migrations.AddField(
            model_name="emailverificationotp",
            name="purpose",
            field=models.CharField(default="generic", max_length=30),
        ),
    ]
