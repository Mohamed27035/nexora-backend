import 'package:dio/dio.dart';

import 'api_service.dart';

class UserManagementService {
  static Future<Response> getUsers() async {
    return await ApiService.dio.get("users/");
  }

  static Future<Response> createUser({
    required String nom,
    required String email,
    required String password,
    required String role,
  }) async {
    return await ApiService.dio.post(
      "users/create/",
      data: {
        "nom": nom,
        "email": email,
        "password": password,
        "role": role,
      },
    );
  }

  static Future<Response> changeRole(int id, String role) async {
    return await ApiService.dio.post(
      "users/change-role/$id/",
      data: {"role": role},
    );
  }

  static Future<Response> activateUser(int id) async {
    return await ApiService.dio.post("users/activate/$id/");
  }

  static Future<Response> suspendUser(int id) async {
    return await ApiService.dio.post("users/suspend/$id/");
  }

  static Future<Response> blockUser(int id) async {
    return await ApiService.dio.post("users/ban/$id/");
  }

  static Future<Response> deleteUser(int id) async {
    return await ApiService.dio.delete("users/delete/$id/");
  }
}
