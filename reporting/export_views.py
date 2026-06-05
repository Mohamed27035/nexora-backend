from django.http import HttpResponse
from rest_framework.response import Response
from transactions.models import Transaction

from users.views import (
    get_current_user,
    is_admin,
    is_comptable
)


def export_transactions_pdf(request):
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import letter
    from reportlab.lib.styles import getSampleStyleSheet
    from reportlab.platypus import (
        SimpleDocTemplate,
        Table,
        TableStyle,
        Paragraph,
        Spacer
    )

    # ==========================
    # AUTH
    # ==========================
    current_user, error = get_current_user(
        request
    )

    if error:

      return HttpResponse(
        "Unauthorized",
        status=401
    )

    if not (
        is_admin(current_user)
        or
        is_comptable(current_user)
    ):

        return HttpResponse(
            "Permission denied",
            status=403
        )

    # ==========================
    # RESPONSE
    # ==========================
    response = HttpResponse(
        content_type='application/pdf'
    )

    response[
        'Content-Disposition'
    ] = (
        'attachment; '
        'filename="transactions_report.pdf"'
    )

    # ==========================
    # PDF
    # ==========================
    doc = SimpleDocTemplate(

        response,

        pagesize=letter
    )

    elements = []

    styles = getSampleStyleSheet()

    title = Paragraph(

        "Transactions Report",

        styles['Title']
    )

    elements.append(title)

    elements.append(
        Spacer(1, 20)
    )

    # ==========================
    # TABLE DATA
    # ==========================
    data = [[

        "ID",

        "Sender",

        "Receiver",

        "Type",

        "Amount",

        "Status"
    ]]

    transactions = (
        Transaction.objects.all()
        .order_by("-created_at")
    )

    for t in transactions:

        data.append([

            str(t.id),

            t.sender.nom,

            (
                t.receiver.nom
                if t.receiver
                else "-"
            ),

            t.type,

            str(t.montant),

            t.status
        ])

    # ==========================
    # TABLE
    # ==========================
    table = Table(data)

    table.setStyle(

        TableStyle([

            (
                'BACKGROUND',
                (0, 0),
                (-1, 0),
                colors.grey
            ),

            (
                'TEXTCOLOR',
                (0, 0),
                (-1, 0),
                colors.whitesmoke
            ),

            (
                'ALIGN',
                (0, 0),
                (-1, -1),
                'CENTER'
            ),

            (
                'FONTNAME',
                (0, 0),
                (-1, 0),
                'Helvetica-Bold'
            ),

            (
                'BOTTOMPADDING',
                (0, 0),
                (-1, 0),
                12
            ),

            (
                'BACKGROUND',
                (0, 1),
                (-1, -1),
                colors.beige
            ),

            (
                'GRID',
                (0, 0),
                (-1, -1),
                1,
                colors.black
            ),
        ])
    )

    elements.append(table)

    # ==========================
    # BUILD PDF
    # ==========================
    doc.build(elements)

    return response

def export_transactions_excel(request):
    import openpyxl

    # ==========================
    # AUTH
    # ==========================
    current_user, error = get_current_user(
        request
    )

    if error:

        return HttpResponse(
            "Unauthorized",
            status=401
        )

    if not (
        is_admin(current_user)
        or
        is_comptable(current_user)
    ):

        return HttpResponse(
            "Permission denied",
            status=403
        )

    # ==========================
    # EXCEL
    # ==========================
    workbook = openpyxl.Workbook()

    sheet = workbook.active

    sheet.title = (
        "Transactions"
    )

    # ==========================
    # HEADERS
    # ==========================
    headers = [

        "ID",

        "Sender",

        "Receiver",

        "Type",

        "Amount",

        "Status",

        "Created At"
    ]

    sheet.append(headers)

    # ==========================
    # DATA
    # ==========================
    transactions = (
        Transaction.objects.all()
        .order_by("-created_at")
    )

    for t in transactions:

        sheet.append([

            t.id,

            t.sender.nom,

            (
                t.receiver.nom
                if t.receiver
                else "-"
            ),

            t.type,

            t.montant,

            t.status,

            str(t.created_at)
        ])

    # ==========================
    # RESPONSE
    # ==========================
    response = HttpResponse(

        content_type=(
            "application/vnd.openxmlformats-"
            "officedocument.spreadsheetml.sheet"
        )
    )

    response[
        "Content-Disposition"
    ] = (
        'attachment; '
        'filename="transactions_report.xlsx"'
    )

    # ==========================
    # SAVE EXCEL
    # ==========================
    excel_file = BytesIO()

    workbook.save(excel_file)

    excel_file.seek(0)

    response.write(
        excel_file.getvalue()
    )

    return response
