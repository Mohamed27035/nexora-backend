from rest_framework.decorators import api_view
from rest_framework.response import Response
from .models import Log
from django.db.models import Count
from users.views import get_current_user, is_admin, is_auditeur


@api_view(['GET'])
def get_logs(request):
    current_user, error = get_current_user(request)
    if error:
        return error

    if not (is_admin(current_user) or is_auditeur(current_user)):
        return Response({"error": "Accès refusé"}, status=403)

    start = request.GET.get("start")
    end = request.GET.get("end")
    action = request.GET.get("action")

    logs = Log.objects.all()

    if start and end:
        logs = logs.filter(date__range=[start, end])

    if action and action != "ALL":
        logs = logs.filter(action=action)

    logs = logs.order_by('-date')[:100]

    return Response([
        {
            "id": l.id,
            "user": l.utilisateur.nom if l.utilisateur else None,
            "action": l.action,
            "description": l.description,
            "date": l.date
        }
        for l in logs
    ])


@api_view(['GET'])
def get_stats(request):
    current_user, error = get_current_user(request)
    if error:
        return error

    if not (is_admin(current_user) or is_auditeur(current_user)):
        return Response({"error": "Accès refusé"}, status=403)

    logs = Log.objects.all()

    return Response({
        "total": logs.count(),
        "create": logs.filter(action="CREATE_USER").count(),
        "update": logs.filter(action="UPDATE_USER").count(),
        "delete": logs.filter(action="DELETE_USER").count(),
        "login": logs.filter(action="LOGIN").count(),
    })


@api_view(['GET'])
def get_activity_chart(request):
    current_user, error = get_current_user(request)
    if error:
        return error

    if not (is_admin(current_user) or is_auditeur(current_user)):
        return Response({"error": "Accès refusé"}, status=403)

    logs = Log.objects.values('action').annotate(count=Count('action'))
    return Response(list(logs))