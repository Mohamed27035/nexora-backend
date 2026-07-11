import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/config/app_config.dart';
import '../core/localization/app_language.dart';
import '../core/theme/app_theme.dart';
import '../services/kyc_service.dart';
import '../utils/dio_error_utils.dart';
import '../utils/ocr_utils.dart';


class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}


class _KycScreenState extends State<KycScreen> {
  File? idImage;
  File? selfieImage;
  bool isLoading = false;
  bool loadingKyc = true;
  bool ocrLoading = false;

  Map<String, dynamic>? kycData;
  String? ocrRawText;
  Map<String, String> ocrFields = {};
  List<String> ocrWarnings = [];
  String? detectedDocumentType;

  String get status => kycData?["status"]?.toString() ?? "NOT_SUBMITTED";
  bool get isApproved => status == "APPROVED";
  bool get isPending => status == "PENDING";
  bool get hasSubmittedKyc => kycData != null;

  Map<String, dynamic> _routeArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) return args;
    if (args is Map) return Map<String, dynamic>.from(args);
    return const {};
  }

  bool _isOnboarding(BuildContext context) =>
      _routeArgs(context)["onboarding"] == true;

  bool _isSkippable(BuildContext context) =>
      _isOnboarding(context) && _routeArgs(context)["skippable"] != false;

  void _goToDashboard() {
    Navigator.pushNamedAndRemoveUntil(context, "/dashboard", (route) => false);
  }

  Future<void> loadKyc() async {
    try {
      final response = await KycService.getMyKyc();
      if (!mounted) return;

      setState(() {
        if (response.data is List && response.data.isNotEmpty) {
          kycData = Map<String, dynamic>.from(response.data[0]);
        } else {
          kycData = null;
        }
        loadingKyc = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loadingKyc = false);
      _showMessage(_friendlyError(e));
    }
  }

  Future<void> pickIdImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (picked != null) {
      setState(() {
        idImage = File(picked.path);
        ocrRawText = null;
        ocrFields = {};
        ocrWarnings = [];
        detectedDocumentType = null;
      });
    }
  }

  Future<void> pickSelfie() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (picked != null) {
      setState(() {
        selfieImage = File(picked.path);
      });
    }
  }

  Future<void> submitKyc() async {
    if (isApproved) {
      _showMessage("Votre verification d'identite est deja approuvee.");
      return;
    }

    if (isPending) {
      final replacePending = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLanguage.t("Demande deja en attente", "طلب موجود مسبقًا")),
          content: Text(AppLanguage.t(
            "Une demande de verification d'identite est deja en attente. Voulez-vous la mettre a jour avec les nouvelles images et les nouvelles informations OCR ?", "يوجد طلب تحقق من الهوية قيد الانتظار. هل تريد تحديثه بالصور الجديدة وبيانات OCR الجديدة؟"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLanguage.t("Annuler", "إلغاء")),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLanguage.t("Mettre a jour", "تحديث")),
            ),
          ],
        ),
      );

      if (replacePending != true) {
        return;
      }
    }

    if (idImage == null || selfieImage == null) {
      _showMessage("Selectionnez le document et le selfie.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final ocrPayload = await _buildOcrPayload();
      final formData = FormData.fromMap({
        "id_document": await MultipartFile.fromFile(
          idImage!.path,
          filename: "id_document.jpg",
        ),
        "selfie": await MultipartFile.fromFile(
          selfieImage!.path,
          filename: "selfie.jpg",
        ),
        ...ocrPayload,
      });

      final response = await KycService.submitKyc(formData);
      final responseData = response.data;
      if (responseData is Map && responseData["kyc"] is Map) {
        setState(() {
          kycData = Map<String, dynamic>.from(responseData["kyc"]);
        });
      }
      await loadKyc();

      if (!mounted) return;
      _showMessage(
        responseData is Map && responseData["message"] != null
            ? responseData["message"].toString()
            : "Votre verification d'identite a ete traitee automatiquement.",
      );
      if (_isOnboarding(context)) {
        _goToDashboard();
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>> _buildOcrPayload() async {
    var text = ocrRawText;
    var fields = Map<String, String>.from(ocrFields);

    if ((text ?? "").trim().isEmpty && idImage != null) {
      try {
        text = await OcrUtils.recognizeText(idImage!);
        fields = OcrUtils.parseIdentityFields(text);

        if (mounted) {
          setState(() {
            ocrRawText = text;
            ocrFields = fields;
            ocrWarnings = OcrUtils.detectWarnings(fields);
            detectedDocumentType = OcrUtils.detectDocumentType(text!);
          });
        }
      } catch (_) {
        return const {};
      }
    }

    return {
      if ((text ?? "").trim().isNotEmpty) "ocr_text": text!.trim(),
      ...fields,
    };
  }

  Future<void> runOcr() async {
    if (idImage == null) {
      _showMessage("Selectionnez d'abord le document.");
      return;
    }

    setState(() => ocrLoading = true);
    try {
      final text = await OcrUtils.recognizeText(idImage!);
      final fields = OcrUtils.parseIdentityFields(text);
      final warnings = OcrUtils.detectWarnings(fields);
      final documentType = OcrUtils.detectDocumentType(text);
      if (!mounted) return;

      setState(() {
        ocrRawText = text;
        ocrFields = fields;
        ocrWarnings = warnings;
        detectedDocumentType = documentType;
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => ocrLoading = false);
      }
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
  void initState() {
    super.initState();
    loadKyc();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLanguage.t("Verification identite", "التحقق من الهوية"))),
      body: loadingKyc
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isOnboarding(context)) ...[
                    _onboardingCard(),
                    const SizedBox(height: 20),
                  ],
                  _statusCard(),
                  const SizedBox(height: 20),
                  if (!isApproved) ...[
                    _imagePickerCard(
                      title: AppLanguage.t("Document d'identite", "بطاقة التعريف"),
                      image: idImage,
                      remoteUrl: _mediaUrl(
                        kycData?["id_document_url"] ?? kycData?["id_document"],
                      ),
                      icon: Icons.badge_outlined,
                      onPressed: isApproved ? null : pickIdImage,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed:
                            isApproved || ocrLoading ? null : runOcr,
                        icon: ocrLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.document_scanner_outlined),
                        label: Text(AppLanguage.t("Lancer OCR", "تشغيل OCR")),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _imagePickerCard(
                      title: AppLanguage.t("Selfie", "صورة سلفي"),
                      image: selfieImage,
                      remoteUrl: _mediaUrl(
                        kycData?["selfie_url"] ?? kycData?["selfie"],
                      ),
                      icon: Icons.photo_camera_outlined,
                      onPressed: isApproved ? null : pickSelfie,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ||
                                isApproved ||
                                false
                            ? null
                            : submitKyc,
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                isApproved
                                    ? AppLanguage.t("Verification approuvee", "تم قبول التحقق")
                                    : isPending
                                    ? AppLanguage.t("Mettre a jour la verification", "تحديث التحقق")
                                    : AppLanguage.t("Verification", "التحقق"),
                         ),
                       ),
                     ),
                    if (_isSkippable(context) && !isApproved && !isPending) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _goToDashboard,
                          child: Text(AppLanguage.t("Passer pour le moment", "تخطي الآن")),
                        ),
                      ),
                    ],
                    if (hasSubmittedKyc && _hasRemoteVerificationData()) ...[
                      const SizedBox(height: 32),
                      _remoteOcrCard(),
                    ],
                  ] else if (hasSubmittedKyc && _hasRemoteVerificationData()) ...[
                    _remoteOcrCard(),
                  ],
                  if (_isOnboarding(context) && (isApproved || isPending || hasSubmittedKyc)) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _goToDashboard,
                        child: Text(
                          AppLanguage.t(
                            "Continuer vers l'application",
                            "المتابعة إلى التطبيق",
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _onboardingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLanguage.t("Activation du compte", "تفعيل الحساب"),
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppLanguage.t(
              "Ajoutez votre piece d'identite, lancez l'OCR, puis prenez un selfie. Le systeme analysera automatiquement les donnees extraites et la verification du selfie. Vous pouvez passer cette etape pour le moment, mais votre compte restera inactif tant que l'identite n'est pas validee.",
              "أضف بطاقة التعريف، ثم شغّل OCR، وبعدها التقط صورة سلفي. سيقوم النظام تلقائيًا بتحليل البيانات المستخرجة والتحقق من السلفي. يمكنك تخطي هذه الخطوة الآن، لكن حسابك سيبقى غير نشط إلى أن يتم اعتماد الهوية.",
            ),
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final color = switch (status) {
      "APPROVED" => Colors.green,
      "REJECTED" => Colors.red,
      "PENDING" => Colors.orange,
      _ => Colors.blue,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLanguage.t("Statut de la verification", "حالة التحقق"),
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            switch (status) {
              "APPROVED" => AppLanguage.t("Votre identite a ete validee.", "تم اعتماد هويتك."),
              "PENDING" => AppLanguage.t("Votre demande est en cours de traitement automatique.", "طلبك قيد المعالجة التلقائية."),
              "REJECTED" => AppLanguage.t("Votre demande a ete rejetee. Verifiez la note.", "تم رفض طلبك. يرجى مراجعة الملاحظة."),
              _ => AppLanguage.t("Aucune demande de verification d'identite n'a encore ete envoyee.", "لم يتم إرسال أي طلب تحقق من الهوية بعد."),
            },
            style: const TextStyle(color: AppColors.muted),
          ),
          if ((kycData?["review_note"]?.toString() ?? "").isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              AppLanguage.t("Note", "ملاحظة") + ": ${kycData!["review_note"]}",
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _imagePickerCard({
    required String title,
    required File? image,
    required String? remoteUrl,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.surfaceSoft),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildPreviewImage(
                image: image,
                remoteUrl: remoteUrl,
                icon: icon,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(image == null ? AppLanguage.t("Ajouter", "إضافة") : AppLanguage.t("Changer", "تغيير")),
            ),
          ),
        ],
      ),
    );
  }

  Widget _remoteOcrCard() {
    final biometricSummary = kycData?["biometric_summary"] is Map
        ? Map<String, dynamic>.from(kycData?["biometric_summary"])
        : <String, dynamic>{};
    final faceConfidence = _asDouble(
      kycData?["face_confidence"] ?? biometricSummary["similarity_score"],
    );
    final faceDetected = _asBool(kycData?["face_detected"]);
    final biometricStatus = kycData?["biometric_status"]?.toString() ?? "PENDING";
    final biometricMessage = kycData?["biometric_message"]?.toString();
    final biometricDecision =
        (kycData?["biometric_decision"] ?? biometricSummary["decision"])
            ?.toString()
            .trim();
    final similarityThreshold = _asDouble(
          kycData?["similarity_threshold"] ?? biometricSummary["threshold"],
        ) ??
        70;
    final isFaceMatchAccepted =
        faceConfidence != null &&
        faceConfidence >= similarityThreshold &&
        biometricStatus.toUpperCase() == "VERIFIED";

    final extractedValues = [
      MapEntry(AppLanguage.t("NNI", "الرقم الوطني"), kycData?["nni"]),
      MapEntry(AppLanguage.t("Prenom", "الاسم"), kycData?["prenom"]),
      MapEntry(AppLanguage.t("Prenom du pere", "اسم الأب"), kycData?["prenom_pere"]),
      MapEntry(AppLanguage.t("Nom de famille", "اسم العائلة"), kycData?["nom_famille"]),
      MapEntry(AppLanguage.t("Sexe", "الجنس"), kycData?["sexe"]),
      MapEntry(AppLanguage.t("Date de naissance", "تاريخ الميلاد"), kycData?["date_naissance"]),
      MapEntry(AppLanguage.t("Lieu de naissance", "مكان الميلاد"), kycData?["lieu_naissance"]),
    ].where((entry) => (entry.value?.toString().trim() ?? "").isNotEmpty).toList();

    final hasVerificationScore = faceConfidence != null;
    final hasVerificationMessage = (biometricMessage ?? "").trim().isNotEmpty;
    final hasDecision = (biometricDecision ?? "").isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasVerificationScore || hasDecision || hasVerificationMessage) ...[
          _confidenceSummaryCard(
            title: AppLanguage.t(
              "Score de verification du selfie",
              "نسبة التحقق من السلفي",
            ),
            confidence: faceConfidence,
            subtitle: AppLanguage.t(
              isFaceMatchAccepted
                  ? "Resultat: accepte - seuil requis: %"
                  : "Resultat: refuse - seuil requis: %",
              isFaceMatchAccepted
                  ? "النتيجة: مقبول - الحد المطلوب: %"
                  : "النتيجة: مرفوض - الحد المطلوب: %",
            ),
            color: _faceColor(faceDetected, biometricStatus, faceConfidence),
            icon: isFaceMatchAccepted
                ? Icons.verified_user_outlined
                : Icons.gpp_bad_outlined,
            trailing: [
              if ((biometricDecision ?? "").isNotEmpty)
                AppLanguage.t(
                  "Decision: ",
                  "القرار: ",
                ),
              if ((biometricMessage ?? "").trim().isNotEmpty)
                biometricMessage!.trim(),
            ].join(" "),
          ),
        ],
        if (extractedValues.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            AppLanguage.t("Informations extraites", "المعلومات المستخرجة"),
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...extractedValues.map((entry) => _infoTile(entry.key, entry.value)),
        ],
      ],
    );
  }
  bool _hasRemoteVerificationData() {
    if (kycData == null) return false;

    final extractedKeys = const [
      "nni",
      "prenom",
      "prenom_pere",
      "nom_famille",
      "sexe",
      "date_naissance",
      "lieu_naissance",
    ];

    final hasExtractedValues = extractedKeys.any(
      (key) => (kycData?[key]?.toString().trim() ?? "").isNotEmpty,
    );

    final hasScore =
        _asDouble(kycData?["face_confidence"]) != null ||
        _asDouble(
              kycData?["biometric_summary"] is Map
                  ? Map<String, dynamic>.from(kycData?["biometric_summary"])[
                      "similarity_score"
                    ]
                  : null,
            ) !=
            null;

    final hasMessage =
        (kycData?["biometric_message"]?.toString().trim() ?? "").isNotEmpty;

    return hasExtractedValues || hasScore || hasMessage;
  }

  Widget _confidenceSummaryCard({
    required String title,
    required double? confidence,
    required String subtitle,
    required Color color,
    required IconData icon,
    String? trailing,
  }) {
    final formattedConfidence = confidence == null
        ? "-"
        : "${confidence.toStringAsFixed(confidence == confidence.roundToDouble() ? 0 : 1)}%";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "$title : $formattedConfidence",
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.muted,
              height: 1.35,
            ),
          ),
          if ((trailing ?? "").trim().isNotEmpty) ...[
            const SizedBox(height: 8),
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

  String? _mediaUrl(dynamic rawValue) {
    final value = rawValue?.toString().trim() ?? "";
    if (value.isEmpty) return null;
    if (value.startsWith("http://") || value.startsWith("https://")) {
      return value;
    }

    final base = AppConfig.apiBaseUrl.endsWith("/")
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
    final path = value.startsWith("/") ? value : "/$value";
    return "$base$path";
  }

  Widget _buildPreviewImage({
    required File? image,
    required String? remoteUrl,
    required IconData icon,
  }) {
    if (image != null) {
      return Image.file(image, fit: BoxFit.cover);
    }

    if ((remoteUrl ?? "").isNotEmpty) {
      return Image.network(
        remoteUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: AppColors.panel,
          child: Icon(icon, color: AppColors.muted, size: 48),
        ),
      );
    }

    return Container(
      color: AppColors.panel,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.muted, size: 48),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              AppLanguage.t(
                "Aucune image conservee pour le moment.",
                "لا توجد صورة محفوظة في الوقت الحالي.",
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String title, dynamic value) {
    final text = value?.toString().trim() ?? "";

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.surfaceSoft),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text.isEmpty ? "-" : text,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value == null) return null;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == "true") return true;
    if (normalized == "false") return false;
    return null;
  }

  Color _confidenceColor(double? value) {
    final score = value ?? 0;
    if (score >= 80) return Colors.green.shade700;
    if (score >= 50) return Colors.orange.shade700;
    return Colors.redAccent.shade700;
  }

  Color _faceColor(bool? detected, String status, double? confidence) {
    if (status.toUpperCase() == "VERIFIED") return Colors.green.shade700;
    if (detected == false || status.toUpperCase() == "FAILED") {
      return Colors.redAccent.shade700;
    }
    return _confidenceColor(confidence);
  }

}



