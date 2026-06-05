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

DEMO_OTP_MODE = os.environ.get(
    "DEMO_OTP_MODE",
    "False"
) == "True"
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

RESEND_FROM_EMAIL = os.environ.get(
    "RESEND_FROM_EMAIL",
    "Nexora <no-reply@example.com>"
)

EMAIL_REQUEST_TIMEOUT = int(
    os.environ.get(
        "EMAIL_REQUEST_TIMEOUT",
        "15"
    )
)

DEFAULT_FROM_EMAIL = RESEND_FROM_EMAIL

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
