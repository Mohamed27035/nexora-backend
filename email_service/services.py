import json
import urllib.error
import urllib.request

from django.conf import settings
from django.core.mail import EmailMultiAlternatives


class EmailServiceError(Exception):
    pass


def has_email_provider_configured():

    return bool(
        _get_sendgrid_configured() or
        _get_resend_configured() or
        _get_mailersend_configured() or
        _get_brevo_configured() or
        _get_smtp_configured()
    )


def _get_sendgrid_configured():

    api_key = getattr(
        settings,
        "SENDGRID_API_KEY",
        ""
    )

    sender_email = getattr(
        settings,
        "SENDGRID_FROM_EMAIL",
        ""
    )

    return bool(
        api_key and
        sender_email
    )


def _get_smtp_configured():

    host = getattr(
        settings,
        "EMAIL_HOST",
        ""
    )

    username = getattr(
        settings,
        "EMAIL_HOST_USER",
        ""
    )

    password = getattr(
        settings,
        "EMAIL_HOST_PASSWORD",
        ""
    )

    from_email = getattr(
        settings,
        "DEFAULT_FROM_EMAIL",
        ""
    )

    return bool(
        host and
        username and
        password and
        from_email
    )


def _get_resend_configured():

    api_key = getattr(
        settings,
        "RESEND_API_KEY",
        ""
    )

    sender_email = getattr(
        settings,
        "RESEND_SENDER_EMAIL",
        ""
    )

    return bool(
        api_key and
        sender_email
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


def send_smtp_email(
    to_email,
    subject,
    message,
    html_message=None,
):
    from_email = getattr(
        settings,
        "DEFAULT_FROM_EMAIL",
        ""
    )

    if not from_email:
        raise EmailServiceError(
            "DEFAULT_FROM_EMAIL is missing"
        )

    email = EmailMultiAlternatives(
        subject=subject,
        body=message,
        from_email=from_email,
        to=[to_email],
    )

    if html_message:
        email.attach_alternative(
            html_message,
            "text/html"
        )

    email.send(
        fail_silently=False
    )

    return {
        "status": "sent_via_smtp"
    }


def send_sendgrid_email(
    to_email,
    subject,
    message,
    html_message=None,
):
    api_key = getattr(
        settings,
        "SENDGRID_API_KEY",
        ""
    )

    sender_email = getattr(
        settings,
        "SENDGRID_FROM_EMAIL",
        ""
    )

    sender_name = getattr(
        settings,
        "SENDGRID_FROM_NAME",
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
            "SENDGRID_API_KEY is missing"
        )

    if not sender_email:
        raise EmailServiceError(
            "SENDGRID_FROM_EMAIL is missing"
        )

    payload = {
        "personalizations": [
            {
                "to": [
                    {
                        "email": to_email
                    }
                ]
            }
        ],
        "from": {
            "email": sender_email,
            "name": sender_name,
        },
        "subject": subject,
        "content": [
            {
                "type": "text/plain",
                "value": message,
            },
            {
                "type": "text/html",
                "value": html_message or f"<html><body><p>{message}</p></body></html>",
            },
        ],
    }

    request = urllib.request.Request(
        url="https://api.sendgrid.com/v3/mail/send",
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
        print("EMAIL SENT SUCCESSFULLY VIA SENDGRID")
        return json.loads(body) if body else {}


def send_resend_email(
    to_email,
    subject,
    message,
    html_message=None,
):
    api_key = getattr(
        settings,
        "RESEND_API_KEY",
        ""
    )

    sender_email = getattr(
        settings,
        "RESEND_SENDER_EMAIL",
        ""
    )

    sender_name = getattr(
        settings,
        "RESEND_SENDER_NAME",
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
            "RESEND_API_KEY is missing"
        )

    if not sender_email:
        raise EmailServiceError(
            "RESEND_SENDER_EMAIL is missing"
        )

    payload = {
        "from": f"{sender_name} <{sender_email}>",
        "to": [
            to_email
        ],
        "subject": subject,
        "text": message,
        "html": html_message or f"<html><body><p>{message}</p></body></html>",
    }

    request = urllib.request.Request(
        url="https://api.resend.com/emails",
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
        print("EMAIL SENT SUCCESSFULLY VIA RESEND")
        return json.loads(body) if body else {}


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
                "No email provider configured. Set SendGrid, Resend, MailerSend, Brevo, or SMTP email environment variables."
            )

        if _get_sendgrid_configured():
            return send_sendgrid_email(
                to_email=to_email,
                subject=subject,
                message=message,
                html_message=html_message,
            )

        if _get_resend_configured():
            return send_resend_email(
                to_email=to_email,
                subject=subject,
                message=message,
                html_message=html_message,
            )

        if _get_mailersend_configured():
            return send_mailersend_email(
                to_email=to_email,
                subject=subject,
                message=message,
                html_message=html_message,
            )

        if _get_brevo_configured():
            return send_brevo_email(
                to_email=to_email,
                subject=subject,
                message=message,
                html_message=html_message,
            )

        return send_smtp_email(
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
            f"Email provider HTTP {e.code}: {error_body}"
        )

    except Exception as e:
        print("EMAIL ERROR =>", str(e))
        if isinstance(e, EmailServiceError):
            raise
        raise EmailServiceError(str(e))
