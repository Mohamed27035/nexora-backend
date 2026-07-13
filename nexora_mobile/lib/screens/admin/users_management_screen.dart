import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/user_management_service.dart';
import '../../widgets/info_card.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  List users = [];
  bool loading = true;
  String search = "";
  String roleFilter = "ALL";

  List get filteredUsers {
    return users.where((user) {
      final role = user["role"]?.toString() ?? "";
      final haystack =
          "${user["nom"] ?? ""} ${user["email"] ?? ""} $role".toLowerCase();
      final matchesSearch = search.isEmpty || haystack.contains(search);
      final matchesRole = roleFilter == "ALL" || role == roleFilter;
      return matchesSearch && matchesRole;
    }).toList();
  }

  Future<void> fetchUsers() async {
    try {
      final response = await UserManagementService.getUsers();
      if (!mounted) return;
      setState(() {
        users = response.data is List ? response.data : response.data["users"] ?? [];
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      _showMessage("Impossible de charger les utilisateurs");
    }
  }

  Future<void> changeRole(int id, String role) async {
    try {
      await UserManagementService.changeRole(id, role);
      await fetchUsers();
      if (!mounted) return;
      _showMessage("Role modifie");
    } catch (_) {
      if (!mounted) return;
      _showMessage("Modification impossible");
    }
  }

  Future<void> userAction(String action, int id) async {
    try {
      switch (action) {
        case "activate":
          await UserManagementService.activateUser(id);
          break;
        case "suspend":
          await UserManagementService.suspendUser(id);
          break;
        case "block":
          await UserManagementService.blockUser(id);
          break;
        case "delete":
          await UserManagementService.deleteUser(id);
          break;
      }
      await fetchUsers();
      if (!mounted) return;
      _showMessage("Action executee");
    } catch (_) {
      if (!mounted) return;
      _showMessage("Action impossible");
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Users Management")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchUsers,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _filters(),
                  const SizedBox(height: 16),
                  ...filteredUsers.map(_userCard),
                ],
              ),
            ),
    );
  }

  Widget _filters() {
    return InfoCard(
      child: Column(
        children: [
          TextField(
            style: const TextStyle(color: AppColors.text),
            decoration: const InputDecoration(
              hintText: "Search user",
              hintStyle: TextStyle(color: AppColors.muted),
            ),
            onChanged: (value) => setState(() => search = value.toLowerCase()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: roleFilter,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.text),
            items: const [
              DropdownMenuItem(value: "ALL", child: Text("Tous les roles")),
              DropdownMenuItem(value: "ADMIN", child: Text("ADMIN")),
              DropdownMenuItem(value: "AUDITEUR", child: Text("AUDITEUR")),
              DropdownMenuItem(value: "COMPTABLE", child: Text("COMPTABLE")),
              DropdownMenuItem(value: "CLIENT", child: Text("CLIENT")),
            ],
            onChanged: (value) => setState(() => roleFilter = value ?? "ALL"),
          ),
        ],
      ),
    );
  }

  Widget _userCard(dynamic user) {
    final id = user["id"] as int?;
    final role = user["role"]?.toString() ?? "CLIENT";

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user["nom"]?.toString() ?? "Utilisateur",
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              user["email"]?.toString() ?? "",
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: role,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.text),
              items: const [
                DropdownMenuItem(value: "ADMIN", child: Text("ADMIN")),
                DropdownMenuItem(value: "AUDITEUR", child: Text("AUDITEUR")),
                DropdownMenuItem(value: "COMPTABLE", child: Text("COMPTABLE")),
                DropdownMenuItem(value: "CLIENT", child: Text("CLIENT")),
              ],
              onChanged: id == null
                  ? null
                  : (value) => changeRole(id, value ?? role),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: id == null ? null : () => userAction("activate", id),
                  child: const Text("Activate"),
                ),
                OutlinedButton(
                  onPressed: id == null ? null : () => userAction("suspend", id),
                  child: const Text("Suspend"),
                ),
                OutlinedButton(
                  onPressed: id == null ? null : () => userAction("block", id),
                  child: const Text("Block"),
                ),
                OutlinedButton(
                  onPressed: id == null ? null : () => userAction("delete", id),
                  child: const Text("Delete"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
