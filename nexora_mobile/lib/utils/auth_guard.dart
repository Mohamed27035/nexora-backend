import 'package:flutter/material.dart';

import '../services/secure_storage_service.dart';

class AuthGuard {

  // ==========================
  // CHECK ROLE
  // ==========================
  static Future<bool> checkRole({

    required List<String>
        allowedRoles,

    required BuildContext context,
  }) async {
    final role = await SecureStorageService.getRole();
    if (!context.mounted) return false;

    // ==========================
    // ACCESS DENIED
    // ==========================
    if (!allowedRoles.contains(
      role,
    )) {

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(

        const SnackBar(

          content: Text(
            "Access denied",
          ),
        ),
      );

      return false;
    }

    return true;
  }
}
