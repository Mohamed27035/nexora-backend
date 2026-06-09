from django.urls import path

from .views import (
    get_audit_log_detail,
    get_audit_logs,
    get_audit_summary,
    get_suspicious_actions,
)

urlpatterns = [
    path("", get_audit_summary),
    path("logs/", get_audit_logs),
    path("logs/<int:log_id>/", get_audit_log_detail),
    path("suspicious/", get_suspicious_actions),
]
