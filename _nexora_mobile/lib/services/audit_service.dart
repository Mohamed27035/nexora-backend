import 'package:dio/dio.dart';

import 'api_service.dart';

class AuditService {
  static Future<Response> getAuditSummary() async {
    return ApiService.dio.get("audit/");
  }

  static Future<Response> getLogs({
    String search = "",
    String action = "ALL",
    String severity = "ALL",
    String entityType = "ALL",
    bool? suspicious,
    bool? sensitive,
    String? start,
    String? end,
  }) async {
    return ApiService.dio.get(
      "logs/",
      queryParameters: {
        if (search.trim().isNotEmpty) "search": search.trim(),
        if (action != "ALL") "action": action,
        if (severity != "ALL") "severity": severity,
        if (entityType != "ALL") "entity_type": entityType,
        if (suspicious != null) "suspicious": suspicious,
        if (sensitive != null) "sensitive": sensitive,
        if (start != null && start.isNotEmpty) "start": start,
        if (end != null && end.isNotEmpty) "end": end,
      },
    );
  }

  static Future<Response> getSuspiciousLogs() async {
    return ApiService.dio.get("logs/suspicious/");
  }

  static Future<Response> getLogDetail(int logId) async {
    return ApiService.dio.get("logs/$logId/");
  }

  static Future<Response> getLogsStats({
    String search = "",
    String action = "ALL",
    String severity = "ALL",
    String entityType = "ALL",
    bool? suspicious,
    bool? sensitive,
    String? start,
    String? end,
  }) async {
    return ApiService.dio.get(
      "logs/stats/",
      queryParameters: {
        if (search.trim().isNotEmpty) "search": search.trim(),
        if (action != "ALL") "action": action,
        if (severity != "ALL") "severity": severity,
        if (entityType != "ALL") "entity_type": entityType,
        if (suspicious != null) "suspicious": suspicious,
        if (sensitive != null) "sensitive": sensitive,
        if (start != null && start.isNotEmpty) "start": start,
        if (end != null && end.isNotEmpty) "end": end,
      },
    );
  }

  static Future<Response> getLogsChart({
    String search = "",
    String action = "ALL",
    String severity = "ALL",
    String entityType = "ALL",
    bool? suspicious,
    bool? sensitive,
    String? start,
    String? end,
  }) async {
    return ApiService.dio.get(
      "logs/chart/",
      queryParameters: {
        if (search.trim().isNotEmpty) "search": search.trim(),
        if (action != "ALL") "action": action,
        if (severity != "ALL") "severity": severity,
        if (entityType != "ALL") "entity_type": entityType,
        if (suspicious != null) "suspicious": suspicious,
        if (sensitive != null) "sensitive": sensitive,
        if (start != null && start.isNotEmpty) "start": start,
        if (end != null && end.isNotEmpty) "end": end,
      },
    );
  }

  static Future<Response> getMyLogs() async {
    return ApiService.dio.get("users/my-logs/");
  }
}
