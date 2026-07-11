import 'package:flutter/material.dart';

import '../core/localization/app_language.dart';
import '../core/theme/app_theme.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLanguage.t('Contact', 'اتصل بنا'))),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF7FBFF),
              Color(0xFFFFF9F4),
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
              _topBanner(),
              const SizedBox(height: 18),
              _introCard(),
              const SizedBox(height: 18),
              _ContactMethodCard(
                icon: Icons.call_rounded,
                color: AppColors.primary,
                title: AppLanguage.t('Appel telephonique', 'اتصال هاتفي'),
                subtitle: AppLanguage.t(
                  'Pour un contact direct avec les responsables.',
                  'للتواصل المباشر مع المسؤولين.',
                ),
                value: '+22249490089',
              ),
              const SizedBox(height: 14),
              _ContactMethodCard(
                icon: Icons.chat_rounded,
                color: AppColors.success,
                title: 'WhatsApp',
                subtitle: AppLanguage.t(
                  'Pour une communication rapide et le suivi des demandes.',
                  'للتواصل السريع ومتابعة الطلبات.',
                ),
                value: '+22249490080',
              ),
              const SizedBox(height: 14),
              _ContactMethodCard(
                icon: Icons.alternate_email_rounded,
                color: AppColors.accent,
                title: AppLanguage.t('Email', 'البريد الإلكتروني'),
                subtitle: AppLanguage.t(
                  'Pour les demandes detaillees et la communication formelle.',
                  'للطلبات المفصلة والمراسلات الرسمية.',
                ),
                value: 'mohamed27035@gmail.com',
              ),
              const SizedBox(height: 18),
              _availabilityCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1D4ED8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLanguage.t('Besoin d aide ?', 'هل تحتاج إلى مساعدة؟'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLanguage.t(
              'Choisissez le canal de communication qui vous convient pour toute demande d information, assistance ou suivi.',
              'اختر وسيلة التواصل المناسبة لك لأي استفسار أو مساعدة أو متابعة.',
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

  Widget _introCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.support_agent, color: AppColors.warning, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLanguage.t(
                'Vous pouvez nous contacter pour les questions liees a l inscription, a la verification d identite, aux transactions, a l administration ou a l utilisation generale de l application.',
                'يمكنك التواصل معنا بخصوص التسجيل، والتحقق من الهوية، والمعاملات، والإدارة، أو الاستخدام العام للتطبيق.',
              ),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 14.5,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _availabilityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.surfaceSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLanguage.t('Canaux disponibles', 'وسائل التواصل المتاحة'),
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            AppLanguage.t(
              'Telephone pour l echange direct, WhatsApp pour la rapidite, et email pour les demandes plus detaillees.',
              'الهاتف للتواصل المباشر، وواتساب للسرعة، والبريد الإلكتروني للطلبات الأكثر تفصيلًا.',
            ),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactMethodCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String value;

  const _ContactMethodCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
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
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
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
      ),
    );
  }
}
