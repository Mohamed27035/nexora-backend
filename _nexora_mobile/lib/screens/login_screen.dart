import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/localization/app_language.dart';
import '../core/theme/app_theme.dart';
import '../screens/nova_sso_webview_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/dashboard_service.dart';
import '../services/nova_sso_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/dio_error_utils.dart';
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
    final password = passwordController.text.trim();
    if (email.isEmpty || !email.contains('@') || password.isEmpty) {
      _showMessage(AppLanguage.t("Vérifiez l'email et le mot de passe.", "تحقق من البريد الإلكتروني وكلمة المرور."));
      return;
    }
    setState(() => loading = true);
    try {
      final response = await AuthService.login(email: email, password: password);
      final token = response.data['access']?.toString();
      var role = response.data['user']?['role']?.toString().toUpperCase() ?? '';
      if (token == null || token.isEmpty) throw Exception('missing_token');
      await SecureStorageService.saveSession(token: token, role: role);
      await ApiService.setAuthToken();
      if (role.isEmpty) {
        try {
          final profile = await DashboardService.getProfile();
          final fetchedRole = profile.data['role']?.toString().toUpperCase() ?? '';
          if (fetchedRole.isNotEmpty) {
            role = fetchedRole;
            await SecureStorageService.saveSession(token: token, role: role);
          }
        } catch (_) {}
      }
      if (!mounted) return;
      _showMessage(AppLanguage.t('Connexion réussie.', 'تم تسجيل الدخول بنجاح.'));
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
    } on DioException catch (error) {
      if (!mounted) return;
      final status = error.response?.statusCode;
      _showMessage((status == 400 || status == 401)
          ? AppLanguage.t('Email ou mot de passe incorrect.', 'البريد الإلكتروني أو كلمة المرور غير صحيحة.')
          : DioErrorUtils.friendlyMessage(error));
    } catch (_) {
      if (!mounted) return;
      _showMessage(AppLanguage.t('Erreur de connexion.', 'حدث خطأ أثناء تسجيل الدخول.'));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _startNovaSso() async {
    setState(() => loading = true);
    try {
      final config = await NovaSsoService.prepareAuthorization();
      if (!mounted) return;
      final success = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => NovaSsoWebViewScreen(
            authorizationUrl: config['authorization_url']!,
            callbackUrl: config['redirect_uri']!,
            expectedState: config['state']!,
          ),
        ),
      );
      if (success == true && mounted) {
        _showMessage(AppLanguage.t('Connexion Nova réussie.', 'تم تسجيل الدخول عبر Nova بنجاح.'));
        Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
      }
    } on DioException catch (error) {
      if (!mounted) return;
      _showMessage(DioErrorUtils.friendlyMessage(error));
    } catch (_) {
      if (!mounted) return;
      _showMessage(AppLanguage.t('Impossible de démarrer Nova SSO.', 'تعذر تشغيل Nova SSO.'));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7FAFF), Color(0xFFF2F7F7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(top: 12, right: 16, child: _languageButton()),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      children: [_heroHeader(), const SizedBox(height: 20), _loginCard()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const NexoraLogo(size: 78, assetPath: 'assets/logo.png'),
          const SizedBox(height: 16),
          const Text('Nexora', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
            AppLanguage.t("", ''),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _loginCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.surfaceSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLanguage.t('Connexion', 'تسجيل الدخول'), style: const TextStyle(color: AppColors.text, fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(AppLanguage.t('', ''), style: const TextStyle(color: AppColors.muted, fontSize: 14.5, height: 1.55)),
          const SizedBox(height: 22),
          TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: _inputDecoration(AppLanguage.t('Adresse email', 'البريد الإلكتروني'), Icons.alternate_email)),
          const SizedBox(height: 16),
          TextField(controller: passwordController, obscureText: true, onSubmitted: (_) => loading ? null : login(), decoration: _inputDecoration(AppLanguage.t('Mot de passe', 'كلمة المرور'), Icons.lock_outline)),
          const SizedBox(height: 22),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: loading ? null : login, child: loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4)) : Text(AppLanguage.t('Se connecter', 'تسجيل الدخول')))),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF7FAFF), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFDCE7FF))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLanguage.t('Connexion entreprise', 'دخول المؤسسة'), style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : _startNovaSso,
                    icon: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: const Color(0xFF5B5BD6), borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: const Icon(Icons.shield_rounded, size: 18, color: Colors.white),
                    ),
                    label: Text(AppLanguage.t('Continuer avec Nova SSO', 'المتابعة عبر Nova SSO')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(child: TextButton(onPressed: () => Navigator.pushNamed(context, '/forgot-password'), child: Text(AppLanguage.t('Mot de passe oublié ?', 'هل نسيت كلمة المرور؟'), style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)))),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                const Icon(Icons.person_add_alt_1_outlined, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(child: Text(AppLanguage.t("Vous n'avez pas encore de compte ?", 'ليس لديك حساب بعد؟'), style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800))),
                TextButton(onPressed: () => Navigator.pushNamed(context, '/register'), child: Text(AppLanguage.t('Créer', 'إنشاء'))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) => InputDecoration(hintText: hint, prefixIcon: Icon(icon));

  Widget _languageButton() {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.notifier,
      builder: (context, language, _) {
        return OutlinedButton.icon(
          onPressed: AppLanguage.toggle,
          icon: const Icon(Icons.language_outlined, size: 18),
          label: Text(language == 'ar' ? 'FR' : 'AR'),
        );
      },
    );
  }
}
