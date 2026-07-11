import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/localization/app_language.dart';
import '../core/theme/app_theme.dart';
import '../services/profile_service.dart';
import '../utils/dio_error_utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final nomController = TextEditingController();
  final prenomController = TextEditingController();
  final telephoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool loading = true;
  String? activeSection;

  String avatar = "";
  String email = "";
  String role = "";
  String roleLabel = "";
  String status = "";
  String lastLogin = "";
  String lastIp = "";
  bool isVerified = false;

  File? selectedImage;

  String tr(String fr, String ar) => AppLanguage.t(fr, ar);

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r"\D"), "");
  }

  bool _isValidPhone(String value) {
    final phone = _normalizePhone(value);
    return phone.length == 8 &&
        (phone.startsWith("2") || phone.startsWith("3") || phone.startsWith("4"));
  }

  bool _isSaving(String section) => activeSection == section;

  Future<void> fetchProfile() async {
    try {
      final response = await ProfileService.getProfile();
      final data = response.data;

      nomController.text = data["nom"] ?? "";
      prenomController.text = data["prenom"] ?? "";
      telephoneController.text = data["telephone"] ?? "";

      setState(() {
        avatar = data["avatar"] ?? "";
        email = data["email"] ?? "";
        role = data["role"] ?? "";
        roleLabel = data["role_label"] ?? role;
        status = data["status"] ?? "ACTIVE";
        isVerified = data["is_verified"] == true;
        lastLogin = data["last_login"]?.toString() ?? "";
        lastIp = data["last_ip"] ?? "";
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _showMessage(_friendlyError(e));
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        selectedImage = File(picked.path);
      });
    }
  }

  Future<void> saveAvatar() async {
    if (selectedImage == null) {
      _showMessage(tr("Choisissez une image d'abord.", "اختر صورة أولاً."));
      return;
    }

    setState(() => activeSection = "avatar");
    try {
      await ProfileService.uploadAvatar(selectedImage!);
      if (!mounted) return;
      _showMessage(tr("La photo de profil a ete mise a jour.", "تم تحديث صورة الملف الشخصي."));
      setState(() => selectedImage = null);
      await fetchProfile();
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => activeSection = null);
      }
    }
  }

  Future<void> saveIdentity() async {
    final nom = nomController.text.trim();
    final prenom = prenomController.text.trim();

    if (nom.isEmpty) {
      _showMessage(tr("Le nom est obligatoire.", "الاسم العائلي مطلوب."));
      return;
    }

    setState(() => activeSection = "identity");
    try {
      await ProfileService.updateProfile(
        nom: nom,
        prenom: prenom,
      );
      if (!mounted) return;
      _showMessage(tr("Le nom a ete mis a jour.", "تم تحديث الاسم."));
      await fetchProfile();
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => activeSection = null);
      }
    }
  }

  Future<void> savePhone() async {
    final telephone = _normalizePhone(telephoneController.text);
    if (!_isValidPhone(telephone)) {
      _showMessage(
        tr(
          "Numero invalide. Il doit contenir 8 chiffres et commencer par 2, 3 ou 4.",
          "رقم غير صالح. يجب أن يتكون من 8 أرقام ويبدأ بـ 2 أو 3 أو 4.",
        ),
      );
      return;
    }

    setState(() => activeSection = "phone");
    try {
      await ProfileService.updateProfile(telephone: telephone);
      if (!mounted) return;
      _showMessage(tr("Le numero a ete mis a jour.", "تم تحديث الرقم."));
      await fetchProfile();
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => activeSection = null);
      }
    }
  }

  Future<void> savePassword() async {
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (password.isEmpty) {
      _showMessage(tr("Entrez le nouveau mot de passe.", "أدخل كلمة المرور الجديدة."));
      return;
    }

    if (password.length < 6) {
      _showMessage(
        tr(
          "Le mot de passe doit contenir au moins 6 caracteres.",
          "يجب أن تحتوي كلمة المرور على 6 أحرف على الأقل.",
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      _showMessage(
        tr(
          "La confirmation du mot de passe ne correspond pas.",
          "تأكيد كلمة المرور غير مطابق.",
        ),
      );
      return;
    }

    setState(() => activeSection = "password");
    try {
      await ProfileService.updateProfile(password: password);
      passwordController.clear();
      confirmPasswordController.clear();
      if (!mounted) return;
      _showMessage(tr("Le mot de passe a ete mis a jour.", "تم تحديث كلمة المرور."));
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => activeSection = null);
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      return DioErrorUtils.friendlyMessage(error);
    }
    return tr("Une erreur est survenue.", "حدث خطأ غير متوقع.");
  }

  String _translateRole(String value) {
    final normalized = value.trim().toUpperCase();
    switch (normalized) {
      case 'ADMIN':
      case 'ADMINISTRATEUR':
        return tr('Administrateur', 'مسؤول');
      case 'AUDITEUR':
        return tr('Auditeur', 'مدقق');
      case 'COMPTABLE':
        return tr('Comptable', 'محاسب');
      case 'CLIENT':
        return tr('Client', 'عميل');
      default:
        return value.isEmpty ? '-' : value;
    }
  }

  String _translateStatus(String value) {
    final normalized = value.trim().toUpperCase();
    switch (normalized) {
      case 'ACTIVE':
        return tr('Actif', 'نشط');
      case 'INACTIVE':
        return tr('Inactif', 'غير نشط');
      case 'SUSPENDED':
        return tr('Suspendu', 'معلق');
      case 'BANNED':
        return tr('Banni', 'محظور');
      case 'VERIFIED':
        return tr('Vérifié', 'موثق');
      case 'PENDING':
        return tr('En attente', 'قيد الانتظار');
      default:
        return value.isEmpty ? '-' : value;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  @override
  void dispose() {
    nomController.dispose();
    prenomController.dispose();
    telephoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr("Profil", "الملف الشخصي"))),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _headerCard(),
                    const SizedBox(height: 18),
                    _statusCard(),
                    const SizedBox(height: 18),
                    _identityCard(),
                    const SizedBox(height: 18),
                    _phoneCard(),
                    const SizedBox(height: 18),
                    _passwordCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _headerCard() {
    final displayName = "${prenomController.text} ${nomController.text}".trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: pickImage,
            child: CircleAvatar(
              radius: 46,
              backgroundColor: Colors.white.withValues(alpha: 0.20),
              backgroundImage: selectedImage != null
                  ? FileImage(selectedImage!)
                  : avatar.isNotEmpty
                      ? NetworkImage(avatar) as ImageProvider
                      : null,
              child: selectedImage == null && avatar.isEmpty
                  ? const Icon(Icons.person, size: 48, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            displayName.isEmpty ? tr("Utilisateur", "مستخدم") : displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            email,
            style: const TextStyle(color: Colors.white, fontSize: 14.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _isSaving("avatar") ? null : pickImage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                icon: const Icon(Icons.image_outlined),
                label: Text(tr("Choisir une photo", "اختيار صورة")),
              ),
              ElevatedButton.icon(
                onPressed: _isSaving("avatar") ? null : saveAvatar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                ),
                icon: _isSaving("avatar")
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving("avatar") ? tr("Envoi...", "جارٍ الإرسال...") : tr("Enregistrer", "حفظ")),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceSoft),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _miniStat(tr("Role", "الدور"), _translateRole(roleLabel), AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _miniStat(tr("Statut", "الحالة"), _translateStatus(status), AppColors.warning)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  tr("Verifie", "موثق"),
                  isVerified ? tr("Oui", "نعم") : tr("Non", "لا"),
                  isVerified ? AppColors.success : AppColors.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _miniStat(
                  tr("Derniere IP", "آخر عنوان IP"),
                  lastIp.isEmpty ? "-" : lastIp,
                  AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              "${tr("Derniere connexion", "آخر تسجيل دخول")} : ${lastLogin.isEmpty ? "-" : lastLogin}",
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _identityCard() {
    return _sectionCard(
      title: tr("Nom et prenom", "الاسم الشخصي"),
      child: Column(
        children: [
          _field(tr("Nom", "اللقب"), nomController, Icons.badge_outlined),
          const SizedBox(height: 14),
          _field(tr("Prenom", "الاسم"), prenomController, Icons.person_outline),
          const SizedBox(height: 18),
          _sectionButton(
            onPressed: _isSaving("identity") ? null : saveIdentity,
            label: _isSaving("identity")
                ? tr("Enregistrement...", "جارٍ الحفظ...")
                : tr("Enregistrer le nom", "حفظ الاسم"),
          ),
        ],
      ),
    );
  }

  Widget _phoneCard() {
    return _sectionCard(
      title: tr("Numero de telephone", "رقم الهاتف"),
      child: Column(
        children: [
          _field(tr("Telephone", "الهاتف"), telephoneController, Icons.call_outlined),
          const SizedBox(height: 18),
          _sectionButton(
            onPressed: _isSaving("phone") ? null : savePhone,
            label: _isSaving("phone")
                ? tr("Enregistrement...", "جارٍ الحفظ...")
                : tr("Enregistrer le numero", "حفظ الرقم"),
          ),
        ],
      ),
    );
  }

  Widget _passwordCard() {
    return _sectionCard(
      title: tr("Mot de passe", "كلمة المرور"),
      child: Column(
        children: [
          _field(
            tr("Nouveau mot de passe", "كلمة المرور الجديدة"),
            passwordController,
            Icons.lock_outline,
            obscureText: true,
          ),
          const SizedBox(height: 14),
          _field(
            tr("Confirmer le mot de passe", "تأكيد كلمة المرور"),
            confirmPasswordController,
            Icons.verified_user_outlined,
            obscureText: true,
          ),
          const SizedBox(height: 18),
          _sectionButton(
            onPressed: _isSaving("password") ? null : savePassword,
            label: _isSaving("password")
                ? tr("Mise a jour...", "جارٍ التحديث...")
                : tr("Mettre a jour le mot de passe", "تحديث كلمة المرور"),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.surfaceSoft),
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
          if (subtitle != null && subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.muted,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _sectionButton({
    required VoidCallback? onPressed,
    required String label,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: label,
        prefixIcon: Icon(icon, color: AppColors.muted),
      ),
    );
  }
}


