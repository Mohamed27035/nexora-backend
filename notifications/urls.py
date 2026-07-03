from django.urls import path

from .views import *

urlpatterns = [

    path(
        "contacts/",
        message_contacts
    ),

    path(
        "messages/",
        my_messages
    ),

    path(
        "messages/send/",
        send_message
    ),

    path(
        "messages/read/<int:pk>/",
        mark_message_as_read
    ),

    path(
        "my/",
        my_notifications
    ),

    path(
        "read/<int:pk>/",
        mark_as_read
    ),

    path(
        "delete/<int:pk>/",
        delete_notification
    ),
]
