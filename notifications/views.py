from rest_framework.decorators import api_view
from rest_framework.response import Response

from .models import Notification
from .serializers import NotificationSerializer

from users.views import get_current_user
from asgiref.sync import async_to_sync

from channels.layers import (
    get_channel_layer
)

# ==========================
# GET USER NOTIFICATIONS
# ==========================
@api_view(["GET"])
def my_notifications(request):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    notifications = Notification.objects.filter(

        utilisateur=current_user

    ).order_by("-created_at")

    serializer = NotificationSerializer(

        notifications,

        many=True
    )

    return Response(serializer.data)


# ==========================
# MARK AS READ
# ==========================
@api_view(["POST"])
def mark_as_read(request, pk):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    try:

        notif = Notification.objects.get(

            id=pk,

            utilisateur=current_user
        )

        notif.is_read = True

        notif.save()

        return Response({
            "message": "Notification lue"
        })

    except Notification.DoesNotExist:

        return Response({

            "error": "Notification introuvable"

        }, status=404)


# ==========================
# DELETE NOTIFICATION
# ==========================
@api_view(["DELETE"])
def delete_notification(request, pk):

    current_user, error = get_current_user(
        request
    )

    if error:
        return error

    try:

        notif = Notification.objects.get(

            id=pk,

            utilisateur=current_user
        )

        notif.delete()

        return Response({
            "message": "Notification supprimée"
        })

    except Notification.DoesNotExist:

        return Response({

            "error": "Notification introuvable"

        }, status=404)
    
    # ==========================
# SEND LIVE NOTIFICATION
# ==========================
def send_live_notification(message):

    channel_layer = (
        get_channel_layer()
    )

    async_to_sync(

        channel_layer.group_send

    )(

        "notifications",

        {

            "type":
            "send_notification",

            "message":
            message
        }
    )