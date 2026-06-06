import json
import urllib.error
import urllib.request

from django.conf import settings


class EmailServiceError(Exception):
    pass


def has_email_provider_configured():

    return bool(
        _get_mailersend_configured() or
        _get_brevo_configured()
    )


def _get_mailersend_configured():

    api_key = getattr(
        settings,
        "MAILERSEND_API_KEY",
        ""
    )

    sender_email = getattr(
        settings,
        "MAILERSEND_SENDER_EMAIL",
        ""
    )

    return bool(
        api_key and
        sender_email
    )


def _get_brevo_configured():

    api_key = getattr(
        settings,
        "BREVO_API_KEY",
        ""
    )

    sender_email = getattr(
        settings,
        "BREVO_SENDER_EMAIL",
        ""
    )

    return bool(
        api_key and
        sender_email
    )


def send_mailersend_email(
    to_email,
    subject,
    message,
    html_message=None,
):
    api_key = getattr(
        settings,
        "MAILERSEND_API_KEY",
        ""
    )

    sender_email = getattr(
        settings,
        "MAILERSEND_SENDER_EMAIL",
        ""
    )

    sender_name = getattr(
        settings,
        "MAILERSEND_SENDER_NAME",
        "Nexora"
    )

    timeout = int(
        getattr(
            settings,
            "EMAIL_REQUEST_TIMEOUT",
            15
        )
    )

    if not api_key:
        raise EmailServiceError(
            "MAILERSEND_API_KEY is missing"
        )

    if not sender_email:
        raise EmailServiceError(
            "MAILERSEND_SENDER_EMAIL is missing"
        )

    payload = {
        "from": {
            "email": sender_email,
            "name": sender_name,
        },
        "to": [
            {
                "email": to_email
            }
        ],
        "subject": subject,
        "text": message,
        "html": html_message or f"<html><body><p>{message}</p></body></html>",
    }

    request = urllib.request.Request(
        url="https://api.mailersend.com/v1/email",
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "nexora-django/1.0",
        },
    )

    with urllib.request.urlopen(
        request,
        timeout=timeout
    ) as response:
        body = response.read().decode("utf-8")
        print("EMAIL SENT SUCCESSFULLY VIA MAILERSEND")
        return json.loads(body) if body else {}


def send_brevo_email(
    to_email,
    subject,
    message,
    html_message=None,
):
    api_key = getattr(
        settings,
        "BREVO_API_KEY",
        ""
    )

    sender_email = getattr(
        settings,
        "BREVO_SENDER_EMAIL",
        ""
    )

    sender_name = getattr(
        settings,
        "BREVO_SENDER_NAME",
        "Nexora"
    )

    timeout = int(
        getattr(
            settings,
            "EMAIL_REQUEST_TIMEOUT",
            15
        )
    )

    if not api_key:
        raise EmailServiceError(
            "BREVO_API_KEY is missing"
        )

    if not sender_email:
        raise EmailServiceError(
            "BREVO_SENDER_EMAIL is missing"
        )

    payload = {
        "sender": {
            "email": sender_email,
            "name": sender_name,
        },
        "to": [
            {
                "email": to_email,
            }
        ],
        "subject": subject,
        "textContent": message,
        "htmlContent": html_message or f"<html><body><p>{message}</p></body></html>",
    }

    request = urllib.request.Request(
        url="https://api.brevo.com/v3/smtp/email",
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
        headers={
            "api-key": api_key,
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "nexora-django/1.0",
        },
    )

    with urllib.request.urlopen(
        request,
        timeout=timeout
    ) as response:
        body = response.read().decode("utf-8")
        print("EMAIL SENT SUCCESSFULLY VIA BREVO")
        return json.loads(body) if body else {}


def send_system_email(
    to_email,
    subject,
    message,
    html_message=None,
):
    try:
        if not has_email_provider_configured():
            raise EmailServiceError(
                "No email provider configured. Set MailerSend or Brevo email environment variables."
            )

        if _get_mailersend_configured():
            return send_mailersend_email(
                to_email=to_email,
                subject=subject,
                message=message,
                html_message=html_message,
            )

        return send_brevo_email(
            to_email=to_email,
            subject=subject,
            message=message,
            html_message=html_message,
        )

    except urllib.error.HTTPError as e:
        error_body = e.read().decode(
            "utf-8",
            errors="ignore"
        )
        print("EMAIL ERROR =>", error_body)
        raise EmailServiceError(
            f"MailerSend HTTP {e.code}: {error_body}"
        )

    except Exception as e:
        print("EMAIL ERROR =>", str(e))
        if isinstance(e, EmailServiceError):
            raise
        raise EmailServiceError(str(e))
