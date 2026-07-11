import 'package:flutter/material.dart';

import '../../core/localization/app_language.dart';
import '../../core/theme/app_theme.dart';
import '../../services/security_service.dart';
import '../../widgets/info_card.dart';

class SecurityCenterScreen extends StatefulWidget {
  const SecurityCenterScreen({super.key});

  @override
  State<SecurityCenterScreen> createState() => _SecurityCenterScreenState();
}

class _SecurityCenterScreenState extends State<SecurityCenterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool loading = true;
  Map<String, dynamic> socStatus = {};
  Map<String, dynamic> overview = {};
  List alerts = [];
  List anomalies = [];
  List behavior = [];
  List timeline = [];

  String tr(String fr, String ar) => AppLanguage.t(fr, ar);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchAll() async {
    setState(() => loading = true);

    dynamic socData = {};
    dynamic alertsData = [];
    dynamic anomaliesData = [];
    dynamic behaviorData = [];
    dynamic timelineData = [];

    await Future.wait([
      () async {
        try {
          socData = (await SecurityService.getSocStatus()).data;
        } catch (_) {
          socData = {};
        }
      }(),
      () async {
        try {
          alertsData = (await SecurityService.getAlerts()).data;
        } catch (_) {
          alertsData = [];
        }
      }(),
      () async {
        try {
          anomaliesData = (await SecurityService.detectAnomalies()).data;
        } catch (_) {
          anomaliesData = [];
        }
      }(),
      () async {
        try {
          behaviorData = (await SecurityService.detectSuspiciousBehavior()).data;
        } catch (_) {
          behaviorData = [];
        }
      }(),
      () async {
        try {
          timelineData = (await SecurityService.getActivityTimeline()).data;
        } catch (_) {
          timelineData = [];
        }
      }(),
    ]);

    if (!mounted) return;
    setState(() {
      socStatus = _asMap(socData["soc"]);
      overview = _asMap(socData["overview"]);
      alerts = _asList(alertsData);
      anomalies = _asList(anomaliesData);
      behavior = _asList(behaviorData);
      timeline = _asList(timelineData);
      loading = false;
    });
  }

  List _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in const ["results", "data", "alerts", "anomalies", "items"]) {
        final value = data[key];
        if (value is List) return value;
      }
    }
    return [];
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? "") ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr("Centre de sécurité", "مركز الأمان")),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: tr("Alertes", "التنبيهات")),
            Tab(text: tr("Anomalies", "الشذوذ")),
            Tab(text: tr("Comportement", "السلوك")),
            Tab(text: tr("Historique", "السجل")),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _socStatusCard(),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _listTab(alerts, empty: tr("Aucune alerte", "لا توجد تنبيهات")),
                      _listTab(anomalies, empty: tr("Aucune anomalie", "لا توجد حالات شذوذ")),
                      _listTab(behavior, empty: tr("Aucun comportement suspect", "لا يوجد سلوك مشبوه")),
                      _timelineTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _socStatusCard() {
    final appName = (socStatus["app_name"] ?? "nexora-api").toString();
    final environment = (socStatus["environment"] ?? "production").toString();
    final blockAttacks = socStatus["block_attacks"] == true;
    final activeBans = _toInt(socStatus["active_banned_ips"]);
    final banDuration = _toInt(socStatus["ban_duration"]);
    final suspiciousCount = _toInt(overview["suspicious_logs"]);
    final criticalCount = _toInt(overview["critical_logs"]);
    final todayCount = _toInt(overview["today_suspicious"]);

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (blockAttacks ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  blockAttacks
                      ? Icons.shield_rounded
                      : Icons.gpp_bad_outlined,
                  color: blockAttacks ? AppColors.success : AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "RSS SOC Middleware",
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$appName • ${environment.toUpperCase()}",
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (blockAttacks ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  blockAttacks ? tr("Protection active", "حماية مفعلة") : tr("Journalisation seule", "تسجيل فقط"),
                  style: TextStyle(
                    color:
                        blockAttacks ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tr("Le middleware filtre les requêtes, bloque les attaques détectées et remonte les événements sensibles au SOC RSS Bank.", "يقوم الوسيط بتصفية الطلبات وحجب الهجمات المكتشفة ورفع الأحداث الحساسة إلى مركز RSS SOC."),
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricChip(
                tr("Blocage", "الحظر"),
                blockAttacks ? tr("Activé", "مفعل") : tr("Désactivé", "غير مفعل"),
                blockAttacks ? AppColors.success : AppColors.warning,
              ),
              _metricChip(
                tr("IPs bannies", "عناوين IP المحظورة"),
                "$activeBans",
                activeBans > 0 ? AppColors.danger : AppColors.primary,
              ),
              _metricChip(
                tr("Ban IP", "مدة الحظر"),
                "${(banDuration / 60).round()} min",
                AppColors.primary,
              ),
              _metricChip(
                tr("Logs suspects", "السجلات المشبوهة"),
                "$suspiciousCount",
                suspiciousCount > 0 ? AppColors.warning : AppColors.muted,
              ),
              _metricChip(
                tr("Logs critiques", "السجلات الحرجة"),
                "$criticalCount",
                criticalCount > 0 ? AppColors.danger : AppColors.muted,
              ),
              _metricChip(
                tr("Aujourd'hui", "اليوم"),
                "$todayCount",
                todayCount > 0 ? AppColors.accent : AppColors.muted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String value, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _listTab(List items, {required String empty}) {
    return RefreshIndicator(
      onRefresh: fetchAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (items.isEmpty)
            InfoCard(
              child: Text(
                empty,
                style: const TextStyle(color: AppColors.muted),
              ),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InfoCard(
                  child: _genericItem(item),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _timelineTab() {
    return RefreshIndicator(
      onRefresh: fetchAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (timeline.isEmpty)
            InfoCard(
              child: Text(
                "Aucune activite",
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else
            ...timeline.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InfoCard(
                  child: _timelineCard(item),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _genericItem(dynamic item) {
    if (item is Map) {
      final entries = item.entries.toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "${_labelize(entry.key.toString())}: ",
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  TextSpan(
                    text: _stringValue(entry.value),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    return Text(
      item.toString(),
      style: const TextStyle(color: AppColors.text),
    );
  }

  Widget _timelineCard(dynamic item) {
    if (item is! Map) {
      return Text(
        item.toString(),
        style: const TextStyle(color: AppColors.text),
      );
    }

    final type = (item["type"] ?? "").toString().toUpperCase();
    final action = (item["action"] ?? "-").toString();
    final description = _stringValue(item["description"]);
    final date = _formatDate(item["date"]);
    final status = (item["status"] ?? "").toString();
    final color = _timelineColor(type, action, status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _timelineIcon(type, action),
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _humanAction(action),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type == "TRANSACTION"
                        ? tr("Transaction", "معاملة")
                        : "Journal de securite",
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (status.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _timelineLine(tr("Description", "الوصف"), description),
        _timelineLine(tr("Date", "التاريخ"), date),
        if (type == "LOG") _timelineLine("Type", "Activite systeme"),
      ],
    );
  }

  Widget _timelineLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: "$label : ",
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: value.isEmpty ? "-" : value,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stringValue(dynamic value) {
    if (value == null) return "-";
    final text = value.toString().trim();
    return text.isEmpty ? "-" : text;
  }

  String _labelize(String raw) {
    switch (raw) {
      case "score":
        return tr("Score", "النتيجة");
      case "alerts":
        return tr("Alertes", "التنبيهات");
      case "anomalies":
        return tr("Anomalies", "الشذوذ");
      case "description":
        return tr("Description", "الوصف");
      case "date":
        return tr("Date", "التاريخ");
      case "active_banned_ips":
        return tr("IPs bannies", "عناوين IP المحظورة");
      case "block_attacks":
        return tr("Blocage", "الحظر");
      case "ban_duration":
        return "Duree du ban";
      default:
        return raw.replaceAll("_", " ");
    }
  }

  String _formatDate(dynamic raw) {
    final text = raw?.toString() ?? "";
    if (text.isEmpty) return "-";
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, "0");
    return "${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}";
  }

  IconData _timelineIcon(String type, String action) {
    if (type == "TRANSACTION") {
      switch (action.toUpperCase()) {
        case "DEPOSIT":
          return Icons.south_west_rounded;
        case "WITHDRAW":
          return Icons.north_east_rounded;
        case "TRANSFER":
          return Icons.swap_horiz_rounded;
      }
    }

    switch (action.toUpperCase()) {
      case "APPROVE_KYC":
        return Icons.verified_user_outlined;
      case "REJECT_KYC":
        return Icons.cancel_outlined;
      case "APPROVE_TRANSACTION":
        return Icons.check_circle_outline;
      case "REJECT_TRANSACTION":
        return Icons.highlight_off;
      case "CHANGE_ROLE":
        return Icons.admin_panel_settings_outlined;
      case "DELETE_USER":
        return Icons.delete_outline;
      case "CREATE_TRANSACTION":
        return Icons.receipt_long_outlined;
      case "RESET_PASSWORD":
        return Icons.lock_reset_outlined;
      case "SUSPEND_USER":
        return Icons.pause_circle_outline;
      case "BAN_USER":
        return Icons.block_outlined;
      default:
        return Icons.history_rounded;
    }
  }

  Color _timelineColor(String type, String action, String status) {
    if (type == "TRANSACTION") {
      return _statusColor(status.isEmpty ? action : status);
    }
    switch (action.toUpperCase()) {
      case "APPROVE_KYC":
      case "APPROVE_TRANSACTION":
        return AppColors.success;
      case "REJECT_KYC":
      case "REJECT_TRANSACTION":
      case "DELETE_USER":
      case "BAN_USER":
        return AppColors.danger;
      case "CHANGE_ROLE":
        return AppColors.primary;
      default:
        return AppColors.warning;
    }
  }

  String _humanAction(String action) {
    switch (action.toUpperCase()) {
      case "APPROVE_KYC":
        return "Verification d'identite approuvee";
      case "REJECT_KYC":
        return "Verification d'identite rejetee";
      case "APPROVE_TRANSACTION":
        return "Transaction approuvee";
      case "REJECT_TRANSACTION":
        return "Transaction rejetee";
      case "CREATE_TRANSACTION":
        return "Transaction creee";
      case "CHANGE_ROLE":
        return "Role modifie";
      case "DELETE_USER":
        return "Utilisateur supprime";
      case "RESET_PASSWORD":
        return "Mot de passe reinitialise";
      case "SUSPEND_USER":
        return "Compte suspendu";
      case "BAN_USER":
        return "Compte banni";
      case "DEPOSIT":
        return "Depot";
      case "WITHDRAW":
        return "Retrait";
      case "TRANSFER":
        return "Transfert";
      default:
        return action.replaceAll("_", " ");
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case "APPROVED":
      case "SUCCESS":
        return AppColors.success;
      case "REJECTED":
      case "FAILED":
      case "CANCELED":
        return AppColors.danger;
      case "PENDING":
        return AppColors.warning;
      case "DEPOSIT":
      case "WITHDRAW":
      case "TRANSFER":
        return AppColors.primary;
      default:
        return AppColors.muted;
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case "APPROVED":
        return "Approuvee";
      case "REJECTED":
        return "Rejetee";
      case "PENDING":
        return "En attente";
      case "FAILED":
        return "Echouee";
      case "CANCELED":
        return "Annulee";
      case "SUCCESS":
        return "Reussie";
      default:
        return status;
    }
  }
}



