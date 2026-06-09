from decimal import Decimal

from django.db.models import Count, Q, Sum
from django.http import HttpResponse
from rest_framework.decorators import api_view
from rest_framework.response import Response

from kyc.models import KYCRequest
from logs.models import Log
from transactions.models import Transaction
from users.models import Utilisateur
from users.views import create_log, get_current_user, is_admin, is_comptable


def _error(message, status=400):
    return Response({"error": message}, status=status)


def _require_reporting_access(request):
    user, error = get_current_user(request)
    if error:
        return None, error

    if not (is_admin(user) or is_comptable(user)):
        return None, _error("Acces refuse", 403)

    return user, None


def _apply_period_filters(request, users, transactions, kyc_requests, logs):
    start = request.GET.get("start")
    end = request.GET.get("end")

    if start:
        transactions = transactions.filter(created_at__date__gte=start)
        kyc_requests = kyc_requests.filter(submitted_at__date__gte=start)
        logs = logs.filter(date__date__gte=start)
    if end:
        transactions = transactions.filter(created_at__date__lte=end)
        kyc_requests = kyc_requests.filter(submitted_at__date__lte=end)
        logs = logs.filter(date__date__lte=end)

    return users, transactions, kyc_requests, logs


def _sum_amount(queryset, transaction_type=None, status_value=None):
    if transaction_type:
        queryset = queryset.filter(type=transaction_type)
    if status_value:
        queryset = queryset.filter(status=status_value)

    value = queryset.aggregate(total=Sum("montant"))["total"] or 0
    return float(Decimal(str(value)))


def _serialize_chart_item(label, value):
    return {
        "label": label,
        "value": value,
    }


@api_view(["GET"])
def report_stats(request):
    user, error = _require_reporting_access(request)
    if error:
        return error

    users = Utilisateur.objects.all()
    transactions = Transaction.objects.select_related("sender", "receiver", "validated_by").all()
    kyc_requests = KYCRequest.objects.select_related("utilisateur", "reviewed_by").all()
    logs = Log.objects.select_related("utilisateur").all()

    users, transactions, kyc_requests, logs = _apply_period_filters(
        request,
        users,
        transactions,
        kyc_requests,
        logs,
    )

    action_breakdown = list(
        logs.values("action")
        .annotate(count=Count("id"))
        .order_by("-count", "action")[:8]
    )

    payload = {
        "administrative": {
            "total_users": users.count(),
            "verified_users": users.filter(is_verified=True).count(),
            "suspended_users": users.filter(is_suspended=True).count(),
            "banned_users": users.filter(is_banned=True).count(),
            "admin_users": users.filter(role__in=["ADMIN", "ADMINISTRATEUR"]).count(),
            "auditeur_users": users.filter(role="AUDITEUR").count(),
            "comptable_users": users.filter(role="COMPTABLE").count(),
            "client_users": users.filter(role="CLIENT").count(),
        },
        "financial": {
            "total_transactions": transactions.count(),
            "pending_transactions": transactions.filter(status="PENDING").count(),
            "approved_transactions": transactions.filter(status="APPROVED").count(),
            "rejected_transactions": transactions.filter(status="REJECTED").count(),
            "total_deposit": _sum_amount(transactions, "DEPOSIT", "APPROVED"),
            "total_withdraw": _sum_amount(transactions, "WITHDRAW", "APPROVED"),
            "total_transfer": _sum_amount(transactions, "TRANSFER", "APPROVED"),
        },
        "kyc": {
            "kyc_pending": kyc_requests.filter(status="PENDING").count(),
            "kyc_approved": kyc_requests.filter(status="APPROVED").count(),
            "kyc_rejected": kyc_requests.filter(status="REJECTED").count(),
        },
        "security": {
            "total_logs": logs.count(),
            "suspicious_actions": logs.filter(is_suspicious=True).count(),
            "critical_actions": logs.filter(severity="CRITICAL").count(),
            "sensitive_actions": logs.filter(
                Q(is_suspicious=True) | Q(severity="CRITICAL")
            ).count(),
            "accounts_banned": users.filter(is_banned=True).count(),
        },
        "action_breakdown": action_breakdown,
    }

    payload.update(payload["administrative"])
    payload.update(payload["financial"])
    payload.update(payload["kyc"])
    payload.update(payload["security"])

    return Response(payload)


@api_view(["GET"])
def report_chart(request):
    _user, error = _require_reporting_access(request)
    if error:
        return error

    users = Utilisateur.objects.all()
    transactions = Transaction.objects.all()
    kyc_requests = KYCRequest.objects.all()
    logs = Log.objects.all()

    users, transactions, kyc_requests, logs = _apply_period_filters(
        request,
        users,
        transactions,
        kyc_requests,
        logs,
    )

    chart = [
        _serialize_chart_item("Users", users.count()),
        _serialize_chart_item("Verified", users.filter(is_verified=True).count()),
        _serialize_chart_item("Pending TX", transactions.filter(status="PENDING").count()),
        _serialize_chart_item("Rejected TX", transactions.filter(status="REJECTED").count()),
        _serialize_chart_item("Pending KYC", kyc_requests.filter(status="PENDING").count()),
        _serialize_chart_item("Suspicious", logs.filter(is_suspicious=True).count()),
        _serialize_chart_item("Critical", logs.filter(severity="CRITICAL").count()),
    ]

    return Response(chart)


@api_view(["GET"])
def export_pdf(request):
    from reportlab.lib.styles import getSampleStyleSheet
    from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer

    user, error = _require_reporting_access(request)
    if error:
        return error

    stats_response = report_stats(request)
    if stats_response.status_code != 200:
        return stats_response

    stats = stats_response.data

    response = HttpResponse(content_type="application/pdf")
    response["Content-Disposition"] = 'attachment; filename="reporting_summary.pdf"'

    doc = SimpleDocTemplate(response)
    styles = getSampleStyleSheet()
    content = [
        Paragraph("Nexora Reporting Summary", styles["Title"]),
        Spacer(1, 12),
        Paragraph("Administrative Metrics", styles["Heading2"]),
        Paragraph(f"Total users: {stats.get('total_users', 0)}", styles["Normal"]),
        Paragraph(f"Verified users: {stats.get('verified_users', 0)}", styles["Normal"]),
        Paragraph(f"Suspended users: {stats.get('suspended_users', 0)}", styles["Normal"]),
        Paragraph(f"Banned users: {stats.get('banned_users', 0)}", styles["Normal"]),
        Spacer(1, 12),
        Paragraph("Financial Metrics", styles["Heading2"]),
        Paragraph(f"Total transactions: {stats.get('total_transactions', 0)}", styles["Normal"]),
        Paragraph(f"Pending transactions: {stats.get('pending_transactions', 0)}", styles["Normal"]),
        Paragraph(f"Rejected transactions: {stats.get('rejected_transactions', 0)}", styles["Normal"]),
        Paragraph(f"Approved deposits: {stats.get('total_deposit', 0)}", styles["Normal"]),
        Paragraph(f"Approved withdrawals: {stats.get('total_withdraw', 0)}", styles["Normal"]),
        Paragraph(f"Approved transfers: {stats.get('total_transfer', 0)}", styles["Normal"]),
        Spacer(1, 12),
        Paragraph("KYC Metrics", styles["Heading2"]),
        Paragraph(f"KYC pending: {stats.get('kyc_pending', 0)}", styles["Normal"]),
        Paragraph(f"KYC approved: {stats.get('kyc_approved', 0)}", styles["Normal"]),
        Paragraph(f"KYC rejected: {stats.get('kyc_rejected', 0)}", styles["Normal"]),
        Spacer(1, 12),
        Paragraph("Audit & Security", styles["Heading2"]),
        Paragraph(f"Suspicious actions: {stats.get('suspicious_actions', 0)}", styles["Normal"]),
        Paragraph(f"Critical actions: {stats.get('critical_actions', 0)}", styles["Normal"]),
        Paragraph(f"Sensitive actions: {stats.get('sensitive_actions', 0)}", styles["Normal"]),
    ]

    doc.build(content)

    create_log(
        user,
        "GENERATE_REPORT",
        "reporting_summary.pdf",
        entity_type="REPORT",
        entity_id="global-report",
        target_repr="reporting_summary.pdf",
        metadata={"format": "PDF"},
    )

    return response


@api_view(["GET"])
def financial_stats(request):
    _user, error = _require_reporting_access(request)
    if error:
        return error

    transactions = Transaction.objects.all()
    _users = Utilisateur.objects.all()
    _kyc = KYCRequest.objects.all()
    _logs = Log.objects.all()
    _users, transactions, _kyc, _logs = _apply_period_filters(
        request,
        _users,
        transactions,
        _kyc,
        _logs,
    )

    approved_transactions = transactions.filter(status="APPROVED")

    deposit = _sum_amount(approved_transactions, "DEPOSIT")
    withdraw = _sum_amount(approved_transactions, "WITHDRAW")
    transfer = _sum_amount(approved_transactions, "TRANSFER")

    return Response(
        {
            "deposit": deposit,
            "withdraw": withdraw,
            "transfer": transfer,
            "balance": deposit - withdraw,
            "pending_transactions": transactions.filter(status="PENDING").count(),
            "rejected_transactions": transactions.filter(status="REJECTED").count(),
        }
    )
