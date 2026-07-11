import 'package:dio/dio.dart';

import 'api_service.dart';


class TransactionService {
  static Future<Response> getTransactions({
    String? search,
    String? status,
    String? type,
    String? direction,
    String? sort,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) {
      queryParameters["search"] = search.trim();
    }
    if (status != null && status.trim().isNotEmpty && status != "ALL") {
      queryParameters["status"] = status.trim().toUpperCase();
    }
    if (type != null && type.trim().isNotEmpty && type != "ALL") {
      queryParameters["type"] = type.trim().toUpperCase();
    }
    if (direction != null && direction.trim().isNotEmpty && direction != "ALL") {
      queryParameters["direction"] = direction.trim().toUpperCase();
    }
    if (sort != null && sort.trim().isNotEmpty) {
      queryParameters["sort"] = sort.trim();
    }

    return ApiService.dio.get(
      "transactions/",
      queryParameters: queryParameters,
    );
  }

  static Future<Response> createTransaction({
    required double montant,
    required String type,
    int? receiver,
    String? receiverPhone,
    String? serviceProvider,
    String? servicePhone,
    String? note,
  }) async {
    return ApiService.dio.post(
      "transactions/create/",
      data: {
        "montant": montant,
        "type": type.toUpperCase(),
        if (receiver != null) "receiver": receiver,
        if (receiverPhone != null && receiverPhone.trim().isNotEmpty)
          "receiver_phone": receiverPhone.trim(),
        if (serviceProvider != null && serviceProvider.trim().isNotEmpty)
          "service_provider": serviceProvider.trim().toUpperCase(),
        if (servicePhone != null && servicePhone.trim().isNotEmpty)
          "service_phone": servicePhone.trim(),
        if (note != null && note.trim().isNotEmpty) "note": note.trim(),
      },
    );
  }

  static Future<Response> approveTransaction(int id, {String? note}) async {
    return ApiService.dio.post(
      "transactions/approve/$id/",
      data: {
        if (note != null && note.trim().isNotEmpty) "note": note.trim(),
      },
    );
  }

  static Future<Response> rejectTransaction(int id, {String? note}) async {
    return ApiService.dio.post(
      "transactions/reject/$id/",
      data: {
        if (note != null && note.trim().isNotEmpty) "note": note.trim(),
      },
    );
  }

  static Future<Response> getBeneficiaries() async {
    return ApiService.dio.get("transactions/beneficiaries/");
  }

  static Future<Response> addBeneficiary({
    required String beneficiaryPhone,
    String? nickname,
  }) async {
    return ApiService.dio.post(
      "transactions/beneficiaries/",
      data: {
        "beneficiary_phone": beneficiaryPhone.trim(),
        if (nickname != null && nickname.trim().isNotEmpty)
          "nickname": nickname.trim(),
      },
    );
  }

  static Future<Response> deleteBeneficiary(int beneficiaryId) async {
    return ApiService.dio.delete("transactions/beneficiaries/$beneficiaryId/");
  }
}

