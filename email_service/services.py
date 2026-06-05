import json
import urllib.error
import urllib.request

from django.conf import settings


class ResendEmailError(Exception):
    pass


# =====================================
# SEND EMAIL VIA RESEND API
# =====================================
def send_system_email(
    to_email,
    subject,
    message,
    html_message=None,
):
    try:
        api_key = getattr(settings, "RESEND_API_KEY", "")
        from_email = getattr(settings, "RESEND_FROM_EMAIL", "") or getattr(settings, "DEFAULT_FROM_EMAIL", "")
        timeout = int(getattr(settings, "EMAIL_REQUEST_TIMEOUT", 15))

        if not api_key:
            raise ResendEmailError("RESEND_API_KEY is missing")

        if not from_email:
            raise ResendEmailError("RESEND_FROM_EMAIL is missing")

        payload = {
            "from": from_email,
            "to": [to_email],
            "subject": subject,
            "text": message,
        }

        if html_message:
            payload["html"] = html_message

        request = urllib.request.Request(
            url="https://api.resend.com/emails",
            data=json.dumps(payload).encode("utf-8"),
            method="POST",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
                "User-Agent": "nexora-django/1.0",
            },
        )

        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read().decode("utf-8")
            print("EMAIL SENT SUCCESSFULLY")
            return json.loads(body) if body else {}

    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8", errors="ignore")
        print("EMAIL ERROR =>", error_body)
        raise ResendEmailError(f"Resend HTTP {e.code}: {error_body}")

    except Exception as e:
        print("EMAIL ERROR =>", str(e))
        if isinstance(e, ResendEmailError):
            raise
        raise ResendEmailError(str(e))
