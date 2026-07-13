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
    required String email,
    required String password,
  }) async {
    return await ApiService.dio.post(
      "users/create/",
      data: {
        "nom": nom,
        "email": email,
        "password": password,
        "role": "CLIENT",
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
}
