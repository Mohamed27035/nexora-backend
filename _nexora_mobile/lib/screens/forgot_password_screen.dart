import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/localization/app_language.dart';
import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../utils/dio_error_utils.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();
  bool loading = false;

  Future<void> sendOtp() async {
    if (emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLanguage.t("Saisissez votre email", "أدخل بريدك الإلكتروني"),
          ),
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final response = await AuthService.sendOtp(
        email: emailController.text.trim(),
      );

      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data)
          : <String, dynamic>{};

      final demoOtp = data["otp"]?.toString();
      final demoMode = data["demo_mode"] == true;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLanguage.t("OTP envoyé avec succès", "تم إرسال رمز OTP بنجاح"),
            ),
          ),
        );

        Navigator.pushNamed(
          context,
          "/reset-password-otp",
          arguments: {
            "email": emailController.text.trim(),
            "otp": demoOtp,
            "demo_mode": demoMode,
          },
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DioErrorUtils.friendlyMessage(e))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLanguage.t(
              "Échec de l'envoi du code OTP",
              "فشل إرسال رمز OTP",
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppLanguage.t("Mot de passe oublié", "نسيت كلمة المرور"),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_reset,
                size: 90,
                color: AppColors.text,
              ),
              const SizedBox(height: 30),
              Text(
                AppLanguage.t("Réinitialiser le mot de passe", "إعادة تعيين كلمة المرور"),
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Text(
                AppLanguage.t(
                  "Saisissez votre email pour recevoir le code OTP",
                  "أدخل بريدك الإلكتروني لاستلام رمز OTP",
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: emailController,
                style: const TextStyle(color: AppColors.text),
                decoration: InputDecoration(
                  hintText: AppLanguage.t("Email", "البريد الإلكتروني"),
                  hintStyle: const TextStyle(color: AppColors.muted),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: loading ? null : sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          AppLanguage.t("Envoyer OTP", "إرسال OTP"),
                          style: const TextStyle(fontSize: 18),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
