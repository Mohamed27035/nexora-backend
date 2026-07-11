class AppConfig {
  static const String _defaultBaseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: "https://nexora-api-ix2q.onrender.com/",
  );

  static String get apiBaseUrl {
    final normalized = _defaultBaseUrl.trim();
    return normalized.endsWith("/") ? normalized : "$normalized/";
  }
}
