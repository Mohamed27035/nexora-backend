from io import BytesIO

from django.http import HttpResponse

from transactions.models import Transaction
from users.views import create_log, get_current_user, is_admin, is_auditeur, is_comptable


def _unauthorized():
    return HttpResponse("Unauthorized", status=401)


def _forbidden():
    return HttpResponse("Permission denied", status=403)


def _require_reporting_access(request):
    current_user, error = get_current_user(request)
    if error:
        return None, _unauthorized()

    if not (is_admin(current_user) or is_comptable(current_user) or is_auditeur(current_user)):
        return None, _forbidden()

    return current_user, None


def _transaction_rows():
    return (
        Transaction.objects.select_related("sender", "receiver", "validated_by")
        .all()
        .order_by("-created_at")
    )


def export_transactions_pdf(request):
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import letter
    from reportlab.lib.styles import getSampleStyleSheet
    from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

    current_user, error = _require_reporting_access(request)
    if error:
        return error

    response = HttpResponse(content_type="application/pdf")
    response["Content-Disposition"] = 'attachment; filename="transactions_report.pdf"'

    doc = SimpleDocTemplate(response, pagesize=letter)
    styles = getSampleStyleSheet()
    elements = [
        Paragraph("Transactions Audit Report", styles["Title"]),
        Spacer(1, 16),
    ]

    data = [[
        "ID",
        "Type",
        "Sender",
        "Receiver",
        "Amount",
        "Status",
        "Validator",
        "Created",
    ]]

    for transaction in _transaction_rows():
        sender_name = " ".join(
            part for part in [transaction.sender.nom, transaction.sender.prenom or ""] if part
        ).strip()
        receiver_name = "-"
        if transaction.receiver:
            receiver_name = " ".join(
                part for part in [transaction.receiver.nom, transaction.receiver.prenom or ""] if part
            ).strip()

        validator_name = "-"
        if transaction.validated_by:
            validator_name = " ".join(
                part
                for part in [
                    transaction.validated_by.nom,
                    transaction.validated_by.prenom or "",
                ]
                if part
            ).strip()

        data.append([
            str(transaction.id),
            transaction.type,
            sender_name or transaction.sender.email,
            receiver_name,
            str(transaction.montant),
            transaction.status,
            validator_name,
            str(transaction.created_at),
        ])

    table = Table(data, repeatRows=1)
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1E293B")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.whitesmoke),
                ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("FONTSIZE", (0, 0), (-1, -1), 8),
                ("BOTTOMPADDING", (0, 0), (-1, 0), 10),
                ("BACKGROUND", (0, 1), (-1, -1), colors.HexColor("#F8FAFC")),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#CBD5E1")),
            ]
        )
    )
    elements.append(table)
    doc.build(elements)

    create_log(
        current_user,
        "GENERATE_REPORT",
        "transactions_report.pdf",
        entity_type="REPORT",
        entity_id="transactions-pdf",
        target_repr="transactions_report.pdf",
        metadata={"format": "PDF"},
    )

    return response


def export_transactions_excel(request):
    import openpyxl

    current_user, error = _require_reporting_access(request)
    if error:
        return error

    workbook = openpyxl.Workbook()
    sheet = workbook.active
    sheet.title = "Transactions"

    headers = [
        "ID",
        "Type",
        "Sender",
        "Sender Email",
        "Receiver",
        "Receiver Email",
        "Amount",
        "Status",
        "Validator",
        "Validation Note",
        "Created At",
        "Updated At",
    ]
    sheet.append(headers)

    for transaction in _transaction_rows():
        sender_name = " ".join(
            part for part in [transaction.sender.nom, transaction.sender.prenom or ""] if part
        ).strip()
        receiver_name = "-"
        receiver_email = "-"
        if transaction.receiver:
            receiver_name = " ".join(
                part for part in [transaction.receiver.nom, transaction.receiver.prenom or ""] if part
            ).strip()
            receiver_email = transaction.receiver.email or "-"

        validator_name = "-"
        if transaction.validated_by:
            validator_name = " ".join(
                part
                for part in [
                    transaction.validated_by.nom,
                    transaction.validated_by.prenom or "",
                ]
                if part
            ).strip()

        sheet.append([
            transaction.id,
            transaction.type,
            sender_name or transaction.sender.email,
            transaction.sender.email,
            receiver_name,
            receiver_email,
            transaction.montant,
            transaction.status,
            validator_name,
            transaction.validation_note or "",
            str(transaction.created_at),
            str(transaction.updated_at),
        ])

    response = HttpResponse(
        content_type=(
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
    )
    response["Content-Disposition"] = 'attachment; filename="transactions_report.xlsx"'

    excel_file = BytesIO()
    workbook.save(excel_file)
    excel_file.seek(0)
    response.write(excel_file.getvalue())

    create_log(
        current_user,
        "GENERATE_REPORT",
        "transactions_report.xlsx",
        entity_type="REPORT",
        entity_id="transactions-excel",
        target_repr="transactions_report.xlsx",
        metadata={"format": "XLSX"},
    )

    return response
