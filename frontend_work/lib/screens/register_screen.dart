import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nomController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool loading = false;

  Future<void> register() async {
    final nom = nomController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (nom.isEmpty || email.isEmpty || !email.contains("@")) {
      _showMessage("Verifiez le nom et email");
      return;
    }

    if (password.length < 6) {
      _showMessage("Le mot de passe doit contenir au moins 6 caracteres");
      return;
    }

    if (password != confirmPassword) {
      _showMessage("Les mots de passe ne correspondent pas");
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await AuthService.register(
        nom: nom,
        email: email,
        password: password,
      );

      if (!mounted) return;
      _showMessage("Compte cree. Vous pouvez vous connecter.");
      Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
    } catch (_) {
      if (!mounted) return;
      _showMessage("Impossible de creer le compte");
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
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
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Creer un compte"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nomController,
              style: const TextStyle(color: AppColors.text),
              decoration: _inputDecoration("Nom"),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppColors.text),
              decoration: _inputDecoration("Email"),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: AppColors.text),
              decoration: _inputDecoration("Mot de passe"),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              style: const TextStyle(color: AppColors.text),
              decoration: _inputDecoration("Confirmer le mot de passe"),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: loading ? null : register,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Creer un compte"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.muted),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }
}
