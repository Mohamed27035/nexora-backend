import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _tokenKey = "auth_token";
  static const String _roleKey = "user_role";

  static Future<void> saveSession({
    required String token,
    required String role,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _roleKey, value: role.toUpperCase());
  }

  static Future<String?> getToken() {
    return _storage.read(key: _tokenKey);
  }

  static Future<String> getRole() async {
    return (await _storage.read(key: _roleKey) ?? "").toUpperCase();
  }

  static Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);
  }
}
