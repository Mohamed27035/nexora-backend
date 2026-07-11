import 'package:dio/dio.dart';

import 'api_service.dart';

class NovaSsoService {
  static const String providerName = "Nova SSO";

  static Future<Map<String, String>> prepareAuthorization() async {
    final Response response = await ApiService.dio.get("authe/sso/nova/");
    final data = response.data is Map ? response.data as Map : const {};

    final authorizationUrl =
        data["authorization_url"]?.toString().trim() ?? "";
    final redirectUri = data["redirect_uri"]?.toString().trim() ?? "";
    final state = data["state"]?.toString().trim() ?? "";

    if (authorizationUrl.isEmpty || redirectUri.isEmpty || state.isEmpty) {
      throw Exception("Configuration Nova SSO incomplète.");
    }

    return {
      "authorization_url": authorizationUrl,
      "redirect_uri": redirectUri,
      "state": state,
    };
  }
}
