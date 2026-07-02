from datetime import timedelta
from decimal import Decimal, InvalidOperation
import uuid

from django.db import transaction as db_transaction
from django.db.models import Q, Sum
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from notifications.models import Notification
from users.models import Utilisateur
from users.views import create_log, get_current_user, has_role

from .models import Beneficiary, Transaction
from .serializers import BeneficiarySerializer, TransactionSerializer


ALLOWED_TRANSACTION_TYPES = {
    "DEPOSIT",
    "WITHDRAW",
    "TRANSFER",
    "TOPUP",
}

REVIEWER_ROLES = {
    "ADMIN",
    "COMPTABLE",
}

ACCOUNTANT_ROLES = {
    "COMPTABLE",
}

ADMIN_ROLES = {
    "ADMIN",
}

HIGH_RISK_AMOUNT = Decimal("10000.00")
VERIFIED_DAILY_LIMIT = Decimal("30000.00")
UNVERIFIED_DAILY_LIMIT = Decimal("5000.00")
MULTI_TRANSFER_THRESHOLD = 4
TOPUP_DENOMINATIONS = {
    Decimal("10.00"),
    Decimal("50.00"),
    Decimal("100.00"),
    Decimal("200.00"),
    Decimal("300.00"),
    Decimal("500.00"),
    Decimal("1000.00"),
    Decimal("2000.00"),
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


def _is_accountant(user):
    return has_role(user, *ACCOUNTANT_ROLES)


def _is_admin(user):
    return has_role(user, *ADMIN_ROLES)


def _require_verified_for_financial_action(user, transaction_type):
    if has_role(user, "CLIENT") and not user.is_verified:
        return _error(
            "Votre compte doit être vérifié par KYC avant d'utiliser les services financiers.",
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
    receiver_phone = "".join(
        ch for ch in str(data.get("receiver_phone", "")).strip() if ch.isdigit()
    )

    if receiver_id:
        return Utilisateur.objects.filter(id=receiver_id).first()

    if receiver_phone:
        matches = Utilisateur.objects.filter(telephone=receiver_phone)
        if matches.count() == 1:
            return matches.first()
        return None

    if receiver_email:
        return Utilisateur.objects.filter(email=receiver_email).first()

    return None


def _normalize_service_phone(value):
    return "".join(ch for ch in str(value or "").strip() if ch.isdigit())


def _normalize_service_provider(value):
    return str(value or "").strip().upper()


def _is_valid_topup_phone(provider, phone):
    if len(phone) != 8:
        return False

    prefixes = {
        "MAURITEL": {"4"},
        "MATTEL": {"3"},
        "CHINGUITEL": {"2"},
    }
    return phone[0] in prefixes.get(provider, set())


def _can_initiate_financial_transaction(user):
    return getattr(user, "role", "").upper() == "CLIENT"


def _generate_receipt_reference(transaction):
    timestamp = timezone.now().strftime("%Y%m%d%H%M%S")
    return f"NXR-{transaction.type[:3]}-{transaction.id}-{timestamp}"


def _daily_total_for_sender(user, *, day=None):
    current_day = day or timezone.now().date()
    total = (
        Transaction.objects.filter(
            sender=user,
            created_at__date=current_day,
            status__in=["SUBMITTED", "PENDING", "ACCOUNTANT_APPROVED", "APPROVED"],
        ).aggregate(total=Sum("montant")).get("total")
        or 0
    )
    return Decimal(str(total)).quantize(Decimal("0.01"))


def _recent_transfer_count(user, *, minutes=15):
    since = timezone.now() - timedelta(minutes=minutes)
    return Transaction.objects.filter(
        sender=user,
        type="TRANSFER",
        created_at__gte=since,
    ).count()


def _build_anomaly_snapshot(user, amount, transaction_type):
    reasons = []
    risk_score = Decimal("0")

    if amount >= HIGH_RISK_AMOUNT:
        reasons.append("Montant inhabituellement eleve")
        risk_score += Decimal("35")

    recent_count = _recent_transfer_count(user)
    if transaction_type == "TRANSFER" and recent_count >= MULTI_TRANSFER_THRESHOLD:
        reasons.append("Plusieurs transferts en peu de temps")
        risk_score += Decimal("25")

    if getattr(user, "last_ip", None):
        prior_ips = Transaction.objects.filter(sender=user).exclude(id__isnull=True).count()
        if prior_ips >= 10 and not user.is_verified:
            reasons.append("Compte peu fiable avec activite inhabituelle")
            risk_score += Decimal("15")

    if not getattr(user, "is_verified", False):
        reasons.append("Compte non verifie")
        risk_score += Decimal("20")

    return {
        "anomaly_detected": bool(reasons),
        "anomaly_reason": " ; ".join(reasons),
        "risk_score": float(min(risk_score, Decimal("100"))),
    }


def _enforce_dynamic_limits(user, amount):
    if not has_role(user, "CLIENT"):
        return _error("Compte non eligible aux operations financieres.", 403)

    if getattr(user, "is_suspended", False) or getattr(user, "is_banned", False):
        return _error("Votre compte n'est pas autorise a effectuer cette operation.", 403)

    daily_limit = VERIFIED_DAILY_LIMIT if user.is_verified else UNVERIFIED_DAILY_LIMIT
    today_total = _daily_total_for_sender(user)

    if today_total + amount > daily_limit:
        return _error(
            f"Plafond journalier atteint. Limite actuelle: {daily_limit} MRU.",
            400,
        )

    return None


def _requires_multi_level(transaction_type, anomaly_detected, amount):
    return transaction_type == "WITHDRAW"


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

    if transaction.type == "TOPUP":
        current_balance = Decimal(str(sender.balance))
        if current_balance < amount:
            raise ValueError("Solde insuffisant")
        sender.balance = float(current_balance - amount)
        sender.save(update_fields=["balance"])
        return

    raise ValueError("Type de transaction invalide")


@api_view(["POST"])
def create_transaction(request):
    user, error = get_current_user(request)
    if error:
        return error

    if not _can_initiate_financial_transaction(user):
        return _error(
            "Seuls les comptes client peuvent initier des operations financieres",
            403,
        )

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

    limit_error = _enforce_dynamic_limits(user, amount)
    if limit_error:
        return limit_error

    receiver = None
    if transaction_type == "TRANSFER":
        receiver = _find_receiver(data)
        if not receiver:
            return _error("Destinataire introuvable avec ce numéro de téléphone", 404)
        if getattr(receiver, "role", "").upper() != "CLIENT":
            return _error("Le destinataire doit etre un compte client", 400)
        if receiver.id == user.id:
            return _error("Impossible de transferer a soi-meme", 400)
        if Decimal(str(user.balance)) < amount:
            return _error("Solde insuffisant", 400)
        data["receiver"] = receiver.id
    elif transaction_type == "TOPUP":
        service_provider = _normalize_service_provider(data.get("service_provider"))
        service_phone = _normalize_service_phone(data.get("service_phone"))
        allowed_providers = {
            choice[0] for choice in Transaction.SERVICE_PROVIDER_CHOICES
        }

        if service_provider not in allowed_providers:
            return _error("Operateur de recharge invalide", 400)

        if not _is_valid_topup_phone(service_provider, service_phone):
            return _error(
                (
                    "Le numero de recharge est invalide pour cet operateur. "
                    "Il doit contenir 8 chiffres. Mauritel commence par 4, "
                    "Mattel par 3 et Chinguitel par 2."
                ),
                400,
            )

        if amount not in TOPUP_DENOMINATIONS:
            allowed_values = ", ".join(
                str(int(value)) if value == value.to_integral() else str(value)
                for value in sorted(TOPUP_DENOMINATIONS)
            )
            return _error(
                f"Montant de recharge invalide. Valeurs autorisees: {allowed_values} MRU.",
                400,
            )

        if Decimal(str(user.balance)) < amount:
            return _error("Solde insuffisant", 400)

        data["service_provider"] = service_provider
        data["service_phone"] = service_phone
        data.pop("receiver", None)
    else:
        data.pop("receiver", None)

    data.pop("receiver_email", None)
    data.pop("receiver_phone", None)

    if transaction_type == "WITHDRAW" and Decimal(str(user.balance)) < amount:
        return _error("Solde insuffisant", 400)

    data["type"] = transaction_type
    data["montant"] = str(amount)

    serializer = TransactionSerializer(data=data)
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    anomaly_snapshot = _build_anomaly_snapshot(user, amount, transaction_type)
    requires_admin_approval = _requires_multi_level(
        transaction_type,
        anomaly_snapshot["anomaly_detected"],
        amount,
    )

    initial_status = "SUBMITTED" if requires_admin_approval else "PENDING"
    review_stage = "ACCOUNTANT_REVIEW" if requires_admin_approval else "SUBMITTED"

    transaction = serializer.save(
        status=initial_status,
        review_stage=review_stage,
        requires_admin_approval=requires_admin_approval,
        anomaly_detected=anomaly_snapshot["anomaly_detected"],
        anomaly_reason=anomaly_snapshot["anomaly_reason"],
        risk_score=anomaly_snapshot["risk_score"],
    )

    if transaction.type in {"TRANSFER", "TOPUP", "DEPOSIT"}:
        with db_transaction.atomic():
            try:
                _apply_transaction_effect(transaction)
            except ValueError as exc:
                transaction.delete()
                return _error(str(exc), 400)

            transaction.status = "APPROVED"
            if transaction.type == "TRANSFER":
                transaction.validation_note = "Auto-approved transfer"
            elif transaction.type == "TOPUP":
                transaction.validation_note = "Auto-approved mobile top-up"
            else:
                transaction.validation_note = "Auto-approved deposit"
            transaction.review_stage = "FINALIZED"
            transaction.receipt_reference = _generate_receipt_reference(transaction)
            transaction.save(
                update_fields=[
                    "status",
                    "validation_note",
                    "review_stage",
                    "receipt_reference",
                    "updated_at",
                ]
            )

        create_log(
            user,
            "CREATE_TRANSACTION",
            (
                f"transaction_id={transaction.id};"
                f"type={transaction.type};amount={transaction.montant};status=APPROVED"
            ),
            entity_type="TRANSACTION",
            entity_id=transaction.id,
            target_repr=transaction.type,
            metadata={
                "status": "APPROVED",
                "amount": str(transaction.montant),
                "sender_id": transaction.sender_id,
                "receiver_id": transaction.receiver_id,
                "service_provider": transaction.service_provider or "",
                "service_phone": transaction.service_phone or "",
                "mode": (
                    "AUTO_TRANSFER"
                    if transaction.type == "TRANSFER"
                    else "AUTO_TOPUP"
                    if transaction.type == "TOPUP"
                    else "AUTO_DEPOSIT"
                ),
                "risk_score": transaction.risk_score,
                "anomaly_detected": transaction.anomaly_detected,
                "anomaly_reason": transaction.anomaly_reason or "",
            },
        )

        create_log(
            user,
            "APPROVE_TRANSACTION",
            (
                f"transaction_id={transaction.id};"
                f"type={transaction.type};amount={transaction.montant};status=APPROVED"
            ),
            entity_type="TRANSACTION",
            entity_id=transaction.id,
            target_repr=transaction.type,
            metadata={
                "status": "APPROVED",
                "amount": str(transaction.montant),
                "sender_id": transaction.sender_id,
                "receiver_id": transaction.receiver_id,
                "service_provider": transaction.service_provider or "",
                "service_phone": transaction.service_phone or "",
                "mode": (
                    "AUTO_TRANSFER"
                    if transaction.type == "TRANSFER"
                    else "AUTO_TOPUP"
                    if transaction.type == "TOPUP"
                    else "AUTO_DEPOSIT"
                ),
                "validation_note": transaction.validation_note or "",
                "risk_score": transaction.risk_score,
                "anomaly_detected": transaction.anomaly_detected,
                "anomaly_reason": transaction.anomaly_reason or "",
            },
        )

        if transaction.type == "TRANSFER":
            create_notification(
                user,
                f"Votre transfert de {transaction.montant} MRU a ete execute avec succes.",
            )
        elif transaction.type == "TOPUP":
            create_notification(
                user,
                (
                    f"Votre recharge {transaction.service_provider or ''} de "
                    f"{transaction.montant} MRU vers {transaction.service_phone or '-'} "
                    f"a ete executee avec succes."
                ),
            )
        else:
            create_notification(
                user,
                f"Votre depot de {transaction.montant} MRU a ete execute avec succes.",
            )

        if transaction.receiver:
            create_notification(
                transaction.receiver,
                f"Vous avez recu un transfert de {transaction.montant} MRU.",
            )

        return Response(
        {
            "message": (
                "Transfert execute avec succes."
                if transaction.type == "TRANSFER"
                else "Recharge executee avec succes."
                if transaction.type == "TOPUP"
                else "Depot execute avec succes."
            ),
            "transaction": _serialize_transaction(transaction, request),
        },
        status=status.HTTP_201_CREATED,
    )

    create_log(
        user,
        "CREATE_TRANSACTION",
        (
            f"transaction_id={transaction.id};"
            f"type={transaction.type};amount={transaction.montant};status={transaction.status}"
        ),
        entity_type="TRANSACTION",
        entity_id=transaction.id,
        target_repr=transaction.type,
        metadata={
            "status": transaction.status,
            "amount": str(transaction.montant),
            "sender_id": transaction.sender_id,
            "receiver_id": transaction.receiver_id,
            "service_provider": transaction.service_provider or "",
            "service_phone": transaction.service_phone or "",
            "review_stage": transaction.review_stage,
            "requires_admin_approval": transaction.requires_admin_approval,
            "risk_score": transaction.risk_score,
            "anomaly_detected": transaction.anomaly_detected,
            "anomaly_reason": transaction.anomaly_reason or "",
        },
    )

    create_notification(
        user,
        (
            f"Votre transaction {transaction.type} a ete creee et attend "
            f"{'une validation comptable puis administrative' if transaction.requires_admin_approval else 'une execution automatique'}."
        ),
    )

    return Response(
        {
            "message": (
                "Transaction soumise avec succes."
                if transaction.requires_admin_approval
                else "Transaction creee avec succes."
            ),
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
    direction_filter = str(request.GET.get("direction", "ALL")).strip().upper()
    start = request.GET.get("start")
    end = request.GET.get("end")
    search = str(request.GET.get("search", "")).strip()
    sort = _normalize_sort(request.GET.get("sort"))

    if _require_reviewer(user):
        transactions = Transaction.objects.select_related(
            "sender",
            "receiver",
            "validated_by",
            "accountant_validated_by",
        ).all()
    else:
        transactions = Transaction.objects.select_related(
            "sender",
            "receiver",
            "validated_by",
            "accountant_validated_by",
        ).filter(Q(sender=user) | Q(receiver=user))

    if status_filter != "ALL":
        transactions = transactions.filter(status=status_filter)

    if type_filter != "ALL":
        transactions = transactions.filter(type=type_filter)

    if direction_filter in {"SENT", "RECEIVED"}:
        if direction_filter == "SENT":
            transactions = transactions.filter(type="TRANSFER", sender=user)
        else:
            transactions = transactions.filter(type="TRANSFER", receiver=user)

    if start:
        transactions = transactions.filter(created_at__date__gte=start)
    if end:
        transactions = transactions.filter(created_at__date__lte=end)

    if search:
        normalized_phone = "".join(ch for ch in search if ch.isdigit())
        search_query = (
            Q(sender__nom__icontains=search)
            | Q(sender__prenom__icontains=search)
            | Q(sender__email__icontains=search)
            | Q(sender__telephone__icontains=search)
            | Q(receiver__nom__icontains=search)
            | Q(receiver__prenom__icontains=search)
            | Q(receiver__email__icontains=search)
            | Q(receiver__telephone__icontains=search)
            | Q(type__icontains=search)
            | Q(status__icontains=search)
            | Q(service_provider__icontains=search)
            | Q(service_phone__icontains=search)
            | Q(note__icontains=search)
            | Q(validation_note__icontains=search)
        )

        if normalized_phone:
            search_query |= (
                Q(sender__telephone__icontains=normalized_phone)
                | Q(receiver__telephone__icontains=normalized_phone)
                | Q(service_phone__icontains=normalized_phone)
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


@api_view(["POST"])
def approve_transaction(request, transaction_id):
    reviewer, error = get_current_user(request)
    if error:
        return error

    if not _require_reviewer(reviewer):
        return _error("Permission refusee", 403)

    transaction = Transaction.objects.select_related(
        "sender",
        "receiver",
        "validated_by",
        "accountant_validated_by",
    ).filter(
        id=transaction_id
    ).first()
    if not transaction:
        return _error("Transaction introuvable", 404)

    if transaction.status not in {"PENDING", "SUBMITTED", "ACCOUNTANT_APPROVED"}:
        return _error("Cette transaction a deja ete traitee", 400)

    accountant_note = str(request.data.get("note", "")).strip()

    if transaction.status == "SUBMITTED":
        if not transaction.requires_admin_approval:
            return _error("Cette transaction ne necessite pas une double validation.", 400)
        if not _is_accountant(reviewer):
            return _error("Cette etape doit etre validee par un comptable.", 403)

        transaction.status = "ACCOUNTANT_APPROVED"
        transaction.review_stage = "ADMIN_REVIEW"
        transaction.accountant_validated_by = reviewer
        transaction.accountant_validation_note = accountant_note
        transaction.save(
            update_fields=[
                "status",
                "review_stage",
                "accountant_validated_by",
                "accountant_validation_note",
                "updated_at",
            ]
        )

        create_log(
            reviewer,
            "ACCOUNTANT_APPROVE_TRANSACTION",
            (
                f"transaction_id={transaction.id};"
                f"type={transaction.type};amount={transaction.montant};status=ACCOUNTANT_APPROVED"
            ),
            entity_type="TRANSACTION",
            entity_id=transaction.id,
            target_repr=transaction.type,
            metadata={
                "status": "ACCOUNTANT_APPROVED",
                "amount": str(transaction.montant),
                "sender_id": transaction.sender_id,
                "receiver_id": transaction.receiver_id,
                "accountant_id": reviewer.id,
                "review_stage": "ADMIN_REVIEW",
                "risk_score": transaction.risk_score,
                "anomaly_detected": transaction.anomaly_detected,
                "anomaly_reason": transaction.anomaly_reason or "",
            },
        )

        create_notification(
            transaction.sender,
            f"Votre transaction #{transaction.id} a ete verifiee par le comptable et attend la validation administrative.",
        )

        return Response(
            {
                "message": "Transaction verifiee par le comptable. Elle attend maintenant la validation administrative.",
                "transaction": _serialize_transaction(transaction, request),
            }
        )

    if transaction.status == "ACCOUNTANT_APPROVED" and not _is_admin(reviewer):
        return _error("La validation finale doit etre effectuee par un administrateur.", 403)

    if transaction.status == "PENDING" and transaction.requires_admin_approval and not _is_admin(reviewer):
        return _error("La validation finale doit etre effectuee par un administrateur.", 403)

    with db_transaction.atomic():
        try:
            _apply_transaction_effect(transaction)
        except ValueError as exc:
            return _error(str(exc), 400)

        transaction.status = "APPROVED"
        transaction.review_stage = "FINALIZED"
        transaction.validated_by = reviewer
        transaction.validation_note = accountant_note
        if not transaction.receipt_reference:
            transaction.receipt_reference = _generate_receipt_reference(transaction)
        transaction.save(
            update_fields=[
                "status",
                "review_stage",
                "validated_by",
                "validation_note",
                "receipt_reference",
                "updated_at",
            ]
        )

    create_log(
        reviewer,
        "APPROVE_TRANSACTION",
        (
            f"transaction_id={transaction.id};"
            f"type={transaction.type};amount={transaction.montant};status=APPROVED"
        ),
        entity_type="TRANSACTION",
        entity_id=transaction.id,
        target_repr=transaction.type,
        metadata={
            "status": "APPROVED",
            "amount": str(transaction.montant),
            "sender_id": transaction.sender_id,
            "receiver_id": transaction.receiver_id,
            "validated_by": reviewer.id,
            "validation_note": transaction.validation_note or "",
            "accountant_validated_by": transaction.accountant_validated_by_id,
            "review_stage": transaction.review_stage,
            "receipt_reference": transaction.receipt_reference or "",
            "risk_score": transaction.risk_score,
            "anomaly_detected": transaction.anomaly_detected,
            "anomaly_reason": transaction.anomaly_reason or "",
        },
    )

    create_notification(
        transaction.sender,
        f"Votre transaction #{transaction.id} a ete approuvee.",
    )

    return Response(
        {
            "message": "Transaction approuvee.",
            "transaction": _serialize_transaction(transaction, request),
        }
    )


@api_view(["POST"])
def reject_transaction(request, transaction_id):
    reviewer, error = get_current_user(request)
    if error:
        return error

    if not _require_reviewer(reviewer):
        return _error("Permission refusee", 403)

    transaction = Transaction.objects.select_related(
        "sender",
        "receiver",
        "accountant_validated_by",
        "validated_by",
    ).filter(id=transaction_id).first()
    if not transaction:
        return _error("Transaction introuvable", 404)

    if transaction.status not in {"PENDING", "SUBMITTED", "ACCOUNTANT_APPROVED"}:
        return _error("Cette transaction a deja ete traitee", 400)

    rejection_note = str(request.data.get("note", "")).strip()

    if transaction.status == "SUBMITTED" and not _is_accountant(reviewer):
        return _error("Le rejet a cette etape doit etre effectue par un comptable.", 403)

    if transaction.status == "ACCOUNTANT_APPROVED" and not _is_admin(reviewer):
        return _error("Le rejet final doit etre effectue par un administrateur.", 403)

    previous_status = transaction.status
    transaction.status = "REJECTED"
    transaction.review_stage = "REJECTED"
    if previous_status == "SUBMITTED":
        transaction.accountant_validated_by = reviewer
        transaction.accountant_validation_note = rejection_note
    else:
        transaction.validated_by = reviewer
        transaction.validation_note = rejection_note
    transaction.save(
        update_fields=[
            "status",
            "review_stage",
            "validated_by",
            "validation_note",
            "accountant_validated_by",
            "accountant_validation_note",
            "updated_at",
        ]
    )

    create_log(
        reviewer,
        "REJECT_TRANSACTION",
        (
            f"transaction_id={transaction.id};"
            f"type={transaction.type};amount={transaction.montant};status=REJECTED"
        ),
        entity_type="TRANSACTION",
        entity_id=transaction.id,
        target_repr=transaction.type,
        metadata={
            "status": "REJECTED",
            "amount": str(transaction.montant),
            "sender_id": transaction.sender_id,
            "receiver_id": transaction.receiver_id,
            "validated_by": reviewer.id,
            "validation_note": transaction.validation_note or transaction.accountant_validation_note or "",
            "review_stage": transaction.review_stage,
            "rejected_by_role": reviewer.role,
            "risk_score": transaction.risk_score,
            "anomaly_detected": transaction.anomaly_detected,
            "anomaly_reason": transaction.anomaly_reason or "",
        },
    )

    create_notification(
        transaction.sender,
        f"Votre transaction #{transaction.id} a ete rejetee.",
    )

    return Response(
        {
            "message": "Transaction rejetee.",
            "transaction": _serialize_transaction(transaction, request),
        }
    )


@api_view(["GET", "POST"])
def beneficiaries(request):
    user, error = get_current_user(request)
    if error:
        return error

    if not has_role(user, "CLIENT"):
        return _error("Seuls les comptes client peuvent gerer des beneficiaires.", 403)

    if request.method == "GET":
        items = Beneficiary.objects.select_related("beneficiary").filter(owner=user)
        return Response(
            BeneficiarySerializer(items, many=True).data,
            status=status.HTTP_200_OK,
        )

    beneficiary = _find_receiver(request.data)
    if not beneficiary:
        return _error("Beneficiaire introuvable.", 404)
    if beneficiary.id == user.id:
        return _error("Impossible d'ajouter votre propre compte.", 400)
    if getattr(beneficiary, "role", "").upper() != "CLIENT":
        return _error("Le beneficiaire doit etre un compte client.", 400)

    nickname = str(request.data.get("nickname", "")).strip() or None
    item, created = Beneficiary.objects.get_or_create(
        owner=user,
        beneficiary=beneficiary,
        defaults={"nickname": nickname},
    )
    if not created:
        item.nickname = nickname or item.nickname
        item.save(update_fields=["nickname"])

    create_log(
        user,
        "ADD_BENEFICIARY",
        f"beneficiary_id={beneficiary.id};phone={beneficiary.telephone}",
        entity_type="BENEFICIARY",
        entity_id=item.id,
        target_repr=beneficiary.email or beneficiary.telephone,
        metadata={
            "owner_id": user.id,
            "beneficiary_id": beneficiary.id,
            "nickname": item.nickname or "",
        },
    )

    return Response(
        {
            "message": "Beneficiaire ajoute avec succes.",
            "beneficiary": BeneficiarySerializer(item).data,
        },
        status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
    )


@api_view(["DELETE"])
def delete_beneficiary(request, beneficiary_id):
    user, error = get_current_user(request)
    if error:
        return error

    item = Beneficiary.objects.select_related("beneficiary").filter(
        id=beneficiary_id,
        owner=user,
    ).first()
    if not item:
        return _error("Beneficiaire introuvable.", 404)

    target = item.beneficiary
    create_log(
        user,
        "DELETE_BENEFICIARY",
        f"beneficiary_id={target.id};phone={target.telephone}",
        entity_type="BENEFICIARY",
        entity_id=item.id,
        target_repr=target.email or target.telephone,
        metadata={
            "owner_id": user.id,
            "beneficiary_id": target.id,
        },
    )
    item.delete()
    return Response({"message": "Beneficiaire supprime avec succes."})
