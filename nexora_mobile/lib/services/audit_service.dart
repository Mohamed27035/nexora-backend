import 'package:dio/dio.dart';

import 'api_service.dart';

class AuditService {
  static Future<Response> getAuditItems() async {
    return await ApiService.dio.get("audit/");
  }

  static Future<Response> getLogs() async {
    return await ApiService.dio.get("logs/");
  }
}
