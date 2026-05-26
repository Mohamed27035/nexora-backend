from django.urls import path
from .views import *

urlpatterns = [
    path('', get_transactions),
    path('<int:id>/', get_transaction),
    path('create/', create_transaction),
    path('delete/<int:id>/', delete_transaction),
]