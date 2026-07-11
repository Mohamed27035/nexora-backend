import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/config/app_config.dart';
import '../core/localization/app_language.dart';
import '../core/theme/app_theme.dart';
import '../services/dashboard_service.dart';
import '../services/secure_storage_service.dart';
import '../services/transaction_service.dart';
import '../utils/dio_error_utils.dart';
import '../widgets/transfer_receipt_dialog.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final montantController = TextEditingController();
  final noteController = TextEditingController();
  final receiverPhoneController = TextEditingController();
  final searchController = TextEditingController();

  List transactions = [];
  List beneficiaries = [];
  bool loading = true;
  bool creating = false;
  String type = "DEPOSIT";
  String topupProvider = "MAURITEL";
  int selectedTopupAmount = 10;
  String statusFilter = "ALL";
  String typeFilter = "ALL";
  String directionFilter = "ALL";
  String sortFilter = "newest";
  String role = "";
  bool canUseServices = true;

  static const List<int> _topupAmounts = [10, 50, 100, 200, 300, 500, 1000, 2000];

  String tr(String fr, String ar) => AppLanguage.t(fr, ar);

  bool get _isInactiveClient => role == "CLIENT" && !canUseServices;

  bool get _isClientRole => role == "CLIENT";

  bool get _canCreateFinancialTransactions => _isClientRole && canUseServices;

  String _providerLabel(String provider) {
    switch (provider.toUpperCase()) {
      case "MAURITEL":
        return "Mauritel";
      case "MATTEL":
        return "Mattel";
      case "CHINGUITEL":
        return "Chinguitel";
      default:
        return provider;
    }
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

  Future<void> _scanReceiverQr() async {
    bool handled = false;

    final scannedPhone = await showModalBottomSheet<String>(
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
              Text(
                AppLanguage.t("Scanner le QR du destinataire", "امسح رمز QR الخاص بالمستفيد"),
                style: TextStyle(
                  color: AppColors.text,
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLanguage.t("Fermer", "إغلاق")),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (scannedPhone == null || scannedPhone.isEmpty || !mounted) return;
    setState(() {
      receiverPhoneController.text = scannedPhone;
      type = "TRANSFER";
    });
    _showMessage(
      AppLanguage.t(
        "Numero du destinataire rempli depuis le QR.",
        "تم ملء رقم المستفيد من رمز QR.",
      ),
    );
  }

  Future<void> fetchTransactions() async {
    try {
      final storedRole = await SecureStorageService.getRole();
      final profileResponse = await DashboardService.getProfile();
      final selectedType = typeFilter == "TRANSFER_SENT" || typeFilter == "TRANSFER_RECEIVED"
          ? "TRANSFER"
          : typeFilter;
      final selectedDirection = typeFilter == "TRANSFER_SENT"
          ? "SENT"
          : typeFilter == "TRANSFER_RECEIVED"
              ? "RECEIVED"
              : directionFilter;
      final response = await TransactionService.getTransactions(
        search: searchController.text,
        status: statusFilter,
        type: selectedType,
        direction: selectedDirection,
        sort: sortFilter,
      );
      final beneficiaryResponse = storedRole == "CLIENT"
          ? await TransactionService.getBeneficiaries()
          : null;
      if (!mounted) return;
      setState(() {
        role = storedRole;
        canUseServices = profileResponse.data["can_use_services"] != false;
        transactions = response.data is List ? response.data : [];
        beneficiaries = beneficiaryResponse?.data is List ? beneficiaryResponse!.data : [];
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _showMessage(_friendlyError(e));
    }
  }

  Future<void> reviewTransaction(int id, bool approve) async {
    final note = await _reviewNoteDialog(approve: approve);
    if (note == null) return;

    try {
      if (approve) {
        await TransactionService.approveTransaction(id, note: note);
      } else {
        await TransactionService.rejectTransaction(id, note: note);
      }
      await fetchTransactions();
      if (!mounted) return;
      _showMessage(approve ? "Transaction approuvee." : "Transaction rejetee.");
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e));
    }
  }

  Future<String?> _reviewNoteDialog({required bool approve}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: Text(
          approve ? tr("Note d'approbation", "ملاحظة الموافقة") : tr("Motif du rejet", "سبب الرفض"),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: approve ? tr("Note optionnelle", "ملاحظة اختيارية") : tr("Motif optionnel", "سبب اختياري"),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr("Annuler", "إلغاء")),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(approve ? tr("Approuver", "موافقة") : tr("Rejeter", "رفض")),
          ),
        ],
      ),
    );
  }

  Future<void> createTransaction() async {
    if (!_canCreateFinancialTransactions) {
      _showMessage(tr("Les operations financieres sont reservees aux comptes client.", "العمليات المالية مخصصة لحسابات العملاء فقط."));
      return;
    }

    final amount = type == "TOPUP"
        ? selectedTopupAmount.toDouble()
        : double.tryParse(montantController.text.replaceAll(",", "."));
    if (amount == null || amount <= 0) {
      _showMessage(tr("Montant invalide.", "المبلغ غير صالح."));
      return;
    }

    final receiverPhone = _normalizePhone(receiverPhoneController.text);

    if (type == "TRANSFER" && !_isValidPhone(receiverPhone)) {
      _showMessage(
        "Le numero du destinataire est invalide. Il doit contenir 8 chiffres et commencer par 2, 3 ou 4.",
      );
      return;
    }

    if (type == "TOPUP" && !_isValidTopupPhone(topupProvider, receiverPhone)) {
      _showMessage(
        tr(
          "Numero de recharge invalide. Il doit contenir 8 chiffres. Mauritel commence par 4, Mattel par 3 et Chinguitel par 2.",
          "رقم التعبئة غير صالح. يجب أن يتكون من 8 أرقام. موريتل يبدأ بـ 4، وماتل بـ 3، وشنقيتل بـ 2.",
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: Text(
          tr("Confirmer", "تأكيد"),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: Text(
          type == "TRANSFER"
              ? "Creer un transfert de $amount MRU vers $receiverPhone ?"
              : type == "TOPUP"
                  ? tr(
                      "Creer une recharge credit ${_providerLabel(topupProvider)} de $amount MRU pour le numero $receiverPhone ?",
                      "إنشاء تعبئة رصيد ${_providerLabel(topupProvider)} بمبلغ $amount MRU للرقم $receiverPhone؟",
                    )
                  : "Creer une transaction ${_typeLabel(type)} de $amount MRU ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr("Annuler", "إلغاء")),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr("Confirmer", "تأكيد")),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => creating = true);

    try {
      final response = await TransactionService.createTransaction(
        montant: amount,
        type: type,
        receiverPhone: type == "TRANSFER" ? receiverPhone : null,
        serviceProvider: type == "TOPUP" ? topupProvider : null,
        servicePhone: type == "TOPUP" ? receiverPhone : null,
        note: noteController.text.trim(),
      );

      final transaction = response.data is Map
          ? Map<String, dynamic>.from(response.data['transaction'] ?? const {})
          : <String, dynamic>{};

      montantController.clear();
      noteController.clear();
      receiverPhoneController.clear();
      await fetchTransactions();

      if (!mounted) return;
      if (type == "TRANSFER" && transaction.isNotEmpty) {
        await showTransferReceiptDialog(
          context,
          tr: tr,
          transaction: transaction,
        );
      } else if (type == "TOPUP") {
        _showMessage(
          tr(
            "Recharge effectuee avec succes.",
            "تم تنفيذ التعبئة بنجاح.",
          ),
        );
      } else {
        _showMessage(tr("Transaction creee.", "تم إنشاء المعاملة."));
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => creating = false);
      }
    }
  }

  Future<void> _saveCurrentBeneficiary() async {
    final phone = _normalizePhone(receiverPhoneController.text);
    if (!_isValidPhone(phone)) {
      _showMessage(
        tr(
          "Entrez un numero valide avant de l'ajouter aux favoris.",
          "أدخل رقماً صحيحاً قبل إضافته إلى المفضلة.",
        ),
      );
      return;
    }

    try {
      await TransactionService.addBeneficiary(beneficiaryPhone: phone);
      await fetchTransactions();
      if (!mounted) return;
      _showMessage(tr("Beneficiaire ajoute.", "تمت إضافة المستفيد."));
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e));
    }
  }

  Future<void> _deleteBeneficiary(int beneficiaryId) async {
    try {
      await TransactionService.deleteBeneficiary(beneficiaryId);
      await fetchTransactions();
      if (!mounted) return;
      _showMessage(tr("Beneficiaire supprime.", "تم حذف المستفيد."));
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e));
    }
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      return DioErrorUtils.friendlyMessage(error);
    }
    return tr("Une erreur est survenue.", "حدث خطأ غير متوقع.");
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    fetchTransactions();
  }

  @override
  void dispose() {
    montantController.dispose();
    noteController.dispose();
    receiverPhoneController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr("Transactions", "المعاملات"))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFF7FAFF),
                    Color(0xFFF5FAF8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: RefreshIndicator(
                onRefresh: fetchTransactions,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    _heroCard(),
                    const SizedBox(height: 18),
                    if (_isInactiveClient) ...[
                      _inactiveAccountBanner(),
                      const SizedBox(height: 18),
                    ],
                    _formCard(),
                    const SizedBox(height: 18),
                    _filtersCard(),
                    const SizedBox(height: 18),
                    _listSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr("Espace des transactions", "فضاء المعاملات"),
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr("Creez, suivez et revisez les operations financieres depuis une interface plus claire.", "أنشئ المعاملات وتابعها وراجعها من خلال واجهة أوضح."),
            style: TextStyle(color: Colors.white, height: 1.6),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _heroStat(tr("Total", "الإجمالي"), transactions.length.toString()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _heroStat(
                  tr("En attente", "قيد الانتظار"),
                  transactions
                      .where(
                        (item) => {
                          "PENDING",
                          "SUBMITTED",
                          "ACCOUNTANT_APPROVED",
                        }.contains((item["status"] ?? "").toString().toUpperCase()),
                      )
                      .length
                      .toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _heroStat(
                  tr("Approuvees", "مقبولة"),
                  transactions
                      .where((item) => (item["status"] ?? "").toString().toUpperCase() == "APPROVED")
                      .length
                      .toString(),
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
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _formCard() {
    if (!_canCreateFinancialTransactions) {
      return _cardShell(
        title: tr("Operations financieres", "العمليات المالية"),
        subtitle: tr("Cet espace reste consultatif pour les roles administratifs.", "هذه المساحة للعرض فقط بالنسبة للأدوار الإدارية."),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            tr(
              "Les roles Administrateur, Comptable et Auditeur peuvent consulter les transactions, mais ne peuvent ni transferer, ni retirer, ni recevoir des fonds.",
              "يمكن لأدوار المدير والمحاسب والمدقق الاطلاع على المعاملات، لكنها لا تستطيع التحويل أو السحب أو استقبال الأموال.",
            ),
            style: TextStyle(color: AppColors.muted, height: 1.6),
          ),
        ),
      );
    }

    return _cardShell(
        title: tr("Nouvelle operation", "عملية جديدة"),
        subtitle: tr("Remplissez les informations de la transaction.", "املأ معلومات المعاملة."),
        child: Column(
          children: [
          TextField(
            enabled: !_isInactiveClient,
            controller: montantController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDecoration(tr("Montant", "المبلغ"), Icons.payments_outlined),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: _inputDecoration(tr("Type", "النوع"), Icons.tune_outlined),
            items: [
              DropdownMenuItem(value: "DEPOSIT", child: Text(tr("Depot", "إيداع"))),
              DropdownMenuItem(value: "WITHDRAW", child: Text(tr("Retrait", "سحب"))),
              DropdownMenuItem(value: "TRANSFER", child: Text(tr("Transfert", "تحويل"))),
            ],
            onChanged: _isInactiveClient
                ? null
                : (value) => setState(() {
                    type = value ?? type;
                    if (type != "TRANSFER") {
                      receiverPhoneController.clear();
                    }
                  }),
          ),
          if (type == "TRANSFER") ...[
            const SizedBox(height: 14),
            TextField(
              enabled: !_isInactiveClient,
              controller: receiverPhoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration(
                tr("Telephone du destinataire", "هاتف المستفيد"),
                Icons.call_outlined,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _isInactiveClient ? null : _scanReceiverQr,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text(tr("Scanner un QR", "مسح رمز QR")),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _isInactiveClient ? null : _saveCurrentBeneficiary,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(tr("Ajouter aux favoris", "إضافة إلى المفضلة")),
              ),
            ),
            if (beneficiaries.isNotEmpty) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tr("Beneficiaires favoris", "المستفيدون المفضلون"),
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 78,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final beneficiary = beneficiaries[index] as Map;
                    final nickname = beneficiary["nickname"]?.toString().trim();
                    final phone = beneficiary["beneficiary_phone"]?.toString() ??
                        beneficiary["beneficiary"]?["telephone"]?.toString() ??
                        "";
                    final displayName = nickname != null && nickname.isNotEmpty
                        ? nickname
                        : beneficiary["beneficiary_name"]?.toString() ??
                            beneficiary["beneficiary"]?["full_name"]?.toString() ??
                            phone;
                    final beneficiaryId = beneficiary["id"] as int?;

                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        setState(() {
                          receiverPhoneController.text = phone;
                        });
                      },
                      child: Container(
                        width: 160,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.panel,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.surfaceSoft),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    phone,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (beneficiaryId != null)
                              IconButton(
                                tooltip: tr("Supprimer", "حذف"),
                                onPressed: () => _deleteBeneficiary(beneficiaryId),
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemCount: beneficiaries.length,
                ),
              ),
            ],
          ],
          const SizedBox(height: 14),
          TextField(
            enabled: !_isInactiveClient,
            controller: noteController,
            maxLines: 3,
            decoration: _inputDecoration(tr("Note", "ملاحظة"), Icons.edit_note_outlined),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: creating || _isInactiveClient ? null : createTransaction,
              child: creating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    )
                  : Text(_isInactiveClient
                      ? tr("Compte inactif", "حساب غير نشط")
                  : tr("Creer la transaction", "إنشاء المعاملة")),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              tr("Les operations de retrait et de transfert necessitent un compte avec identite verifiee.", "عمليات السحب والتحويل تتطلب حسابًا بهوية موثقة."),
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inactiveAccountBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr("Compte inactif", "حساب غير نشط"),
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          SizedBox(height: 8),
          Text(
            tr("Les services financiers restent bloques tant que votre verification d'identite n'a pas ete approuvee par l'administrateur.", "تظل الخدمات المالية معطلة إلى أن يوافق المسؤول على التحقق من هويتك."),
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _filtersCard() {
    return _cardShell(
      title: tr("Filtres et recherche", "الفلاتر والبحث"),
      subtitle: tr("Affinez la liste des operations.", "خصص قائمة العمليات."),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: _inputDecoration(
              tr("Recherche par ID, nom, telephone, email ou note", "ابحث بالمعرف أو الاسم أو الهاتف أو البريد أو الملاحظة"),
              Icons.search,
            ),
            onSubmitted: (_) => fetchTransactions(),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 430;
              if (stacked) {
                return Column(
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: typeFilter,
                      decoration: _inputDecoration("Type", Icons.filter_alt_outlined),
                      items: [
                        DropdownMenuItem(value: "ALL", child: Text(tr("Tous", "الكل"))),
                        DropdownMenuItem(value: "DEPOSIT", child: Text(tr("Depot", "إيداع"))),
                        DropdownMenuItem(value: "WITHDRAW", child: Text(tr("Retrait", "سحب"))),
                        DropdownMenuItem(value: "TRANSFER", child: Text(tr("Tous les transferts", "كل التحويلات"))),
                        DropdownMenuItem(value: "TOPUP", child: Text(tr("Recharges", "التعبئات"))),
                        DropdownMenuItem(value: "TRANSFER_SENT", child: Text(tr("Transferts envoyes", "التحويلات المرسلة"))),
                        DropdownMenuItem(value: "TRANSFER_RECEIVED", child: Text(tr("Transferts recus", "التحويلات المستلمة"))),
                      ],
                      onChanged: (value) => setState(() => typeFilter = value ?? "ALL"),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: statusFilter,
                      decoration: _inputDecoration(tr("Statut", "الحالة"), Icons.flag_outlined),
                      items: [
                        DropdownMenuItem(value: "ALL", child: Text(tr("Tous", "الكل"))),
                        DropdownMenuItem(value: "PENDING", child: Text(tr("En attente", "قيد الانتظار"))),
                        DropdownMenuItem(value: "SUBMITTED", child: Text(tr("Soumise", "تم الإرسال"))),
                        DropdownMenuItem(value: "ACCOUNTANT_APPROVED", child: Text(tr("Validee par comptable", "مراجعة المحاسب"))),
                        DropdownMenuItem(value: "APPROVED", child: Text(tr("Approuvee", "مقبولة"))),
                        DropdownMenuItem(value: "REJECTED", child: Text(tr("Rejetee", "مرفوضة"))),
                      ],
                      onChanged: (value) =>
                          setState(() => statusFilter = value ?? "ALL"),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: typeFilter,
                      decoration: _inputDecoration("Type", Icons.filter_alt_outlined),
                      items: [
                        DropdownMenuItem(value: "ALL", child: Text(tr("Tous", "الكل"))),
                        DropdownMenuItem(value: "DEPOSIT", child: Text(tr("Depot", "إيداع"))),
                        DropdownMenuItem(value: "WITHDRAW", child: Text(tr("Retrait", "سحب"))),
                        DropdownMenuItem(value: "TRANSFER", child: Text(tr("Tous les transferts", "كل التحويلات"))),
                        DropdownMenuItem(value: "TOPUP", child: Text(tr("Recharges", "التعبئات"))),
                        DropdownMenuItem(value: "TRANSFER_SENT", child: Text(tr("Transferts envoyes", "التحويلات المرسلة"))),
                        DropdownMenuItem(value: "TRANSFER_RECEIVED", child: Text(tr("Transferts recus", "التحويلات المستلمة"))),
                      ],
                      onChanged: (value) => setState(() => typeFilter = value ?? "ALL"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: statusFilter,
                      decoration: _inputDecoration(tr("Statut", "الحالة"), Icons.flag_outlined),
                      items: [
                        DropdownMenuItem(value: "ALL", child: Text(tr("Tous", "الكل"))),
                        DropdownMenuItem(value: "PENDING", child: Text(tr("En attente", "قيد الانتظار"))),
                        DropdownMenuItem(value: "SUBMITTED", child: Text(tr("Soumise", "تم الإرسال"))),
                        DropdownMenuItem(value: "ACCOUNTANT_APPROVED", child: Text(tr("Validee par comptable", "مراجعة المحاسب"))),
                        DropdownMenuItem(value: "APPROVED", child: Text(tr("Approuvee", "مقبولة"))),
                        DropdownMenuItem(value: "REJECTED", child: Text(tr("Rejetee", "مرفوضة"))),
                      ],
                      onChanged: (value) =>
                          setState(() => statusFilter = value ?? "ALL"),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: sortFilter,
            decoration: _inputDecoration(tr("Tri", "الترتيب"), Icons.swap_vert_outlined),
            items: [
              DropdownMenuItem(value: "newest", child: Text(tr("Plus recentes", "الأحدث"))),
              DropdownMenuItem(value: "oldest", child: Text(tr("Plus anciennes", "الأقدم"))),
              DropdownMenuItem(value: "amount_desc", child: Text(tr("Montant decroissant", "المبلغ تنازليًا"))),
              DropdownMenuItem(value: "amount_asc", child: Text(tr("Montant croissant", "المبلغ تصاعديًا"))),
            ],
            onChanged: (value) => setState(() => sortFilter = value ?? "newest"),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: fetchTransactions,
              icon: const Icon(Icons.filter_alt_outlined),
              label: Text(tr("Appliquer les filtres", "تطبيق الفلاتر")),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listSection() {
    if (transactions.isEmpty) {
      return _cardShell(
        title: tr("Liste des transactions", "قائمة المعاملات"),
        subtitle: tr("Aucune operation disponible pour le moment.", "لا توجد عمليات متاحة حاليًا."),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: Text(
              tr("Aucune transaction.", "لا توجد معاملات."),
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            tr("Liste des transactions", "قائمة المعاملات"),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                ),
          ),
        ),
        const SizedBox(height: 14),
        ...transactions.map((item) => _transactionCard(item)).toList(),
      ],
    );
  }

  Widget _transactionCard(dynamic transaction) {
    final id = transaction["id"] as int?;
    final status = transaction["status"]?.toString() ?? "";
    final reviewStage = transaction["review_stage"]?.toString() ?? "";
    final canAccountantReview = id != null &&
        status == "SUBMITTED" &&
        role == "COMPTABLE";
    final canAdminReview = id != null &&
        status == "ACCOUNTANT_APPROVED" &&
        role == "ADMIN";
    final canReview = canAccountantReview || canAdminReview;
    final canSendAccountantNote = id != null && role == 'COMPTABLE';
    final createdAt = _formatDateTime(transaction["created_at"]);
    final updatedAt = _formatDateTime(transaction["updated_at"]);
    final note = _normalizeDescription(transaction["note"]);
    final validationNote = _normalizeDescription(transaction["validation_note"]);
    final accountantNote =
        _normalizeDescription(transaction["accountant_validation_note"]);
    final riskScore = _normalizeRiskScore(transaction["risk_score"]);
    final anomalyDetected = transaction["anomaly_detected"] == true;
    final anomalyReason = _normalizeDescription(transaction["anomaly_reason"]);
    final receiptReference =
        transaction["receipt_reference"]?.toString().trim() ?? "";

    final proof = transaction["proof_url"]?.toString() ??
        transaction["proof"]?.toString() ??
        "";
    final proofUrl = proof.isEmpty
        ? null
        : (proof.startsWith("http") ? proof : "${AppConfig.apiBaseUrl}$proof");

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Transaction #${transaction["id"] ?? "-"}",
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _miniInfo(tr("Type", "النوع"), _typeLabel(transaction["type"]?.toString() ?? "")),
              _miniInfo(tr("Montant", "المبلغ"), "${transaction["montant"] ?? "-"} MRU"),
            ],
          ),
          const SizedBox(height: 14),
          _detailLine(
            "Expediteur",
            transaction["sender_display"] ??
                transaction["sender_full_name"] ??
                transaction["sender_name"] ??
                transaction["sender_email"],
          ),
          _detailLine(
            AppLanguage.t("Telephone expediteur", "هاتف المرسل"),
            transaction["sender_phone"],
          ),
          _detailLine(
            tr("Destinataire", "المستفيد"),
            transaction["receiver_display"] ??
                transaction["receiver_full_name"] ??
                transaction["receiver_name"] ??
                transaction["receiver_email"],
          ),
          if ((transaction["type"]?.toString().toUpperCase() ?? "") == "TOPUP")
            _detailLine(
              tr("Operateur", "الشبكة"),
              _providerLabel(transaction["service_provider"]?.toString() ?? ""),
            ),
          if ((transaction["type"]?.toString().toUpperCase() ?? "") == "TOPUP")
            _detailLine(
              tr("Numero recharge", "رقم التعبئة"),
              transaction["service_phone"],
            ),
          _detailLine(
            tr("Etape de traitement", "مرحلة المعالجة"),
            _reviewStageLabel(reviewStage),
          ),
          if (riskScore != null)
            _detailLine(
              tr("Score de risque", "درجة الخطر"),
              "${riskScore.toStringAsFixed(0)}%",
            ),
          if (anomalyDetected)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr("Alerte d'anomalie", "تنبيه شبهة"),
                    style: TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    anomalyReason == "-" ? tr("Operation consideree comme sensible ou inhabituelle.", "تم اعتبار العملية حساسة أو غير اعتيادية.") : anomalyReason,
                    style: TextStyle(color: AppColors.text, height: 1.45),
                  ),
                ],
              ),
            ),
          _detailLine(tr("Creee le", "أُنشئت في"), createdAt),
          _detailLine(tr("Mise a jour", "آخر تحديث"), updatedAt),
          _detailLine(tr("Note", "ملاحظة"), note),
          _detailLine(
            "Validee par",
            transaction["validated_by_full_name"] ??
                transaction["validated_by_name"],
          ),
          _detailLine(
            tr("Revisee par le comptable", "راجعها المحاسب"),
            transaction["accountant_validated_by_full_name"] ??
                transaction["accountant_validated_by_name"],
          ),
          _detailLine(
            tr("Note du comptable", "ملاحظة المحاسب"),
            accountantNote,
          ),
          _detailLine(tr("Note de validation", "ملاحظة المراجعة"), validationNote),
          if (receiptReference.isNotEmpty)
            _detailLine(
              tr("Reference du recu", "مرجع الوصل"),
              receiptReference,
            ),
          if (proofUrl != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _showProof(proofUrl),
              icon: const Icon(Icons.image_outlined),
              label: Text(tr("Voir la preuve", "عرض الإثبات")),
            ),
          ],
          if (canReview) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => reviewTransaction(id, true),
                    child: Text(
                      canAccountantReview
                          ? tr("Valider et transmettre", "اعتماد وإحالة")
                          : tr("Approuver definitivement", "موافقة نهائية"),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => reviewTransaction(id, false),
                    child: Text(tr("Rejeter", "رفض")),
                  ),
                ),
              ],
            ),
          ],
          if (canSendAccountantNote) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                "/messages",
                arguments: {
                  "recipientRole": "ADMIN",
                  "category": "TRANSACTION",
                  "transactionId": id,
                  "subject": "Observation comptable - transaction #$id",
                  "body": tr(
                    "Je souhaite signaler cette operation a l'administration.",
                    "أرغب في إرسال ملاحظة محاسبية إلى الإدارة بخصوص هذه العملية.",
                  ),
                },
              ),
              icon: const Icon(Icons.sticky_note_2_outlined),
              label: Text(
                tr("Envoyer une note a l'administration", "إرسال ملاحظة إلى الإدارة"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniInfo(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _detailLine(String label, dynamic value) {
    final text = value?.toString().trim() ?? "";
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: "$label : ",
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
            TextSpan(
              text: text.isEmpty ? "-" : text,
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

  String _formatDateTime(dynamic raw) {
    final text = raw?.toString().trim() ?? "";
    if (text.isEmpty) return "-";

    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;

    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, "0");

    return "${two(local.day)}/${two(local.month)}/${local.year} - ${two(local.hour)}:${two(local.minute)}";
  }

  String _normalizeDescription(dynamic raw) {
    final text = raw?.toString().trim() ?? "";
    if (text.isEmpty) return "-";

    return text
        .replaceAll(";", "; ")
        .replaceAll(RegExp(r"\s+"), " ")
        .trim();
  }

  double? _normalizeRiskScore(dynamic raw) {
    if (raw == null) return null;
    final value = double.tryParse(raw.toString());
    if (value == null) return null;
    if (value <= 1) return value * 100;
    return value;
  }

  String _reviewStageLabel(String stage) {
    switch (stage.toUpperCase()) {
      case "SUBMITTED":
        return tr("Soumise", "تم الإرسال");
      case "ACCOUNTANT_REVIEW":
        return tr("En revue comptable", "قيد مراجعة المحاسب");
      case "ADMIN_REVIEW":
        return tr("En revue administrateur", "قيد مراجعة المدير");
      case "FINALIZED":
        return tr("Finalisee", "مكتملة");
      case "REJECTED":
        return tr("Rejetee", "مرفوضة");
      case "AUTO":
        return tr("Validation automatique", "اعتماد تلقائي");
      default:
        return stage.isEmpty ? "-" : stage;
    }
  }

  Widget _cardShell({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.surfaceSoft),
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
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  void _showProof(String proofUrl) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          color: Colors.black,
          padding: const EdgeInsets.all(10),
          child: InteractiveViewer(
            child: Image.network(
              proofUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, _, __) => Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  tr("Impossible de charger l'image", "تعذر تحميل الصورة"),
                  style: TextStyle(color: Colors.white),
                ),
              ),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case "APPROVED":
        return AppColors.success;
      case "ACCOUNTANT_APPROVED":
        return const Color(0xFF0F766E);
      case "SUBMITTED":
        return const Color(0xFF2563EB);
      case "REJECTED":
        return AppColors.danger;
      case "FAILED":
      case "CANCELED":
        return AppColors.danger;
      case "PENDING":
      default:
        return AppColors.warning;
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case "APPROVED":
        return tr("Approuvee", "مقبولة");
      case "ACCOUNTANT_APPROVED":
        return tr("Validee par comptable", "مراجعة المحاسب");
      case "SUBMITTED":
        return tr("Soumise", "تم الإرسال");
      case "REJECTED":
        return tr("Rejetee", "مرفوضة");
      case "PENDING":
        return tr("En attente", "قيد الانتظار");
      case "FAILED":
        return tr("Echouee", "فاشلة");
      case "CANCELED":
        return tr("Annulee", "ملغاة");
      case "SUCCESS":
        return tr("Reussie", "ناجحة");
      default:
        return status.isEmpty ? "-" : status;
    }
  }

  String _typeLabel(String type) {
    switch (type.toUpperCase()) {
      case "DEPOSIT":
        return tr("Depot", "إيداع");
      case "WITHDRAW":
        return tr("Retrait", "سحب");
      case "TRANSFER":
        return tr("Transfert", "تحويل");
      case "TOPUP":
        return tr("Recharge credit", "تعبئة رصيد");
      default:
        return type.isEmpty ? "-" : type;
    }
  }

  InputDecoration _inputDecoration(String hint, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.muted),
      suffixIcon: suffixIcon,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }
}











