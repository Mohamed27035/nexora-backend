import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

typedef ReceiptTranslator = String Function(String fr, String ar);

Future<void> showTransferReceiptDialog(
  BuildContext context, {
  required ReceiptTranslator tr,
  required Map<String, dynamic> transaction,
}) async {
  final receiverPhone = (transaction['receiver_phone'] ?? '').toString().trim();
  final amountText = _formatAmount(transaction['montant']);
  final receiptId = (transaction['id'] ?? '-').toString();
  final createdAt = _formatDateTime(transaction['created_at']);

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Nexora',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.success, width: 4),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.success,
                  size: 52,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                tr('Transfert reussi', 'تم التحويل بنجاح'),
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              _ReceiptLine(
                label: tr('Numero du destinataire', 'رقم المستفيد'),
                value: receiverPhone.isEmpty ? '-' : receiverPhone,
              ),
              const SizedBox(height: 10),
              _ReceiptLine(
                label: tr('Montant envoye', 'المبلغ المرسل'),
                value: '$amountText MRU',
              ),
              const SizedBox(height: 10),
              _ReceiptLine(
                label: tr('Date et heure', 'التاريخ والوقت'),
                value: createdAt,
              ),
              const SizedBox(height: 10),
              _ReceiptLine(
                label: tr('Reference', 'المرجع'),
                value: '#$receiptId',
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(tr('Terminer', 'إنهاء')),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _formatAmount(dynamic value) {
  final amount = double.tryParse((value ?? '').toString()) ?? 0;
  if (amount == amount.roundToDouble()) {
    return amount.toInt().toString();
  }
  return amount.toStringAsFixed(2);
}

String _formatDateTime(dynamic raw) {
  final text = (raw ?? '').toString().trim();
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return text.isEmpty ? '-' : text;
  final local = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

class _ReceiptLine extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
