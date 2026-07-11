import 'package:flutter/material.dart';

import '../core/localization/app_language.dart';
import '../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLanguage.t('A propos', 'حول التطبيق'))),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF8FBFF),
              Color(0xFFF8F5FF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _heroCard(),
              const SizedBox(height: 18),
              _contentCard(
                title: AppLanguage.t('Presentation', 'تقديم'),
                child: Text(
                  AppLanguage.t(
                    'Nexora est une plateforme fintech orientee vers l administration, le reporting, l audit, la securite et la verification d identite. Elle aide a suivre les utilisateurs, les transactions et les operations sensibles dans une interface claire et moderne.',
                    'Nexora منصة مالية موجهة للإدارة والتقارير والتدقيق والأمان والتحقق من الهوية. تساعد المنصة على متابعة المستخدمين والمعاملات والعمليات الحساسة داخل واجهة حديثة ومنظمة.',
                  ),
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    height: 1.65,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _contentCard(
                title: AppLanguage.t('Ce que l application permet', 'ما الذي يتيحه التطبيق'),
                child: Column(
                  children: [
                    _FeatureTile(
                      icon: Icons.verified_user_outlined,
                      color: AppColors.warning,
                      title: AppLanguage.t('Verification d identite', 'التحقق من الهوية'),
                      subtitle: AppLanguage.t(
                        'Collecte des documents, selfie, extraction OCR et validation administrative.',
                        'جمع الوثائق والصورة الشخصية واستخراج بيانات البطاقة ثم التحقق الإداري.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _FeatureTile(
                      icon: Icons.swap_horiz,
                      color: AppColors.primary,
                      title: AppLanguage.t('Gestion des transactions', 'إدارة المعاملات'),
                      subtitle: AppLanguage.t(
                        'Suivi des depots, retraits et transferts avec controle des etats et historique.',
                        'متابعة الإيداعات والسحوبات والتحويلات مع مراقبة الحالات والسجل.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _FeatureTile(
                      icon: Icons.receipt_long_outlined,
                      color: AppColors.danger,
                      title: AppLanguage.t('Audit et reporting', 'التدقيق والتقارير'),
                      subtitle: AppLanguage.t(
                        'Tracabilite des actions sensibles, tableaux de bord et indicateurs utiles.',
                        'تتبع العمليات الحساسة ولوحات القيادة والمؤشرات المفيدة.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _contentCard(
                title: AppLanguage.t('Assistance et responsables', 'الدعم والمسؤولون'),
                child: Column(
                  children: [
                    _ContactRow(
                      icon: Icons.call_outlined,
                      color: AppColors.primary,
                      label: AppLanguage.t('Telephone', 'الهاتف'),
                      value: '+22249490089',
                    ),
                    SizedBox(height: 12),
                    _ContactRow(
                      icon: Icons.chat_bubble_outline,
                      color: AppColors.success,
                      label: AppLanguage.t('WhatsApp', 'واتساب'),
                      value: '+22249490080',
                    ),
                    SizedBox(height: 12),
                    _ContactRow(
                      icon: Icons.email_outlined,
                      color: AppColors.accent,
                      label: AppLanguage.t('Email', 'البريد الإلكتروني'),
                      value: 'mohamed27035@gmail.com',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _supportNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2563EB),
            Color(0xFF14B8A6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _HeroBadge(icon: Icons.shield_outlined),
              SizedBox(width: 10),
              _HeroBadge(icon: Icons.analytics_outlined),
              SizedBox(width: 10),
              _HeroBadge(icon: Icons.account_balance_wallet_outlined),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Nexora',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLanguage.t(
              'Plateforme fintech pour l administration, l audit, le reporting et la gestion securisee des operations.',
              'منصة مالية للإدارة والتدقيق والتقارير والتسيير الآمن للعمليات.',
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contentCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _supportNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.surfaceSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLanguage.t(
                'Pour toute difficulte liee a l inscription, a la verification d identite, aux transactions ou a l administration, contactez les responsables par telephone, WhatsApp ou email.',
                'إذا واجهت أي صعوبة متعلقة بالتسجيل أو التحقق من الهوية أو المعاملات أو الإدارة، فتواصل مع المسؤولين عبر الهاتف أو واتساب أو البريد الإلكتروني.',
              ),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final IconData icon;

  const _HeroBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _ContactRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
