from django.urls import path

from .views import (

    submit_kyc,

    get_my_kyc,

    get_all_kyc,

    approve_kyc,

    reject_kyc
)

urlpatterns = [

    # ==========================
    # SUBMIT
    # ==========================
    path(

        "submit/",

        submit_kyc,

        name="submit_kyc"
    ),

    # ==========================
    # MY KYC
    # ==========================
    path(

        "my/",

        get_my_kyc,

        name="get_my_kyc"
    ),

    # ==========================
    # ADMIN
    # ==========================
    path(

        "all/",

        get_all_kyc,

        name="get_all_kyc"
    ),

    path(

        "approve/<int:kyc_id>/",

        approve_kyc,

        name="approve_kyc"
    ),

    path(

        "reject/<int:kyc_id>/",

        reject_kyc,

        name="reject_kyc"
    ),
]