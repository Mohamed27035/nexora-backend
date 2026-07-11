import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_language.dart';
import '../../core/theme/app_theme.dart';
import '../../services/kyc_service.dart';
import '../../services/user_management_service.dart';
import '../../utils/dio_error_utils.dart';
import '../../utils/ocr_utils.dart';
import '../../widgets/info_card.dart';

class UserDetailsScreen extends StatefulWidget {
  const UserDetailsScreen({super.key});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  String tr(String fr, String ar) => AppLanguage.t(fr, ar);
  Map<String, dynamic>? user;
  Map<String, dynamic>? latestKyc;
  bool loading = true;
  bool processing = false;

  int? get _userId {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int) return args;
    if (args is Map && args["id"] is int) return args["id"] as int;
    return null;
  }

  Map<String, dynamic>? get _prefilledUser {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args["user"] is Map) {
      return Map<String, dynamic>.from(args["user"] as Map);
    }
    return null;
  }

  bool get _isVerified => user?["is_verified"] == true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading) {
      fetchData();
    }
  }

  Future<void> fetchData() async {
    final userId = _userId;
    final seededUser = _prefilledUser;

    if (userId == null && seededUser == null) {
      if (!mounted) return;
      setState(() => loading = false);
      _showMessage(tr("Identifiant utilisateur introuvable.", "تعذر العثور على معرف المستخدم."));
      return;
    }

    try {
      dynamic userData = seededUser;
      final kycResponse = await KycService.getAllKyc();

      if (userId != null) {
        try {
          final userResponse = await UserManagementService.getUser(userId);
          userData = Map<String, dynamic>.from(userResponse.data as Map);
        } catch (_) {
          userData ??= seededUser;
        }
      }

      final kycData = kycResponse.data;
      final requests = kycData is List ? kycData : (kycData["kyc"] ?? []);

      Map<String, dynamic>? matched;
      if (requests is List) {
        for (final item in requests) {
          final currentId = userId ?? seededUser?["id"];
          if (item is Map && item["utilisateur"] == currentId) {
            matched = Map<String, dynamic>.from(item);
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        user = userData == null ? null : Map<String, dynamic>.from(userData as Map);
        latestKyc = matched;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _showMessage(_friendlyError(e));
    }
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      return DioErrorUtils.friendlyMessage(error);
    }
    return "Une erreur est survenue.";
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr("Fiche utilisateur", "بطاقة المستخدم"))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _profileCard(),
                  const SizedBox(height: 16),
                  if (!_isVerified)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: InfoCard(
                        child: Text(
                          tr(
                            "La verification d'identite de ce compte est maintenant traitee automatiquement a partir du document et du selfie. Les images ne sont pas conservees apres analyse.",
                            "أصبح التحقق من هوية هذا الحساب يُعالج تلقائيًا اعتمادًا على البطاقة والسيلفي، ولا يتم الاحتفاظ بالصور بعد التحليل.",
                          ),
                          style: const TextStyle(color: AppColors.muted, height: 1.4),
                        ),
                      ),
                    ),
                  _ocrCard(),
                  const SizedBox(height: 16),
                  _imagesCard(),
                ],
              ),
            ),
    );
  }

  Widget _profileCard() {
    final item = user ?? {};
    final fullName =
        item["full_name"]?.toString().trim().isNotEmpty == true
            ? item["full_name"].toString()
            : item["nom"]?.toString() ?? "Utilisateur";

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fullName,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _isVerified
                      ? Colors.green.withOpacity(0.12)
                      : Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _isVerified ? "VERIFIE" : "NON VERIFIE",
                  style: TextStyle(
                    color: _isVerified ? Colors.green.shade700 : Colors.orange.shade700,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _line(AppLanguage.t("Email", "البريد الإلكتروني"), item["email"]),
          _line("Telephone", item["telephone"]),
          _line("Role", item["role_label"] ?? item["role"]),
          _line("Statut", item["status"]),
          if ((item["role"]?.toString().toUpperCase() ?? "") == "CLIENT")
            _line("Solde", "${item["balance"] ?? 0} MRU"),
          _line("Derniere IP", item["last_ip"]),
        ],
      ),
    );
  }

  Widget _ocrCard() {
    final item = latestKyc ?? {};
    final structuredOcr = _resolvedOcrData();
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Informations extraites de la carte",
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (latestKyc == null)
            const Text(
              "Aucune demande d'identite disponible pour cet utilisateur.",
              style: TextStyle(color: AppColors.muted),
            )
          else ...[
            _line("Etat de la verification", item["status"]),
            _line("NNI", _ocrValue("nni", structuredOcr)),
            _line("Prenom", _ocrValue("prenom", structuredOcr)),
            _line("Prenom du pere", _ocrValue("prenom_pere", structuredOcr)),
            _line("Nom de famille", _ocrValue("nom_famille", structuredOcr)),
            _line("Sexe", _ocrValue("sexe", structuredOcr)),
            _line("Date de naissance", _ocrValue("date_naissance", structuredOcr)),
            _line("Lieu de naissance", _ocrValue("lieu_naissance", structuredOcr)),
            _line("Note de revision", item["review_note"]),
            const SizedBox(height: 12),
            _metricBanner(
              title: tr("Confiance extraction", "ثقة الاستخراج"),
              value: _asDouble(item["ocr_confidence"]),
              subtitle:
                  "${_asInt(item["ocr_extracted_fields"]) ?? 0}/${_asInt(item["ocr_required_fields"]) ?? 7} champs extraits${_stringList(item["ocr_missing_fields"]).isEmpty ? "" : " - manquants: ${_stringList(item["ocr_missing_fields"]).join(", ")}"}",
              color: _confidenceColor(_asDouble(item["ocr_confidence"])),
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 10),
            _metricBanner(
              title: tr("Confiance selfie", "ثقة السيلفي"),
              value: _asDouble(item["face_confidence"]),
              subtitle:
                  "Visage ${_asBool(item["face_detected"]) == true ? "detecte" : "non detecte"} - statut: ${_formatBiometricStatus(item["biometric_status"]?.toString() ?? "PENDING")}",
              color: _faceColor(
                _asBool(item["face_detected"]),
                item["biometric_status"]?.toString() ?? "PENDING",
                _asDouble(item["face_confidence"]),
              ),
              icon: _asBool(item["face_detected"]) == true
                  ? Icons.face_retouching_natural
                  : Icons.face_unlock_outlined,
              trailing: item["biometric_message"]?.toString(),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> _resolvedOcrData() {
    final item = latestKyc ?? {};
    final rawMap = item["ocr_data"];
    if (rawMap is Map) {
      final mapped = Map<String, dynamic>.from(rawMap);
      if (mapped.values.any((value) => (value?.toString().trim() ?? "").isNotEmpty)) {
        return mapped;
      }
    }

    final rawText = item["ocr_text"]?.toString() ?? "";
    if (rawText.trim().isEmpty) {
      return item;
    }

    final parsed = OcrUtils.parseIdentityFields(rawText);
    return {
      ...item,
      ...parsed,
    };
  }

  dynamic _ocrValue(String key, Map<String, dynamic> structuredOcr) {
    final direct = latestKyc?[key];
    final directText = direct?.toString().trim() ?? "";
    if (directText.isNotEmpty) {
      return direct;
    }
    return structuredOcr[key];
  }

  Widget _metricBanner({
    required String title,
    required double? value,
    required String subtitle,
    required Color color,
    required IconData icon,
    String? trailing,
  }) {
    final formatted = value == null
        ? "-"
        : "${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)}%";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "$title : $formatted",
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.muted,
              height: 1.35,
            ),
          ),
          if ((trailing ?? "").trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              trailing!,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _imagesCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr("Pieces justificatives", "المرفقات"),
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr(
              "",
              "",
            ),
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, dynamic value) {
    final text = value?.toString().trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        "$label: ${text == null || text.isEmpty ? "-" : text}",
        style: const TextStyle(color: AppColors.muted),
      ),
    );
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value == null) return null;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == "true") return true;
    if (normalized == "false") return false;
    return null;
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((item) => _labelForField(item.toString())).toList();
    }
    return const [];
  }

  String _labelForField(String value) {
    switch (value) {
      case "prenom_pere":
        return "Prenom du pere";
      case "nom_famille":
        return "Nom de famille";
      case "date_naissance":
        return "Date de naissance";
      case "lieu_naissance":
        return "Lieu de naissance";
      default:
        return value;
    }
  }

  Color _confidenceColor(double? score) {
    final value = score ?? 0;
    if (value >= 80) return Colors.green.shade700;
    if (value >= 50) return Colors.orange.shade700;
    return Colors.redAccent.shade700;
  }

  Color _faceColor(bool? detected, String status, double? score) {
    if (status.toUpperCase() == "VERIFIED") return Colors.green.shade700;
    if (detected == false || status.toUpperCase() == "FAILED") {
      return Colors.redAccent.shade700;
    }
    return _confidenceColor(score);
  }

  String _formatBiometricStatus(String status) {
    switch (status.toUpperCase()) {
      case "VERIFIED":
        return "verifie";
      case "FAILED":
        return "echec";
      case "ERROR":
        return "erreur";
      case "SKIPPED":
        return "ignore";
      default:
        return "en attente";
    }
  }
}





