# logs/urls.py
from django.urls import path
from .views import get_logs, get_stats, get_activity_chart

urlpatterns = [
    path('', get_logs),
    path('stats/', get_stats),
    path('chart/', get_activity_chart),
]