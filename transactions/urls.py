from django.urls import path

from .views import (

    create_transaction,

    get_transactions,

    approve_transaction,

    reject_transaction,
)


urlpatterns = [

    # ==========================
    # GET TRANSACTIONS
    # ==========================
    path(

        "",

        get_transactions,

        name="get_transactions"
    ),

    # ==========================
    # CREATE TRANSACTION
    # ==========================
    path(

        "create/",

        create_transaction,

        name="create_transaction"
    ),

    # ==========================
    # APPROVE TRANSACTION
    # ==========================
    path(

        "approve/<int:transaction_id>/",

        approve_transaction,

        name="approve_transaction"
    ),

    # ==========================
    # REJECT TRANSACTION
    # ==========================
    path(

        "reject/<int:transaction_id>/",

        reject_transaction,

        name="reject_transaction"
    ),
]