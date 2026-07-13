import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/kyc_service.dart';
import '../../widgets/info_card.dart';

class KycReviewScreen extends StatefulWidget {
  const KycReviewScreen({super.key});

  @override
  State<KycReviewScreen> createState() => _KycReviewScreenState();
}

class _KycReviewScreenState extends State<KycReviewScreen> {
  List requests = [];
  bool loading = true;
  String statusFilter = "ALL";

  List get filteredRequests {
    return requests.where((item) {
      final status = item["status"]?.toString() ?? "";
      return statusFilter == "ALL" || status == statusFilter;
    }).toList();
  }

  Future<void> fetchKyc() async {
    try {
      final response = await KycService.getAllKyc();
      if (!mounted) return;
      setState(() {
        requests = response.data is List ? response.data : response.data["kyc"] ?? [];
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      _showMessage("Impossible de charger KYC");
    }
  }

  Future<void> approve(int id) async {
    try {
      await KycService.approveKyc(id);
      await fetchKyc();
      if (!mounted) return;
      _showMessage("KYC approuve");
    } catch (_) {
      if (!mounted) return;
      _showMessage("Action impossible");
    }
  }

  Future<void> reject(int id) async {
    final reason = await _rejectReason();
    if (reason == null) return;
    try {
      await KycService.rejectKyc(id, reason: reason);
      await fetchKyc();
      if (!mounted) return;
      _showMessage("KYC rejete");
    } catch (_) {
      if (!mounted) return;
      _showMessage("Action impossible");
    }
  }

  Future<String?> _rejectReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Raison du rejet"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Raison"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text("Rejeter"),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    fetchKyc();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("KYC Review")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchKyc,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: statusFilter,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: AppColors.text),
                    items: const [
                      DropdownMenuItem(value: "ALL", child: Text("Tous")),
                      DropdownMenuItem(value: "PENDING", child: Text("Pending")),
                      DropdownMenuItem(value: "APPROVED", child: Text("Approved")),
                      DropdownMenuItem(value: "REJECTED", child: Text("Rejected")),
                    ],
                    onChanged: (value) => setState(() => statusFilter = value ?? "ALL"),
                  ),
                  const SizedBox(height: 16),
                  ...filteredRequests.map(_requestCard),
                ],
              ),
            ),
    );
  }

  Widget _requestCard(dynamic item) {
    final id = item["id"] as int?;
    final status = item["status"]?.toString() ?? "";
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "KYC #${id ?? "-"} - $status",
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _line("User", item["user"] ?? item["user_email"]),
            _line("NNI", item["nni"]),
            _line("Nom", item["nom_famille"]),
            _line("Prenom", item["prenom"]),
            _line("Date naissance", item["date_naissance"]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: id == null ? null : () => approve(id),
                  child: const Text("Approve"),
                ),
                OutlinedButton(
                  onPressed: id == null ? null : () => reject(id),
                  child: const Text("Reject"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        "$label: ${value?.toString() ?? "-"}",
        style: const TextStyle(color: AppColors.muted),
      ),
    );
  }
}
