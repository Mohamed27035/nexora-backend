from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from decimal import Decimal
from .models import Transaction
from .serializers import TransactionSerializer

from users.views import (
    get_current_user,
    create_log
)

from users.models import Utilisateur

from notifications.models import Notification


# ==========================
# CREATE NOTIFICATION
# ==========================
def create_notification(user, message):

    try:

        Notification.objects.create(

            utilisateur=user,

            title="Transaction",

            message=message
        )

    except Exception as e:

        print(
            "NOTIFICATION ERROR =>",
            str(e)
        )


# ==========================
# CREATE TRANSACTION
# ==========================
@api_view(['POST'])
def create_transaction(request):

    user, error = get_current_user(
        request
    )

    if error:
        return error

    data = request.data.copy()

    # ==========================
    # SENDER
    # ==========================
    data["sender"] = user.id

    # ==========================
    # VALIDATE AMOUNT
    # ==========================
    try:

        montant = float(
            data.get("montant", 0)
        )

    except:

        return Response({

            "error":
            "Montant invalide"

        }, status=400)

    if montant <= 0:

        return Response({

            "error":
            "Invalid amount"

        }, status=400)

    # ==========================
    # TYPE
    # ==========================
    transaction_type = data.get(
        "type"
    )

    # ==========================
    # VALID TYPES
    # ==========================
    if transaction_type not in [

        "DEPOSIT",

        "WITHDRAW",

        "TRANSFER"
    ]:

        return Response({

            "error":
            "Type invalide"

        }, status=400)

    # ==========================
    # WITHDRAW CHECK
    # ==========================
    if transaction_type == "WITHDRAW":

        if user.balance < montant:

            return Response({

                "error":
                "Insufficient balance"

            }, status=400)

    # ==========================
    # TRANSFER CHECK
    # ==========================
    if transaction_type == "TRANSFER":

        receiver_id = data.get(
            "receiver"
        )

        if not receiver_id:

            return Response({

                "error":
                "Receiver required"

            }, status=400)

        try:

            receiver = Utilisateur.objects.get(
                id=receiver_id
            )

        except Utilisateur.DoesNotExist:

            return Response({

                "error":
                "Receiver not found"

            }, status=404)

        if receiver.id == user.id:

            return Response({

                "error":
                "Cannot transfer to yourself"

            }, status=400)

        if user.balance < montant:

            return Response({

                "error":
                "Insufficient balance"

            }, status=400)

    # ==========================
    # CREATE
    # ==========================
    serializer = TransactionSerializer(
        data=data
    )

    if serializer.is_valid():

        transaction = serializer.save()

        # LOG
        create_log(

            user,

            "CREATE_TRANSACTION",

            f"transaction_id={transaction.id}"
        )

        # NOTIFICATION
        create_notification(

            user,

            f"Transaction {transaction.type} créée avec succès"
        )

        return Response({

            "message":
            "Transaction created",

            "transaction":
            TransactionSerializer(
                transaction
            ).data

        }, status=status.HTTP_201_CREATED)

    return Response(

        serializer.errors,

        status=status.HTTP_400_BAD_REQUEST
    )


# ==========================
# GET TRANSACTIONS
# ==========================
# ==========================
# GET TRANSACTIONS
# ==========================
@api_view(['GET'])
def get_transactions(request):

    user, error = get_current_user(
        request
    )

    if error:
        return error

    role = str(
        user.role
    ).upper()

    # ==========================
    # FILTERS
    # ==========================
    status_filter = request.GET.get(
        "status",
        "ALL"
    )

    type_filter = request.GET.get(
        "type",
        "ALL"
    )

    start = request.GET.get(
        "start"
    )

    end = request.GET.get(
        "end"
    )

    search = request.GET.get(
        "search",
        ""
    )

    # ==========================
    # BASE QUERY
    # ==========================
    if role in [

        "ADMIN",
        "COMPTABLE"

    ]:

        transactions = (
            Transaction.objects.all()
        )

    else:

        transactions = (
            Transaction.objects.filter(
                sender=user
            )
        )

    # ==========================
    # STATUS FILTER
    # ==========================
    if status_filter != "ALL":

        transactions = transactions.filter(
            status=status_filter
        )

    # ==========================
    # TYPE FILTER
    # ==========================
    if type_filter != "ALL":

        transactions = transactions.filter(
            type=type_filter
        )

    # ==========================
    # DATE FILTER
    # ==========================
    if start:

        transactions = transactions.filter(
            created_at__date__gte=start
        )

    if end:

        transactions = transactions.filter(
            created_at__date__lte=end
        )

    # ==========================
    # SEARCH
    # ==========================
    if search:

        transactions = transactions.filter(
            sender__nom__icontains=search
        ) | transactions.filter(
            receiver__nom__icontains=search
        ) | transactions.filter(
            type__icontains=search
        )

    # ==========================
    # ORDER
    # ==========================
    transactions = transactions.order_by(
        "-created_at"
    )

    serializer = TransactionSerializer(

        transactions,

        many=True
    )

    return Response(
        serializer.data
    )


# ==========================
# APPROVE TRANSACTION
# ==========================
# ==========================
# APPROVE TRANSACTION
# ==========================
@api_view(['POST'])
def approve_transaction(
    request,
    transaction_id
):

    try:

        user, error = get_current_user(
            request
        )

        if error:
            return error

        # ==========================
        # ONLY ADMIN / COMPTABLE
        # ==========================
        if str(user.role).upper() not in [

            "ADMIN",
            "COMPTABLE"

        ]:

            return Response({

                "error":
                "Permission denied"

            }, status=403)

        # ==========================
        # GET TRANSACTION
        # ==========================
        try:

            transaction = (
                Transaction.objects.get(
                    id=transaction_id
                )
            )

        except Transaction.DoesNotExist:

            return Response({

                "error":
                "Transaction not found"

            }, status=404)

        # ==========================
        # ALREADY PROCESSED
        # ==========================
        if transaction.status != "PENDING":

            return Response({

                "error":
                "Transaction already processed"

            }, status=400)

        sender = transaction.sender

        receiver = transaction.receiver

        montant = Decimal(
            str(transaction.montant)
        )

        print(
            "TYPE =>",
            transaction.type
        )

        print(
            "AMOUNT =>",
            montant
        )

        print(
            "SENDER BALANCE BEFORE =>",
            sender.balance
        )

        # ==========================
        # DEPOSIT
        # ==========================
        if transaction.type == "DEPOSIT":

            sender.balance = Decimal(
                str(sender.balance)
            ) + montant

            sender.save()

            print(
                "BALANCE AFTER DEPOSIT =>",
                sender.balance
            )

        # ==========================
        # WITHDRAW
        # ==========================
        elif transaction.type == "WITHDRAW":

            if Decimal(
                str(sender.balance)
            ) < montant:

                return Response({

                    "error":
                    "Insufficient balance"

                }, status=400)

            sender.balance = Decimal(
                str(sender.balance)
            ) - montant

            sender.save()

            print(
                "BALANCE AFTER WITHDRAW =>",
                sender.balance
            )

        # ==========================
        # TRANSFER
        # ==========================
        elif transaction.type == "TRANSFER":

            if not receiver:

                return Response({

                    "error":
                    "Receiver missing"

                }, status=400)

            if Decimal(
                str(sender.balance)
            ) < montant:

                return Response({

                    "error":
                    "Insufficient balance"

                }, status=400)

            sender.balance = Decimal(
                str(sender.balance)
            ) - montant

            receiver.balance = Decimal(
                str(receiver.balance)
            ) + montant

            sender.save()

            receiver.save()

            print(
                "TRANSFER SUCCESS"
            )

        # ==========================
        # VALIDATION
        # ==========================
        transaction.status = "APPROVED"

        transaction.validated_by = user

        transaction.validation_note = (
            request.data.get(
                "note",
                ""
            )
        )

        transaction.save()

        # ==========================
        # LOG
        # ==========================
        create_log(

            user,

            "APPROVE_TRANSACTION",

            f"transaction_id={transaction.id}"
        )

        # ==========================
        # NOTIFICATION
        # ==========================
        create_notification(

            sender,

            f"Votre transaction #{transaction.id} a été approuvée"
        )

        return Response({

            "message":
            "Transaction approved"

        })

    except Exception as e:

        print(
            "APPROVAL ERROR =>",
            str(e)
        )

        return Response({

            "error":
            str(e)

        }, status=500)
@api_view(['POST'])
def reject_transaction(
    request,
    transaction_id
):

    user, error = get_current_user(
        request
    )

    if error:
        return error

    # ==========================
    # ONLY ADMIN / COMPTABLE
    # ==========================
    if str(user.role).upper() not in [

        "ADMIN",

        "COMPTABLE"

    ]:

        return Response({

            "error":
            "Permission denied"

        }, status=403)

    try:

        transaction = Transaction.objects.get(
            id=transaction_id
        )

    except Transaction.DoesNotExist:

        return Response({

            "error":
            "Transaction not found"

        }, status=404)

    # ==========================
    # ALREADY PROCESSED
    # ==========================
    if transaction.status != "PENDING":

        return Response({

            "error":
            "Transaction already processed"

        }, status=400)

    transaction.status = "REJECTED"

    transaction.validated_by = user

    transaction.validation_note = (
        request.data.get(
            "note",
            ""
        )
    )

    transaction.save()

    # LOG
    create_log(

        user,

        "REJECT_TRANSACTION",

        f"transaction_id={transaction.id}"
    )

    # NOTIFICATION
    create_notification(

        transaction.sender,

        f"Votre transaction #{transaction.id} a été rejetée"
    )

    return Response({

        "message":
        "Transaction rejected"

    })