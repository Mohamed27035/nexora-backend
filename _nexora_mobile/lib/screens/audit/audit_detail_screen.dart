import 'package:flutter/material.dart';

import '../../core/localization/app_language.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/info_card.dart';

class AuditDetailScreen extends StatelessWidget {
  String tr(String fr, String ar) => AppLanguage.t(fr, ar);
  final Map<String, dynamic> logItem;

  const AuditDetailScreen({
    super.key,
    required this.logItem,
  });

  Color _severityColor(String value) {
    switch (value.toUpperCase()) {
      case "CRITICAL":
        return AppColors.danger;
      case "WARNING":
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  Widget _detailRow(String label, dynamic value) {
    final text = value == null || value.toString().trim().isEmpty ? "-" : value.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final severity = (logItem["severity"] ?? "INFO").toString();
    final metadata = logItem["metadata"];
    final metadataText = metadata is Map && metadata.isNotEmpty ? metadata.toString() : "-";

    return Scaffold(
      appBar: AppBar(
        title: Text(tr("Audit Details", "تفاصيل التدقيق")),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (logItem["action"] ?? "Audit").toString(),
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _severityColor(severity).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        severity,
                        style: TextStyle(
                          color: _severityColor(severity),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _detailRow(tr("Auteur", "المنفذ"), logItem["user"]),
                _detailRow(tr("Email de l'auteur", "بريد المنفذ"), logItem["user_email"]),
                _detailRow(tr("Action", "العملية"), logItem["action"]),
                _detailRow(tr("Sensible", "حساس"), (logItem["is_sensitive"] == true) ? tr("Oui", "نعم") : tr("Non", "لا")),
                _detailRow(tr("Suspect", "مشبوه"), (logItem["is_suspicious"] == true) ? tr("Oui", "نعم") : tr("Non", "لا")),
                _detailRow(tr("Type d'entite", "نوع الكيان"), logItem["entity_type"]),
                _detailRow(tr("Identifiant de l'entite", "معرف الكيان"), logItem["entity_id"]),
                _detailRow(tr("Cible", "الهدف"), logItem["target_repr"]),
                _detailRow(tr("Date", "التاريخ"), logItem["date"]),
                _detailRow(tr("Description", "الوصف"), logItem["description"]),
                _detailRow(tr("Metadonnees", "البيانات الوصفية"), metadataText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

