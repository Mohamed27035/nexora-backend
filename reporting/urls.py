from django.urls import path

from .export_views import export_transactions_excel, export_transactions_pdf
from .views import export_pdf, financial_stats, report_chart, report_stats

urlpatterns = [
    path("stats/", report_stats),
    path("chart/", report_chart),
    path("financial/", financial_stats),
    path("export-pdf/", export_pdf),
    path(
        "export-transactions-pdf/",
        export_transactions_pdf,
        name="export_transactions_pdf",
    ),
    path(
        "export-transactions-excel/",
        export_transactions_excel,
        name="export_transactions_excel",
    ),
]
