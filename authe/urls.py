from django.urls import path

from .views import (
    logine,
    register_admin,
    forgot_password,
    send_otp,
    verify_otp,
    send_welcome_otp,
    verify_welcome_otp,
)


urlpatterns = [

    path(
        'logine/',
        logine
    ),

    path(
        'register-admin/',
        register_admin
    ),

    path(
        'forgot-password/',
        forgot_password
    ),

    path(
        'send-otp/',
        send_otp
    ),

    path(
        'verify-otp/',
        verify_otp
    ),

    path(
    'send-welcome-otp/',
    send_welcome_otp
),
    path(
    'verify-welcome-otp/',
     verify_welcome_otp

),
]