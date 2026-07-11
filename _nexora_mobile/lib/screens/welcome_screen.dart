import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/localization/app_language.dart';
import '../core/theme/app_theme.dart';
import '../screens/nova_sso_webview_screen.dart';
import '../services/nova_sso_service.dart';
import '../services/otp_service.dart';
import '../utils/dio_error_utils.dart';
import '../widgets/nexora_logo.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final emailController = TextEditingController();
  bool loading = false;

  Future<void> sendOtp() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _showMessage(AppLanguage.t('Saisissez votre adresse email.', 'أدخل بريدك الإلكتروني.'));
      return;
    }
    setState(() => loading = true);
    try {
      await OtpService.sendOtp(email: email);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_welcome', true);
      if (!mounted) return;
      Navigator.pushNamed(context, '/otp', arguments: email);
    } on DioException catch (error) {
      if (!mounted) return;
      _showMessage(DioErrorUtils.friendlyMessage(error));
    } catch (_) {
      if (!mounted) return;
      _showMessage(AppLanguage.t("Impossible d'envoyer le code OTP.", 'تعذر إرسال رمز OTP.'));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _showNovaDialog() async {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F8FF), Color(0xFFEEF6FF), Color(0xFFF5FBFA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(top: 12, right: 16, child: _languageButton()),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      children: [_heroPanel(), const SizedBox(height: 12), _authPanel()],
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

  Widget _heroPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_outlined, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(AppLanguage.t('Accès sécurisé', 'ولوج آمن'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Center(child: NexoraLogo(size: 52, assetPath: 'assets/logo.png')),
          const SizedBox(height: 8),
          const Center(child: Text('Nexora', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _HeroMetric(icon: Icons.insights_outlined, label: AppLanguage.t('Reporting', 'التقارير')),
              _HeroMetric(icon: Icons.shield_outlined, label: AppLanguage.t('Audit', 'التدقيق')),
              _HeroMetric(icon: Icons.account_balance_wallet_outlined, label: AppLanguage.t('Transactions', 'المعاملات')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _authPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.96), borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFFE4EBF6))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLanguage.t('Choisissez votre méthode', 'اختر طريقتك'), style: const TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          _methodBadge(icon: Icons.mark_email_read_outlined, title: AppLanguage.t('Connexion par OTP', 'الدخول عبر OTP'), subtitle: AppLanguage.t("Rapide, simple et adaptée à l'accès individuel.", 'سريع وبسيط ومناسب للدخول الفردي.'), accent: const Color(0xFFDBEAFE), iconColor: AppColors.primary),
          const SizedBox(height: 14),
          TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(hintText: AppLanguage.t('Adresse email', 'البريد الإلكتروني'), prefixIcon: const Icon(Icons.alternate_email_rounded))),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: loading ? null : sendOtp, icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2)) : const Icon(Icons.arrow_forward_rounded), label: Text(loading ? AppLanguage.t('Envoi en cours...', 'جارٍ الإرسال...') : AppLanguage.t('Continuer avec OTP', 'المتابعة عبر OTP')))),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: loading ? null : _showNovaDialog,
              icon: Container(width: 28, height: 28, decoration: BoxDecoration(color: const Color(0xFF5B5BD6), borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: const Icon(Icons.shield_rounded, size: 18, color: Colors.white)),
              label: Text(AppLanguage.t('Continuer avec Nova SSO', 'المتابعة عبر Nova SSO')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodBadge({required IconData icon, required String title, required String subtitle, required Color accent, required Color iconColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF8FBFF), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE6EDF8))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: iconColor)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.text, fontSize: 15.5, fontWeight: FontWeight.w900)),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13.2, height: 1.45)),
                ],
              ],
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
        return OutlinedButton.icon(onPressed: AppLanguage.toggle, icon: const Icon(Icons.language_outlined, size: 18), label: Text(language == 'ar' ? 'FR' : 'AR'));
      },
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: Colors.white), const SizedBox(width: 8), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))]),
    );
  }
}
