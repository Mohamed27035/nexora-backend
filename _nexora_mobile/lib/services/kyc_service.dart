import 'package:dio/dio.dart';

import 'api_service.dart';


class KycService {
  static Future<Response> getMyKyc() async {
    await ApiService.setAuthToken();
    return ApiService.dio.get("kyc/my/");
  }

  static Future<Response> submitKyc(FormData formData) async {
    await ApiService.setAuthToken();
    return ApiService.dio.post(
      "kyc/submit/",
      data: formData,
    );
  }

  static Future<Response> checkSelfie(FormData formData) async {
    await ApiService.setAuthToken();
    return ApiService.dio.post(
      "kyc/check-selfie/",
      data: formData,
    );
  }

  static Future<Response> getAllKyc({
    String? status,
    String? search,
  }) async {
    await ApiService.setAuthToken();

    final queryParameters = <String, dynamic>{};
    if (status != null && status.trim().isNotEmpty && status != "ALL") {
      queryParameters["status"] = status.trim().toUpperCase();
    }
    if (search != null && search.trim().isNotEmpty) {
      queryParameters["search"] = search.trim();
    }

    return ApiService.dio.get(
      "kyc/all/",
      queryParameters: queryParameters,
    );
  }

  static Future<Response> approveKyc(int id, {String? note}) async {
    await ApiService.setAuthToken();
    return ApiService.dio.post(
      "kyc/approve/$id/",
      data: {
        if (note != null && note.trim().isNotEmpty) "note": note.trim(),
      },
    );
  }

  static Future<Response> rejectKyc(int id, {String? reason}) async {
    await ApiService.setAuthToken();
    return ApiService.dio.post(
      "kyc/reject/$id/",
      data: {
        if (reason != null && reason.trim().isNotEmpty) "note": reason.trim(),
      },
    );
  }
}
