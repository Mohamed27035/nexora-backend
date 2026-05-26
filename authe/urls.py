from django.urls import path

from .views import (
    logine,
    register_admin,
    forgot_password,
    send_otp,
    verify_otp
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
]