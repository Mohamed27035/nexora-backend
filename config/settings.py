"""
Django settings for config project.
"""

from pathlib import Path
from datetime import timedelta

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = 'django-insecure-z%66s$p0q_g0p!1fuailmx+1grx_h!4p377v-ql96@5m*#rw^!'

DEBUG = False

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
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
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


# 🔐 JWT CONFIG
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=60),
    'AUTH_HEADER_TYPES': ('Bearer',),
}


# 🔥 DRF + JWT (مهم جداً)


# 🌐 CORS
CORS_ALLOW_ALL_ORIGINS = True


APPEND_SLASH = True

print("DB PATH =>", DATABASES['default']['NAME'])
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'


# =====================================
# EMAIL CONFIG
# =====================================

EMAIL_BACKEND = (
    'django.core.mail.backends.smtp.EmailBackend'
)

EMAIL_HOST = 'smtp.gmail.com'

EMAIL_PORT = 587

EMAIL_USE_TLS = True

EMAIL_HOST_USER = 'mohamed27035@gmail.com'

EMAIL_HOST_PASSWORD = 'zogcvcajhvllgbjo'

DEFAULT_FROM_EMAIL = (
    EMAIL_HOST_USER
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
