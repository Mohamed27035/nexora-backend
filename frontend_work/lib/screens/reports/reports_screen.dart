import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/reporting_service.dart';
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

  Future<void> fetchReports() async {
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
      _showMessage("Impossible de charger les rapports");
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  List _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data["data"] is List) return data["data"];
    if (data is Map && data["chart"] is List) return data["chart"];
    return data is Map ? data.entries.toList() : [];
  }

  Future<void> callExport(Future Function() exportCall, String label) async {
    try {
      await exportCall();
      if (!mounted) return;
      _showMessage("$label genere cote backend");
    } catch (_) {
      if (!mounted) return;
      _showMessage("Export impossible");
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    fetchReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reporting")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchReports,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _statsGrid(stats),
                  const SizedBox(height: 16),
                  _chartCard(),
                  const SizedBox(height: 16),
                  _financialCard(),
                  const SizedBox(height: 16),
                  _exportsCard(),
                ],
              ),
            ),
    );
  }

  Widget _statsGrid(Map<String, dynamic> data) {
    final entries = data.entries.take(6).toList();
    if (entries.isEmpty) {
      return const InfoCard(
        child: Text("Aucune statistique", style: TextStyle(color: AppColors.muted)),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.7,
      ),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                entry.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              Text(
                entry.value.toString(),
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chartCard() {
    final spots = <FlSpot>[];
    for (var i = 0; i < chartItems.length; i++) {
      final item = chartItems[i];
      final value = item is Map
          ? double.tryParse((item["value"] ?? item["count"] ?? item["total"] ?? 0).toString())
          : double.tryParse(item.toString());
      spots.add(FlSpot(i.toDouble(), value ?? 0));
    }

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Charts",
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: spots.isEmpty
                ? const Center(
                    child: Text(
                      "Aucune donnee chart",
                      style: TextStyle(color: AppColors.muted),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: const Color(0xFF38BDF8),
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _financialCard() {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Financial Stats",
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (financial.isEmpty)
            const Text("Aucune donnee", style: TextStyle(color: AppColors.muted))
          else
            ...financial.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "${entry.key}: ${entry.value}",
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _exportsCard() {
    return InfoCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton(
            onPressed: () => callExport(ReportingService.exportPdf, "PDF"),
            child: const Text("Export PDF"),
          ),
          ElevatedButton(
            onPressed: () => callExport(
              ReportingService.exportTransactionsPdf,
              "Transactions PDF",
            ),
            child: const Text("Transactions PDF"),
          ),
          ElevatedButton(
            onPressed: () => callExport(
              ReportingService.exportTransactionsExcel,
              "Transactions Excel",
            ),
            child: const Text("Excel"),
          ),
        ],
      ),
    );
  }
}
