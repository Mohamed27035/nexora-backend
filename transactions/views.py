from decimal import Decimal, InvalidOperation

from django.db import transaction as db_transaction
from django.db.models import Q
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from notifications.models import Notification
from users.models import Utilisateur
from users.views import create_log, get_current_user, has_role

from .models import Transaction
from .serializers import TransactionSerializer


ALLOWED_TRANSACTION_TYPES = {
    "DEPOSIT",
    "WITHDRAW",
    "TRANSFER",
}

REVIEWER_ROLES = {
    "ADMIN",
    "COMPTABLE",
}


def _error(message, status_code=400):
    return Response({"error": message}, status=status_code)


def _normalize_transaction_type(value):
    return str(value or "").strip().upper()


def _normalize_sort(value):
    allowed = {
        "newest": "-created_at",
        "oldest": "created_at",
        "amount_desc": "-montant",
        "amount_asc": "montant",
        "updated_desc": "-updated_at",
    }
    return allowed.get(str(value or "").strip().lower(), "-created_at")


def _serialize_transaction(transaction, request):
    return TransactionSerializer(
        transaction,
        context={"request": request},
    ).data


def create_notification(user, message):
    try:
        Notification.objects.create(
            utilisateur=user,
            title="Transaction",
            message=message,
        )
    except Exception:
        pass


def _require_reviewer(user):
    return has_role(user, *REVIEWER_ROLES)


def _require_verified_for_financial_action(user, transaction_type):
    if transaction_type in {"WITHDRAW", "TRANSFER"} and not user.is_verified:
        return _error(
            "Votre compte doit être vérifié par KYC pour effectuer cette opération.",
            403,
        )
    return None


def _parse_amount(raw_amount):
    try:
        amount = Decimal(str(raw_amount))
    except (InvalidOperation, TypeError, ValueError):
        return None

    if amount <= 0:
        return None

    return amount.quantize(Decimal("0.01"))


def _find_receiver(data):
    receiver_id = data.get("receiver")
    receiver_email = str(data.get("receiver_email", "")).strip().lower()

    if receiver_id:
        return Utilisateur.objects.filter(id=receiver_id).first()

    if receiver_email:
        return Utilisateur.objects.filter(email=receiver_email).first()

    return None


@api_view(["POST"])
def create_transaction(request):
    user, error = get_current_user(request)
    if error:
        return error

    data = request.data.copy()
    data["sender"] = user.id

    transaction_type = _normalize_transaction_type(data.get("type"))
    amount = _parse_amount(data.get("montant"))

    if not amount:
        return _error("Montant invalide", 400)

    if transaction_type not in ALLOWED_TRANSACTION_TYPES:
        return _error("Type de transaction invalide", 400)

    kyc_error = _require_verified_for_financial_action(user, transaction_type)
    if kyc_error:
        return kyc_error

    receiver = None
    if transaction_type == "TRANSFER":
        receiver = _find_receiver(data)
        if not receiver:
            return _error("Destinataire introuvable", 404)
        if receiver.id == user.id:
            return _error("Impossible de transférer à soi-même", 400)
        if Decimal(str(user.balance)) < amount:
            return _error("Solde insuffisant", 400)
        data["receiver"] = receiver.id
    else:
        data.pop("receiver", None)

    data.pop("receiver_email", None)

    if transaction_type == "WITHDRAW" and Decimal(str(user.balance)) < amount:
        return _error("Solde insuffisant", 400)

    data["type"] = transaction_type
    data["montant"] = str(amount)

    serializer = TransactionSerializer(data=data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    transaction = serializer.save()

    create_log(
        user,
        "CREATE_TRANSACTION",
        (
            f"transaction_id={transaction.id};"
            f"type={transaction.type};amount={transaction.montant};status=PENDING"
        ),
    )

    create_notification(
        user,
        f"Votre transaction {transaction.type} a été créée et attend une validation.",
    )

    return Response(
        {
            "message": "Transaction créée avec succès.",
            "transaction": _serialize_transaction(transaction, request),
        },
        status=status.HTTP_201_CREATED,
    )


@api_view(["GET"])
def get_transactions(request):
    user, error = get_current_user(request)
    if error:
        return error

    status_filter = str(request.GET.get("status", "ALL")).strip().upper()
    type_filter = _normalize_transaction_type(request.GET.get("type", "ALL"))
    start = request.GET.get("start")
    end = request.GET.get("end")
    search = str(request.GET.get("search", "")).strip()
    sort = _normalize_sort(request.GET.get("sort"))

    if _require_reviewer(user):
        transactions = Transaction.objects.select_related(
            "sender",
            "receiver",
            "validated_by",
        ).all()
    else:
        transactions = Transaction.objects.select_related(
            "sender",
            "receiver",
            "validated_by",
        ).filter(Q(sender=user) | Q(receiver=user))

    if status_filter != "ALL":
        transactions = transactions.filter(status=status_filter)

    if type_filter != "ALL":
        transactions = transactions.filter(type=type_filter)

    if start:
        transactions = transactions.filter(created_at__date__gte=start)
    if end:
        transactions = transactions.filter(created_at__date__lte=end)

    if search:
        search_query = (
            Q(sender__nom__icontains=search)
            | Q(sender__prenom__icontains=search)
            | Q(sender__email__icontains=search)
            | Q(receiver__nom__icontains=search)
            | Q(receiver__prenom__icontains=search)
            | Q(receiver__email__icontains=search)
            | Q(type__icontains=search)
            | Q(status__icontains=search)
            | Q(note__icontains=search)
            | Q(validation_note__icontains=search)
        )

        if search.isdigit():
            search_query |= Q(id=int(search))

        transactions = transactions.filter(search_query)

    transactions = transactions.order_by(sort)

    serializer = TransactionSerializer(
        transactions,
        many=True,
        context={"request": request},
    )
    return Response(serializer.data)


def _apply_transaction_effect(transaction):
    sender = transaction.sender
    receiver = transaction.receiver
    amount = Decimal(str(transaction.montant)).quantize(Decimal("0.01"))

    if transaction.type == "DEPOSIT":
        sender.balance = float(Decimal(str(sender.balance)) + amount)
        sender.save(update_fields=["balance"])
        return

    if transaction.type == "WITHDRAW":
        current_balance = Decimal(str(sender.balance))
        if current_balance < amount:
            raise ValueError("Solde insuffisant")
        sender.balance = float(current_balance - amount)
        sender.save(update_fields=["balance"])
        return

    if transaction.type == "TRANSFER":
        if not receiver:
            raise ValueError("Destinataire manquant")

        sender_balance = Decimal(str(sender.balance))
        if sender_balance < amount:
            raise ValueError("Solde insuffisant")

        receiver_balance = Decimal(str(receiver.balance))
        sender.balance = float(sender_balance - amount)
        receiver.balance = float(receiver_balance + amount)
        sender.save(update_fields=["balance"])
        receiver.save(update_fields=["balance"])
        return

    raise ValueError("Type de transaction invalide")


@api_view(["POST"])
def approve_transaction(request, transaction_id):
    reviewer, error = get_current_user(request)
    if error:
        return error

    if not _require_reviewer(reviewer):
        return _error("Permission refusée", 403)

    transaction = Transaction.objects.select_related("sender", "receiver").filter(
        id=transaction_id
    ).first()
    if not transaction:
        return _error("Transaction introuvable", 404)

    if transaction.status != "PENDING":
        return _error("Cette transaction a déjà été traitée", 400)

    with db_transaction.atomic():
        try:
            _apply_transaction_effect(transaction)
        except ValueError as exc:
            return _error(str(exc), 400)

        transaction.status = "APPROVED"
        transaction.validated_by = reviewer
        transaction.validation_note = request.data.get("note", "")
        transaction.save(
            update_fields=["status", "validated_by", "validation_note", "updated_at"]
        )

    create_log(
        reviewer,
        "APPROVE_TRANSACTION",
        (
            f"transaction_id={transaction.id};"
            f"type={transaction.type};amount={transaction.montant};status=APPROVED"
        ),
    )

    create_notification(
        transaction.sender,
        f"Votre transaction #{transaction.id} a été approuvée.",
    )

    return Response(
        {
            "message": "Transaction approuvée.",
            "transaction": _serialize_transaction(transaction, request),
        }
    )


@api_view(["POST"])
def reject_transaction(request, transaction_id):
    reviewer, error = get_current_user(request)
    if error:
        return error

    if not _require_reviewer(reviewer):
        return _error("Permission refusée", 403)

    transaction = Transaction.objects.filter(id=transaction_id).first()
    if not transaction:
        return _error("Transaction introuvable", 404)

    if transaction.status != "PENDING":
        return _error("Cette transaction a déjà été traitée", 400)

    transaction.status = "REJECTED"
    transaction.validated_by = reviewer
    transaction.validation_note = request.data.get("note", "")
    transaction.save(
        update_fields=["status", "validated_by", "validation_note", "updated_at"]
    )

    create_log(
        reviewer,
        "REJECT_TRANSACTION",
        (
            f"transaction_id={transaction.id};"
            f"type={transaction.type};amount={transaction.montant};status=REJECTED"
        ),
    )

    create_notification(
        transaction.sender,
        f"Votre transaction #{transaction.id} a été rejetée.",
    )

    return Response(
        {
            "message": "Transaction rejetée.",
            "transaction": _serialize_transaction(transaction, request),
        }
    )
