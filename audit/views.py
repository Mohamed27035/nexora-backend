from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import status

from .models import Transaction
from .serializers import TransactionSerializer
from users.permissions import IsAuditeur


# 🔍 GET ALL (auditeur seulement)
@api_view(['GET'])
@permission_classes([IsAuthenticated, IsAuditeur])
def get_transactions(request):
    transactions = Transaction.objects.all()
    serializer = TransactionSerializer(transactions, many=True)
    return Response(serializer.data)


# 🔍 GET ONE (auditeur seulement)
@api_view(['GET'])
@permission_classes([IsAuthenticated, IsAuditeur])
def get_transaction(request, id):
    try:
        transaction = Transaction.objects.get(id=id)
    except Transaction.DoesNotExist:
        return Response({"error": "Transaction introuvable"}, status=404)

    serializer = TransactionSerializer(transaction)
    return Response(serializer.data)


# ➕ CREATE (auditeur seulement)
@api_view(['POST'])
@permission_classes([IsAuthenticated, IsAuditeur])
def create_transaction(request):
    serializer = TransactionSerializer(data=request.data)

    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data, status=201)

    return Response(serializer.errors, status=400)


# ❌ DELETE (auditeur seulement)
@api_view(['DELETE'])
@permission_classes([IsAuthenticated, IsAuditeur])
def delete_transaction(request, id):
    try:
        transaction = Transaction.objects.get(id=id)
    except Transaction.DoesNotExist:
        return Response({"error": "Transaction introuvable"}, status=404)

    transaction.delete()
    return Response({"message": "Transaction supprimée"})