import 'package:dio/dio.dart';

import '../core/config/app_config.dart';
import '../utils/navigation_service.dart';
import 'secure_storage_service.dart';

class ApiService {
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      // Render/hosted backends can have cold starts; keep timeouts generous.
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        "Content-Type": "application/json",
      },
    ),
  );

  static void init() {
    if (dio.interceptors.isNotEmpty) return;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorageService.getToken();
          if (token != null) {
            options.headers["Authorization"] = "Bearer $token";
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await SecureStorageService.clearSession();
            NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
              "/login",
              (route) => false,
            );
          }
          return handler.next(error);
        },
      ),
    );
  }

  static Future<void> setAuthToken() async {
    final token = await SecureStorageService.getToken();
    if (token != null) {
      dio.options.headers["Authorization"] = "Bearer $token";
    } else {
      dio.options.headers.remove("Authorization");
    }
  }
}
