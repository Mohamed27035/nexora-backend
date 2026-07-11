import 'package:flutter/material.dart';

import '../core/localization/app_language.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';

class ResetPasswordOtpScreen extends StatefulWidget {
  const ResetPasswordOtpScreen({super.key});

  @override
  State<ResetPasswordOtpScreen> createState() => _ResetPasswordOtpScreenState();
}

class _ResetPasswordOtpScreenState extends State<ResetPasswordOtpScreen> {
  final otpController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool loading = false;
  bool initialized = false;
  String? demoOtp;
  bool demoMode = false;

  Future<void> verifyOtp(String email) async {
    if (otpController.text.trim().isEmpty) {
      _showMessage(AppLanguage.t('Entrez le code OTP', 'أدخل رمز OTP'));
      return;
    }
    if (passwordController.text.trim().isEmpty || confirmPasswordController.text.trim().isEmpty) {
      _showMessage(AppLanguage.t('Entrez le mot de passe', 'أدخل كلمة المرور'));
      return;
    }
    if (passwordController.text != confirmPasswordController.text) {
      _showMessage(AppLanguage.t('Les mots de passe ne correspondent pas', 'كلمتا المرور غير متطابقتين'));
      return;
    }

    setState(() => loading = true);
    try {
      await AuthService.verifyOtp(
        email: email,
        otp: otpController.text.trim(),
        password: passwordController.text.trim(),
      );
      if (!mounted) return;
      _showMessage(AppLanguage.t('Mot de passe mis à jour avec succès', 'تم تحديث كلمة المرور بنجاح'));
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (_) {
      if (!mounted) return;
      _showMessage(AppLanguage.t('Échec de la vérification OTP', 'فشل التحقق من OTP'));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;

    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    if (rawArgs is Map) {
      demoOtp = rawArgs['otp']?.toString();
      demoMode = rawArgs['demo_mode'] == true;
      if ((demoOtp ?? '').isNotEmpty) {
        otpController.text = demoOtp!;
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final rawArgs = ModalRoute.of(context)!.settings.arguments;
    final email = rawArgs is Map ? (rawArgs['email'] ?? '').toString() : rawArgs.toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(AppLanguage.t('Vérification OTP', 'التحقق من OTP'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (demoMode && (demoOtp ?? '').isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLanguage.t('Mode OTP démo', 'وضع OTP التجريبي'), style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('OTP: $demoOtp', style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            const Icon(Icons.security, size: 90, color: AppColors.text),
            const SizedBox(height: 30),
            Text(AppLanguage.t('Vérification OTP', 'التحقق من OTP'), style: const TextStyle(color: AppColors.text, fontSize: 30, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Text(email, style: const TextStyle(color: AppColors.muted, fontSize: 16)),
            const SizedBox(height: 40),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                hintText: AppLanguage.t('Code OTP', 'رمز OTP'),
                hintStyle: const TextStyle(color: AppColors.muted),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                hintText: AppLanguage.t('Nouveau mot de passe', 'كلمة المرور الجديدة'),
                hintStyle: const TextStyle(color: AppColors.muted),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                hintText: AppLanguage.t('Confirmer le mot de passe', 'تأكيد كلمة المرور'),
                hintStyle: const TextStyle(color: AppColors.muted),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 35),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: loading ? null : () => verifyOtp(email),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(AppLanguage.t('Vérifier OTP', 'التحقق من OTP'), style: const TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    otpController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
