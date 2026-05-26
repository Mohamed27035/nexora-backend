from django.core.mail import send_mail

from django.conf import settings


# =====================================
# SEND EMAIL
# =====================================
def send_system_email(

    to_email,

    subject,

    message
):

    try:

        send_mail(

            subject,

            message,

            settings.DEFAULT_FROM_EMAIL,

            [to_email],

            fail_silently=False
        )

        print(
            "EMAIL SENT SUCCESSFULLY"
        )

        return True

    except Exception as e:

        print(
            "EMAIL ERROR =>",
            str(e)
        )

        return False