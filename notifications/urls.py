from django.urls import path

from .views import *

urlpatterns = [

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