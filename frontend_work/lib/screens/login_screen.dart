import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../core/config/app_config.dart';
import '../core/localization/app_language.dart';
import '../core/theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/secure_storage_service.dart';
import '../widgets/nexora_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || !email.contains("@") || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Verifiez email et mot de passe")),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final response = await AuthService.login(
        email: email,
        password: password,
      );

      final token = response.data["access"]?.toString();
      final role =
          response.data["user"]?["role"]?.toString().toUpperCase() ?? "";

      if (token == null || token.isEmpty) {
        throw Exception("Token manquant");
      }

      await SecureStorageService.saveSession(token: token, role: role);
      await ApiService.setAuthToken();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connexion reussie")),
      );
      Navigator.pushNamedAndRemoveUntil(context, "/dashboard", (route) => false);
    } on DioException catch (error) {
      if (!mounted) return;
      final message = error.response?.statusCode == 401 ||
              error.response?.statusCode == 400
          ? "Email ou mot de passe incorrect"
          : "Connexion au backend impossible";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur de connexion")),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: 44,
            right: 18,
            child: _languageButton(),
          ),
          Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const NexoraLogo(size: 82),
                const SizedBox(height: 10),
                const Text(
                  "Reporting - Audit - Administration",
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Backend USB: ${AppConfig.apiBaseUrl}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: AppColors.text),
                  decoration: _inputDecoration("Email"),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  onSubmitted: (_) => loading ? null : login(),
                  style: const TextStyle(color: AppColors.text),
                  decoration: _inputDecoration(AppLanguage.t("Mot de passe", "\u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631")),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: loading ? null : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(AppLanguage.t("Login", "\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644"), style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, "/forgot-password"),
                  child: Text(
                    AppLanguage.t("Mot de passe oublie ?", "\u0646\u0633\u064a\u062a \u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631\u061f"),
                    style: const TextStyle(color: AppColors.muted, fontSize: 16),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, "/register"),
                  child: Text(
                    AppLanguage.t("Creer un compte", "\u0625\u0646\u0634\u0627\u0621 \u062d\u0633\u0627\u0628"),
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
        ],
      ),
    );
  }

  Widget _languageButton() {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.notifier,
      builder: (context, language, _) {
        return OutlinedButton(
          onPressed: AppLanguage.toggle,
          child: Text(language == "ar" ? "FR" : "AR"),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.muted),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.surfaceSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    );
  }
}
