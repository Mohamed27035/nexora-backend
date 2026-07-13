import 'package:dio/dio.dart';

import 'api_service.dart';

class KycService {
  static Future<Response> getMyKyc() async {
    await ApiService.setAuthToken();
    return await ApiService.dio.get("kyc/my/");
  }

  static Future<Response> submitKyc(FormData formData) async {
    await ApiService.setAuthToken();
    return await ApiService.dio.post(
      "kyc/submit/",
      data: formData,
    );
  }

  static Future<Response> getAllKyc() async {
    await ApiService.setAuthToken();
    return await ApiService.dio.get("kyc/all/");
  }

  static Future<Response> approveKyc(int id) async {
    await ApiService.setAuthToken();
    return await ApiService.dio.post("kyc/approve/$id/");
  }

  static Future<Response> rejectKyc(int id, {String? reason}) async {
    await ApiService.setAuthToken();
    return await ApiService.dio.post(
      "kyc/reject/$id/",
      data: {
        if (reason != null && reason.trim().isNotEmpty)
          "reason": reason.trim(),
      },
    );
  }
}
