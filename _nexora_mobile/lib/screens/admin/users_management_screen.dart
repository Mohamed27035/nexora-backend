import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_language.dart';
import '../../core/theme/app_theme.dart';
import '../../services/user_management_service.dart';
import '../../utils/auth_guard.dart';
import '../../utils/dio_error_utils.dart';
import '../../widgets/info_card.dart';


class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}


class _UsersManagementScreenState extends State<UsersManagementScreen> {
  String tr(String fr, String ar) => AppLanguage.t(fr, ar);
  List users = [];
  bool loading = true;
  String search = "";
  String roleFilter = "ALL";
  String statusFilter = "ALL";
  bool? verifiedFilter;
  bool _authorized = false;
  int? _currentUserId;

  List get filteredUsers {
    return users.where((user) {
      final role = (user["role"] ?? "").toString().toUpperCase();
      final haystack =
          "${user["nom"] ?? ""} ${user["prenom"] ?? ""} ${user["email"] ?? ""} ${user["telephone"] ?? ""} $role"
              .toLowerCase();
      final matchesSearch = search.isEmpty || haystack.contains(search);
      final matchesRole = roleFilter == "ALL" || role == roleFilter;
      final status = _userStatusLabel(user);
      final matchesStatus = statusFilter == "ALL" || status == statusFilter;
      final verified = user["is_verified"] == true;
      final matchesVerified =
          verifiedFilter == null || verified == verifiedFilter;
      return matchesSearch && matchesRole && matchesStatus && matchesVerified;
    }).toList();
  }

  Future<void> fetchUsers() async {
    try {
      _currentUserId ??= await _fetchCurrentUserId();
      final response = await UserManagementService.getUsers(
        search: search,
        role: roleFilter,
        status: statusFilter,
        verified: verifiedFilter,
      );

      if (!mounted) return;

      setState(() {
        users = _extractUsers(response.data);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      _showMessage(_friendlyError(e));
    }
  }

  Future<int?> _fetchCurrentUserId() async {
    try {
      final response = await UserManagementService.getCurrentUser();
      final data = response.data;
      if (data is Map) {
        final id = data["id"];
        if (id is int) return id;
        return int.tryParse(id?.toString() ?? "");
      }
    } catch (_) {}
    return null;
  }

  Future<void> changeRole(int id, String role) async {
    try {
      await UserManagementService.changeRole(id, role);
      await fetchUsers();
      if (!mounted) return;
      _showMessage(tr("Role modifie.", "تم تغيير الدور."));
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e));
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
      _showMessage(tr("Action executee.", "تم تنفيذ الإجراء."));
    } catch (e) {
      if (!mounted) return;
      _showMessage(_friendlyError(e));
    }
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      return DioErrorUtils.friendlyMessage(error);
    }
    return tr("Une erreur est survenue.", "حدث خطأ غير متوقع.");
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ok = await AuthGuard.checkRole(
        allowedRoles: const ["ADMIN"],
        context: context,
      );
      if (!mounted) return;

      if (!ok) {
        Navigator.maybePop(context);
        return;
      }

      setState(() => _authorized = true);
      fetchUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_authorized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr("Gestion des utilisateurs", "إدارة المستخدمين"))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchUsers,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _filters(),
                  const SizedBox(height: 16),
                  if (filteredUsers.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(
                        child: Text(
                          tr("Aucun utilisateur ne correspond aux filtres.", "لا يوجد مستخدمون مطابقون للفلاتر."),
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ),
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
            decoration: InputDecoration(
              hintText: tr("Rechercher par nom, email ou telephone", "ابحث بالاسم أو البريد الإلكتروني أو الهاتف"),
              hintStyle: const TextStyle(color: AppColors.muted),
              suffixIcon: IconButton(
                onPressed: fetchUsers,
                icon: const Icon(Icons.search, color: AppColors.text),
              ),
            ),
            onChanged: (value) => setState(() => search = value.toLowerCase()),
            onSubmitted: (_) => fetchUsers(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: roleFilter,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.text),
            items: [
              DropdownMenuItem(value: "ALL", child: Text(tr("Tous les roles", "كل الأدوار"))),
              DropdownMenuItem(value: "ADMIN", child: Text(_roleLabel("ADMIN"))),
              DropdownMenuItem(value: "AUDITEUR", child: Text(_roleLabel("AUDITEUR"))),
              DropdownMenuItem(value: "COMPTABLE", child: Text(_roleLabel("COMPTABLE"))),
              DropdownMenuItem(value: "CLIENT", child: Text(_roleLabel("CLIENT"))),
            ],
            onChanged: (value) => setState(() => roleFilter = value ?? "ALL"),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: statusFilter,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.text),
            items: [
              DropdownMenuItem(value: "ALL", child: Text(tr("Tous les statuts", "كل الحالات"))),
              DropdownMenuItem(value: "INACTIVE", child: Text(_statusLabel("INACTIVE"))),
              DropdownMenuItem(value: "ACTIVE", child: Text(_statusLabel("ACTIVE"))),
              DropdownMenuItem(value: "VERIFIED", child: Text(_statusLabel("VERIFIED"))),
              DropdownMenuItem(value: "SUSPENDED", child: Text(_statusLabel("SUSPENDED"))),
              DropdownMenuItem(value: "BANNED", child: Text(_statusLabel("BANNED"))),
            ],
            onChanged: (value) => setState(() => statusFilter = value ?? "ALL"),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: switch (verifiedFilter) {
              true => "YES",
              false => "NO",
              null => "ALL",
            },
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.text),
            items: [
              DropdownMenuItem(value: "ALL", child: Text(tr("Tous les comptes", "كل الحسابات"))),
              DropdownMenuItem(value: "YES", child: Text(tr("Comptes verifies", "الحسابات الموثقة"))),
              DropdownMenuItem(
                value: "NO",
                child: Text(tr("Comptes non verifies", "الحسابات غير الموثقة")),
              ),
            ],
            onChanged: (value) {
              setState(() {
                verifiedFilter = switch (value) {
                  "YES" => true,
                  "NO" => false,
                  _ => null,
                };
              });
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: fetchUsers,
              icon: const Icon(Icons.filter_alt_outlined),
              label: Text(tr("Appliquer les filtres", "تطبيق الفلاتر")),
            ),
          ),
        ],
      ),
    );
  }

  Widget _userCard(dynamic user) {
    final id = user["id"] as int?;
    final role = (user["role"]?.toString() ?? "CLIENT").toUpperCase();
    final status = _userStatusLabel(user);
    final canChangeRole = !(role == "CLIENT" && status == "INACTIVE");
    final isCurrentUser = id != null && id == _currentUserId;
    final isLastAdmin = role == "ADMIN" && _adminCount() <= 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: id == null
            ? null
            : () => Navigator.pushNamed(
                  context,
                  "/admin/user-details",
                  arguments: {
                    "id": id,
                    "user": user,
                  },
                ).then((_) => fetchUsers()),
        child: InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user["full_name"]?.toString().trim().isNotEmpty == true
                    ? user["full_name"].toString()
                    : user["nom"]?.toString() ?? tr("Utilisateur", "مستخدم"),
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
              const SizedBox(height: 6),
              Text(
                "${tr("Telephone", "الهاتف")}: ${user["telephone"]?.toString().isNotEmpty == true ? user["telephone"] : "-"}",
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 6),
              Text(
                "${tr("Statut", "الحالة")}: $status",
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 6),
              Text(
                "${tr("Role", "الدور")}: ${user["role_label"] ?? _roleLabel(role)}",
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 6),
              Text(
                "${tr("Verifie", "موثق")}: ${user["is_verified"] == true ? tr("Oui", "نعم") : tr("Non", "لا")}",
                style: const TextStyle(color: AppColors.muted),
              ),
              if (!canChangeRole) ...[
                const SizedBox(height: 6),
                Text(
                  tr("Ce client reste inactif jusqu'a l'approbation de son identite. Son role ne peut pas etre change.", "يبقى هذا العميل غير نشط إلى حين الموافقة على هويته، ولا يمكن تغيير دوره."),
                  style: TextStyle(color: AppColors.warning),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: id == null
                          ? null
                          : () => Navigator.pushNamed(
                                context,
                                "/admin/user-details",
                                arguments: {
                                  "id": id,
                                  "user": user,
                                },
                              ).then((_) => fetchUsers()),
                      icon: const Icon(Icons.badge_outlined),
                      label: Text(tr("Voir la fiche", "عرض البطاقة")),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: role,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.text),
                items: [
                  DropdownMenuItem(value: "ADMIN", child: Text(_roleLabel("ADMIN"))),
                  DropdownMenuItem(value: "AUDITEUR", child: Text(_roleLabel("AUDITEUR"))),
                  DropdownMenuItem(value: "COMPTABLE", child: Text(_roleLabel("COMPTABLE"))),
                  DropdownMenuItem(value: "CLIENT", child: Text(_roleLabel("CLIENT"))),
                ],
                onChanged: id == null || !canChangeRole || isCurrentUser
                    ? null
                    : (value) async {
                        final next = (value ?? role).toUpperCase();
                        if (next == role) return;

                          final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                            title: Text(
                              tr("Confirmer", "تأكيد"),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            content: Text(
                              tr("Changer le role vers $next ?", "هل تريد تغيير الدور إلى $next؟"),
                              style: const TextStyle(height: 1.3),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(tr("Annuler", "إلغاء")),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(tr("Confirmer", "تأكيد")),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          changeRole(id, next);
                        }
                      },
              ),
              const SizedBox(height: 10),
              if (isCurrentUser)
                Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    tr("Ce compte correspond a votre session actuelle. Sa suppression et la modification de son role sont desactivees.", "هذا الحساب هو حساب جلستك الحالية، لذلك تم تعطيل الحذف وتغيير الدور."),
                    style: TextStyle(color: AppColors.warning),
                  ),
                )
              else if (isLastAdmin)
                Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    tr("Le dernier administrateur ne peut pas etre supprime.", "لا يمكن حذف آخر مسؤول في النظام."),
                    style: TextStyle(color: AppColors.warning),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: id == null || isCurrentUser
                        ? null
                        : () => userAction("activate", id),
                    child: Text(tr("Activer", "تفعيل")),
                  ),
                  OutlinedButton(
                    onPressed: id == null || isCurrentUser
                        ? null
                        : () => userAction("suspend", id),
                    child: Text(tr("Suspendre", "تعليق")),
                  ),
                  OutlinedButton(
                    onPressed: id == null || isCurrentUser
                        ? null
                        : () => userAction("block", id),
                    child: Text(tr("Bannir", "حظر")),
                  ),
                  OutlinedButton(
                    onPressed: id == null || isCurrentUser || isLastAdmin
                        ? null
                        : () => userAction("delete", id),
                    child: Text(tr("Supprimer", "حذف")),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _adminCount() {
    return users.where((user) {
      final role = (user["role"]?.toString() ?? "").toUpperCase();
      return role == "ADMIN";
    }).length;
  }

  String _userStatusLabel(dynamic user) {
    try {
      final statusRaw = user["status"]?.toString();
      if (statusRaw != null && statusRaw.trim().isNotEmpty) {
        return _statusLabel(statusRaw.toUpperCase());
      }

      final banned = user["is_banned"] ?? user["banned"] ?? user["ban"] ?? false;
      if (banned == true || banned.toString().toLowerCase() == "true") {
        return _statusLabel("BANNED");
      }

      final suspended = user["is_suspended"] ?? user["suspended"] ?? false;
      if (suspended == true || suspended.toString().toLowerCase() == "true") {
        return _statusLabel("SUSPENDED");
      }

      final verified =
          user["is_verified"] ?? user["verified"] ?? user["isVerified"] ?? false;
      if (verified == true || verified.toString().toLowerCase() == "true") {
        return _statusLabel("VERIFIED");
      }
    } catch (_) {}

    return _statusLabel("INACTIVE");
  }


  String _roleLabel(String role) {
    switch (role.toUpperCase()) {
      case "ADMIN":
        return tr("Administrateur", "مسؤول");
      case "AUDITEUR":
        return tr("Auditeur", "مدقق");
      case "COMPTABLE":
        return tr("Comptable", "محاسب");
      default:
        return tr("Client", "عميل");
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
      case "ACTIVE":
        return tr("Actif", "نشط");
      case "VERIFIED":
        return tr("Verifie", "موثق");
      case "SUSPENDED":
        return tr("Suspendu", "معلق");
      case "BANNED":
        return tr("Banni", "محظور");
      default:
        return tr("Inactif", "غير نشط");
    }
  }
  List _extractUsers(dynamic data) {
    if (data is List) return data;
    if (data is! Map) return [];

    final candidates = [
      data["users"],
      data["results"],
      data["items"],
      data["data"],
    ];

    for (final candidate in candidates) {
      if (candidate is List) return candidate;
      if (candidate is Map) {
        final nested = _extractUsers(candidate);
        if (nested.isNotEmpty) return nested;
      }
    }

    return [];
  }
}




