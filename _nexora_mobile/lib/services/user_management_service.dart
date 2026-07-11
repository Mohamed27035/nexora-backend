import 'package:dio/dio.dart';

import 'api_service.dart';
import 'secure_storage_service.dart';


class UserManagementService {
  static Future<Response> getUsers({
    String? search,
    String? role,
    String? status,
    bool? verified,
  }) async {
    final queryParameters = <String, dynamic>{};

    if (search != null && search.trim().isNotEmpty) {
      queryParameters["search"] = search.trim();
    }

    if (role != null && role.trim().isNotEmpty && role != "ALL") {
      queryParameters["role"] = role.trim().toUpperCase();
    }

    if (status != null && status.trim().isNotEmpty && status != "ALL") {
      queryParameters["status"] = status.trim().toUpperCase();
    }

    if (verified != null) {
      queryParameters["verified"] = verified;
    }

    return ApiService.dio.get(
      "users/",
      queryParameters: queryParameters,
    );
  }

  static Future<Response> getUser(int id) async {
    return ApiService.dio.get("users/$id/");
  }

  static Future<Response> getCurrentUser() async {
    return ApiService.dio.get("users/me/");
  }

  static Future<Response> createUser({
    required String nom,
    required String email,
    required String password,
    String role = "CLIENT",
  }) async {
    final currentRole = await SecureStorageService.getRole();
    if (currentRole != "ADMIN") {
      throw StateError("Access denied");
    }

    return ApiService.dio.post(
      "users/create/",
      data: {
        "nom": nom.trim(),
        "email": email.trim().toLowerCase(),
        "password": password,
        "role": role.toUpperCase(),
      },
    );
  }

  static Future<Response> changeRole(int id, String role) async {
    final currentRole = await SecureStorageService.getRole();
    if (currentRole != "ADMIN") {
      throw StateError("Access denied");
    }

    return ApiService.dio.post(
      "users/change-role/$id/",
      data: {"role": role.toUpperCase()},
    );
  }

  static Future<Response> activateUser(int id) async {
    return ApiService.dio.post("users/activate/$id/");
  }

  static Future<Response> suspendUser(int id) async {
    return ApiService.dio.post("users/suspend/$id/");
  }

  static Future<Response> blockUser(int id) async {
    return ApiService.dio.post("users/ban/$id/");
  }

  static Future<Response> deleteUser(int id) async {
    try {
      return await ApiService.dio.post("users/delete/$id/");
    } on DioException catch (error) {
      final status = error.response?.statusCode ?? 0;
      if (status == 403 || status == 404 || status == 405) {
        try {
          return await ApiService.dio.post("users/$id/delete/");
        } on DioException catch (_) {
          return await ApiService.dio.delete("users/delete/$id/");
        }
      }
      rethrow;
    }
  }
}
