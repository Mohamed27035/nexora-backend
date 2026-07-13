import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/secure_storage_service.dart';
import '../services/transaction_service.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final montantController = TextEditingController();
  final noteController = TextEditingController();
  final searchController = TextEditingController();

  List transactions = [];
  bool loading = true;
  bool creating = false;
  String type = "DEPOSIT";
  String statusFilter = "ALL";
  String typeFilter = "ALL";
  String role = "";

  List get filteredTransactions {
    final query = searchController.text.trim().toLowerCase();
    return transactions.where((transaction) {
      final matchesType = typeFilter == "ALL" || transaction["type"] == typeFilter;
      final matchesStatus =
          statusFilter == "ALL" || transaction["status"] == statusFilter;
      final note = transaction["note"]?.toString().toLowerCase() ?? "";
      final matchesQuery = query.isEmpty || note.contains(query);
      return matchesType && matchesStatus && matchesQuery;
    }).toList();
  }

  Future<void> fetchTransactions() async {
    try {
      final storedRole = await SecureStorageService.getRole();
      final response = await TransactionService.getTransactions();
      if (!mounted) return;
      setState(() {
        role = storedRole;
        transactions = response.data;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
      _showMessage("Impossible de charger les transactions");
    }
  }

  Future<void> reviewTransaction(int id, bool approve) async {
    try {
      if (approve) {
        await TransactionService.approveTransaction(id);
      } else {
        await TransactionService.rejectTransaction(id);
      }
      await fetchTransactions();
      if (!mounted) return;
      _showMessage(approve ? "Transaction approuvee" : "Transaction rejetee");
    } catch (_) {
      if (!mounted) return;
      _showMessage("Action impossible");
    }
  }

  Future<void> createTransaction() async {
    final amount = double.tryParse(montantController.text.replaceAll(",", "."));
    if (amount == null || amount <= 0) {
      _showMessage("Montant invalide");
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmer"),
        content: Text("Creer une transaction $type de $amount ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Confirmer"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      creating = true;
    });

    try {
      await TransactionService.createTransaction(
        montant: amount,
        type: type,
        note: noteController.text.trim(),
      );

      montantController.clear();
      noteController.clear();
      await fetchTransactions();

      if (!mounted) return;
      _showMessage("Transaction creee");
    } catch (_) {
      if (!mounted) return;
      _showMessage("Creation impossible");
    } finally {
      if (mounted) {
        setState(() {
          creating = false;
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
  void initState() {
    super.initState();
    searchController.addListener(() => setState(() {}));
    fetchTransactions();
  }

  @override
  void dispose() {
    montantController.dispose();
    noteController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transactions"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchTransactions,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _formCard(),
                    const SizedBox(height: 20),
                    _filters(),
                    const SizedBox(height: 20),
                    _list(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.surfaceSoft),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          TextField(
            controller: montantController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.text),
            decoration: _inputDecoration("Montant"),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: type,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.text),
            decoration: _inputDecoration("Type"),
            items: const [
              DropdownMenuItem(value: "DEPOSIT", child: Text("Deposit")),
              DropdownMenuItem(value: "WITHDRAW", child: Text("Withdraw")),
              DropdownMenuItem(value: "TRANSFER", child: Text("Transfer")),
            ],
            onChanged: (value) => setState(() => type = value ?? type),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: noteController,
            style: const TextStyle(color: AppColors.text),
            decoration: _inputDecoration("Note"),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: creating ? null : createTransaction,
              child: creating
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Create Transaction"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Column(
      children: [
        TextField(
          controller: searchController,
          style: const TextStyle(color: AppColors.text),
          decoration: _inputDecoration("Recherche dans les notes"),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: typeFilter,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.text),
                decoration: _inputDecoration("Type"),
                items: const [
                  DropdownMenuItem(value: "ALL", child: Text("Tous")),
                  DropdownMenuItem(value: "DEPOSIT", child: Text("Deposit")),
                  DropdownMenuItem(value: "WITHDRAW", child: Text("Withdraw")),
                  DropdownMenuItem(value: "TRANSFER", child: Text("Transfer")),
                ],
                onChanged: (value) => setState(() => typeFilter = value ?? "ALL"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: statusFilter,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.text),
                decoration: _inputDecoration("Status"),
                items: const [
                  DropdownMenuItem(value: "ALL", child: Text("Tous")),
                  DropdownMenuItem(value: "PENDING", child: Text("Pending")),
                  DropdownMenuItem(value: "APPROVED", child: Text("Approved")),
                  DropdownMenuItem(value: "REJECTED", child: Text("Rejected")),
                ],
                onChanged: (value) => setState(() => statusFilter = value ?? "ALL"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _list() {
    final items = filteredTransactions;
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Text(
          "Aucune transaction",
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final transaction = items[index];
        final id = transaction["id"] as int?;
        final status = transaction["status"]?.toString() ?? "";
        final canReview =
            id != null && status == "PENDING" && (role == "ADMIN" || role == "COMPTABLE");
        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.surfaceSoft),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction["type"]?.toString() ?? "",
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Montant: ${transaction["montant"] ?? "-"}",
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 6),
              Text(
                "Status: ${transaction["status"] ?? "-"}",
                style: const TextStyle(color: AppColors.muted),
              ),
              if ((transaction["created_at"]?.toString() ?? "").isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  "Date: ${transaction["created_at"]}",
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
              if ((transaction["note"]?.toString() ?? "").isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  transaction["note"].toString(),
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
              if (canReview) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: () => reviewTransaction(id, true),
                      child: const Text("Approve"),
                    ),
                    OutlinedButton(
                      onPressed: () => reviewTransaction(id, false),
                      child: const Text("Reject"),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.muted),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }
}
