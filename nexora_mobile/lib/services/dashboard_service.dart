import 'package:dio/dio.dart';

import 'api_service.dart';


class DashboardService {

  // ==========================
  // PROFILE
  // ==========================
  static Future<Response>
      getProfile() async {

    return await ApiService.dio.get(

      "users/profile/",
    );
  }

  // ==========================
  // STATS
  // ==========================
  static Future<Response>
      getStats() async {

    return await ApiService.dio.get(

      "users/stats/",
    );
  }

  // ==========================
  // ALERTS
  // ==========================
  static Future<Response>
      getAlerts() async {

    return await ApiService.dio.get(

      "users/me/alerts/",
    );
  }
}
