import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/audit_service.dart';
import '../../widgets/info_card.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabController;
  List auditItems = [];
  List logs = [];
  bool loading = true;
  String? auditError;
  String? logsError;
  String search = "";
  String actionFilter = "ALL";

  List get filteredLogs {
    return logs.where((item) {
      final action = item["action"]?.toString() ?? "";
      final haystack = item.toString().toLowerCase();
      final matchesSearch = search.isEmpty || haystack.contains(search);
      final matchesAction = actionFilter == "ALL" || action == actionFilter;
      return matchesSearch && matchesAction;
    }).toList();
  }

  List get suspiciousItems {
    return [...auditItems, ...logs].where((item) {
      final text = item.toString().toLowerCase();
      return text.contains("suspicious") ||
          text.contains("failed") ||
          text.contains("blocked") ||
          text.contains("anomaly");
    }).toList();
  }

  Future<void> fetchData() async {
    dynamic auditData = [];
    dynamic logsData = [];
    String? nextAuditError;
    String? nextLogsError;

    try {
      auditData = (await AuditService.getAuditItems()).data;
    } catch (_) {
      nextAuditError = "Impossible de charger audit";
    }

    try {
      logsData = (await AuditService.getLogs()).data;
    } catch (_) {
      nextLogsError = "Impossible de charger logs";
    }

    if (!mounted) return;
    setState(() {
      auditItems = _asList(auditData);
      logs = _asList(logsData);
      auditError = nextAuditError;
      logsError = nextLogsError;
      loading = false;
    });

    if (nextAuditError != null && nextLogsError != null) {
      _showMessage("Impossible de charger audit/logs");
    }
  }

  List _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data["results"] is List) return data["results"];
    if (data is Map && data["logs"] is List) return data["logs"];
    if (data is Map && data["audit"] is List) return data["audit"];
    if (data is Map && data["data"] is List) return data["data"];
    return [];
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
    fetchData();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Audit & Logs"),
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(text: "Logs"),
            Tab(text: "Audit"),
            Tab(text: "Suspicious"),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: tabController,
              children: [
                _logsTab(),
                _listTab(auditItems),
                _listTab(suspiciousItems),
              ],
            ),
    );
  }

  Widget _logsTab() {
    final actions = logs
        .map((item) => item["action"]?.toString() ?? "")
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();

    return RefreshIndicator(
      onRefresh: fetchData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InfoCard(
            child: Column(
              children: [
                TextField(
                  style: const TextStyle(color: AppColors.text),
                  decoration: const InputDecoration(
                    hintText: "Search logs",
                    hintStyle: TextStyle(color: AppColors.muted),
                  ),
                  onChanged: (value) => setState(() => search = value.toLowerCase()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: actionFilter,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: AppColors.text),
                  items: [
                    const DropdownMenuItem(value: "ALL", child: Text("Toutes actions")),
                    ...actions.map(
                      (action) => DropdownMenuItem(
                        value: action,
                        child: Text(action),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => actionFilter = value ?? "ALL"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (logsError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                logsError!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          ...filteredLogs.map(_eventCard),
        ],
      ),
    );
  }

  Widget _listTab(List items) {
    return RefreshIndicator(
      onRefresh: fetchData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: items.isEmpty
            ? [
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Text(
                      "Aucune donnee",
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                ),
              ]
            : items.map(_eventCard).toList(),
      ),
    );
  }

  Widget _eventCard(dynamic item) {
    final title = item["action"] ??
        item["event"] ??
        item["type"] ??
        item["message"] ??
        "Audit item";
    final user = item["user"] ?? item["user_email"] ?? item["email"] ?? "";
    final date = item["created_at"] ?? item["timestamp"] ?? item["date"] ?? "";

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toString(),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (user.toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(user.toString(), style: const TextStyle(color: AppColors.muted)),
            ],
            if (date.toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(date.toString(), style: const TextStyle(color: AppColors.muted)),
            ],
            const SizedBox(height: 8),
            Text(
              item.toString(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
