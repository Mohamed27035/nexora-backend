import 'package:dio/dio.dart';

import 'api_service.dart';

class OtpService {

  // ==========================
  // SEND WELCOME OTP
  // ==========================
  static Future<Response> sendOtp({
    required String email,
  }) async {

    print(
      "URL => ${ApiService.dio.options.baseUrl}authe/send-welcome-otp/"
    );

    final response = await ApiService.dio.post(
      "authe/send-welcome-otp/",
      data: {
        "email": email,
      },
    );

    print(
      "RESPONSE => ${response.data}"
    );

    return response;
  }

  // ==========================
  // VERIFY WELCOME OTP
  // ==========================
  static Future<Response> verifyWelcomeOtp({

    required String email,

    required String otp,

  }) async {

    return await ApiService.dio.post(

      "authe/verify-welcome-otp/",

      data: {

        "email": email,

        "otp": otp,
      },
    );
  }

  // ==========================
  // VERIFY FORGOT PASSWORD OTP
  // ==========================
  static Future<Response> verifyOtp({

    required String email,

    required String otp,

  }) async {

    return await ApiService.dio.post(

      "authe/verify-otp/",

      data: {

        "email": email,

        "otp": otp,
      },
    );
  }
}