import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_language.dart';
import '../../core/theme/app_theme.dart';
import '../../models/exported_file.dart';
import '../../services/reporting_service.dart';
import '../../utils/file_utils.dart';
import '../../widgets/info_card.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, dynamic> stats = {};
  Map<String, dynamic> financial = {};
  List chartItems = [];
  bool loading = true;
  String? activeExportKey;

  String tr(String fr, String ar) => AppLanguage.t(fr, ar);

  Future<void> fetchReports() async {
    setState(() => loading = true);
    try {
      final responses = await Future.wait([
        ReportingService.getStats(),
        ReportingService.getFinancialStats(),
        ReportingService.getChartData(),
      ]);

      if (!mounted) return;
      setState(() {
        stats = _asMap(responses[0].data);
        financial = _asMap(responses[1].data);
        chartItems = _asList(responses[2].data);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      _showMessage(tr("Impossible de charger les rapports", "تعذر تحميل التقارير"));
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  List _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data["chart"] is List) return data["chart"];
    if (data is Map && data["data"] is List) return data["data"];
    return [];
  }

  Map<String, dynamic> get _administrativeSection => _asMap(stats["administrative"]);
  Map<String, dynamic> get _financialSection => {
        ..._asMap(stats["financial"]),
        ...financial,
      };
  Map<String, dynamic> get _identitySection => _asMap(stats["kyc"]);
  Map<String, dynamic> get _securitySection => _asMap(stats["security"]);

  List<MapEntry<String, dynamic>> _visibleEntries(Map<String, dynamic> values) {
    return values.entries.where((entry) {
      final value = entry.value;
      if (value == null) return false;
      if (value is Map || value is Iterable) return false;
      return value.toString().trim().isNotEmpty;
    }).toList();
  }

  Future<void> _handleExport({
    required String exportKey,
    required Future<ExportedFile> Function() exportCall,
    required String successLabel,
    required bool openAfterSave,
    bool shareAfterSave = false,
  }) async {
    setState(() => activeExportKey = exportKey);
    try {
      final fileData = await exportCall();
      if (fileData.bytes.isEmpty) {
        throw Exception("Empty file");
      }

      final file = await FileUtils.saveExport(
        bytes: fileData.bytes,
        filename: fileData.filename,
      );

      if (shareAfterSave) {
        await FileUtils.shareFile(
          file,
          subject: successLabel,
          text: tr("Export genere depuis Nexora.", "تم إنشاء التصدير من Nexora."),
        );
      } else if (openAfterSave) {
        final opened = await FileUtils.openFile(file);
        if (!opened) {
          await FileUtils.shareFile(
            file,
            subject: successLabel,
            text: tr("Export genere depuis Nexora.", "تم إنشاء التصدير من Nexora."),
          );
        }
      }

      if (!mounted) return;
      _showMessage("$successLabel ${tr("pret", "جاهز")} : ${file.path}");
    } catch (_) {
      if (!mounted) return;
      _showMessage(tr("Export impossible", "تعذر إنشاء التصدير"));
    } finally {
      if (mounted) {
        setState(() => activeExportKey = null);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _metricLabel(String key) {
    switch (key) {
      case 'total_users':
        return tr('Utilisateurs totaux', 'إجمالي المستخدمين');
      case 'verified_users':
        return tr('Utilisateurs verifies', 'المستخدمون الموثقون');
      case 'suspended_users':
        return tr('Utilisateurs suspendus', 'المستخدمون المعلقون');
      case 'banned_users':
        return tr('Utilisateurs bannis', 'المستخدمون المحظورون');
      case 'admin_users':
        return tr('Administrateurs', 'المسؤولون');
      case 'auditeur_users':
        return tr('Auditeurs', 'المدققون');
      case 'comptable_users':
        return tr('Comptables', 'المحاسبون');
      case 'client_users':
        return tr('Clients', 'العملاء');
      case 'total_transactions':
        return tr('Transactions totales', 'إجمالي المعاملات');
      case 'pending_transactions':
        return tr('Transactions en attente', 'المعاملات المعلقة');
      case 'approved_transactions':
        return tr('Transactions approuvees', 'المعاملات المقبولة');
      case 'rejected_transactions':
        return tr('Transactions rejetees', 'المعاملات المرفوضة');
      case 'total_deposit':
        return tr('Total depots', 'إجمالي الإيداعات');
      case 'total_withdraw':
        return tr('Total retraits', 'إجمالي السحوبات');
      case 'total_transfer':
        return tr('Total transferts', 'إجمالي التحويلات');
      case 'kyc_pending':
        return tr('Identites en attente', 'طلبات الهوية المعلقة');
      case 'kyc_approved':
        return tr('Identites approuvees', 'طلبات الهوية المقبولة');
      case 'kyc_rejected':
        return tr('Identites rejetees', 'طلبات الهوية المرفوضة');
      case 'total_logs':
        return tr('Journaux totaux', 'إجمالي السجلات');
      case 'suspicious_actions':
        return tr('Actions suspectes', 'العمليات المشبوهة');
      case 'critical_actions':
        return tr('Actions critiques', 'العمليات الحرجة');
      case 'sensitive_actions':
        return tr('Actions sensibles', 'العمليات الحساسة');
      default:
        return key
            .replaceAll('_', ' ')
            .split(' ')
            .where((part) => part.isNotEmpty)
            .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
    }
  }

  String _formatMetricValue(dynamic value) {
    if (value is num) {
      final asDouble = value.toDouble();
      if (asDouble == asDouble.roundToDouble()) {
        return asDouble.toInt().toString();
      }
      return asDouble.toStringAsFixed(2);
    }
    return value.toString();
  }

  double _chartValue(dynamic item) {
    if (item is Map) {
      return double.tryParse((item["value"] ?? 0).toString()) ?? 0;
    }
    return double.tryParse(item.toString()) ?? 0;
  }

  String _chartLabel(dynamic item, int index) {
    String raw;
    if (item is Map) {
      raw = (item["label"] ?? item["name"] ?? '#${index + 1}').toString();
    } else {
      raw = '#${index + 1}';
    }

    final key = raw.toLowerCase();
    if (key.contains('verified')) return tr('Verifies', 'موثق');
    if (key.contains('pending')) return tr('En attente', 'معلق');
    if (key.contains('rejected')) return tr('Rejete', 'مرفوض');
    if (key.contains('suspicious')) return tr('Suspect', 'مشبوه');
    if (key.contains('critical')) return tr('Critique', 'حرج');
    if (key.contains('users')) return tr('Utilisateurs', 'مستخدمون');
    if (key.contains('transactions')) return tr('Transactions', 'المعاملات');
    return raw;
  }

  @override
  void initState() {
    super.initState();
    fetchReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Rapports', 'التقارير'))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchReports,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _overviewCard(),
                  const SizedBox(height: 16),
                  _sectionCard(tr('Rapport administratif', 'التقرير الإداري'), _administrativeSection),
                  const SizedBox(height: 16),
                  _sectionCard(tr('Rapport financier', 'التقرير المالي'), _financialSection),
                  const SizedBox(height: 16),
                  _sectionCard(tr("Rapport de vérification d'identité", 'تقرير التحقق من الهوية'), _identitySection),
                  const SizedBox(height: 16),
                  _sectionCard(tr('Rapport securite et audit', 'تقرير الأمن والتدقيق'), _securitySection),
                  const SizedBox(height: 16),
                  _chartCard(),
                  const SizedBox(height: 16),
                  _exportsCard(),
                ],
              ),
            ),
    );
  }

  Widget _overviewCard() {
    final items = [
      {
        'label': tr('Utilisateurs', 'المستخدمون'),
        'value': _administrativeSection['total_users'] ?? 0,
        'color': AppColors.primary,
      },
      {
        'label': tr('Transactions', 'المعاملات'),
        'value': _financialSection['total_transactions'] ?? 0,
        'color': AppColors.success,
      },
      {
        'label': tr('Verifications en attente', 'التحققات المعلقة'),
        'value': _identitySection['kyc_pending'] ?? 0,
        'color': AppColors.warning,
      },
      {
        'label': tr('Suspectes', 'المشبوهة'),
        'value': _securitySection['suspicious_actions'] ?? 0,
        'color': AppColors.danger,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = constraints.maxWidth < 380 ? 1.25 : 1.45;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: ratio,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final label = item['label'].toString();
            final value = item['value'];
            final color = item['color'] as Color;
            return InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value.toString(),
                      style: TextStyle(
                        color: color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sectionCard(String title, Map<String, dynamic> values) {
    final entries = _visibleEntries(values);

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Text(
              tr('Aucune donnee', 'لا توجد بيانات'),
              style: const TextStyle(color: AppColors.muted),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    'Glissez horizontalement pour voir les indicateurs',
                    'اسحب أفقياً لعرض المؤشرات',
                  ),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 132,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: entries.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Container(
                        width: 164,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.panel,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.surfaceSoft.withOpacity(0.85),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _metricLabel(entry.key),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _formatMetricValue(entry.value),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _chartCard() {
    final bars = <BarChartGroupData>[];
    for (var i = 0; i < chartItems.length; i++) {
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: _chartValue(chartItems[i]),
              width: 18,
              borderRadius: BorderRadius.circular(8),
              color: AppColors.primary,
            ),
          ],
        ),
      );
    }

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Graphique des rapports', 'الرسم البياني للتقارير'),
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: bars.isEmpty
                ? Center(
                    child: Text(
                      tr('Aucune donnee pour le graphique', 'لا توجد بيانات للرسم البياني'),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: true, reservedSize: 36),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= chartItems.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: SizedBox(
                                  width: 60,
                                  child: Text(
                                    _chartLabel(chartItems[index], index),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 10,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: bars,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _exportsCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Exportations', 'التصدير'),
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _exportTile(
            title: tr('Rapport PDF', 'تقرير PDF'),
            subtitle: tr(
              'Resume global des rapports administratifs, financiers et de securite.',
              'إنشاء ملف PDF للملخصات الإدارية والمالية.',
            ),
            exportKey: 'report_pdf',
            icon: Icons.picture_as_pdf_outlined,
            color: AppColors.danger,
            onOpen: () => _handleExport(
              exportKey: 'report_pdf',
              exportCall: ReportingService.exportPdfFile,
              successLabel: 'PDF',
              openAfterSave: true,
            ),
            onShare: () => _handleExport(
              exportKey: 'report_pdf_share',
              exportCall: ReportingService.exportPdfFile,
              successLabel: 'PDF',
              openAfterSave: false,
              shareAfterSave: true,
            ),
          ),
          const SizedBox(height: 12),
          _exportTile(
            title: tr('Transactions PDF', 'المعاملات PDF'),
            subtitle: tr(
              tr('Rapport PDF detaille pour l audit des transactions.', 'تقرير PDF مفصل لتدقيق المعاملات.'),
              'تقرير PDF مفصل لتدقيق المعاملات.',
            ),
            exportKey: 'transactions_pdf',
            icon: Icons.receipt_long_outlined,
            color: AppColors.warning,
            onOpen: () => _handleExport(
              exportKey: 'transactions_pdf',
              exportCall: ReportingService.exportTransactionsPdfFile,
              successLabel: tr('Transactions PDF', 'المعاملات PDF'),
              openAfterSave: true,
            ),
            onShare: () => _handleExport(
              exportKey: 'transactions_pdf_share',
              exportCall: ReportingService.exportTransactionsPdfFile,
              successLabel: tr('Transactions PDF', 'المعاملات PDF'),
              openAfterSave: false,
              shareAfterSave: true,
            ),
          ),
          const SizedBox(height: 12),
          _exportTile(
            title: tr('Transactions Excel', 'المعاملات Excel'),
            subtitle: tr(
              tr('Export XLSX pour l analyse, le controle et l audit.', 'تصدير XLSX للتحليل والمراقبة والتدقيق.'),
              'تصدير XLSX للتحليل والمراقبة والتدقيق.',
            ),
            exportKey: 'transactions_excel',
            icon: Icons.table_view_outlined,
            color: AppColors.success,
            onOpen: () => _handleExport(
              exportKey: 'transactions_excel',
              exportCall: ReportingService.exportTransactionsExcelFile,
              successLabel: 'Excel',
              openAfterSave: true,
            ),
            onShare: () => _handleExport(
              exportKey: 'transactions_excel_share',
              exportCall: ReportingService.exportTransactionsExcelFile,
              successLabel: 'Excel',
              openAfterSave: false,
              shareAfterSave: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _exportTile({
    required String title,
    required String subtitle,
    required String exportKey,
    required IconData icon,
    required Color color,
    required Future<void> Function() onOpen,
    required Future<void> Function() onShare,
  }) {
    final isLoadingThis = activeExportKey == exportKey || activeExportKey == '${exportKey}_share';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
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
                      title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isLoadingThis ? null : onOpen,
                  icon: isLoadingThis
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                  label: Text(tr('Enregistrer et ouvrir', 'حفظ وفتح')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoadingThis ? null : onShare,
                  icon: const Icon(Icons.share_outlined),
                  label: Text(tr('Partager', 'مشاركة')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


