import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_language.dart';
import '../../core/theme/app_theme.dart';
import '../../services/kyc_service.dart';
import '../../utils/dio_error_utils.dart';
import '../../widgets/info_card.dart';


class KycReviewScreen extends StatefulWidget {
  const KycReviewScreen({super.key});

  @override
  State<KycReviewScreen> createState() => _KycReviewScreenState();
}


class _KycReviewScreenState extends State<KycReviewScreen> {
  String tr(String fr, String ar) => AppLanguage.t(fr, ar);
  List requests = [];
  bool loading = true;
  String statusFilter = "ALL";
  String search = "";

  List get filteredRequests {
    return requests.where((item) {
      final status = item["status"]?.toString() ?? "";
      final haystack =
          "${item["utilisateur_full_name"] ?? item["utilisateur_name"] ?? ""} ${item["nni"] ?? ""} ${item["prenom"] ?? ""} ${item["nom_famille"] ?? ""}"
              .toLowerCase();
      final matchesStatus = statusFilter == "ALL" || status == statusFilter;
      final matchesSearch = search.isEmpty || haystack.contains(search);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  Future<void> fetchKyc() async {
    try {
      final response = await KycService.getAllKyc(
        status: statusFilter,
        search: search,
      );
      if (!mounted) return;

      setState(() {
        requests = response.data is List ? response.data : response.data["kyc"] ?? [];
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _showMessage(_friendlyError(e));
    }
  }

  Future<void> approve(int id) async {
    try {
      await KycService.approveKyc(id);
      await fetchKyc();
      if (!mounted) return;
      _showMessage("Verification d'identite approuvee.");
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e));
    }
  }

  Future<void> reject(int id) async {
    final reason = await _rejectReason();
    if (reason == null) return;

    try {
      await KycService.rejectKyc(id, reason: reason);
      await fetchKyc();
      if (!mounted) return;
      _showMessage("Verification d'identite rejetee.");
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e));
    }
  }

  Future<String?> _rejectReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: Text(
          tr("Raison du rejet", "سبب الرفض"),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: tr("Raison", "السبب"),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr("Annuler", "إلغاء")),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(tr("Rejeter", "رفض")),
          ),
        ],
      ),
    );
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
  void initState() {
    super.initState();
    fetchKyc();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr("Verification d'identite", "التحقق من الهوية"))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchKyc,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  InfoCard(
                    child: Column(
                      children: [
                        TextField(
                          style: const TextStyle(color: AppColors.text),
                          decoration: InputDecoration(
                            hintText: tr("Rechercher par nom ou NNI", "ابحث بالاسم أو رقم NNI"),
                            hintStyle: const TextStyle(color: AppColors.muted),
                            suffixIcon: IconButton(
                              onPressed: fetchKyc,
                              icon: const Icon(
                                Icons.search,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          onChanged: (value) => setState(
                            () => search = value.toLowerCase(),
                          ),
                          onSubmitted: (_) => fetchKyc(),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: statusFilter,
                          dropdownColor: AppColors.surface,
                          style: const TextStyle(color: AppColors.text),
                          items: [
                            DropdownMenuItem(
                              value: "ALL",
                              child: Text(AppLanguage.t("Tous", "الكل")),
                            ),
                            DropdownMenuItem(
                              value: "PENDING",
                              child: Text(AppLanguage.t("En attente", "قيد الانتظار")),
                            ),
                            DropdownMenuItem(
                              value: "APPROVED",
                              child: Text(AppLanguage.t("Approuvé", "موافق عليه")),
                            ),
                            DropdownMenuItem(
                              value: "REJECTED",
                              child: Text(AppLanguage.t("Rejeté", "مرفوض")),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => statusFilter = value ?? "ALL");
                          },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: fetchKyc,
                            icon: const Icon(Icons.filter_alt_outlined),
                            label: Text(AppLanguage.t("Appliquer les filtres", "تطبيق التصفية")),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (filteredRequests.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text(
                          "Aucune demande de verification d'identite ne correspond aux filtres.",
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ),
                  ...filteredRequests.map(_requestCard),
                ],
              ),
            ),
    );
  }

  Widget _requestCard(dynamic item) {
    final id = item["id"] as int?;
    final status = item["status"]?.toString() ?? "";
    final fullName =
        item["utilisateur_full_name"]?.toString().trim().isNotEmpty == true
            ? item["utilisateur_full_name"].toString()
            : item["utilisateur_name"]?.toString() ?? "-";

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Verification #${id ?? "-"} - $status",
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _line("Utilisateur", fullName),
            _line("NNI", item["nni"]),
            _line("Nom", item["nom_famille"]),
            _line("Prenom", item["prenom"]),
            _line("Prenom du pere", item["prenom_pere"]),
            _line("Sexe", item["sexe"]),
            _line("Date de naissance", item["date_naissance"]),
            _line("Lieu de naissance", item["lieu_naissance"]),
            _line("Note de revision", item["review_note"]),
            const SizedBox(height: 8),
            _ocrBadge(item),
            const SizedBox(height: 12),
            _confidenceTile(
              title: tr("Confiance extraction", "ثقة الاستخراج"),
              value: _asDouble(item["ocr_confidence"]),
              subtitle:
                  "${_asInt(item["ocr_extracted_fields"]) ?? 0}/${_asInt(item["ocr_required_fields"]) ?? 7} champs extraits${_stringList(item["ocr_missing_fields"]).isEmpty ? "" : " - manquants: ${_stringList(item["ocr_missing_fields"]).join(", ")}"}",
              color: _confidenceColor(_asDouble(item["ocr_confidence"])),
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 10),
            _confidenceTile(
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
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceSoft),
              ),
              child: Text(
                tr(
                  "Cette verification est traitee automatiquement. Les images source ne sont pas conservees apres l'analyse, et la liste affiche uniquement les donnees extraites ainsi que le resultat final.",
                  "تتم معالجة هذا التحقق تلقائيًا. لا يتم الاحتفاظ بالصور الأصلية بعد التحليل، وتعرض هذه القائمة فقط البيانات المستخرجة والنتيجة النهائية.",
                ),
                style: const TextStyle(color: AppColors.muted, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case "APPROVED":
        return Colors.green;
      case "REJECTED":
        return Colors.redAccent;
      case "PENDING":
      default:
        return Colors.orange;
    }
  }

  Widget _ocrBadge(dynamic item) {
    final ready = item["ocr_complete"] == true || !_isOcrEmpty(item);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ready
            ? Colors.green.withOpacity(0.12)
            : Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        ready ? "Les donnees OCR sont disponibles." : "Les donnees OCR sont incompletes.",
        style: TextStyle(
          color: ready ? Colors.green.shade700 : Colors.orange.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _confidenceTile({
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
            style: const TextStyle(color: AppColors.muted, height: 1.35),
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


  Widget _line(String label, dynamic value) {
    final text = value?.toString().trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        "$label: ${text == null || text.isEmpty ? "-" : text}",
        style: const TextStyle(color: AppColors.muted),
      ),
    );
  }

  bool _isOcrEmpty(dynamic item) {
    final keys = [
      "nni",
      "prenom",
      "prenom_pere",
      "nom_famille",
      "sexe",
      "date_naissance",
      "lieu_naissance",
    ];

    for (final key in keys) {
      final value = item[key]?.toString().trim() ?? "";
      if (value.isNotEmpty) {
        return false;
      }
    }

    return true;
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




