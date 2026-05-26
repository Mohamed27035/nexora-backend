from django.urls import path
from .views import report_stats, report_chart, export_pdf ,financial_stats
from .export_views import (export_transactions_pdf)
from .export_views import (export_transactions_excel)
urlpatterns = [
    path(
    "export-transactions-pdf/",
    export_transactions_pdf,name="export_transactions_pdf"),
    path('stats/', report_stats),
    path('chart/', report_chart),
    path('export-pdf/', export_pdf),
    path('financial/', financial_stats),
    path("export-transactions-excel/",export_transactions_excel,name="export_transactions_excel"),
]