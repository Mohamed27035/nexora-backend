import 'package:dio/dio.dart';

import 'api_service.dart';


class OtpService {

  // ==========================
  // SEND OTP
  // ==========================
  static Future<Response>
      sendOtp({

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
  static Future<Response>
      verifyOtp({

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