"""
Django settings for config project.
"""

from pathlib import Path
from datetime import timedelta

import os
import dj_database_url

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get(
    "SECRET_KEY"
)
DEBUG = os.environ.get(
    "DEBUG"
) == "True"


GOOGLE_OAUTH2_CLIENT_ID = os.environ.get("GOOGLE_OAUTH2_CLIENT_ID", "")


def env_flag(name, default="False"):

    return os.environ.get(
        name,
        default
    ).strip().lower() in (
        "1",
        "true",
        "yes",
        "on"
    )


DEMO_OTP_MODE = env_flag(
    "DEMO_OTP_MODE"
)
ALLOWED_HOSTS = [".onrender.com"]


INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'channels',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'corsheaders',
    'users',
    'reporting',
    'audit',
    'logs',
    'authe',
    'transactions',
    'notifications',
    'email_service',
    'kyc',
]


MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]


ROOT_URLCONF = 'config.urls'


TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]


WSGI_APPLICATION = 'config.wsgi.application'
ASGI_APPLICATION = 'config.asgi.application'


DATABASES = {

    'default': dj_database_url.parse(

        os.environ.get(
            "DATABASE_URL"
        )
    )
}

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]


LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'

USE_I18N = True
USE_TZ = True


STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'


# ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â JWT CONFIG
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=60),
    'AUTH_HEADER_TYPES': ('Bearer',),
}


# ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â¥ DRF + JWT (Ãƒâ„¢Ã¢â‚¬Â¦Ãƒâ„¢Ã¢â‚¬Â¡Ãƒâ„¢Ã¢â‚¬Â¦ ÃƒËœÃ‚Â¬ÃƒËœÃ‚Â¯ÃƒËœÃ‚Â§Ãƒâ„¢Ã¢â‚¬Â¹)


# ÃƒÂ°Ã…Â¸Ã…â€™Ã‚Â CORS
CORS_ALLOW_ALL_ORIGINS = True


APPEND_SLASH = True




MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'


# =====================================
# EMAIL CONFIG
# =====================================

RESEND_API_KEY = os.environ.get(
    "RESEND_API_KEY",
    ""
)

RESEND_SENDER_EMAIL = os.environ.get(
    "RESEND_SENDER_EMAIL",
    ""
)

RESEND_SENDER_NAME = os.environ.get(
    "RESEND_SENDER_NAME",
    "Nexora"
)

MAILERSEND_API_KEY = os.environ.get(
    "MAILERSEND_API_KEY",
    ""
)

MAILERSEND_SENDER_EMAIL = os.environ.get(
    "MAILERSEND_SENDER_EMAIL",
    ""
)

MAILERSEND_SENDER_NAME = os.environ.get(
    "MAILERSEND_SENDER_NAME",
    "Nexora"
)

BREVO_API_KEY = os.environ.get(
    "BREVO_API_KEY",
    ""
)

BREVO_SENDER_EMAIL = os.environ.get(
    "BREVO_SENDER_EMAIL",
    ""
)

BREVO_SENDER_NAME = os.environ.get(
    "BREVO_SENDER_NAME",
    "Nexora"
)

EMAIL_REQUEST_TIMEOUT = int(
    os.environ.get(
        "EMAIL_REQUEST_TIMEOUT",
        "15"
    )
)

DEFAULT_FROM_EMAIL = (
    os.environ.get("SMTP_FROM_EMAIL", "") or
    RESEND_SENDER_EMAIL or
    BREVO_SENDER_EMAIL or
    MAILERSEND_SENDER_EMAIL or
    "no-reply@example.com"
)

EMAIL_BACKEND = os.environ.get(
    "EMAIL_BACKEND",
    "django.core.mail.backends.smtp.EmailBackend"
)

EMAIL_HOST = os.environ.get(
    "EMAIL_HOST",
    ""
)

EMAIL_PORT = int(
    os.environ.get(
        "EMAIL_PORT",
        "587"
    )
)

EMAIL_HOST_USER = os.environ.get(
    "EMAIL_HOST_USER",
    ""
)

EMAIL_HOST_PASSWORD = os.environ.get(
    "EMAIL_HOST_PASSWORD",
    ""
)

EMAIL_USE_TLS = env_flag(
    "EMAIL_USE_TLS",
    "True"
)

EMAIL_USE_SSL = env_flag(
    "EMAIL_USE_SSL",
    "False"
)

# =====================================
# CHANNELS
# =====================================

CHANNEL_LAYERS = {

    "default": {

        "BACKEND": (
            "channels.layers.InMemoryChannelLayer"
        ),
    },
}
