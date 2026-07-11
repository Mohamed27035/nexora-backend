import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/localization/app_language.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/otp_service.dart';
import '../utils/dio_error_utils.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final otpController = TextEditingController();
  bool loading = false;

  Future<void> verifyOtp(String email, {String mode = "welcome"}) async {
    if (otpController.text.trim().isEmpty) {
      _showMessage(AppLanguage.t('Entrez le code OTP', 'أدخل رمز OTP'));
      return;
    }

    setState(() => loading = true);
    try {
      if (mode == "register") {
        await AuthService.verifyRegisterOtp(
          email: email,
          otp: otpController.text.trim(),
        );
      } else {
        await OtpService.verifyWelcomeOtp(
          email: email,
          otp: otpController.text.trim(),
        );
      }
      if (!mounted) return;
      _showMessage(
        mode == "register"
            ? AppLanguage.t(
                'Compte confirmé avec succès. Connectez-vous maintenant.',
                'تم تأكيد الحساب بنجاح. يمكنك تسجيل الدخول الآن.',
              )
            : AppLanguage.t('Vérification réussie', 'تم التحقق بنجاح'),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } on DioException catch (error) {
      if (!mounted) return;
      _showMessage(DioErrorUtils.friendlyMessage(error));
    } catch (_) {
      if (!mounted) return;
      _showMessage(AppLanguage.t('Échec de la vérification OTP', 'فشل التحقق من OTP'));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final rawArgs = ModalRoute.of(context)!.settings.arguments;
    final email = rawArgs is Map ? (rawArgs['email'] ?? '').toString() : rawArgs.toString();
    final mode = rawArgs is Map ? (rawArgs['mode'] ?? 'welcome').toString() : 'welcome';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(AppLanguage.t('Vérification OTP', 'التحقق من OTP'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(Icons.lock_outline, color: Colors.white, size: 50),
            ),
            const SizedBox(height: 25),
            Text(
              mode == "register"
                  ? AppLanguage.t('Confirmer le compte', 'تأكيد الحساب')
                  : AppLanguage.t('Vérification OTP', 'التحقق من OTP'),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              mode == "register"
                  ? AppLanguage.t(
                      'Un code de confirmation a été envoyé à\n$email',
                      'تم إرسال رمز تأكيد إلى\n$email',
                    )
                  : AppLanguage.t('Code envoyé à\n$email', 'تم إرسال الرمز إلى\n$email'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 18),
            ),
            const SizedBox(height: 45),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, letterSpacing: 10),
              decoration: InputDecoration(
                hintText: '------',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: loading ? null : () => verifyOtp(email, mode: mode),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        mode == "register"
                            ? AppLanguage.t('Confirmer le compte', 'تأكيد الحساب')
                            : AppLanguage.t('Vérifier OTP', 'التحقق من OTP'),
                        style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
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
    super.dispose();
  }
}
