import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/localization/app_language.dart';
import '../core/theme/app_theme.dart';
import '../services/notification_service.dart';
import '../services/user_management_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic> _currentUser = {};

  bool _loading = true;
  bool _sending = false;
  bool _unreadOnly = false;

  String _mailbox = "all";
  String _category = "GENERAL";
  String? _errorMessage;
  int? _selectedRecipientId;
  bool _routeArgsApplied = false;
  int? _linkedTransactionId;
  int? _preferredRecipientId;
  String? _preferredRecipientRole;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeArgsApplied) return;
    _routeArgsApplied = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return;

    final data = Map<String, dynamic>.from(args as Map);
    _preferredRecipientId = _toInt(data["recipientId"]);
    _preferredRecipientRole = data["recipientRole"]?.toString().toUpperCase();
    _linkedTransactionId = _toInt(data["transactionId"]);

    final category = data["category"]?.toString().trim() ?? "";
    if (category.isNotEmpty) {
      _category = category.toUpperCase();
    }

    final subject = data["subject"]?.toString().trim() ?? "";
    if (subject.isNotEmpty) {
      _subjectController.text = subject;
    }

    final body = data["body"]?.toString().trim() ?? "";
    if (body.isNotEmpty) {
      _bodyController.text = body;
    }

    if (_contacts.isNotEmpty) {
      _selectedRecipientId = _resolveSelectedRecipient(_contacts);
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait([
        UserManagementService.getCurrentUser(),
        NotificationService.getMessageContacts(),
        NotificationService.getMessages(
          mailbox: _mailbox,
          unreadOnly: _unreadOnly,
        ),
      ]);

      final currentUser = _normalizeMap(results[0].data);
      final contacts = _normalizeList(results[1].data);
      final messages = _normalizeList(results[2].data);

      if (!mounted) return;

      setState(() {
        _currentUser = currentUser;
        _contacts = contacts;
        _messages = messages;
        _selectedRecipientId = _resolveSelectedRecipient(contacts);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = AppLanguage.t(
          "Impossible de charger la messagerie interne.",
          "ØªØ¹Ø°Ø± ØªØ­Ù…ÙŠÙ„ Ø§Ù„Ù…Ø±Ø§Ø³Ù„Ø§Øª Ø§Ù„Ø¯Ø§Ø®Ù„ÙŠØ©.",
        );
      });
    }
  }

  int? _resolveSelectedRecipient(List<Map<String, dynamic>> contacts) {
    if (_preferredRecipientId != null &&
        contacts.any((item) => _userId(item) == _preferredRecipientId)) {
      return _preferredRecipientId;
    }
    if (_selectedRecipientId != null &&
        contacts.any((item) => _userId(item) == _selectedRecipientId)) {
      return _selectedRecipientId;
    }
    if ((_preferredRecipientRole ?? "").isNotEmpty) {
      for (final item in contacts) {
        final role = (item["role"]?.toString() ?? "").toUpperCase();
        if (role == _preferredRecipientRole) {
          return _userId(item);
        }
      }
    }
    if (contacts.isEmpty) return null;
    return _userId(contacts.first);
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? "");
  }

  Map<String, dynamic> _normalizeMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _normalizeList(dynamic data) {
    final items = <dynamic>[];
    if (data is List) {
      items.addAll(data);
    } else if (data is Map && data["results"] is List) {
      items.addAll(data["results"] as List);
    } else if (data is Map && data["messages"] is List) {
      items.addAll(data["messages"] as List);
    } else if (data is Map && data["contacts"] is List) {
      items.addAll(data["contacts"] as List);
    } else if (data is Map && data["data"] is List) {
      items.addAll(data["data"] as List);
    }

    return items.map((item) => _normalizeMap(item)).where((item) => item.isNotEmpty).toList();
  }

  String get _role {
    return (_currentUser["role"]?.toString() ?? "").toUpperCase();
  }

  bool get _isAdmin => _role == "ADMIN";
  bool get _isAuditor => _role == "AUDITEUR";
  bool get _isAccountant => _role == "COMPTABLE";
  bool get _isClient => _role == "CLIENT";

  String _screenTitle() {
    if (_isAdmin) {
      return AppLanguage.t("Messagerie interne", "Ø§Ù„Ù…Ø±Ø§Ø³Ù„Ø§Øª Ø§Ù„Ø¯Ø§Ø®Ù„ÙŠØ©");
    }
    if (_isAuditor) {
      return AppLanguage.t("Alertes d'audit", "ØªÙ†Ø¨ÙŠÙ‡Ø§Øª Ø§Ù„ØªØ¯Ù‚ÙŠÙ‚");
    }
    if (_isAccountant) {
      return AppLanguage.t("Notes comptables", "Ù…Ù„Ø§Ø­Ø¸Ø§Øª Ø§Ù„Ù…Ø­Ø§Ø³Ø¨");
    }
    return AppLanguage.t("Contacter l'administration", "Ù…Ø±Ø§Ø³Ù„Ø© Ø§Ù„Ø¥Ø¯Ø§Ø±Ø©");
  }

  String _screenSubtitle() {
    if (_isAdmin) {
      return AppLanguage.t(
        "Echangez avec les clients, auditeurs et comptables depuis un espace unique.",
        "ØªØ¨Ø§Ø¯Ù„ Ø§Ù„Ø±Ø³Ø§Ø¦Ù„ Ù…Ø¹ Ø§Ù„Ø¹Ù…Ù„Ø§Ø¡ ÙˆØ§Ù„Ù…Ø¯Ù‚Ù‚ÙŠÙ† ÙˆØ§Ù„Ù…Ø­Ø§Ø³Ø¨ÙŠÙ† Ù…Ù† Ù…Ø³Ø§Ø­Ø© Ù…ÙˆØ­Ø¯Ø©.",
      );
    }
    if (_isAuditor) {
      return AppLanguage.t(
        "Envoyez vos alertes et observations a l'administration.",
        "Ø£Ø±Ø³Ù„ ØªÙ†Ø¨ÙŠÙ‡Ø§ØªÙƒ ÙˆÙ…Ù„Ø§Ø­Ø¸Ø§ØªÙƒ Ø¥Ù„Ù‰ Ø§Ù„Ø¥Ø¯Ø§Ø±Ø©.",
      );
    }
    if (_isAccountant) {
      return AppLanguage.t(
        "Partagez vos observations sur les operations avec l'administration.",
        "Ø´Ø§Ø±Ùƒ Ù…Ù„Ø§Ø­Ø¸Ø§ØªÙƒ Ø­ÙˆÙ„ Ø§Ù„Ø¹Ù…Ù„ÙŠØ§Øª Ù…Ø¹ Ø§Ù„Ø¥Ø¯Ø§Ø±Ø©.",
      );
    }
    return AppLanguage.t(
      "Posez vos questions a l'administration meme si votre compte est restreint.",
      "Ø§Ø·Ø±Ø­ Ø§Ø³ØªÙØ³Ø§Ø±Ø§ØªÙƒ Ø¹Ù„Ù‰ Ø§Ù„Ø¥Ø¯Ø§Ø±Ø© Ø­ØªÙ‰ Ø¥Ø°Ø§ ÙƒØ§Ù† Ø­Ø³Ø§Ø¨Ùƒ Ù…Ù‚ÙŠÙ‘Ø¯Ù‹Ø§.",
    );
  }

  String _categoryLabel(String value) {
    switch (value.toUpperCase()) {
      case "SUPPORT":
        return AppLanguage.t("Support", "Ø¯Ø¹Ù…");
      case "TRANSACTION":
        return AppLanguage.t("Transaction", "Ù…Ø¹Ø§Ù…Ù„Ø©");
      case "ALERT":
        return AppLanguage.t("Alerte", "ØªÙ†Ø¨ÙŠÙ‡");
      case "AUDIT":
        return AppLanguage.t("Audit", "ØªØ¯Ù‚ÙŠÙ‚");
      default:
        return AppLanguage.t("General", "Ø¹Ø§Ù…");
    }
  }

  String _mailboxLabel(String value) {
    switch (value) {
      case "inbox":
        return AppLanguage.t("Recus", "Ø§Ù„ÙˆØ§Ø±Ø¯Ø©");
      case "sent":
        return AppLanguage.t("Envoyes", "Ø§Ù„Ù…Ø±Ø³Ù„Ø©");
      default:
        return AppLanguage.t("Tous", "Ø§Ù„ÙƒÙ„");
    }
  }

  String _stringValue(Map<String, dynamic> item, List<String> keys, String fallback) {
    for (final key in keys) {
      final raw = item[key];
      final value = _repairText(raw?.toString() ?? "").trim();
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  int _userId(Map<String, dynamic> item) {
    final raw = item["id"] ?? item["recipient_id"] ?? item["sender_id"];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "") ?? 0;
  }

  String _contactName(Map<String, dynamic> item) {
    return _stringValue(
      item,
      ["full_name", "nom_complet", "nom", "name", "username"],
      AppLanguage.t("Utilisateur", "Ù…Ø³ØªØ®Ø¯Ù…"),
    );
  }

  String _contactRole(Map<String, dynamic> item) {
    final role = item["role_label"]?.toString().trim();
    if (role != null && role.isNotEmpty) return _repairText(role);

    switch ((item["role"]?.toString() ?? "").toUpperCase()) {
      case "ADMIN":
        return AppLanguage.t("Administrateur", "Ø§Ù„Ø¥Ø¯Ø§Ø±Ø©");
      case "AUDITEUR":
        return AppLanguage.t("Auditeur", "Ø§Ù„Ù…Ø¯Ù‚Ù‚");
      case "COMPTABLE":
        return AppLanguage.t("Comptable", "Ø§Ù„Ù…Ø­Ø§Ø³Ø¨");
      default:
        return AppLanguage.t("Client", "Ø§Ù„Ø¹Ù…ÙŠÙ„");
    }
  }

  bool _isOwnMessage(Map<String, dynamic> item) {
    final currentId = _userId(_currentUser);
    final senderRaw = item["sender_id"] ?? item["sender"];
    if (senderRaw is int) return senderRaw == currentId;
    return int.tryParse(senderRaw?.toString() ?? "") == currentId;
  }

  Future<void> _sendMessage() async {
    final recipientId = _selectedRecipientId;
    final body = _bodyController.text.trim();
    final subject = _subjectController.text.trim();

    if (recipientId == null) {
      _showSnack(
        AppLanguage.t("Choisissez un destinataire.", "Ø§Ø®ØªØ± Ø§Ù„Ù…Ø³ØªÙ„Ù…."),
      );
      return;
    }
    if (body.isEmpty) {
      _showSnack(
        AppLanguage.t("Le message ne peut pas etre vide.", "Ù„Ø§ ÙŠÙ…ÙƒÙ† Ø£Ù† ØªÙƒÙˆÙ† Ø§Ù„Ø±Ø³Ø§Ù„Ø© ÙØ§Ø±ØºØ©."),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      await NotificationService.sendMessage(
        recipientId: recipientId,
        subject: subject,
        body: body,
        category: _category,
        transactionId: _linkedTransactionId,
      );

      _subjectController.clear();
      _bodyController.clear();

      await _loadData();

      if (!mounted) return;
      _showSnack(
        AppLanguage.t("Message envoye.", "ØªÙ… Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„Ø±Ø³Ø§Ù„Ø©."),
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        AppLanguage.t("Echec de l'envoi du message.", "ÙØ´Ù„ Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„Ø±Ø³Ø§Ù„Ø©."),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _openMessage(Map<String, dynamic> item) async {
    final messageId = _userId(item);
    final isRead = item["is_read"] == true;

    if (!isRead && !_isOwnMessage(item) && messageId > 0) {
      try {
        await NotificationService.markMessageAsRead(messageId);
      } catch (_) {}
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _stringValue(
                    item,
                    ["subject", "title"],
                    AppLanguage.t("Sans objet", "Ø¨Ø¯ÙˆÙ† Ø¹Ù†ÙˆØ§Ù†"),
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "${AppLanguage.t("Categorie", "Ø§Ù„ØªØµÙ†ÙŠÙ")} : ${_categoryLabel(item["category"]?.toString() ?? "GENERAL")}",
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _messageMeta(item),
                  style: const TextStyle(
                    color: AppColors.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    _stringValue(
                      item,
                      ["body", "message", "content"],
                      AppLanguage.t("Message vide", "Ø±Ø³Ø§Ù„Ø© ÙØ§Ø±ØºØ©"),
                    ),
                    style: const TextStyle(
                      color: AppColors.text,
                      height: 1.55,
                    ),
                  ),
                ),
                if (!_isOwnMessage(item)) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _prepareReply(item);
                      },
                      icon: const Icon(Icons.reply_rounded),
                      label: Text(
                        AppLanguage.t("Repondre", "رد"),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    await _loadData();
  }

  void _prepareReply(Map<String, dynamic> item) {
    final senderIdRaw = item["sender_id"] ?? item["sender"];
    final senderId = senderIdRaw is int
        ? senderIdRaw
        : int.tryParse(senderIdRaw?.toString() ?? "");

    if (senderId == null || senderId <= 0) {
      _showSnack(
        AppLanguage.t(
          "Impossible de determiner le destinataire de la reponse.",
          "تعذر تحديد مستلم الرد.",
        ),
      );
      return;
    }

    final originalSubject = _stringValue(
      item,
      ["subject", "title"],
      AppLanguage.t("Sans objet", "بدون عنوان"),
    );
    final repairedSubject = originalSubject.trim();
    final replyPrefix = AppLanguage.t("Re : ", "رد: ");
    final subject = repairedSubject.toLowerCase().startsWith("re:")
        ? repairedSubject
        : "$replyPrefix$repairedSubject";

    final senderName = _stringValue(
      item,
      ["sender_name", "sender_full_name", "sender_fullname", "sender_label"],
      AppLanguage.t("Utilisateur", "مستخدم"),
    );

    setState(() {
      _preferredRecipientId = senderId;
      _selectedRecipientId = senderId;
      _category = (item["category"]?.toString().trim().isNotEmpty ?? false)
          ? item["category"].toString().toUpperCase()
          : "GENERAL";
      _subjectController.text = subject;
      _bodyController.text = AppLanguage.t(
        "\n\n--- Reponse a $senderName ---\n",
        "\n\n--- رد على $senderName ---\n",
      );
    });

    _showSnack(
      AppLanguage.t(
        "Le formulaire de reponse est pret.",
        "تم تجهيز نموذج الرد.",
      ),
    );
  }

  String _messageMeta(Map<String, dynamic> item) {
    final sender = _stringValue(
      item,
      ["sender_name", "sender_full_name", "sender_fullname", "sender_label"],
      AppLanguage.t("Expediteur inconnu", "Ù…Ø±Ø³Ù„ ØºÙŠØ± Ù…Ø¹Ø±ÙˆÙ"),
    );
    final recipient = _stringValue(
      item,
      ["recipient_name", "recipient_full_name", "recipient_fullname", "recipient_label"],
      AppLanguage.t("Destinataire inconnu", "Ù…Ø³ØªÙ„Ù… ØºÙŠØ± Ù…Ø¹Ø±ÙˆÙ"),
    );
    final date = _formatDate(item["created_at"]?.toString() ?? "");

    return AppLanguage.t(
      "De : $sender\nA : $recipient\nDate : $date",
      "Ù…Ù†: $sender\nØ¥Ù„Ù‰: $recipient\nØ§Ù„ØªØ§Ø±ÙŠØ®: $date",
    );
  }

  String _formatDate(String value) {
    if (value.trim().isEmpty) {
      return AppLanguage.t("Non precisee", "ØºÙŠØ± Ù…Ø­Ø¯Ø¯");
    }

    try {
      final dt = DateTime.parse(value).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return "$day/$month/$year - $hour:$minute";
    } catch (_) {
      return value;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
    return value.contains("ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢") ||
        value.contains("ÃƒÆ’Ã†â€™Ãƒâ€¹Ã…â€œ") ||
        value.contains("ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢") ||
        value.contains("ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡") ||
        value.contains("ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¿Ãƒâ€šÃ‚Â½") ||
        value.contains("Ã˜Â§") ||
        value.contains("Ã™");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitle()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _heroCard(),
                  const SizedBox(height: 16),
                  if (_errorMessage != null) _errorCard(),
                  _composerCard(),
                  const SizedBox(height: 16),
                  _filtersCard(),
                  const SizedBox(height: 16),
                  _messagesCard(),
                ],
              ),
            ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3FCA), Color(0xFF1CA7C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.forum_rounded, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            _screenTitle(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _screenSubtitle(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Text(
        _errorMessage!,
        style: const TextStyle(
          color: AppColors.danger,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _composerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLanguage.t("Nouveau message", "Ø±Ø³Ø§Ù„Ø© Ø¬Ø¯ÙŠØ¯Ø©"),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLanguage.t(
              "Envoyez une note, une alerte ou une question en texte uniquement.",
              "Ø£Ø±Ø³Ù„ Ù…Ù„Ø§Ø­Ø¸Ø© Ø£Ùˆ ØªÙ†Ø¨ÙŠÙ‡Ù‹Ø§ Ø£Ùˆ Ø§Ø³ØªÙØ³Ø§Ø±Ù‹Ø§ Ù†ØµÙŠÙ‹Ø§ ÙÙ‚Ø·.",
            ),
            style: const TextStyle(
              color: AppColors.muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _selectedRecipientId,
            decoration: InputDecoration(
              labelText: AppLanguage.t("Destinataire", "Ø§Ù„Ù…Ø³ØªÙ„Ù…"),
            ),
            items: _contacts
                .map(
                  (contact) => DropdownMenuItem<int>(
                    value: _userId(contact),
                    child: Text(
                      "${_contactName(contact)} - ${_contactRole(contact)}",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _contacts.isEmpty
                ? null
                : (value) {
                    setState(() => _selectedRecipientId = value);
                  },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: InputDecoration(
              labelText: AppLanguage.t("Categorie", "Ø§Ù„ØªØµÙ†ÙŠÙ"),
            ),
            items: const ["GENERAL", "SUPPORT", "TRANSACTION", "ALERT", "AUDIT"]
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(_categoryLabel(value)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _category = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subjectController,
            decoration: InputDecoration(
              labelText: AppLanguage.t("Objet (optionnel)", "Ø§Ù„Ø¹Ù†ÙˆØ§Ù† (Ø§Ø®ØªÙŠØ§Ø±ÙŠ)"),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            maxLines: 5,
            minLines: 4,
            decoration: InputDecoration(
              labelText: AppLanguage.t("Message", "Ø§Ù„Ø±Ø³Ø§Ù„Ø©"),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _sendMessage,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _sending
                    ? AppLanguage.t("Envoi...", "Ø¬Ø§Ø±Ù Ø§Ù„Ø¥Ø±Ø³Ø§Ù„...")
                    : AppLanguage.t("Envoyer", "Ø¥Ø±Ø³Ø§Ù„"),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filtersCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLanguage.t("Boite de reception", "Ø¹Ù„Ø¨Ø© Ø§Ù„Ø±Ø³Ø§Ø¦Ù„"),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ["all", "inbox", "sent"].map((value) {
              final selected = _mailbox == value;
              return ChoiceChip(
                label: Text(_mailboxLabel(value)),
                selected: selected,
                onSelected: (_) async {
                  setState(() => _mailbox = value);
                  await _loadData();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _unreadOnly,
            title: Text(AppLanguage.t("Messages non lus seulement", "Ø§Ù„Ø±Ø³Ø§Ø¦Ù„ ØºÙŠØ± Ø§Ù„Ù…Ù‚Ø±ÙˆØ¡Ø© ÙÙ‚Ø·")),
            onChanged: (value) async {
              setState(() => _unreadOnly = value);
              await _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _messagesCard() {
    return Container(
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
              Text(
                AppLanguage.t("Messages", "Ø§Ù„Ø±Ø³Ø§Ø¦Ù„"),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              Text(
                _messages.length.toString(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_messages.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                AppLanguage.t(
                  "Aucun message pour le moment.",
                  "Ù„Ø§ ØªÙˆØ¬Ø¯ Ø±Ø³Ø§Ø¦Ù„ Ø­Ø§Ù„ÙŠÙ‹Ø§.",
                ),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ..._messages.map(_messageTile),
        ],
      ),
    );
  }

  Widget _messageTile(Map<String, dynamic> item) {
    final own = _isOwnMessage(item);
    final isRead = item["is_read"] == true;
    final accent = own ? AppColors.primary : AppColors.success;

    return GestureDetector(
      onTap: () => _openMessage(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: own ? AppColors.primary.withValues(alpha: 0.05) : AppColors.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: own
                ? AppColors.primary.withValues(alpha: 0.16)
                : AppColors.surfaceSoft,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                own ? Icons.north_east_rounded : Icons.south_west_rounded,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _stringValue(
                            item,
                            ["subject", "title"],
                            AppLanguage.t("Sans objet", "Ø¨Ø¯ÙˆÙ† Ø¹Ù†ÙˆØ§Ù†"),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          own
                              ? AppLanguage.t("Envoye", "Ù…Ø±Ø³Ù„")
                              : (isRead
                                  ? AppLanguage.t("Lu", "Ù…Ù‚Ø±ÙˆØ¡")
                                  : AppLanguage.t("Nouveau", "Ø¬Ø¯ÙŠØ¯")),
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    own
                        ? AppLanguage.t(
                            "Vers ${_stringValue(item, ["recipient_name", "recipient_full_name"], AppLanguage.t("destinataire", "Ø§Ù„Ù…Ø³ØªÙ„Ù…"))}",
                            "Ø¥Ù„Ù‰ ${_stringValue(item, ["recipient_name", "recipient_full_name"], AppLanguage.t("Ø§Ù„Ù…Ø³ØªÙ„Ù…", "Ø§Ù„Ù…Ø³ØªÙ„Ù…"))}",
                          )
                        : AppLanguage.t(
                            "De ${_stringValue(item, ["sender_name", "sender_full_name"], AppLanguage.t("expediteur", "Ø§Ù„Ù…Ø±Ø³Ù„"))}",
                            "Ù…Ù† ${_stringValue(item, ["sender_name", "sender_full_name"], AppLanguage.t("Ø§Ù„Ù…Ø±Ø³Ù„", "Ø§Ù„Ù…Ø±Ø³Ù„"))}",
                          ),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _stringValue(
                      item,
                      ["body", "message", "content"],
                      AppLanguage.t("Message vide", "Ø±Ø³Ø§Ù„Ø© ÙØ§Ø±ØºØ©"),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(item["created_at"]?.toString() ?? ""),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

