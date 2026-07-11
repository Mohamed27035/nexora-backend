import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_language.dart';
import '../../core/theme/app_theme.dart';
import '../../services/audit_service.dart';
import '../../widgets/info_card.dart';
import 'audit_detail_screen.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  Map<String, dynamic> summary = {};
  List logs = [];
  List suspiciousLogs = [];
  List myLogs = [];
  Map<String, dynamic> stats = {};
  List chart = [];
  bool loading = true;

  String search = "";
  String actionFilter = "ALL";
  String severityFilter = "ALL";
  String entityTypeFilter = "ALL";
  bool sensitiveOnly = false;

  String tr(String fr, String ar) => AppLanguage.t(fr, ar);

  Future<void> fetchData() async {
    setState(() => loading = true);

    try {
      final logsResponse = await AuditService.getLogs(
        search: search,
        action: actionFilter,
        severity: severityFilter,
        entityType: entityTypeFilter,
        sensitive: sensitiveOnly ? true : null,
      );
      final statsResponse = await AuditService.getLogsStats(
        search: search,
        action: actionFilter,
        severity: severityFilter,
        entityType: entityTypeFilter,
        sensitive: sensitiveOnly ? true : null,
      );
      final chartResponse = await AuditService.getLogsChart(
        search: search,
        action: actionFilter,
        severity: severityFilter,
        entityType: entityTypeFilter,
        sensitive: sensitiveOnly ? true : null,
      );
      final summaryResponse = await AuditService.getAuditSummary();
      final suspiciousResponse = await AuditService.getSuspiciousLogs();
      final myLogsResponse = await AuditService.getMyLogs();

      if (!mounted) return;
      setState(() {
        logs = _asList(logsResponse.data);
        stats = _asMap(statsResponse.data);
        chart = _asList(chartResponse.data);
        summary = _asMap(summaryResponse.data);
        suspiciousLogs = _asList(suspiciousResponse.data);
        myLogs = _asList(myLogsResponse.data);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      _showMessage(tr("Impossible de charger les donnees d'audit", "???? ????? ?????? ???????"));
    }
  }

  List _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data["results"] is List) return data["results"];
    if (data is Map && data["logs"] is List) return data["logs"];
    if (data is Map && data["recent_sensitive"] is List) return data["recent_sensitive"];
    return [];
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Color _severityColor(String value) {
    switch (value.toUpperCase()) {
      case "CRITICAL":
        return AppColors.danger;
      case "WARNING":
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  String _severityLabel(String value) {
    switch (value.toUpperCase()) {
      case "CRITICAL":
        return tr("CRITICAL", "???");
      case "WARNING":
        return tr("WARNING", "?????");
      default:
        return tr("INFO", "??????");
    }
  }

  String _formatDate(dynamic raw) {
    final text = raw?.toString().trim() ?? "";
    if (text.isEmpty) return "-";
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, "0");
    return "${two(local.day)}/${two(local.month)}/${local.year} ${tr('à', '??????')} ${two(local.hour)}:${two(local.minute)}";
  }

  String _humanAction(String action) {
    switch (action.toUpperCase()) {
      case "SUBMIT_KYC":
        return tr("Soumission de la vérification d'identité", "????? ??? ?????? ?? ??????");
      case "APPROVE_KYC":
        return tr("Approbation de la vérification d'identité", "???????? ??? ?????? ?? ??????");
      case "REJECT_KYC":
        return tr("Rejet de la vérification d'identité", "??? ?????? ?? ??????");
      case "APPROVE_TRANSACTION":
        return tr("Transaction approuvée", "???????? ??? ????????");
      case "REJECT_TRANSACTION":
        return tr("Transaction rejetée", "??? ????????");
      case "CREATE_TRANSACTION":
        return tr("Transaction créée", "????? ??????");
      case "CHANGE_ROLE":
        return tr("Changement de rôle", "????? ?????");
      case "DELETE_USER":
        return tr("Suppression d'utilisateur", "??? ??????");
      case "LOGIN":
        return tr("Connexion", "????? ??????");
      default:
        return action.replaceAll("_", " ");
    }
  }

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr("Audit et journaux", "??????? ????????"))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _filtersCard(),
                  const SizedBox(height: 16),
                  _summaryGrid(),
                  const SizedBox(height: 16),
                  _chartCard(),
                  const SizedBox(height: 16),
                  _suspiciousCard(),
                  const SizedBox(height: 16),
                  _sectionTitle(tr("Tous les journaux d'audit", "?? ????? ???????")),
                  const SizedBox(height: 8),
                  if (logs.isEmpty)
                    InfoCard(
                      child: Text(
                        tr("Aucun log ne correspond aux filtres.", "?? ???? ??? ????? ???????."),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    )
                  else
                    ...logs.map((item) => _logCard(item)),
                  const SizedBox(height: 16),
                  _sectionTitle(tr("Mon activite recente", "????? ??????")),
                  const SizedBox(height: 8),
                  if (myLogs.isEmpty)
                    InfoCard(
                      child: Text(
                        tr("Aucune activite personnelle.", "?? ???? ???? ????."),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    )
                  else
                    ...myLogs.take(6).map((item) => _logCard(item)),
                ],
              ),
            ),
    );
  }

  Widget _filtersCard() {
    final actionItems = ["ALL", "LOGIN", "CREATE_USER", "UPDATE_USER", "DELETE_USER", "APPROVE_TRANSACTION", "REJECT_TRANSACTION", "APPROVE_KYC", "REJECT_KYC"];
    final severityItems = ["ALL", "INFO", "WARNING", "CRITICAL"];
    final entityItems = ["ALL", "USER", "TRANSACTION", "KYC", "REPORT"];

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr("Filtres d'audit", "????? ???????"),
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: tr("Rechercher par action, utilisateur, cible ou entite...", "???? ?????? ?? ???????? ?? ????? ?? ??????..."),
            ),
            onChanged: (value) => search = value.trim(),
            onSubmitted: (_) => fetchData(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: actionFilter,
            items: actionItems
                .map((item) => DropdownMenuItem(value: item, child: Text(_actionFilterLabel(item))))
                .toList(),
            onChanged: (value) => setState(() => actionFilter = value ?? "ALL"),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: severityFilter,
            items: severityItems
                .map((item) => DropdownMenuItem(value: item, child: Text(_severityFilterLabel(item))))
                .toList(),
            onChanged: (value) => setState(() => severityFilter = value ?? "ALL"),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: entityTypeFilter,
            items: entityItems
                .map((item) => DropdownMenuItem(value: item, child: Text(_entityFilterLabel(item))))
                .toList(),
            onChanged: (value) => setState(() => entityTypeFilter = value ?? "ALL"),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr("Actions sensibles uniquement", "???????? ??????? ???")),
            value: sensitiveOnly,
            onChanged: (value) => setState(() => sensitiveOnly = value),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: fetchData,
              child: Text(tr("Appliquer les filtres", "????? ???????")),
            ),
          ),
        ],
      ),
    );
  }

  String _severityFilterLabel(String value) {
    switch (value) {
      case "ALL":
        return tr("Toutes les severites", "?? ????? ???????");
      case "INFO":
        return tr("Information", "??????");
      case "WARNING":
        return tr("Avertissement", "?????");
      case "CRITICAL":
        return tr("Critique", "???");
      default:
        return value;
    }
  }

  String _actionFilterLabel(String value) {
    switch (value) {
      case "ALL":
        return tr("Toutes les actions", "?? ????????");
      case "LOGIN":
        return tr("Connexion", "????? ??????");
      case "CREATE_USER":
        return tr("Creation utilisateur", "????? ??????");
      case "UPDATE_USER":
        return tr("Mise a jour utilisateur", "????? ??????");
      case "DELETE_USER":
        return tr("Suppression utilisateur", "??? ??????");
      case "APPROVE_TRANSACTION":
        return tr("Approbation transaction", "???????? ??? ????????");
      case "REJECT_TRANSACTION":
        return tr("Rejet transaction", "??? ????????");
      case "APPROVE_KYC":
        return tr("Approbation identite", "???????? ??? ??????");
      case "REJECT_KYC":
        return tr("Rejet identite", "??? ??????");
      default:
        return value;
    }
  }

  String _entityFilterLabel(String value) {
    switch (value) {
      case "ALL":
        return tr("Toutes les entites", "?? ????????");
      case "USER":
        return tr("Utilisateur", "??????");
      case "TRANSACTION":
        return tr("Transaction", "??????");
      case "KYC":
        return tr("Verification identite", "?????? ?? ??????");
      case "REPORT":
        return tr("Rapport", "?????");
      default:
        return value;
    }
  }

  Widget _summaryGrid() {
    final items = [
      {
        "label": tr("Journaux totaux", "?????? ???????"),
        "value": summary["total_logs"] ?? stats["total_logs"] ?? 0,
        "color": AppColors.primary,
      },
      {
        "label": tr("Suspicious", "????????"),
        "value": summary["suspicious_actions"] ?? stats["suspicious_actions"] ?? 0,
        "color": AppColors.warning,
      },
      {
        "label": tr("Critical", "??????"),
        "value": summary["critical_actions"] ?? stats["critical_actions"] ?? 0,
        "color": AppColors.danger,
      },
      {
        "label": tr("Sensitive", "???????"),
        "value": stats["sensitive_actions"] ?? 0,
        "color": AppColors.accent,
      },
      {
        "label": tr("Users", "??????????"),
        "value": summary["user_actions"] ?? 0,
        "color": AppColors.success,
      },
      {
        "label": tr("Transactions", "?????????"),
        "value": summary["transaction_actions"] ?? 0,
        "color": AppColors.primary,
      },
      {
        "label": tr("Identite", "??????"),
        "value": summary["kyc_actions"] ?? 0,
        "color": AppColors.warning,
      },
      {
        "label": tr("Acteurs", "????????"),
        "value": stats["actors_count"] ?? 0,
        "color": AppColors.success,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = constraints.maxWidth < 380 ? 1.35 : 1.58;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: ratio,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final label = item["label"].toString();
            final value = item["value"];
            final color = item["color"] as Color;
            return InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value.toString(),
                      style: TextStyle(
                        color: color,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _chartCard() {
    final spots = <FlSpot>[];
    for (var i = 0; i < chart.length; i++) {
      final item = chart[i];
      final value = double.tryParse((item["value"] ?? 0).toString()) ?? 0;
      spots.add(FlSpot(i.toDouble(), value));
    }

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(tr("Audit Activity", "???? ???????")),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: spots.isEmpty
                ? Center(
                    child: Text(
                      tr("Aucune donnee d'activite.", "?? ???? ?????? ????."),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: true),
                      titlesData: const FlTitlesData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          color: AppColors.primary,
                          barWidth: 3,
                          isCurved: true,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _openAdminMessaging({
    required String category,
    required String subject,
    required String body,
  }) {
    Navigator.of(context).pushNamed(
      "/messages",
      arguments: {
        "recipientRole": "ADMIN",
        "category": category,
        "subject": subject,
        "body": body,
      },
    );
  }

  Widget _suspiciousCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(tr("Actions suspectes", "???????? ????????")),
          const SizedBox(height: 8),
          if (suspiciousLogs.isEmpty)
            Text(
              tr("Aucune action suspecte detectee.", "?? ???? ?????? ?????? ??????."),
              style: const TextStyle(color: AppColors.muted),
            )
          else
            ...suspiciousLogs.take(5).map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _humanAction((item["action"] ?? "").toString()),
                          style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (item["target_repr"] ?? item["description"] ?? "-").toString(),
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () => _openAdminMessaging(
                              category: "ALERT",
                              subject: tr("Alerte d'audit", "????? ??????"),
                              body: tr(
                                "Action suspecte detectee : ",
                                "?? ??? ????? ??????: ",
                              ) +
                                  _humanAction((item["action"] ?? "").toString()) +
                                  "\n" +
                                  tr("Cible : ", "?????: ") +
                                  (item["target_repr"] ?? item["description"] ?? "-").toString(),
                            ),
                            icon: const Icon(Icons.notification_important_outlined),
                            label: Text(
                              tr("Signaler a l'administration", "????? ???????"),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _logCard(dynamic item) {
    final data = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map);
    final severity = (data["severity"] ?? "INFO").toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AuditDetailScreen(logItem: data),
            ),
          );
        },
        child: InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _humanAction((data["action"] ?? "AUDIT").toString()),
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _severityColor(severity).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _severityLabel(severity),
                      style: TextStyle(
                        color: _severityColor(severity),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "${tr("Acteur", "??????")} : ${data["user"] ?? "-"}",
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                "${tr("Entite", "??????")} : ${data["entity_type"] ?? "-"} #${data["entity_id"] ?? "-"}",
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                "${tr("Cible", "?????")} : ${data["target_repr"] ?? "-"}",
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                "${tr("Date", "???????")} : ${_formatDate(data["date"])}",
                style: const TextStyle(color: AppColors.muted),
              ),
              if ((data["description"] ?? "").toString().trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  data["description"].toString(),
                  style: const TextStyle(color: AppColors.text),
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _openAdminMessaging(
                    category: "AUDIT",
                    subject: tr("Observation d'audit", "?????? ???????"),
                    body: tr(
                      "Je souhaite remonter cette observation a l'administration.\n",
                      "???? ?? ??? ??? ???????? ??? ???????.\n",
                    ) +
                        tr("Action : ", "???????: ") +
                        _humanAction((data["action"] ?? "AUDIT").toString()) +
                        "\n" +
                        tr("Entite : ", "??????: ") +
                        "${data["entity_type"] ?? "-"} #${data["entity_id"] ?? "-"}" +
                        "\n" +
                        tr("Cible : ", "?????: ") +
                        "${data["target_repr"] ?? "-"}" +
                        "\n" +
                        tr("Date : ", "???????: ") +
                        _formatDate(data["date"]),
                  ),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: Text(
                    tr("Envoyer une observation a l'administration", "????? ?????? ??? ???????"),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}





