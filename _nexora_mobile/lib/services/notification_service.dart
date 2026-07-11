import 'package:dio/dio.dart';

import 'api_service.dart';

class NotificationService {
  static Future<Response> getNotifications() async {
    return await ApiService.dio.get("notifications/my/");
  }

  static Future<Response> getAlertsFallback() async {
    return await ApiService.dio.get("users/me/alerts/");
  }

  static Future<Response> markAsRead(int id) async {
    return await ApiService.dio.post("notifications/read/$id/");
  }

  static Future<Response> deleteNotification(int id) async {
    return await ApiService.dio.delete("notifications/delete/$id/");
  }

  static Future<Response> getMessageContacts() async {
    return await ApiService.dio.get("notifications/contacts/");
  }

  static Future<Response> getMessages({
    String mailbox = "all",
    bool unreadOnly = false,
    int? transactionId,
  }) async {
    final queryParameters = <String, dynamic>{
      "mailbox": mailbox,
    };

    if (unreadOnly) {
      queryParameters["unread_only"] = true;
    }
    if (transactionId != null) {
      queryParameters["transaction_id"] = transactionId;
    }

    return await ApiService.dio.get(
      "notifications/messages/",
      queryParameters: queryParameters,
    );
  }

  static Future<Response> sendMessage({
    required int recipientId,
    required String body,
    String subject = "",
    String category = "GENERAL",
    int? transactionId,
  }) async {
    final data = <String, dynamic>{
      "recipient_id": recipientId,
      "subject": subject,
      "body": body,
      "category": category,
    };

    if (transactionId != null) {
      data["transaction_id"] = transactionId;
    }

    return await ApiService.dio.post(
      "notifications/messages/send/",
      data: data,
    );
  }

  static Future<Response> markMessageAsRead(int id) async {
    return await ApiService.dio.post("notifications/messages/read/$id/");
  }
}
