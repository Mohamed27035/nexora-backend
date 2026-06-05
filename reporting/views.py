from rest_framework.decorators import api_view
from rest_framework.response import Response
from django.db.models import Count
from django.db.models.functions import TruncDate
from logs.models import Log
from users.views import get_current_user, is_admin, is_comptable
from transactions.models import Transaction
from django.http import HttpResponse


@api_view(['GET'])
def report_stats(request):
    user, error = get_current_user(request)
    if error:
        return error

    if not (is_admin(user) or is_comptable(user)):
        return Response({"error": "Accès refusé"}, status=403)

    start = request.GET.get("start")
    end = request.GET.get("end")

    logs = Log.objects.all()
    if start and end:
        logs = logs.filter(date__range=[start, end])

    return Response({
        "total": logs.count(),
        "create": logs.filter(action="CREATE_USER").count(),
        "update": logs.filter(action="UPDATE_USER").count(),
        "delete": logs.filter(action="DELETE_USER").count(),
        "login": logs.filter(action="LOGIN").count(),
    })


# 🔥 CHART مرتبط بالـ filters
@api_view(['GET'])
def report_chart(request):
    user, error = get_current_user(request)
    if error:
        return error

    if not (is_admin(user) or is_comptable(user)):
        return Response({"error": "Accès refusé"}, status=403)

    start = request.GET.get("start")
    end = request.GET.get("end")

    logs = Log.objects.all()
    if start and end:
        logs = logs.filter(date__range=[start, end])

    logs = (
        logs
        .annotate(day=TruncDate('date'))
        .values('day')
        .annotate(count=Count('id'))
        .order_by('day')
    )

    return Response(list(logs))


# 📄 PDF محسّن
@api_view(['GET'])
def export_pdf(request):
    from reportlab.lib.styles import getSampleStyleSheet
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer

    user, error = get_current_user(request)
    if error:
        return error

    if not (is_admin(user) or is_comptable(user)):
        return Response({"error": "Accès refusé"}, status=403)

    start = request.GET.get("start")
    end = request.GET.get("end")

    logs = Log.objects.all()
    if start and end:
        logs = logs.filter(date__range=[start, end])

    response = HttpResponse(content_type='application/pdf')
    response['Content-Disposition'] = 'attachment; filename="report.pdf"'

    doc = SimpleDocTemplate(response)
    styles = getSampleStyleSheet()

    content = []

    content.append(Paragraph("Reporting System", styles['Title']))
    content.append(Spacer(1, 10))

    content.append(Paragraph(f"Total Logs: {logs.count()}", styles['Normal']))
    content.append(Paragraph(f"Create: {logs.filter(action='CREATE_USER').count()}", styles['Normal']))
    content.append(Paragraph(f"Update: {logs.filter(action='UPDATE_USER').count()}", styles['Normal']))
    content.append(Paragraph(f"Delete: {logs.filter(action='DELETE_USER').count()}", styles['Normal']))
    content.append(Paragraph(f"Login: {logs.filter(action='LOGIN').count()}", styles['Normal']))

    doc.build(content)

    return response

# 🔥 FINANCIAL STATS


@api_view(['GET'])
def financial_stats(request):
    user, error = get_current_user(request)
    if error:
        return error

    if not (is_admin(user) or is_comptable(user)):
        return Response({"error": "Accès refusé"}, status=403)

    start = request.GET.get("start")
    end = request.GET.get("end")

    transactions = Transaction.objects.all()

    if start and end:
        transactions = transactions.filter(date__range=[start, end])

    total_deposit = sum(t.montant for t in transactions if t.type == "DEPOSIT")
    total_withdraw = sum(t.montant for t in transactions if t.type == "WITHDRAW")

    return Response({
        "deposit": total_deposit,
        "withdraw": total_withdraw,
        "balance": total_deposit - total_withdraw
    })
