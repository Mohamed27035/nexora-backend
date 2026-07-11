import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/localization/app_language.dart';
import '../core/theme/app_theme.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> notifications = [];
  bool loading = true;
  String? errorMessage;

  Future<void> fetchNotifications() async {
    if (mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final response = await NotificationService.getNotifications();
      final extractedNotifications = _asList(response.data);

      List<Map<String, dynamic>> fallbackAlerts = [];
      if (extractedNotifications.isEmpty) {
        try {
          final alertsResponse = await NotificationService.getAlertsFallback();
          fallbackAlerts = _alertsAsNotifications(alertsResponse.data);
        } catch (_) {
          fallbackAlerts = [];
        }
      }

      if (!mounted) return;
      setState(() {
        notifications = extractedNotifications.isNotEmpty
            ? extractedNotifications
            : fallbackAlerts;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = AppLanguage.t(
          "Impossible de charger les notifications",
          "تعذر تحميل الإشعارات",
        );
      });
    }
  }

  List<Map<String, dynamic>> _asList(dynamic data) {
    final rawList = <dynamic>[];

    if (data is List) {
      rawList.addAll(data);
    } else if (data is Map && data["results"] is List) {
      rawList.addAll(data["results"] as List);
    } else if (data is Map && data["notifications"] is List) {
      rawList.addAll(data["notifications"] as List);
    } else if (data is Map && data["data"] is List) {
      rawList.addAll(data["data"] as List);
    }

    return rawList
        .map((item) {
          if (item is Map<String, dynamic>) return item;
          if (item is Map) return Map<String, dynamic>.from(item);
          return <String, dynamic>{};
        })
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _alertsAsNotifications(dynamic data) {
    final alerts = data is Map ? data["alerts"] : null;
    if (alerts is! List || alerts.isEmpty) return [];

    return List.generate(alerts.length, (index) {
      return {
        "id": -1 - index,
        "title": AppLanguage.t("Alerte", "تنبيه"),
        "message": alerts[index].toString(),
        "type": "warning",
        "is_read": false,
      };
    });
  }

  Future<void> markAsRead(int id) async {
    if (id < 0) {
      if (!mounted) return;
      setState(() {
        notifications = notifications.map((item) {
          if (item["id"] == id) {
            return {
              ...item,
              "is_read": true,
            };
          }
          return item;
        }).toList();
      });
      return;
    }

    try {
      await NotificationService.markAsRead(id);
      await fetchNotifications();
    } catch (_) {}
  }

  Future<void> deleteNotif(int id) async {
    if (id < 0) {
      if (!mounted) return;
      setState(() {
        notifications =
            notifications.where((item) => item["id"] != id).toList();
      });
      return;
    }

    try {
      await NotificationService.deleteNotification(id);
      await fetchNotifications();
    } catch (_) {}
  }

  String _stringValue(
    Map<String, dynamic> notification,
    String key,
    String fallback,
  ) {
    final value = notification[key];
    final text = _repairText(value?.toString() ?? "").trim();
    return text.isEmpty ? fallback : text;
  }

  String _repairText(String value) {
    if (value.isEmpty) return value;

    try {
      final repaired = utf8.decode(
        latin1.encode(value),
        allowMalformed: true,
      );
      if (_looksBroken(value) && !_looksBroken(repaired)) {
        return repaired;
      }
    } catch (_) {}

    return value;
  }

  bool _looksBroken(String value) {
    return value.contains("ÃƒÆ’") ||
        value.contains("ÃƒËœ") ||
        value.contains("Ãƒâ„¢") ||
        value.contains("Ãƒâ€š") ||
        value.contains("Ã¯Â¿Â½");
  }

  bool _isRead(Map<String, dynamic> notification) {
    return notification["is_read"] == true;
  }

  String _typeLabel(String type) {
    switch (type.toLowerCase()) {
      case "danger":
      case "error":
        return AppLanguage.t("Danger", "خطر");
      case "warning":
        return AppLanguage.t("Avertissement", "تحذير");
      case "success":
        return AppLanguage.t("Succès", "نجاح");
      default:
        return AppLanguage.t("Info", "معلومة");
    }
  }

  int _notificationId(Map<String, dynamic> notification) {
    final raw = notification["id"];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "") ?? -999999;
  }

  Color _accentColor(String type) {
    if (type == "warning") return AppColors.warning;
    if (type == "danger" || type == "error") return AppColors.danger;
    if (type == "success") return AppColors.success;
    return AppColors.primary;
  }

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLanguage.t("Notifications", "الإشعارات"))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFF7FAFF),
                    Color(0xFFFFFAF4),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                    )
                  : notifications.isEmpty
                      ? _emptyState()
                      : RefreshIndicator(
                          onRefresh: fetchNotifications,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                            children: [
                              _heroHeader(),
                              const SizedBox(height: 18),
                              ...notifications.map(_notificationCard),
                            ],
                          ),
                        ),
            ),
    );
  }

  Widget _heroHeader() {
    final unreadCount = notifications.where((item) => !_isRead(item)).length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLanguage.t("Centre des notifications", "مركز الإشعارات"),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLanguage.t(
              "Suivez les alertes, messages système et événements importants.",
              "تابع التنبيهات ورسائل النظام والأحداث المهمة.",
            ),
            style: const TextStyle(color: Colors.white, height: 1.6),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _heroStat(
                  AppLanguage.t("Total", "الإجمالي"),
                  notifications.length.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _heroStat(
                  AppLanguage.t("Non lues", "غير المقروءة"),
                  unreadCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _notificationCard(Map<String, dynamic> notification) {
    final notificationId = _notificationId(notification);
    final isRead = _isRead(notification);
    final title = _stringValue(
      notification,
      "title",
      AppLanguage.t("Notification", "إشعار"),
    );
    final message = _stringValue(notification, "message", "");
    final type = _stringValue(notification, "type", "info").toLowerCase();
    final safeTitle = _looksBroken(title)
        ? (type == "danger" || type == "error"
            ? AppLanguage.t("Alerte de sécurité", "تنبيه أمني")
            : AppLanguage.t("Notification", "إشعار"))
        : title;
    final accentColor = _accentColor(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_iconForType(type), color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      safeTitle,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message.isEmpty ? "-" : message,
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _typeLabel(type),
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isRead
                          ? AppColors.panel
                          : AppColors.warning.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isRead
                          ? AppLanguage.t("Lue", "مقروءة")
                          : AppLanguage.t("Nouvelle", "جديدة"),
                      style: TextStyle(
                        color:
                            isRead ? AppColors.primary : AppColors.warning,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (!isRead)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => markAsRead(notificationId),
                    child: Text(
                      AppLanguage.t("Marquer comme lue", "تحديد كمقروءة"),
                    ),
                  ),
                ),
              if (!isRead) const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => deleteNotif(notificationId),
                  child: Text(AppLanguage.t("Supprimer", "حذف")),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case "danger":
      case "error":
        return Icons.warning_amber_rounded;
      case "warning":
        return Icons.notifications_active_outlined;
      case "success":
        return Icons.verified_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              AppLanguage.t("Aucune notification", "لا توجد إشعارات"),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLanguage.t(
                "Les nouvelles alertes et informations importantes apparaîtront ici.",
                "ستظهر هنا التنبيهات الجديدة والمعلومات المهمة.",
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
