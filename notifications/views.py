from rest_framework.decorators import api_view
from rest_framework.response import Response

from transactions.models import Transaction
from users.models import Utilisateur
from users.views import (
    create_log,
    get_current_user,
    has_role,
    normalize_role,
    serialize_user,
)

from .models import InternalMessage, Notification
from .serializers import InternalMessageSerializer, NotificationSerializer
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


def _send_internal_notification(recipient, sender, subject, category):
    sender_name = " ".join(
        part for part in [sender.nom, sender.prenom or ""] if part
    ).strip() or sender.email
    title = "Nouveau message interne"
    message = f"{sender_name} vous a envoye un message ({category.lower()})."
    if subject:
        message = f"{message} Sujet: {subject}"

    Notification.objects.create(
        utilisateur=recipient,
        title=title,
        message=message,
        type="info",
    )
    send_live_notification(message)


def _allowed_recipient_queryset(current_user):
    role = normalize_role(getattr(current_user, "role", ""))

    if role == "ADMIN":
        return Utilisateur.objects.exclude(id=current_user.id)

    # Non-admin roles exchange operational remarks and support requests
    # exclusively through the administration channel.
    if role in {"COMPTABLE", "AUDITEUR", "CLIENT"}:
        return Utilisateur.objects.filter(role="ADMIN").exclude(id=current_user.id)

    return Utilisateur.objects.filter(role="ADMIN").exclude(id=current_user.id)


def _can_message(current_user, recipient):
    return _allowed_recipient_queryset(current_user).filter(id=recipient.id).exists()


@api_view(["GET"])
def message_contacts(request):

    current_user, error = get_current_user(request)
    if error:
        return error

    contacts = _allowed_recipient_queryset(current_user)
    return Response([serialize_user(contact, request) for contact in contacts])


@api_view(["GET"])
def my_messages(request):

    current_user, error = get_current_user(request)
    if error:
        return error

    mailbox = str(request.GET.get("mailbox", "all")).strip().lower()
    unread_only = str(request.GET.get("unread_only", "")).strip().lower() in {
        "1",
        "true",
        "yes",
        "oui",
    }
    related_transaction_id = request.GET.get("transaction_id")

    queryset = InternalMessage.objects.filter(
        sender=current_user
    ) | InternalMessage.objects.filter(
        recipient=current_user
    )

    if mailbox == "inbox":
        queryset = queryset.filter(recipient=current_user)
    elif mailbox == "sent":
        queryset = queryset.filter(sender=current_user)

    if unread_only:
        queryset = queryset.filter(recipient=current_user, is_read=False)

    if related_transaction_id:
        queryset = queryset.filter(related_transaction_id=related_transaction_id)

    serializer = InternalMessageSerializer(
        queryset.order_by("-created_at"),
        many=True,
    )
    return Response(serializer.data)


@api_view(["POST"])
def send_message(request):

    current_user, error = get_current_user(request)
    if error:
        return error

    recipient_id = request.data.get("recipient_id")
    body = str(request.data.get("body", "")).strip()
    subject = str(request.data.get("subject", "")).strip()
    category = normalize_role(request.data.get("category") or "").upper() or "GENERAL"
    related_transaction_id = request.data.get("transaction_id")

    valid_categories = {choice[0] for choice in InternalMessage.CATEGORY_CHOICES}
    if category not in valid_categories:
        category = "GENERAL"

    if not recipient_id:
        return Response({"error": "Destinataire manquant"}, status=400)

    if not body:
        return Response({"error": "Le contenu du message est obligatoire"}, status=400)

    try:
        recipient = Utilisateur.objects.get(id=int(recipient_id))
    except Exception:
        return Response({"error": "Destinataire introuvable"}, status=404)

    if not _can_message(current_user, recipient):
        return Response({"error": "Envoi non autorise vers ce destinataire"}, status=403)

    related_transaction = None
    if related_transaction_id:
        related_transaction = Transaction.objects.filter(id=related_transaction_id).first()
        if related_transaction is None:
            return Response({"error": "Transaction introuvable"}, status=404)

    message = InternalMessage.objects.create(
        sender=current_user,
        recipient=recipient,
        subject=subject,
        body=body,
        category=category,
        related_transaction=related_transaction,
    )

    create_log(
        current_user,
        "SEND_INTERNAL_MESSAGE",
        target=subject or body[:120],
        entity_type="MESSAGE",
        entity_id=message.id,
        target_repr=recipient.email,
        metadata={
            "category": category,
            "recipient_id": recipient.id,
            "transaction_id": getattr(related_transaction, "id", None),
        },
    )

    _send_internal_notification(recipient, current_user, subject, category)

    return Response(
        InternalMessageSerializer(message).data,
        status=201,
    )


@api_view(["POST"])
def mark_message_as_read(request, pk):

    current_user, error = get_current_user(request)
    if error:
        return error

    try:
        message = InternalMessage.objects.get(
            id=pk,
            recipient=current_user,
        )
    except InternalMessage.DoesNotExist:
        return Response({"error": "Message introuvable"}, status=404)

    if not message.is_read:
        message.is_read = True
        message.save(update_fields=["is_read"])

    return Response({"message": "Message marque comme lu"})


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
