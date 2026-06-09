from django.urls import path

from .views import (
    get_activity_chart,
    get_log_detail,
    get_logs,
    get_stats,
    get_suspicious_logs,
)

urlpatterns = [
    path("", get_logs),
    path("stats/", get_stats),
    path("chart/", get_activity_chart),
    path("suspicious/", get_suspicious_logs),
    path("<int:log_id>/", get_log_detail),
]
