import 'package:dio/dio.dart';

import 'api_service.dart';

class SecurityService {
  static Future<Response> getSocStatus() async {
    return await ApiService.dio.get("users/security-status/");
  }

  static Future<Response> getAlerts() async {
    return await ApiService.dio.get("users/me/alerts/");
  }

  static Future<Response> detectAnomalies() async {
    return await ApiService.dio.get("users/detect-anomalies/");
  }

  static Future<Response> detectSuspiciousBehavior() async {
    return await ApiService.dio.get("users/detect-behavior/");
  }

  static Future<Response> getActivityTimeline() async {
    return await ApiService.dio.get("users/timeline/");
  }
}
