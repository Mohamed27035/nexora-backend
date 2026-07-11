import 'package:dio/dio.dart';

class DioErrorUtils {
  static String friendlyMessage(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final detail = _extractDetail(data);

    if (status == 400 && detail.isNotEmpty) return detail;
    if (status == 401) return detail.isNotEmpty ? detail : "غير مصرح (401).";
    if (status == 403) return detail.isNotEmpty ? detail : "ممنوع (403).";
    if (status == 404) {
      return detail.isNotEmpty ? detail : "المسار غير موجود (404).";
    }
    if (status == 409) {
      return detail.isNotEmpty ? detail : "يوجد تعارض في العملية (409).";
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return "الخادم يتأخر في الاستجابة. أعد المحاولة بعد ثوان.";
    }
    if (status != null) {
      return detail.isNotEmpty ? "HTTP $status: $detail" : "HTTP $status";
    }
    return "تعذر الاتصال بالخادم.";
  }

  static String _extractDetail(dynamic data) {
    if (data == null) return "";
    if (data is String) return data;
    if (data is Map) {
      final detail = data["detail"];
      if (detail != null) return detail.toString();

      final error = data["error"];
      if (error != null) return error.toString();

      final message = data["message"];
      if (message != null) return message.toString();

      final nonField = data["non_field_errors"];
      if (nonField is List && nonField.isNotEmpty) {
        return nonField.first.toString();
      }

      for (final entry in data.entries) {
        final key = entry.key?.toString() ?? "";
        if (key.isEmpty ||
            key == "detail" ||
            key == "error" ||
            key == "message" ||
            key == "non_field_errors") {
          continue;
        }

        final value = entry.value;
        if (value is List && value.isNotEmpty) {
          return "$key: ${value.first}";
        }
        if (value is String && value.trim().isNotEmpty) {
          return "$key: $value";
        }
      }
    }
    return "";
  }
}
