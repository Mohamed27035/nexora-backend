import 'package:flutter/material.dart';

import '../core/localization/app_language.dart';
import '../core/theme/app_theme.dart';
import '../services/dashboard_service.dart';
import '../services/secure_storage_service.dart';
import '../services/transaction_service.dart';
import '../utils/auth_guard.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _bg = AppColors.background;
  static const _ink = AppColors.text;
  static const _muted = AppColors.muted;
  static const _line = AppColors.surfaceSoft;

  Map<String, dynamic> profile = {};
  Map<String, dynamic> stats = {};
  List alerts = [];
  List transactions = [];
  bool loading = true;
  String role = "";

  Future<void> fetchData() async {
    try {
      final profileRes = await DashboardService.getProfile();
      final storedRole = await SecureStorageService.getRole();
      dynamic statsData = {};
      dynamic alertsData = {};
      dynamic transactionData = [];

      try {
        statsData = (await DashboardService.getStats()).data;
      } catch (_) {
        statsData = {};
      }

      try {
        alertsData = (await DashboardService.getAlerts()).data;
      } catch (_) {
        alertsData = {};
      }

      try {
        transactionData = (await TransactionService.getTransactions()).data;
      } catch (_) {
        transactionData = [];
      }

      if (!mounted) return;

      setState(() {
        profile = Map<String, dynamic>.from(profileRes.data);
        stats = statsData is Map ? Map<String, dynamic>.from(statsData) : {};
        alerts = alertsData is Map
            ? alertsData["alerts"] ?? alertsData["results"] ?? []
            : alertsData is List
                ? alertsData
                : [];
        transactions = transactionData is List
            ? transactionData
            : transactionData is Map
                ? transactionData["results"] ?? transactionData["transactions"] ?? []
                : [];
        role = (profile["role"]?.toString() ?? storedRole).toUpperCase();
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de charger le dashboard")),
      );
    }
  }

  Future<void> logout() async {
    await SecureStorageService.clearSession();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
  }

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: fetchData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 96),
                  children: [
                    _topBar(),
                    const SizedBox(height: 18),
                    _topModulesMenu(),
                    const SizedBox(height: 24),
                    _mainCard(),
                    const SizedBox(height: 22),
                    _summaryCards(),
                    const SizedBox(height: 28),
                    _sectionHeader(
                      AppLanguage.t("Transactions recentes", "آخر المعاملات"),
                      AppLanguage.t("Voir tout", "عرض الكل"),
                      () => Navigator.pushNamed(context, "/transactions"),
                    ),
                    const SizedBox(height: 14),
                    _recentTransactions(),
                    _sectionHeader(AppLanguage.t("Audit alerts", "تنبيهات التدقيق"), "", null),
                    const SizedBox(height: 14),
                    _alertsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _topBar() {
    final name = profile["prenom"] ?? profile["nom"] ?? "utilisateur";
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLanguage.t("Bonjour,", "\u0645\u0631\u062d\u0628\u0627\u060c"),
                style: const TextStyle(color: _muted, fontSize: 20),
              ),
              const SizedBox(height: 4),
              Text(
                name.toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        _topIcon(Icons.notifications_none, () => Navigator.pushNamed(context, "/notifications")),
        const SizedBox(width: 12),
        _topIcon(Icons.person, () => Navigator.pushNamed(context, "/profile"), selected: true),
        const SizedBox(width: 12),
        _topIcon(Icons.logout, logout),
        const SizedBox(width: 12),
        _languageChip(),
      ],
    );
  }

  Widget _languageChip() {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.notifier,
      builder: (context, language, _) {
        return InkWell(
          onTap: AppLanguage.toggle,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 54,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _line),
            ),
            child: Text(
              language == "ar" ? "FR" : "AR",
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
            ),
          ),
        );
      },
    );
  }

  Widget _topIcon(IconData icon, VoidCallback onTap, {bool selected = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE4EAFF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? const Color(0xFFB9C7FF) : _line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: selected ? AppColors.primary : _ink),
      ),
    );
  }

  Widget _mainCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD9E0F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLanguage.t("Centre de controle Fintech", "\u0645\u0631\u0643\u0632 \u0627\u0644\u062a\u062d\u0643\u0645 \u0627\u0644\u0645\u0627\u0644\u064a"),
                  style: const TextStyle(color: _muted, fontSize: 17),
                ),
              ),
              _statusBadge(),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            _headlineValue(),
            style: const TextStyle(
              color: _ink,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLanguage.t("Reporting - Audit - Administration", "\u0627\u0644\u062a\u0642\u0627\u0631\u064a\u0631 - \u0627\u0644\u062a\u062f\u0642\u064a\u0642 - \u0627\u0644\u0625\u062f\u0627\u0631\u0629"),
            style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          const Divider(color: _line),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _quickAction(Icons.add, AppLanguage.t("Recharger", "شحن"), const Color(0xFFE9ECFF), AppColors.primary, "/transactions"),
              _quickAction(Icons.send, AppLanguage.t("Envoyer", "إرسال"), const Color(0xFFE2F6F3), AppColors.accent, "/transactions"),
              _quickAction(Icons.history, AppLanguage.t("Historique", "السجل"), const Color(0xFFFFF1DE), AppColors.warning, "/transactions"),
              _quickAction(Icons.account_balance, AppLanguage.t("Comptes", "الحسابات"), const Color(0xFFF1E5FF), const Color(0xFF8B5CF6), "/reports"),
            ],
          ),
        ],
      ),
    );
  }

  String _headlineValue() {
    final balance = stats["balance"] ?? stats["solde"] ?? stats["total_balance"];
    if (balance != null) return "$balance MRU";
    if (role == "ADMIN") return "${_firstValue(["total_users", "users", "total"])} users";
    return "0 MRU";
  }

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE3FAF3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFA8EAD8)),
      ),
      child: Text(
        role.isEmpty ? "Actif" : role,
        style: const TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, Color bg, Color color, String route) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.18)),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF475467),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCards() {
    return Row(
      children: [
        Expanded(child: _summaryCard(Icons.arrow_upward, AppLanguage.t("Total envoye", "إجمالي المرسل"), _firstValue(["sent", "total_sent", "withdraw"]), const Color(0xFFFFE4EA), AppColors.danger)),
        const SizedBox(width: 12),
        Expanded(child: _summaryCard(Icons.arrow_downward, AppLanguage.t("Total recu", "إجمالي المستلم"), _firstValue(["received", "total_received", "deposit"]), const Color(0xFFE2F6F3), AppColors.accent)),
        const SizedBox(width: 12),
        Expanded(child: _summaryCard(Icons.receipt_long, AppLanguage.t("Transactions", "المعاملات"), _firstValue(["transactions", "total_transactions", "transaction_count"]), const Color(0xFFE8EFFF), AppColors.primary)),
      ],
    );
  }

  Widget _summaryCard(IconData icon, String label, String value, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14),
          Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value == "0" ? "0 MRU" : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String action, VoidCallback? onAction) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
        if (action.isNotEmpty)
          TextButton(
            onPressed: onAction,
            child: Text(action, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
      ],
    );
  }

  Widget _recentTransactions() {
    if (transactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 38),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _line),
        ),
        child: const Column(
          children: [
            Icon(Icons.receipt_long, color: _muted, size: 46),
            SizedBox(height: 10),
            Text("Aucune transaction recente", style: TextStyle(color: _muted)),
          ],
        ),
      );
    }

    return Column(
      children: transactions.take(3).map((item) {
        final type = item["type"]?.toString() ?? "Transaction";
        final amount = item["montant"] ?? item["amount"] ?? "-";
        final status = item["status"]?.toString() ?? "";
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              const Icon(Icons.swap_horiz, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type, style: const TextStyle(color: _ink, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(status, style: const TextStyle(color: _muted, fontSize: 12)),
                  ],
                ),
              ),
              Text("$amount", style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _topModulesMenu() {
    final modules = <_Module>[
      _Module("Accueil", Icons.home, AppColors.primary, () {}),
      if (role == "ADMIN" || role == "COMPTABLE")
        _Module("Wallet", Icons.account_balance_wallet, AppColors.accent, () async {
          final allowed = await AuthGuard.checkRole(
            allowedRoles: ["ADMIN", "COMPTABLE"],
            context: context,
          );
          if (!allowed || !mounted) return;
          Navigator.pushNamed(context, "/transactions");
        }),
      if (role == "ADMIN")
        _Module("Admin", Icons.admin_panel_settings, AppColors.primary, () => Navigator.pushNamed(context, "/admin/users")),
      if (role == "ADMIN")
        _Module("KYC", Icons.fact_check, AppColors.warning, () => Navigator.pushNamed(context, "/admin/kyc-review")),
      if (role == "ADMIN" || role == "AUDITEUR")
        _Module("Audit", Icons.receipt_long, AppColors.danger, () => Navigator.pushNamed(context, "/audit")),
      if (role == "ADMIN" || role == "COMPTABLE" || role == "AUDITEUR")
        _Module("Reporting", Icons.insights, AppColors.success, () => Navigator.pushNamed(context, "/reports")),
      _Module("Notifications", Icons.notifications_active, AppColors.primary, () => Navigator.pushNamed(context, "/notifications")),
      _Module("Profil", Icons.person, AppColors.accent, () => Navigator.pushNamed(context, "/profile")),
      if (role == "CLIENT")
        _Module("KYC", Icons.verified, AppColors.warning, () => Navigator.pushNamed(context, "/kyc")),
    ];

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: modules.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final module = modules[index];
          return InkWell(
          onTap: module.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 112,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: module.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(module.icon, color: module.color),
                ),
                const SizedBox(height: 10),
                Text(
                  module.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          );
        },
      ),
    );
  }

  Widget _alertsList() {
    if (alerts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.64),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _line),
        ),
        child: const Text("Aucune alerte detectee", style: TextStyle(color: _muted)),
      );
    }

    return Column(
      children: alerts.map((alert) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE4EA),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFFCBD5)),
          ),
          child: Text(alert.toString(), style: const TextStyle(color: _ink)),
        );
      }).toList(),
    );
  }

  String _firstValue(List<String> keys) {
    for (final key in keys) {
      final value = stats[key];
      if (value != null) return value.toString();
    }
    return "0";
  }
}

class _Module {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _Module(this.label, this.icon, this.color, this.onTap);
}
