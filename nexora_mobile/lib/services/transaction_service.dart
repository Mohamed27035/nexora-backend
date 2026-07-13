import 'package:dio/dio.dart';

import 'api_service.dart';


class TransactionService {

  // ==========================
  // GET TRANSACTIONS
  // ==========================
  static Future<Response>
      getTransactions() async {

    return await ApiService.dio.get(

      "transactions/",
    );
  }

  // ==========================
  // CREATE TRANSACTION
  // ==========================
  static Future<Response>
      createTransaction({

    required double montant,

    required String type,

    int? receiver,

    String? note,

  }) async {

    return await ApiService.dio.post(

      "transactions/create/",

      data: {

        "montant": montant,

        "type": type,

        "receiver": receiver,

        "note": note,
      },
    );
  }

  static Future<Response> approveTransaction(int id) async {
    return await ApiService.dio.post(
      "transactions/approve/$id/",
    );
  }

  static Future<Response> rejectTransaction(int id) async {
    return await ApiService.dio.post(
      "transactions/reject/$id/",
    );
  }
}
