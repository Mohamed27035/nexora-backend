import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../utils/dio_error_utils.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nomController = TextEditingController();
  final prenomController = TextEditingController();
  final emailController = TextEditingController();
  final telephoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool loading = false;

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r"\D"), "");
  }

  bool _isValidPhone(String value) {
    final phone = _normalizePhone(value);
    return phone.length == 8 &&
        (phone.startsWith("2") || phone.startsWith("3") || phone.startsWith("4"));
  }

  Future<void> register() async {
    final nom = nomController.text.trim();
    final prenom = prenomController.text.trim();
    final email = emailController.text.trim();
    final telephone = _normalizePhone(telephoneController.text);
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (nom.isEmpty || email.isEmpty || !email.contains("@")) {
      _showMessage("Verifiez le nom et l'email.");
      return;
    }

    if (prenom.isEmpty) {
      _showMessage("Verifiez le prenom.");
      return;
    }

    if (!_isValidPhone(telephone)) {
      _showMessage(
        "Numero de telephone invalide. Il doit contenir 8 chiffres et commencer par 2, 3 ou 4.",
      );
      return;
    }

    if (password.length < 6) {
      _showMessage("Le mot de passe doit contenir au moins 6 caracteres.");
      return;
    }

    if (password != confirmPassword) {
      _showMessage("Les mots de passe ne correspondent pas.");
      return;
    }

    setState(() => loading = true);

    try {
      await AuthService.sendRegisterOtp(
        nom: nom,
        prenom: prenom,
        email: email,
        telephone: telephone,
        password: password,
      );

      if (!mounted) return;
      _showMessage("Un code OTP a ete envoye a votre adresse email.");
      Navigator.pushNamed(
        context,
        "/otp",
        arguments: {
          "email": email,
          "mode": "register",
        },
      );
    } on DioException catch (e) {
      if (!mounted) return;
      _showMessage(DioErrorUtils.friendlyMessage(e));
    } catch (_) {
      if (!mounted) return;
      _showMessage("Impossible d'envoyer le code OTP.");
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    nomController.dispose();
    prenomController.dispose();
    emailController.dispose();
    telephoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF7FBFF),
              Color(0xFFF5FAF8),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    _topBanner(),
                    const SizedBox(height: 18),
                    _formCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Creer un compte",
            style: TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Rejoignez la plateforme et confirmez d'abord votre email avec un code OTP avant de vous connecter.",
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _formCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.surfaceSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          _sectionTitle("Informations personnelles"),
          const SizedBox(height: 16),
          TextField(
            controller: nomController,
            decoration: _inputDecoration("Nom", Icons.badge_outlined),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: prenomController,
            decoration: _inputDecoration("Prenom", Icons.person_outline),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration("Adresse email", Icons.alternate_email),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: telephoneController,
            keyboardType: TextInputType.phone,
            decoration: _inputDecoration("Telephone", Icons.call_outlined),
          ),
          const SizedBox(height: 22),
          _sectionTitle("Securite du compte"),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: _inputDecoration("Mot de passe", Icons.lock_outline),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: confirmPasswordController,
            obscureText: true,
            decoration: _inputDecoration(
              "Confirmer le mot de passe",
              Icons.verified_user_outlined,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : register,
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    )
                  : const Text("Creer un compte"),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, "/login"),
            child: const Text(
              "Vous avez deja un compte ? Se connecter",
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.muted),
    );
  }
}
