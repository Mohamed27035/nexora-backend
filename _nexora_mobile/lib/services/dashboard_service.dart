import 'package:dio/dio.dart';

import 'api_service.dart';

class DashboardService {
  // ==========================
  // PROFILE
  // ==========================
  static Future<Response> getProfile() async {
    return await ApiService.dio.get(
      "users/profile/",
    );
  }

  // ==========================
  // STATS
  // ==========================
  static Future<Response> getStats({String role = ""}) async {
    final normalizedRole = role.toUpperCase();

    if (normalizedRole == "ADMIN" ||
        normalizedRole == "AUDITEUR" ||
        normalizedRole == "COMPTABLE") {
      return await ApiService.dio.get("reporting/stats/");
    }

    return await ApiService.dio.get("users/stats/");
  }

  // ==========================
  // ALERTS
  // ==========================
  static Future<Response> getAlerts() async {
    return await ApiService.dio.get(
      "users/me/alerts/",
    );
  }
}
