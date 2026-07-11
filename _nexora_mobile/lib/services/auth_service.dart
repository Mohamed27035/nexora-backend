import 'package:dio/dio.dart';

import 'api_service.dart';

class AuthService {

  // ==========================
  // LOGIN
  // ==========================
  static Future<Response> login({

    required String email,

    required String password,

  }) async {

    return await ApiService.dio.post(

      "authe/logine/",

      data: {

        "email": email,

        "password": password,
      },
    );
  }

  static Future<Response> register({
    required String nom,
    required String prenom,
    required String email,
    required String telephone,
    required String password,
  }) async {
    final data = {
      "nom": nom,
      "prenom": prenom,
      "email": email.trim().toLowerCase(),
      "telephone": telephone,
      "password": password,
    };

    // If no ADMIN exists yet, register first user as ADMIN.
    final adminExistsRes = await ApiService.dio.get("users/check-admin/");
    final exists = adminExistsRes.data is Map
        ? adminExistsRes.data["exists"] == true
        : true;

    if (!exists) {
      return await ApiService.dio.post(
        "authe/register-admin/",
        data: data,
      );
    }

    // Otherwise, create a CLIENT account (public endpoint).
    try {
      return await ApiService.dio.post(
        "users/register/",
        data: data,
      );
    } on DioException catch (e) {
      // Backward compatible fallbacks if endpoint name differs.
      if (e.response?.statusCode == 404) {
        try {
          return await ApiService.dio.post(
            "authe/register-client/",
            data: data,
          );
        } on DioException {
          // last resort: attempt users/create/ with explicit CLIENT role
          return await ApiService.dio.post(
            "users/create/",
            data: {
              ...data,
              "role": "CLIENT",
            },
          );
        }
      }
      rethrow;
    }
  }

  static Future<Response> sendRegisterOtp({
    required String nom,
    required String prenom,
    required String email,
    required String telephone,
    required String password,
  }) async {
    return await ApiService.dio.post(
      "authe/send-register-otp/",
      data: {
        "nom": nom,
        "prenom": prenom,
        "email": email.trim().toLowerCase(),
        "telephone": telephone,
        "password": password,
      },
    );
  }

  static Future<Response> verifyRegisterOtp({
    required String email,
    required String otp,
  }) async {
    return await ApiService.dio.post(
      "authe/verify-register-otp/",
      data: {
        "email": email.trim().toLowerCase(),
        "otp": otp,
      },
    );
  }
  // ==========================
  // SEND OTP
  // ==========================
  static Future<Response> sendOtp({

    required String email,

  }) async {

    return await ApiService.dio.post(

      "authe/send-otp/",

      data: {

        "email": email,
      },
    );
  }

  // ==========================
  // VERIFY OTP
  // ==========================
  static Future<Response> verifyOtp({

    required String email,

    required String otp,

    required String password,

  }) async {

    return await ApiService.dio.post(

      "authe/verify-otp/",

      data: {

        "email": email,

        "otp": otp,

        "password": password,
      },
    );
  }

  static Future<Response> novaSsoLogin({
    String? code,
    String? state,
    String? accessToken,
  }) async {
    return await ApiService.dio.post(
      "authe/sso/nova/",
      data: {
        if (code != null && code.trim().isNotEmpty) "code": code.trim(),
        if (state != null && state.trim().isNotEmpty) "state": state.trim(),
        if (accessToken != null && accessToken.trim().isNotEmpty)
          "access_token": accessToken.trim(),
      },
    );
  }
}
