import 'package:dio/dio.dart';

import 'api_service.dart';


class NotificationService {

  // ==========================
  // GET NOTIFICATIONS
  // ==========================
  static Future<Response>
      getNotifications() async {

    return await ApiService.dio.get(

      "notifications/my/",
    );
  }

  // ==========================
  // MARK AS READ
  // ==========================
  static Future<Response>
      markAsRead(int id) async {

    return await ApiService.dio.post(

      "notifications/read/$id/",
    );
  }

  // ==========================
  // DELETE
  // ==========================
  static Future<Response>
      deleteNotification(
          int id) async {

    return await ApiService.dio.delete(

      "notifications/delete/$id/",
    );
  }
}