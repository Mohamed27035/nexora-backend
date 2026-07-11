import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/localization/app_language.dart';
import '../core/theme/app_theme.dart';
import '../services/dashboard_service.dart';
import '../services/secure_storage_service.dart';
import '../services/transaction_service.dart';
import '../utils/dio_error_utils.dart';
import '../widgets/transfer_receipt_dialog.dart';

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
  bool _hideBalance = false;
  final PageController _dashboardPageController = PageController();
  int _dashboardPageIndex = 0;

  static const String _hideBalanceKey = "dashboard_hide_balance";

  Future<String> _resolveRole({
    required Map<String, dynamic> profileData,
    required String storedRole,
  }) async {
    final profileRole = profileData["role"]?.toString().toUpperCase() ?? "";
    final resolved = (profileRole.isNotEmpty ? profileRole : storedRole).toUpperCase();
    if (resolved.isNotEmpty && resolved != storedRole.toUpperCase()) {
      final token = await SecureStorageService.getToken();
      if (token != null && token.isNotEmpty) {
        await SecureStorageService.saveSession(token: token, role: resolved);
      }
    }
    return resolved;
  }

  Future<void> fetchData() async {
    try {
      final profileRes = await DashboardService.getProfile();
      final storedRole = await SecureStorageService.getRole();
      final profileMap = Map<String, dynamic>.from(profileRes.data);
      final resolvedRole = await _resolveRole(
        profileData: profileMap,
        storedRole: storedRole,
      );

      dynamic statsData = {};
      dynamic alertsData = {};
      dynamic transactionData = [];

      try {
        statsData = (await DashboardService.getStats(role: resolvedRole)).data;
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
        profile = profileMap;
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
        role = resolvedRole;
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

  Future<void> _loadBalancePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hideBalance = prefs.getBool(_hideBalanceKey) ?? false;
    });
  }

  Future<void> _toggleBalanceVisibility() async {
    final next = !_hideBalance;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideBalanceKey, next);
    if (!mounted) return;
    setState(() => _hideBalance = next);
  }

  double _toAmount(dynamic item) {
    if (item is Map) {
      return double.tryParse((item["montant"] ?? item["amount"] ?? 0).toString()) ?? 0;
    }
    return double.tryParse(item.toString()) ?? 0;
  }

  int get _currentUserId {
    final raw = profile["id"];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "") ?? 0;
  }

  String _statusOf(dynamic item) {
    if (item is Map) {
      return (item["status"] ?? "").toString().toUpperCase();
    }
    return "";
  }

  int _countStatuses(List<String> statuses) {
    return transactions.where((item) => statuses.contains(_statusOf(item))).length;
  }

  int get _totalTransactions => transactions.length;

  int get _pendingTransactions => _countStatuses(["PENDING", "WAITING"]);

  int get _approvedTransactions => _countStatuses(["APPROVED", "VALIDATED", "SUCCESS"]);

  int get _rejectedTransactions => _countStatuses(["REJECTED", "FAILED", "CANCELED"]);

  bool _isApproved(dynamic item) => _statusOf(item) == "APPROVED";

  bool _isSentByCurrentUser(dynamic item) {
    if (item is! Map) return false;
    final senderId = item["sender"];
    if (senderId is int) return senderId == _currentUserId;
    return int.tryParse(senderId?.toString() ?? "") == _currentUserId;
  }

  bool _isReceivedByCurrentUser(dynamic item) {
    if (item is! Map) return false;
    final receiverId = item["receiver"];
    if (receiverId is int) return receiverId == _currentUserId;
    return int.tryParse(receiverId?.toString() ?? "") == _currentUserId;
  }

  double get _totalSentApproved {
    return transactions
        .where((item) => _isApproved(item) && _isSentByCurrentUser(item))
        .fold<double>(0, (sum, item) => sum + _toAmount(item));
  }

  double get _totalReceivedApproved {
    return transactions.where((item) {
      if (!_isApproved(item) || item is! Map) return false;
      final type = (item["type"] ?? "").toString().toUpperCase();
      if (type == "DEPOSIT") return _isSentByCurrentUser(item);
      return _isReceivedByCurrentUser(item);
    }).fold<double>(0, (sum, item) => sum + _toAmount(item));
  }

  double get _approvalRate {
    if (_totalTransactions == 0) return 0;
    return (_approvedTransactions / _totalTransactions) * 100;
  }

  bool get _isVerifiedProfile {
    final raw = profile["is_verified"];
    if (raw is bool) return raw;
    return raw?.toString().toLowerCase() == "true";
  }

  int get _activeAlertsCount => alerts.length;

  int get _submittedTransactionsCount =>
      _countStatuses(["SUBMITTED", "ACCOUNTANT_APPROVED"]);

  int get _anomalyTransactionsCount => transactions.where((item) {
        if (item is! Map) return false;
        return item["anomaly_detected"] == true;
      }).length;

  double get _trustScore {
    double score = 100;

    if (!_isVerifiedProfile) score -= 25;
    if (!_canUseServices) score -= 18;
    score -= (_activeAlertsCount * 6).clamp(0, 30).toDouble();
    score -= (_rejectedTransactions * 4).clamp(0, 20).toDouble();
    score -= (_pendingTransactions * 2).clamp(0, 10).toDouble();

    return score.clamp(10, 100);
  }

  int _intFromStats(List<String> keys) {
    final source = _flatStats;
    for (final key in keys) {
      final value = source[key];
      if (value is num) return value.round();
      final parsed = int.tryParse(value?.toString() ?? "");
      if (parsed != null) return parsed;
    }
    return 0;
  }

  bool get _canUseServices {
    final raw = profile["can_use_services"];
    if (raw is bool) return raw;
    return !(role == "CLIENT" && profile["is_verified"] != true);
  }

  bool get _isInactiveClient => role == "CLIENT" && !_canUseServices;

  bool get _isClientRole => role == "CLIENT";

  bool get _showFinancialBalance => _isClientRole;

  bool _moduleRequiresActiveAccount(String label) {
    return label == "Transactions" || label == "Ø§Ù„Ù…Ø¹Ø§Ù…Ù„Ø§Øª";
  }

  void _showInactiveAccountMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Votre compte est inactif. Completez la verification d'identite puis attendez la validation de l'administrateur.",
        ),
      ),
    );
  }

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r"\D"), "");
  }

  bool _isValidPhone(String value) {
    final phone = _normalizePhone(value);
    return phone.length == 8 &&
        (phone.startsWith("2") || phone.startsWith("3") || phone.startsWith("4"));
  }

  bool _isValidTopupPhone(String provider, String value) {
    final phone = _normalizePhone(value);
    if (phone.length != 8) return false;

    switch (provider.toUpperCase()) {
      case "MAURITEL":
        return phone.startsWith("4");
      case "MATTEL":
        return phone.startsWith("3");
      case "CHINGUITEL":
        return phone.startsWith("2");
      default:
        return false;
    }
  }

  String get _profilePhone {
    return _normalizePhone(profile["telephone"]?.toString() ?? "");
  }

  String get _profileName {
    final fullName = profile["full_name"]?.toString().trim() ?? "";
    if (fullName.isNotEmpty) return fullName;

    final parts = [
      profile["nom"]?.toString().trim() ?? "",
      profile["prenom"]?.toString().trim() ?? "",
    ].where((item) => item.isNotEmpty).toList();

    return parts.isEmpty ? "Utilisateur" : parts.join(" ");
  }

  bool get _hasVisibleBalance {
    if (!_showFinancialBalance) return false;
    final flatStats = _flatStats;
    final balance =
        profile["balance"] ?? flatStats["balance"] ?? flatStats["solde"] ?? flatStats["total_balance"];
    return balance != null;
  }

  String _receiveQrPayload() {
    return jsonEncode({
      "type": "nexora_receive",
      "phone": _profilePhone,
      "name": _profileName,
      "currency": "MRU",
      "user_id": profile["id"],
    });
  }

  String? _extractPhoneFromQr(String rawValue) {
    final raw = rawValue.trim();
    if (raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final phone = _normalizePhone(decoded["phone"]?.toString() ?? "");
        if (_isValidPhone(phone)) {
          return phone;
        }
      }
    } catch (_) {}

    final directPhone = _normalizePhone(raw);
    if (_isValidPhone(directPhone)) {
      return directPhone;
    }

    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _scanTransferQr() async {
    bool handled = false;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.62,
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Scanner le QR du destinataire",
                style: TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: MobileScanner(
                    onDetect: (capture) {
                      if (handled) return;
                      final barcodes = capture.barcodes;
                      if (barcodes.isEmpty) return;
                      final raw = barcodes.first.rawValue ?? "";
                      final phone = _extractPhoneFromQr(raw);
                      if (phone == null) return;
                      handled = true;
                      Navigator.pop(context, phone);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLanguage.t("Fermer", "Ø¥ØºÙ„Ø§Ù‚")),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReceiveQrSheet() {
    if (!_isValidPhone(_profilePhone)) {
      _showMessage("Ajoutez d'abord un numero de telephone valide pour generer votre QR.");
      return;
    }

    final payload = _receiveQrPayload();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Recevoir de l'argent",
                  style: TextStyle(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _line),
                  ),
                  child: QrImageView(
                    data: payload,
                    size: 190,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _profileName,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _profilePhone,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 17,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: _profilePhone));
                          if (!mounted) return;
                          _showMessage(AppLanguage.t("Numero copie.", "ØªÙ… Ù†Ø³Ø® Ø§Ù„Ø±Ù‚Ù…."));
                        },
                        icon: const Icon(Icons.copy_all_outlined),
                        label: Text(AppLanguage.t("Copier", "Ù†Ø³Ø®")),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text("Fermer"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openQuickTransactionSheet(String transactionType) async {
    if (!_isClientRole) {
      _showMessage(AppLanguage.t(
        "Les operations financieres sont reservees aux comptes client.",
        "Ø§Ù„Ø¹Ù…Ù„ÙŠØ§Øª Ø§Ù„Ù…Ø§Ù„ÙŠØ© Ù…Ø®ØµØµØ© Ù„Ø­Ø³Ø§Ø¨Ø§Øª Ø§Ù„Ø¹Ù…Ù„Ø§Ø¡ ÙÙ‚Ø·.",
      ));
      return;
    }

    if (_isInactiveClient) {
      _showInactiveAccountMessage();
      return;
    }

    final amountController = TextEditingController();
    final phoneController = TextEditingController();
    String topupProvider = "MAURITEL";
    final topupOptions = <int>[10, 50, 100, 200, 300, 500, 1000, 2000];
    int? selectedTopupAmount = 10;
    bool submitting = false;
    String? sheetError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> submit() async {
              setLocalState(() => sheetError = null);
              final amount = transactionType == "TOPUP"
                  ? selectedTopupAmount?.toDouble()
                  : double.tryParse(
                      amountController.text.trim().replaceAll(",", "."),
                    );
              if (amount == null || amount <= 0) {
                setLocalState(() => sheetError = AppLanguage.t("Montant invalide.", "Ø§Ù„Ù…Ø¨Ù„Øº ØºÙŠØ± ØµØ§Ù„Ø­."));
                return;
              }

              final receiverPhone = _normalizePhone(phoneController.text);
              if (transactionType == "TRANSFER" && !_isValidPhone(receiverPhone)) {
                setLocalState(
                  () => sheetError = AppLanguage.t(
                    "Le numero du destinataire est invalide. Il doit contenir 8 chiffres et commencer par 2, 3 ou 4.",
                    "Ø±Ù‚Ù… Ø§Ù„Ù…Ø³ØªÙÙŠØ¯ ØºÙŠØ± ØµØ§Ù„Ø­. ÙŠØ¬Ø¨ Ø£Ù† ÙŠØªÙƒÙˆÙ† Ù…Ù† 8 Ø£Ø±Ù‚Ø§Ù… ÙˆÙŠØ¨Ø¯Ø£ Ø¨Ù€ 2 Ø£Ùˆ 3 Ø£Ùˆ 4.",
                  ),
                );
                return;
              }

              if (transactionType == "TOPUP" &&
                  !_isValidTopupPhone(topupProvider, receiverPhone)) {
                setLocalState(
                  () => sheetError = AppLanguage.t(
                    "Le numero de recharge est invalide. Il doit contenir 8 chiffres. Mauritel commence par 4, Mattel par 3 et Chinguitel par 2.",
                    "رقم التعبئة غير صالح. يجب أن يتكون من 8 أرقام. موريتل يبدأ بـ 4، وماتل بـ 3، وشنقيتل بـ 2.",
                  ),
                );
                return;
              }

              setLocalState(() => submitting = true);
              try {
                final response = await TransactionService.createTransaction(
                  montant: amount,
                  type: transactionType,
                  receiverPhone: transactionType == "TRANSFER" ? receiverPhone : null,
                  serviceProvider:
                      transactionType == "TOPUP" ? topupProvider : null,
                  servicePhone: transactionType == "TOPUP" ? receiverPhone : null,
                  note: "",
                );
                final transaction = response.data is Map
                    ? Map<String, dynamic>.from(response.data['transaction'] ?? const {})
                    : <String, dynamic>{};
                if (!mounted || !context.mounted) return;
                Navigator.pop(context);
                await fetchData();
                if (!mounted || !context.mounted) return;
                if (transactionType == "TRANSFER" && transaction.isNotEmpty) {
                  await showTransferReceiptDialog(
                    context,
                    tr: AppLanguage.t,
                    transaction: transaction,
                  );
                } else {
                    _showMessage(
                      transactionType == "TRANSFER"
                          ? AppLanguage.t("Transfert cree avec succes.", "ØªÙ… Ø¥Ù†Ø´Ø§Ø¡ Ø§Ù„ØªØ­ÙˆÙŠÙ„ Ø¨Ù†Ø¬Ø§Ø­.")
                          : transactionType == "TOPUP"
                              ? AppLanguage.t("Recharge credit creee avec succes.", "تم إنشاء تعبئة الرصيد بنجاح.")
                              : AppLanguage.t("Retrait cree avec succes.", "ØªÙ… Ø¥Ù†Ø´Ø§Ø¡ Ø§Ù„Ø³Ø­Ø¨ Ø¨Ù†Ø¬Ø§Ø­."),
                    );
                  }
              } catch (e) {
                setLocalState(
                  () => sheetError = e is DioException
                      ? DioErrorUtils.friendlyMessage(e)
                      : AppLanguage.t("Une erreur est survenue.", "Ø­Ø¯Ø« Ø®Ø·Ø£ ØºÙŠØ± Ù…ØªÙˆÙ‚Ø¹."),
                );
              } finally {
                if (mounted) {
                  setLocalState(() => submitting = false);
                }
              }
            }

                return Padding(
                  padding: EdgeInsets.only(
                    left: 14,
                    right: 14,
                    top: 12,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 14,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                      transactionType == "TRANSFER"
                          ? "Nouveau transfert"
                          : transactionType == "TOPUP"
                              ? "Nouvelle recharge credit"
                              : "Nouveau retrait",
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (transactionType == "TOPUP") ...[
                      DropdownButtonFormField<String>(
                        value: topupProvider,
                        items: const [
                          DropdownMenuItem(value: "MAURITEL", child: Text("Mauritel")),
                          DropdownMenuItem(value: "MATTEL", child: Text("Mattel")),
                          DropdownMenuItem(value: "CHINGUITEL", child: Text("Chinguitel")),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setLocalState(() => topupProvider = value);
                        },
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: AppLanguage.t("Operateur", "المشغل"),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (sheetError != null && sheetError!.trim().isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFFB3B3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(Icons.warning_amber_rounded, color: Color(0xFFD92D20)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                sheetError!,
                                style: const TextStyle(
                                  color: Color(0xFFB42318),
                                  fontSize: 12.2,
                                  fontWeight: FontWeight.w700,
                                  height: 1.22,
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (transactionType == "TOPUP") ...[
                      Text(
                        AppLanguage.t("Choisissez une valeur", "اختر قيمة التعبئة"),
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 12.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: topupOptions.map((value) {
                          final selected = selectedTopupAmount == value;
                          return InkWell(
                            onTap: () => setLocalState(() => selectedTopupAmount = value),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 104,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected ? AppColors.primary : _line,
                                  width: selected ? 1.8 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (selected) ...[
                                    const Icon(
                                      Icons.check,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                   Text(
                                     "$value MRU",
                                     style: TextStyle(
                                       color: selected ? AppColors.primary : _ink,
                                       fontWeight: FontWeight.w800,
                                       fontSize: 12,
                                     ),
                                   ),
                                 ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ] else ...[
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: AppLanguage.t("Montant (MRU)", "المبلغ (MRU)"),
                        ),
                      ),
                    ],
                    if (transactionType == "TRANSFER" || transactionType == "TOPUP") ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: transactionType == "TOPUP"
                              ? AppLanguage.t("Numero a recharger", "رقم التعبئة")
                              : AppLanguage.t("Numero du destinataire", "رقم المستفيد"),
                          suffixIcon: transactionType == "TRANSFER"
                              ? IconButton(
                                  onPressed: () async {
                                    final scannedPhone = await _scanTransferQr();
                                    if (scannedPhone == null || scannedPhone.isEmpty) return;
                                    phoneController.text = scannedPhone;
                                  },
                                  icon: const Icon(Icons.qr_code_scanner_rounded),
                                  tooltip: AppLanguage.t("Scanner un QR", "مسح QR"),
                                )
                              : null,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: submitting ? null : submit,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          submitting
                              ? AppLanguage.t("Traitement...", "جارٍ التنفيذ...")
                              : AppLanguage.t("Valider", "تأكيد"),
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<FlSpot> get _transactionSpots {
    final recent = transactions.take(7).toList().reversed.toList();
    return List.generate(
      recent.length,
      (index) => FlSpot(index.toDouble(), _toAmount(recent[index])),
    );
  }

  Map<String, dynamic> get _flatStats {
    final flattened = <String, dynamic>{};

    void addValue(String key, dynamic value) {
      if (value == null) return;
      if (value is Map) {
        final nested = Map<String, dynamic>.from(value);
        nested.forEach(addValue);
        return;
      }
      if (value is Iterable) return;
      flattened[key] = value;
    }

    stats.forEach(addValue);
    return flattened;
  }

  List<MapEntry<String, dynamic>> get _topStatEntries {
    final source = _flatStats;
    final preferred = [
      "total_users",
      "verified_users",
      "total_transactions",
      "approved_transactions",
      "pending_transactions",
      "suspicious_actions",
      "kyc_pending",
      "balance",
      "total_balance",
      "sent",
      "received",
      "deposit",
      "withdraw",
    ];

    final selected = <MapEntry<String, dynamic>>[];
    for (final key in preferred) {
      if (source.containsKey(key)) {
        selected.add(MapEntry(key, source[key]));
      }
      if (selected.length == 6) break;
    }

    if (selected.length < 6) {
      for (final entry in source.entries) {
        if (selected.any((item) => item.key == entry.key)) continue;
        selected.add(entry);
        if (selected.length == 6) break;
      }
    }
    return selected;
  }

  String _labelize(String key) {
    return key
        .replaceAll("_", " ")
        .split(" ")
        .where((part) => part.isNotEmpty)
        .map((part) => "${part[0].toUpperCase()}${part.substring(1)}")
        .join(" ");
  }

  String _safeNumber(dynamic value) {
    if (value is num) {
      return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
    }
    if (value == null) return "0";
    if (value is Map || value is Iterable) return "-";
    return value.toString();
  }

  @override
  void initState() {
    super.initState();
    _loadBalancePreference();
    fetchData();
  }

  @override
  void dispose() {
    _dashboardPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      drawer: _sideDrawer(),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: fetchData,
                child: Stack(
                  children: [
                    Positioned(
                      top: -120,
                      right: -70,
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 240,
                      left: -100,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                      children: [
                        _topBar(),
                        const SizedBox(height: 12),
                        _topModulesMenu(),
                        if (!_canUseServices) ...[
                          const SizedBox(height: 12),
                          _inactiveAccountBanner(),
                        ],
                        const SizedBox(height: 16),
                        _mainCard(),
                        const SizedBox(height: 16),
                        _dashboardPagesSection(),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _topBar() {
    final name = profile["prenom"] ?? profile["nom"] ?? "utilisateur";
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.96),
            const Color(0xFFF4F8FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLanguage.t("Bonjour", "Ù…Ø±Ø­Ø¨Ø§"),
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  _topBarSubtitle(),
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _statusBadge(),
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  return _topIcon(
                    Icons.menu_rounded,
                    () => Scaffold.of(context).openDrawer(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topIcon(IconData icon, VoidCallback onTap, {bool selected = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE4EAFF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF123B9E),
            AppColors.primary,
            const Color(0xFF2E7BF6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLanguage.t(
                    "Centre de controle Fintech",
                    "Ù…Ø±ÙƒØ² Ø§Ù„ØªØ­ÙƒÙ… Ø§Ù„Ù…Ø§Ù„ÙŠ",
                  ),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _statusBadge(dark: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _headlineValue(),
                  style: const TextStyle(
                    color: Colors.white,
                      fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (_hasVisibleBalance)
                IconButton(
                  onPressed: _toggleBalanceVisibility,
                  tooltip: AppLanguage.t(
                    _hideBalance ? "Afficher le solde" : "Masquer le solde",
                    _hideBalance ? "إظهار الرصيد" : "إخفاء الرصيد",
                  ),
                  icon: Icon(
                    _hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          if (_hasVisibleBalance)
            Text(
              AppLanguage.t(
                _hideBalance ? "Solde masque" : "Solde disponible",
                _hideBalance ? "الرصيد مخفي" : "الرصيد المتاح",
              ),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.74),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            AppLanguage.t(
              "Rapports - Audit - Administration",
              "التقارير - التدقيق - الإدارة",
            ),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          if (_isClientRole) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.white.withValues(alpha: 0.18)),
            const SizedBox(height: 12),
            _summaryCards(),
            const SizedBox(height: 12),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: _quickActionButton(
                    label: AppLanguage.t("Recharge credit", "تعبئة رصيد"),
                    icon: Icons.phone_android_rounded,
                    onTap: () => _openQuickTransactionSheet("TOPUP"),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: _quickActionButton(
                    label: AppLanguage.t("Transfert", "ØªØ­ÙˆÙŠÙ„"),
                    icon: Icons.swap_horiz_rounded,
                    onTap: () => _openQuickTransactionSheet("TRANSFER"),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: _quickActionButton(
                    label: AppLanguage.t("Retrait", "Ø³Ø­Ø¨"),
                    icon: Icons.outbox_rounded,
                    onTap: () => _openQuickTransactionSheet("WITHDRAW"),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _quickActionButton(
                    label: AppLanguage.t("Mon QR", "Ø±Ù…Ø² QR Ø§Ù„Ø®Ø§Øµ Ø¨ÙŠ"),
                    icon: Icons.qr_code_2_rounded,
                    onTap: _showReceiveQrSheet,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _inactiveAccountBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF4DE),
            Color(0xFFFFF8EC),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF8D58B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.lock_clock_outlined,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Compte inactif",
                  style: TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Vous pouvez consulter l'application, mais les services financiers restent bloques jusqu'a la validation de votre identite par l'administrateur.",
            style: TextStyle(color: _muted, height: 1.45),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, "/kyc"),
            icon: const Icon(Icons.verified_outlined),
            label: Text(
              AppLanguage.t(
                "Completer la verification d'identite",
                "Ø¥ÙƒÙ…Ø§Ù„ Ø§Ù„ØªØ­Ù‚Ù‚ Ù…Ù† Ø§Ù„Ù‡ÙˆÙŠØ©",
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, "/messages"),
            icon: const Icon(Icons.forum_outlined),
            label: Text(
              AppLanguage.t(
                "Contacter l'administration",
                "Ù…Ø±Ø§Ø³Ù„Ø© Ø§Ù„Ø¥Ø¯Ø§Ø±Ø©",
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _headlineValue() {
    final flatStats = _flatStats;
    final balance =
        profile["balance"] ?? flatStats["balance"] ?? flatStats["solde"] ?? flatStats["total_balance"];
    if (_showFinancialBalance && balance != null) {
      if (_hideBalance) return "Ã¢â‚¬Â¢Ã¢â‚¬Â¢Ã¢â‚¬Â¢Ã¢â‚¬Â¢Ã¢â‚¬Â¢Ã¢â‚¬Â¢";
      return "$balance MRU";
    }
    if (role == "ADMIN") return AppLanguage.t("Administration", "Ø§Ù„Ø¥Ø¯Ø§Ø±Ø©");
    if (role == "AUDITEUR") return AppLanguage.t("Audit", "Ø§Ù„ØªØ¯Ù‚ÙŠÙ‚");
    if (role == "COMPTABLE") return AppLanguage.t("Comptabilite", "Ø§Ù„Ù…Ø­Ø§Ø³Ø¨Ø©");
    return AppLanguage.t("Compte client", "Ø­Ø³Ø§Ø¨ Ø¹Ù…ÙŠÙ„");
  }

  Widget _statusBadge({bool dark = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.16)
            : const Color(0xFFE3FAF3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.20)
              : const Color(0xFFA8EAD8),
        ),
      ),
      child: Text(
        _roleLabel(),
        style: TextStyle(
          color: dark ? Colors.white : AppColors.accent,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _roleDashboardItems() {
    if (role == "ADMIN") {
      return [
        {
          "title": AppLanguage.t("Utilisateurs", "Ø§Ù„Ù…Ø³ØªØ®Ø¯Ù…ÙˆÙ†"),
          "value": _intFromStats(["total_users"]).toString(),
          "subtitle": AppLanguage.t("Total comptes", "Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ø­Ø³Ø§Ø¨Ø§Øª"),
          "icon": Icons.groups_rounded,
          "color": AppColors.primary,
        },
        {
          "title": AppLanguage.t("Verifies", "Ø§Ù„Ù…ÙˆØ«Ù‚ÙˆÙ†"),
          "value": _intFromStats(["verified_users"]).toString(),
          "subtitle": AppLanguage.t("Comptes valides", "Ø­Ø³Ø§Ø¨Ø§Øª Ù…ÙˆØ«Ù‚Ø©"),
          "icon": Icons.verified_user_outlined,
          "color": AppColors.success,
        },
        {
          "title": AppLanguage.t("Identite en attente", "Ù‡ÙˆÙŠØ§Øª Ù‚ÙŠØ¯ Ø§Ù„Ø§Ù†ØªØ¸Ø§Ø±"),
          "value": _intFromStats(["kyc_pending"]).toString(),
          "subtitle": AppLanguage.t("Demandes a traiter", "Ø·Ù„Ø¨Ø§Øª ØªØ­ØªØ§Ø¬ Ø§Ù„Ù…Ø¹Ø§Ù„Ø¬Ø©"),
          "icon": Icons.badge_outlined,
          "color": AppColors.warning,
        },
        {
          "title": AppLanguage.t("Alertes suspectes", "ØªÙ†Ø¨ÙŠÙ‡Ø§Øª Ù…Ø´Ø¨ÙˆÙ‡Ø©"),
          "value": _intFromStats(["suspicious_actions"]).toString(),
          "subtitle": AppLanguage.t("Actions a surveiller", "Ø¹Ù…Ù„ÙŠØ§Øª Ù„Ù„Ù…Ø±Ø§Ù‚Ø¨Ø©"),
          "icon": Icons.warning_amber_rounded,
          "color": AppColors.danger,
        },
      ];
    }

    if (role == "AUDITEUR") {
      return [
        {
          "title": AppLanguage.t("Alertes actives", "Ø§Ù„ØªÙ†Ø¨ÙŠÙ‡Ø§Øª Ø§Ù„Ù†Ø´Ø·Ø©"),
          "value": _activeAlertsCount.toString(),
          "subtitle": AppLanguage.t("Centre de surveillance", "Ù…Ø±ÙƒØ² Ø§Ù„Ù…Ø±Ø§Ù‚Ø¨Ø©"),
          "icon": Icons.notifications_active_outlined,
          "color": AppColors.danger,
        },
        {
          "title": AppLanguage.t("Actions suspectes", "Ø§Ù„Ø¥Ø¬Ø±Ø§Ø¡Ø§Øª Ø§Ù„Ù…Ø´Ø¨ÙˆÙ‡Ø©"),
          "value": _intFromStats(["suspicious_actions"]).toString(),
          "subtitle": AppLanguage.t("Detection automatique", "ÙƒØ´Ù ØªÙ„Ù‚Ø§Ø¦ÙŠ"),
          "icon": Icons.visibility_outlined,
          "color": AppColors.warning,
        },
        {
          "title": AppLanguage.t("Operations rejetees", "Ø§Ù„Ø¹Ù…Ù„ÙŠØ§Øª Ø§Ù„Ù…Ø±ÙÙˆØ¶Ø©"),
          "value": _rejectedTransactions.toString(),
          "subtitle": AppLanguage.t("Cas a verifier", "Ø­Ø§Ù„Ø§Øª ÙŠØ¬Ø¨ ÙØ­ØµÙ‡Ø§"),
          "icon": Icons.rule_folder_outlined,
          "color": AppColors.primary,
        },
        {
          "title": AppLanguage.t("Score de confiance", "Ø¯Ø±Ø¬Ø© Ø§Ù„Ø«Ù‚Ø©"),
          "value": "${_trustScore.toStringAsFixed(0)}%",
          "subtitle": AppLanguage.t("Vue utilisateur globale", "Ù†Ø¸Ø±Ø© Ø¹Ø§Ù…Ø© Ø¹Ù„Ù‰ Ø§Ù„Ø«Ù‚Ø©"),
          "icon": Icons.shield_moon_outlined,
          "color": AppColors.accent,
        },
      ];
    }

    if (role == "COMPTABLE") {
      return [
        {
          "title": AppLanguage.t("Soumises", "Ø§Ù„Ù…Ù‚Ø¯Ù…Ø©"),
          "value": _submittedTransactionsCount.toString(),
          "subtitle": AppLanguage.t("En attente de revue", "ÙÙŠ Ø§Ù†ØªØ¸Ø§Ø± Ø§Ù„Ù…Ø±Ø§Ø¬Ø¹Ø©"),
          "icon": Icons.playlist_add_check_circle_outlined,
          "color": AppColors.warning,
        },
        {
          "title": AppLanguage.t("A transmettre", "Ù„Ù„Ø¥Ø­Ø§Ù„Ø©"),
          "value": _countStatuses(["ACCOUNTANT_APPROVED"]).toString(),
          "subtitle": AppLanguage.t("Vers administrateur", "Ø¥Ù„Ù‰ Ø§Ù„Ù…Ø¯ÙŠØ±"),
          "icon": Icons.forward_to_inbox_outlined,
          "color": AppColors.primary,
        },
        {
          "title": AppLanguage.t("Anomalies", "Ø§Ù„Ø´Ø¨Ù‡Ø§Øª"),
          "value": _anomalyTransactionsCount.toString(),
          "subtitle": AppLanguage.t("Operations sensibles", "Ø¹Ù…Ù„ÙŠØ§Øª Ø­Ø³Ø§Ø³Ø©"),
          "icon": Icons.gpp_maybe_outlined,
          "color": AppColors.danger,
        },
        {
          "title": AppLanguage.t("Score de confiance", "Ø¯Ø±Ø¬Ø© Ø§Ù„Ø«Ù‚Ø©"),
          "value": "${_trustScore.toStringAsFixed(0)}%",
          "subtitle": AppLanguage.t("Indice de conformite", "Ù…Ø¤Ø´Ø± Ø§Ù„Ø§Ù…ØªØ«Ø§Ù„"),
          "icon": Icons.fact_check_outlined,
          "color": AppColors.success,
        },
      ];
    }

    return [
      {
        "title": AppLanguage.t("Score de confiance", "Ø¯Ø±Ø¬Ø© Ø§Ù„Ø«Ù‚Ø©"),
        "value": "${_trustScore.toStringAsFixed(0)}%",
        "subtitle": AppLanguage.t("Base sur verification et alertes", "Ù…Ø¨Ù†ÙŠ Ø¹Ù„Ù‰ Ø§Ù„ØªØ­Ù‚Ù‚ ÙˆØ§Ù„ØªÙ†Ø¨ÙŠÙ‡Ø§Øª"),
        "icon": Icons.verified_outlined,
        "color": _trustScore >= 70 ? AppColors.success : AppColors.warning,
      },
      {
        "title": AppLanguage.t("Transactions valides", "Ø§Ù„Ù…Ø¹Ø§Ù…Ù„Ø§Øª Ø§Ù„Ù…Ù‚Ø¨ÙˆÙ„Ø©"),
        "value": _approvedTransactions.toString(),
        "subtitle": AppLanguage.t("Operations reussies", "Ø§Ù„Ø¹Ù…Ù„ÙŠØ§Øª Ø§Ù„Ù†Ø§Ø¬Ø­Ø©"),
        "icon": Icons.task_alt_outlined,
        "color": AppColors.primary,
      },
      {
        "title": AppLanguage.t("En attente", "Ù‚ÙŠØ¯ Ø§Ù„Ø§Ù†ØªØ¸Ø§Ø±"),
        "value": _pendingTransactions.toString(),
        "subtitle": AppLanguage.t("Demandes en cours", "Ø·Ù„Ø¨Ø§Øª Ø¬Ø§Ø±ÙŠØ©"),
        "icon": Icons.timelapse_outlined,
        "color": AppColors.warning,
      },
      {
        "title": AppLanguage.t("Alertes", "Ø§Ù„ØªÙ†Ø¨ÙŠÙ‡Ø§Øª"),
        "value": _activeAlertsCount.toString(),
        "subtitle": AppLanguage.t("Points a surveiller", "Ù†Ù‚Ø§Ø· ØªØ³ØªØ­Ù‚ Ø§Ù„Ø§Ù†ØªØ¨Ø§Ù‡"),
        "icon": Icons.notification_important_outlined,
        "color": AppColors.danger,
      },
    ];
  }

  Widget _roleDashboardPanel() {
    final items = _roleDashboardItems();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLanguage.t("Tableau de bord  ", ""),
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                final Color color = item["color"] as Color;

                return Container(
                  width: 136,
                  padding: const EdgeInsets.fromLTRB(11, 10, 11, 9),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _line.withValues(alpha: 0.8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item["icon"] as IconData, color: color),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item["title"].toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item["value"].toString(),
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item["subtitle"].toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 9,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _complianceItems() {
    if (role == "ADMIN") {
      return [
        {
          "title": AppLanguage.t("Demandes d'identite", "Ø·Ù„Ø¨Ø§Øª Ø§Ù„ØªØ­Ù‚Ù‚ Ù…Ù† Ø§Ù„Ù‡ÙˆÙŠØ©"),
          "value": _intFromStats(["kyc_pending"]).toString(),
        },
        {
          "title": AppLanguage.t("Alertes suspectes", "Ø§Ù„ØªÙ†Ø¨ÙŠÙ‡Ø§Øª Ø§Ù„Ù…Ø´Ø¨ÙˆÙ‡Ø©"),
          "value": _intFromStats(["suspicious_actions"]).toString(),
        },
        {
          "title": AppLanguage.t("Dossiers verifies", "Ø§Ù„Ù…Ù„ÙØ§Øª Ø§Ù„Ù…ÙˆØ«Ù‚Ø©"),
          "value": _intFromStats(["verified_users"]).toString(),
        },
      ];
    }

    if (role == "AUDITEUR") {
      return [
        {
          "title": AppLanguage.t("Alertes detectees", "Ø§Ù„ØªÙ†Ø¨ÙŠÙ‡Ø§Øª Ø§Ù„Ù…ÙƒØªØ´ÙØ©"),
          "value": _activeAlertsCount.toString(),
        },
        {
          "title": AppLanguage.t("Operations a controler", "Ø¹Ù…Ù„ÙŠØ§Øª ØªØ­ØªØ§Ø¬ Ø±Ù‚Ø§Ø¨Ø©"),
          "value": _anomalyTransactionsCount.toString(),
        },
        {
          "title": AppLanguage.t("Rejets analyses", "Ø§Ù„Ø¹Ù…Ù„ÙŠØ§Øª Ø§Ù„Ù…Ø±ÙÙˆØ¶Ø©"),
          "value": _rejectedTransactions.toString(),
        },
      ];
    }

    if (role == "COMPTABLE") {
      return [
        {
          "title": AppLanguage.t("Niveau 1 a valider", "Ø§Ù„Ù…Ø±Ø­Ù„Ø© Ø§Ù„Ø£ÙˆÙ„Ù‰ Ù„Ù„Ù…ØµØ§Ø¯Ù‚Ø©"),
          "value": _countStatuses(["SUBMITTED"]).toString(),
        },
        {
          "title": AppLanguage.t("A envoyer a l'admin", "Ù„Ø¥Ø­Ø§Ù„ØªÙ‡Ø§ Ø¥Ù„Ù‰ Ø§Ù„Ø¥Ø¯Ø§Ø±Ø©"),
          "value": _countStatuses(["ACCOUNTANT_APPROVED"]).toString(),
        },
        {
          "title": AppLanguage.t("Anomalies a verifier", "Ø´Ø¨Ù‡Ø§Øª ØªØªØ·Ù„Ø¨ ÙØ­ØµÙ‹Ø§"),
          "value": _anomalyTransactionsCount.toString(),
        },
      ];
    }

    return [
      {
        "title": AppLanguage.t("Statut du compte", "Ø­Ø§Ù„Ø© Ø§Ù„Ø­Ø³Ø§Ø¨"),
        "value": _canUseServices
            ? AppLanguage.t("Actif", "Ù†Ø´Ø·")
            : AppLanguage.t("Inactif", "ØºÙŠØ± Ù†Ø´Ø·"),
      },
      {
        "title": AppLanguage.t("Verification d'identite", "Ø§Ù„ØªØ­Ù‚Ù‚ Ù…Ù† Ø§Ù„Ù‡ÙˆÙŠØ©"),
        "value": _isVerifiedProfile
            ? AppLanguage.t("Validee", "Ù…Ù‚Ø¨ÙˆÙ„")
            : AppLanguage.t("En attente", "Ù‚ÙŠØ¯ Ø§Ù„Ø§Ù†ØªØ¸Ø§Ø±"),
      },
      {
        "title": AppLanguage.t("Score de confiance", "Ø¯Ø±Ø¬Ø© Ø§Ù„Ø«Ù‚Ø©"),
        "value": "${_trustScore.toStringAsFixed(0)}%",
      },
    ];
  }

  Widget _complianceCenterCard() {
    final items = _complianceItems();
    final goodStatus = _trustScore >= 70 && (_canUseServices || role != "CLIENT");

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (goodStatus ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  goodStatus ? Icons.verified_user_outlined : Icons.policy_outlined,
                  color: goodStatus ? AppColors.success : AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLanguage.t(
                        "Centre d'alertes et de conformite",
                        "Ù…Ø±ÙƒØ² Ø§Ù„ØªÙ†Ø¨ÙŠÙ‡Ø§Øª ÙˆØ§Ù„Ø§Ù…ØªØ«Ø§Ù„",
                      ),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLanguage.t(
                        "Resume des points de vigilance et des controles prioritaires.",
                        "Ù…Ù„Ø®Øµ Ù†Ù‚Ø§Ø· Ø§Ù„Ø§Ù†ØªØ¨Ø§Ù‡ ÙˆØ¹Ù†Ø§ØµØ± Ø§Ù„Ø±Ù‚Ø§Ø¨Ø© Ø°Ø§Øª Ø§Ù„Ø£ÙˆÙ„ÙˆÙŠØ©.",
                      ),
                      style: const TextStyle(color: _muted, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (goodStatus ? AppColors.success : AppColors.warning)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (goodStatus ? AppColors.success : AppColors.warning)
                    .withValues(alpha: 0.28),
              ),
            ),
            child: Text(
              goodStatus
                  ? AppLanguage.t(
                      "Le niveau global de confiance est satisfaisant et les controles restent stables.",
                      "Ù…Ø³ØªÙˆÙ‰ Ø§Ù„Ø«Ù‚Ø© Ø§Ù„Ø¹Ø§Ù… Ø¬ÙŠØ¯ Ø­Ø§Ù„ÙŠÙ‹Ø§ ÙˆØ§Ù„Ø±Ù‚Ø§Ø¨Ø© Ù…Ø³ØªÙ‚Ø±Ø©.",
                    )
                  : AppLanguage.t(
                      "Des points de vigilance necessitent encore un suivi avant une conformite complete.",
                      "Ù‡Ù†Ø§Ùƒ Ù†Ù‚Ø§Ø· ØªØ­ØªØ§Ø¬ Ù…ØªØ§Ø¨Ø¹Ø© Ø¥Ø¶Ø§ÙÙŠØ© Ù‚Ø¨Ù„ Ø§Ù„ÙˆØµÙˆÙ„ Ø¥Ù„Ù‰ Ø§Ù…ØªØ«Ø§Ù„ ÙƒØ§Ù…Ù„.",
                    ),
              style: const TextStyle(color: _ink, height: 1.45),
            ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _line.withValues(alpha: 0.75)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item["title"]!,
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item["value"]!,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w900,
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

  Widget _advancedStatsPanel() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _insightCard(
                AppLanguage.t("Taux d'approbation", "Ù…Ø¹Ø¯Ù„ Ø§Ù„Ù‚Ø¨ÙˆÙ„"),
                "${_approvalRate.toStringAsFixed(1)}%",
                AppLanguage.t("Base sur les transactions deja chargees.", "Ø¨Ù†Ø§Ø¡Ù‹ Ø¹Ù„Ù‰ Ø§Ù„Ù…Ø¹Ø§Ù…Ù„Ø§Øª Ø§Ù„Ù…Ø­Ù…Ù„Ø© Ø³Ø§Ø¨Ù‚Ù‹Ø§."),
                Icons.verified_outlined,
                AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _insightCard(
                AppLanguage.t("Score de confiance", "درجة الثقة"),
                "${_trustScore.toStringAsFixed(0)}%",
                AppLanguage.t("Calcule selon la verification, les alertes et l'etat du compte.", "يُحسب حسب التحقق والتنبيهات وحالة الحساب."),
                Icons.shield_outlined,
                _trustScore >= 70 ? AppColors.primary : AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _insightCard(
                AppLanguage.t("En attente", "Ù‚ÙŠØ¯ Ø§Ù„Ø§Ù†ØªØ¸Ø§Ø±"),
                _pendingTransactions.toString(),
                AppLanguage.t("Transactions en cours de traitement.", "Ù…Ø¹Ø§Ù…Ù„Ø§Øª Ù…Ø§ Ø²Ø§Ù„Øª Ù‚ÙŠØ¯ Ø§Ù„Ù…Ø¹Ø§Ù„Ø¬Ø©."),
                Icons.pending_actions_outlined,
                AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _insightCard(
                AppLanguage.t("Rejetees", "Ù…Ø±ÙÙˆØ¶Ø©"),
                _rejectedTransactions.toString(),
                AppLanguage.t("Operations annulees ou refusees.", "Ø¹Ù…Ù„ÙŠØ§Øª Ù…Ù„ØºØ§Ø© Ø£Ùˆ Ù…Ø±ÙÙˆØ¶Ø©."),
                Icons.gpp_bad_outlined,
                AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _trendCard(),
        const SizedBox(height: 12),
        _statsBreakdownCard(),
      ],
    );
  }

  Widget _insightCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontSize: 10.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendCard() {
    final spots = _transactionSpots;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Tendance des transactions",
            style: TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLanguage.t("Visualisation locale des montants recents.", "Ø¹Ø±Ø¶ Ù…Ø­Ù„ÙŠ Ù„Ù„Ù…Ø¨Ø§Ù„Øº Ø§Ù„Ø£Ø®ÙŠØ±Ø©."),
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: spots.isEmpty
                ? Center(
                    child: Text(
                      AppLanguage.t("Aucune donnee recente", "Ù„Ø§ ØªÙˆØ¬Ø¯ Ø¨ÙŠØ§Ù†Ø§Øª Ø­Ø¯ÙŠØ«Ø©"),
                      style: const TextStyle(color: _muted),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 3,
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primary.withValues(alpha: 0.12),
                          ),
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statsBreakdownCard() {
    final entries = _topStatEntries;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLanguage.t("Statistiques avancees", "Ø¥Ø­ØµØ§Ø¡Ø§Øª Ù…ØªÙ‚Ø¯Ù…Ø©"),
            style: TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            role == "ADMIN" || role == "AUDITEUR" || role == "COMPTABLE"
                ? AppLanguage.t("Indicateurs cles pour l'administration, la finance, la verification d'identite et l'audit.", "Ù…Ø¤Ø´Ø±Ø§Øª Ø£Ø³Ø§Ø³ÙŠØ© Ù„Ù„Ø¥Ø¯Ø§Ø±Ø© ÙˆØ§Ù„Ù…Ø§Ù„ÙŠØ© ÙˆØ§Ù„ØªØ­Ù‚Ù‚ Ù…Ù† Ø§Ù„Ù‡ÙˆÙŠØ© ÙˆØ§Ù„ØªØ¯Ù‚ÙŠÙ‚.")
                : AppLanguage.t("Resume rapide des statistiques disponibles sur votre tableau de bord.", "Ù…Ù„Ø®Øµ Ø³Ø±ÙŠØ¹ Ù„Ù„Ø¥Ø­ØµØ§Ø¡Ø§Øª Ø§Ù„Ù…ØªØ§Ø­Ø© ÙÙŠ Ù„ÙˆØ­Ø© Ø§Ù„ØªØ­ÙƒÙ…."),
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text(
              AppLanguage.t("Aucune statistique detaillee", "Ù„Ø§ ØªÙˆØ¬Ø¯ Ø¥Ø­ØµØ§Ø¡Ø§Øª Ù…ÙØµÙ„Ø©"),
              style: const TextStyle(color: _muted),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLanguage.t("Glissez horizontalement pour voir plus d'indicateurs", "Ø§Ø³Ø­Ø¨ Ø£ÙÙ‚ÙŠÙ‹Ø§ Ù„Ø¹Ø±Ø¶ Ø§Ù„Ù…Ø²ÙŠØ¯ Ù…Ù† Ø§Ù„Ù…Ø¤Ø´Ø±Ø§Øª"),
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 124,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: entries.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Container(
                        width: 172,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.panel,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _line.withValues(alpha: 0.8),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _labelize(entry.key),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _safeNumber(entry.value),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _sideDrawer() {
    return Drawer(
      backgroundColor: _bg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.primary,
                    Color(0xFF2E7BF6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.account_circle_outlined,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    (profile["prenom"] ?? profile["nom"] ?? "Utilisateur").toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _topBarSubtitle(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.notifications_none),
              title: Text(AppLanguage.t("Notifications", "Ø§Ù„Ø¥Ø´Ø¹Ø§Ø±Ø§Øª")),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/notifications");
              },
            ),
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: Text(AppLanguage.t("Messagerie", "المراسلات")),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/messages");
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(AppLanguage.t("Profil", "Ø§Ù„Ù…Ù„Ù Ø§Ù„Ø´Ø®ØµÙŠ")),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/profile");
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(AppLanguage.t("A propos", "Ø­ÙˆÙ„ Ø§Ù„ØªØ·Ø¨ÙŠÙ‚")),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/about");
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_mail_outlined),
              title: Text(AppLanguage.t("Contact", "Ø§ØªØµÙ„ Ø¨Ù†Ø§")),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/contact");
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(AppLanguage.t("Transactions", "Ø§Ù„Ù…Ø¹Ø§Ù…Ù„Ø§Øª")),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, "/transactions");
              },
            ),
            if (role == "CLIENT")
              ListTile(
                leading: const Icon(Icons.verified_outlined),
                title: Text(
                  AppLanguage.t("Verification d'identite", "Ø§Ù„ØªØ­Ù‚Ù‚ Ù…Ù† Ø§Ù„Ù‡ÙˆÙŠØ©"),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, "/kyc");
                },
              ),
            if (role == "ADMIN")
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(AppLanguage.t("Gestion des utilisateurs", "Ø¥Ø¯Ø§Ø±Ø© Ø§Ù„Ù…Ø³ØªØ®Ø¯Ù…ÙŠÙ†")),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, "/admin/users");
                },
              ),
            if (role == "ADMIN")
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: Text(
                  AppLanguage.t(
                    "Verification d'identite",
                    "Ø§Ù„ØªØ­Ù‚Ù‚ Ù…Ù† Ø§Ù„Ù‡ÙˆÙŠØ©",
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, "/admin/kyc-review");
                },
              ),
            if (role == "ADMIN" || role == "AUDITEUR" || role == "COMPTABLE")
              ListTile(
                leading: const Icon(Icons.insights_outlined),
                title: Text(AppLanguage.t("Rapports", "Ø§Ù„ØªÙ‚Ø§Ø±ÙŠØ±")),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, "/reports");
                },
              ),
            if (role == "ADMIN" || role == "AUDITEUR")
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(AppLanguage.t("Audit et journaux", "Ø§Ù„ØªØ¯Ù‚ÙŠÙ‚ ÙˆØ§Ù„Ø³Ø¬Ù„Ø§Øª")),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, "/audit");
                },
              ),
            if (role == "ADMIN" || role == "AUDITEUR")
              ListTile(
                leading: const Icon(Icons.security_outlined),
                title: Text(AppLanguage.t("Centre de securite", "Ù…Ø±ÙƒØ² Ø§Ù„Ø£Ù…Ø§Ù†")),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, "/security");
                },
              ),
            ValueListenableBuilder<String>(
              valueListenable: AppLanguage.notifier,
              builder: (context, language, _) {
                return ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(AppLanguage.t("Langue", "Ø§Ù„Ù„ØºØ©")),
                  trailing: Text(
                    language == "ar" ? "AR" : "FR",
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  onTap: AppLanguage.toggle,
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(AppLanguage.t("Deconnexion", "ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø®Ø±ÙˆØ¬")),
              onTap: () async {
                Navigator.pop(context);
                await logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCards() {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            Icons.arrow_upward,
            AppLanguage.t("Total envoye", "Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…Ø±Ø³Ù„"),
            _summaryAmountValue(_totalSentApproved),
            const Color(0xFFFFE4EA),
            AppColors.danger,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            Icons.arrow_downward,
            AppLanguage.t("Total recu", "Ø¥Ø¬Ù…Ø§Ù„ÙŠ Ø§Ù„Ù…Ø³ØªÙ„Ù…"),
            _summaryAmountValue(_totalReceivedApproved),
            const Color(0xFFE2F6F3),
            AppColors.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            Icons.receipt_long,
            AppLanguage.t("Transactions", "Ø§Ù„Ù…Ø¹Ø§Ù…Ù„Ø§Øª"),
            _firstValue(["transactions", "total_transactions", "transaction_count"]),
            const Color(0xFFE8EFFF),
            AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
    IconData icon,
    String label,
    String value,
    Color bg,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 11,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value == "0" ? "0 MRU" : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String action, VoidCallback? onAction) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
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
          color: Colors.white.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _line),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long, color: _muted, size: 46),
            SizedBox(height: 10),
            Text(AppLanguage.t("Aucune transaction recente", "Ù„Ø§ ØªÙˆØ¬Ø¯ Ù…Ø¹Ø§Ù…Ù„Ø§Øª Ø­Ø¯ÙŠØ«Ø©"), style: TextStyle(color: _muted)),
          ],
        ),
      );
    }

    return Column(
      children: transactions.take(4).map((item) {
        final type = item["type"]?.toString() ?? "Transaction";
        final amount = item["montant"] ?? item["amount"] ?? "-";
        final status = item["status"]?.toString() ?? "";
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.swap_horiz, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _transactionTypeLabel(type),
                      style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _transactionStatusLabel(status),
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "$amount MRU",
                style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _dashboardPagesSection() {
    final pages = <Widget>[
      SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: _roleDashboardPanel(),
      ),
      SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: _complianceCenterCard(),
      ),
      SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: _advancedStatsPanel(),
      ),
      SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _sectionHeader(
              AppLanguage.t("Transactions recentes", "المعاملات الأخيرة"),
              AppLanguage.t("Voir tout", "عرض الكل"),
              () => Navigator.pushNamed(context, "/transactions"),
            ),
            const SizedBox(height: 10),
            _recentTransactions(),
          ],
        ),
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 520,
          child: PageView.builder(
            controller: _dashboardPageController,
            itemCount: pages.length,
            onPageChanged: (index) {
              if (!mounted) return;
              setState(() => _dashboardPageIndex = index);
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: pages[index],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(pages.length, (index) {
            final isActive = _dashboardPageIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _topModulesMenu() {
    final modules = <_Module>[
      _Module(AppLanguage.t("Accueil", "Ø§Ù„Ø±Ø¦ÙŠØ³ÙŠØ©"), Icons.home, AppColors.primary, () {}),
      _Module(
        AppLanguage.t("Transactions", "Ø§Ù„Ù…Ø¹Ø§Ù…Ù„Ø§Øª"),
        Icons.swap_horiz,
        AppColors.primary,
        () => Navigator.pushNamed(context, "/transactions"),
        enabled: !_isInactiveClient,
      ),
      if (role == "ADMIN")
        _Module(
          AppLanguage.t("Administration", "Ø§Ù„Ø¥Ø¯Ø§Ø±Ø©"),
          Icons.admin_panel_settings,
          AppColors.primary,
          () => Navigator.pushNamed(context, "/admin/users"),
        ),
      if (role == "ADMIN" || role == "AUDITEUR")
        _Module(
          AppLanguage.t("Audit", "Ø§Ù„ØªØ¯Ù‚ÙŠÙ‚"),
          Icons.receipt_long,
          AppColors.danger,
          () => Navigator.pushNamed(context, "/audit"),
        ),
      if (role == "ADMIN" || role == "COMPTABLE" || role == "AUDITEUR")
        _Module(
          AppLanguage.t("Rapports", "Ø§Ù„ØªÙ‚Ø§Ø±ÙŠØ±"),
          Icons.insights,
          AppColors.success,
          () => Navigator.pushNamed(context, "/reports"),
        ),
      _Module(
        AppLanguage.t("Messagerie", "المراسلات"),
        Icons.forum_outlined,
        AppColors.primary,
        () => Navigator.pushNamed(context, "/messages"),
      ),
      _Module(
        AppLanguage.t("Notifications", "Ø§Ù„Ø¥Ø´Ø¹Ø§Ø±Ø§Øª"),
        Icons.notifications_active,
        AppColors.primary,
        () => Navigator.pushNamed(context, "/notifications"),
      ),
      _Module(
        AppLanguage.t("Profil", "Ø§Ù„Ù…Ù„Ù Ø§Ù„Ø´Ø®ØµÙŠ"),
        Icons.person,
        AppColors.accent,
        () => Navigator.pushNamed(context, "/profile"),
      ),
      _Module(
        AppLanguage.t("A propos", "Ø­ÙˆÙ„ Ø§Ù„ØªØ·Ø¨ÙŠÙ‚"),
        Icons.info_outline,
        AppColors.success,
        () => Navigator.pushNamed(context, "/about"),
      ),
      _Module(
        AppLanguage.t("Contact", "Ø§ØªØµÙ„ Ø¨Ù†Ø§"),
        Icons.contact_mail_outlined,
        AppColors.primary,
        () => Navigator.pushNamed(context, "/contact"),
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLanguage.t("Acces rapide", "ÙˆØµÙˆÙ„ Ø³Ø±ÙŠØ¹"),
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 102,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: modules.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final module = modules[index];
                final enabled = module.enabled;
                final requiresActiveAccount = _moduleRequiresActiveAccount(module.label);
                return InkWell(
                  onTap: enabled
                      ? module.onTap
                      : (requiresActiveAccount ? _showInactiveAccountMessage : null),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 118,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: enabled
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: enabled ? _line : _muted.withValues(alpha: 0.22),
                      ),
                      boxShadow: enabled
                          ? [
                              BoxShadow(
                                color: module.color.withValues(alpha: 0.10),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: module.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            module.icon,
                            color: enabled ? module.color : _muted,
                          ),
                        ),
                          const SizedBox(height: 6),
                        Expanded(
                          child: Center(
                            child: Text(
                              module.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: enabled ? _ink : _muted,
                                fontWeight: FontWeight.w900,
                                fontSize: 10.2,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ),
                        if (!enabled && requiresActiveAccount) ...[
                          const SizedBox(height: 2),
                          Text(
                            AppLanguage.t("Inactif", "ØºÙŠØ± Ù†Ø´Ø·"),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.danger.withValues(alpha: 0.82),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertsList() {
    if (alerts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _line),
        ),
        child: Text(
          AppLanguage.t("Aucune alerte detectee", "Ù„Ø§ ØªÙˆØ¬Ø¯ ØªÙ†Ø¨ÙŠÙ‡Ø§Øª Ù…ÙƒØªØ´ÙØ©"),
          style: const TextStyle(color: _muted),
        ),
      );
    }

    return Column(
      children: alerts.map((alert) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEEF1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFCBD5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  alert.toString(),
                  style: const TextStyle(
                    color: _ink,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _firstValue(List<String> keys) {
    final source = _flatStats;
    for (final key in keys) {
      final value = source[key];
      if (value != null) return value.toString();
    }
    return "0";
  }

  String _summaryAmountValue(double value) {
    if (value == value.roundToDouble()) {
      return "${value.toInt()} MRU";
    }
    return "${value.toStringAsFixed(2)} MRU";
  }

  String _transactionStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case "APPROVED":
        return AppLanguage.t("Approuvee", "Ù…Ù‚Ø¨ÙˆÙ„Ø©");
      case "REJECTED":
        return AppLanguage.t("Rejetee", "Ù…Ø±ÙÙˆØ¶Ø©");
      case "PENDING":
        return AppLanguage.t("En attente", "Ù‚ÙŠØ¯ Ø§Ù„Ø§Ù†ØªØ¸Ø§Ø±");
      case "FAILED":
        return AppLanguage.t("Echouee", "ÙØ´Ù„Øª");
      case "CANCELED":
        return AppLanguage.t("Annulee", "Ù…Ù„ØºØ§Ø©");
      case "SUCCESS":
        return AppLanguage.t("Reussie", "Ù†Ø§Ø¬Ø­Ø©");
      default:
        return status.isEmpty ? "-" : status;
    }
  }

  String _transactionTypeLabel(String type) {
    switch (type.toUpperCase()) {
      case "DEPOSIT":
        return AppLanguage.t("Depot", "Ø¥ÙŠØ¯Ø§Ø¹");
      case "WITHDRAW":
        return AppLanguage.t("Retrait", "Ø³Ø­Ø¨");
      case "TRANSFER":
        return AppLanguage.t("Transfert", "ØªØ­ÙˆÙŠÙ„");
      case "TOPUP":
        return AppLanguage.t("Recharge credit", "تعبئة رصيد");
      default:
        return type.isEmpty ? AppLanguage.t("Transaction", "Ù…Ø¹Ø§Ù…Ù„Ø©") : type;
    }
  }

  String _topBarSubtitle() {
    if (role == "ADMIN") {
      return AppLanguage.t(
        "",
        "",
      );
    }
    if (role == "AUDITEUR") {
      return AppLanguage.t(
        "",
        "",
      );
    }
    if (role == "COMPTABLE") {
      return AppLanguage.t(
        "",
        "",
      );
    }
    return _canUseServices
        ? AppLanguage.t(
            "Accedez rapidement a vos operations et a votre espace client.",
            "ÙŠÙ…ÙƒÙ†Ùƒ Ø§Ù„ÙˆØµÙˆÙ„ Ø¨Ø³Ø±Ø¹Ø© Ø¥Ù„Ù‰ Ø¹Ù…Ù„ÙŠØ§ØªÙƒ ÙˆÙ…Ø³Ø§Ø­ØªÙƒ Ø§Ù„Ø´Ø®ØµÙŠØ©."
          )
        : AppLanguage.t(
            "Votre compte reste consultatif jusqu'a validation de votre identite.",
            "ÙŠØ¨Ù‚Ù‰ Ø­Ø³Ø§Ø¨Ùƒ ÙÙŠ ÙˆØ¶Ø¹ Ø§Ù„Ø§Ø³ØªØ¹Ø±Ø§Ø¶ Ø­ØªÙ‰ ÙŠØªÙ… Ø§Ù„ØªØ­Ù‚Ù‚ Ù…Ù† Ù‡ÙˆÙŠØªÙƒ.",
          );
  }

  String _mainCardDescription() {
    if (role == "ADMIN") {
      return AppLanguage.t("Vue unifiee des utilisateurs, des transactions, du reporting et du controle de l'identite.", "Ø¹Ø±Ø¶ Ù…ÙˆØ­Ù‘Ø¯ Ù„Ù„Ù…Ø³ØªØ®Ø¯Ù…ÙŠÙ† ÙˆØ§Ù„Ù…Ø¹Ø§Ù…Ù„Ø§Øª ÙˆØ§Ù„ØªÙ‚Ø§Ø±ÙŠØ± ÙˆØ§Ù„ØªØ­ÙƒÙ… ÙÙŠ Ø§Ù„Ù‡ÙˆÙŠØ©.");
    }
    if (role == "AUDITEUR") {
      return AppLanguage.t("Acces centralise aux alertes, journaux d'audit et indicateurs de risque.", "ÙˆØµÙˆÙ„ Ù…Ø±ÙƒØ²ÙŠ Ø¥Ù„Ù‰ Ø§Ù„ØªÙ†Ø¨ÙŠÙ‡Ø§Øª ÙˆØ³Ø¬Ù„Ø§Øª Ø§Ù„ØªØ¯Ù‚ÙŠÙ‚ ÙˆÙ…Ø¤Ø´Ø±Ø§Øª Ø§Ù„Ù…Ø®Ø§Ø·Ø±.");
    }
    if (role == "COMPTABLE") {
      return AppLanguage.t("Suivez les flux financiers, les validations et les operations sensibles.", "ØªØ§Ø¨Ø¹ Ø§Ù„ØªØ¯ÙÙ‚Ø§Øª Ø§Ù„Ù…Ø§Ù„ÙŠØ© ÙˆØ¹Ù…Ù„ÙŠØ§Øª Ø§Ù„Ù…ØµØ§Ø¯Ù‚Ø© ÙˆØ§Ù„Ø¹Ù…Ù„ÙŠØ§Øª Ø§Ù„Ø­Ø³Ø§Ø³Ø©.");
    }
    return _canUseServices
        ? AppLanguage.t("Suivez votre activite, vos mouvements et l'etat de votre compte depuis un espace unique.", "ØªØ§Ø¨Ø¹ Ù†Ø´Ø§Ø·Ùƒ ÙˆØ­Ø±ÙƒØ§ØªÙƒ ÙˆØ­Ø§Ù„Ø© Ø­Ø³Ø§Ø¨Ùƒ Ù…Ù† Ù…Ø³Ø§Ø­Ø© ÙˆØ§Ø­Ø¯Ø©.")
        : AppLanguage.t("Explorez l'application pendant que votre dossier d'identite est en cours de verification.", "ØªØµÙØ­ Ø§Ù„ØªØ·Ø¨ÙŠÙ‚ Ø¨ÙŠÙ†Ù…Ø§ Ù…Ù„Ù Ù‡ÙˆÙŠØªÙƒ Ù‚ÙŠØ¯ Ø§Ù„ØªØ­Ù‚Ù‚.");
  }

  String _roleLabel() {
    switch (role) {
      case "ADMIN":
        return AppLanguage.t("Administrateur", "Ù…Ø¯ÙŠØ± Ø§Ù„Ù†Ø¸Ø§Ù…");
      case "AUDITEUR":
        return AppLanguage.t("Auditeur", "Ù…Ø¯Ù‚Ù‚");
      case "COMPTABLE":
        return AppLanguage.t("Comptable", "Ù…Ø­Ø§Ø³Ø¨");
      case "CLIENT":
        return AppLanguage.t(_canUseServices ? "Client actif" : "Client inactif", _canUseServices ? "Ø¹Ù…ÙŠÙ„ Ù†Ø´Ø·" : "Ø¹Ù…ÙŠÙ„ ØºÙŠØ± Ù†Ø´Ø·");
      default:
        return AppLanguage.t("Actif", "Ù†Ø´Ø·");
    }
  }
}

class _Module {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _Module(this.label, this.icon, this.color, this.onTap, {this.enabled = true});
}





