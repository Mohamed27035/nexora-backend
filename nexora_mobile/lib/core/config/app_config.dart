class AppConfig {
  static const String _defaultBaseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: "http://127.0.0.1:8000/",
  );

  static String get apiBaseUrl {
    final normalized = _defaultBaseUrl.trim();
    return normalized.endsWith("/") ? normalized : "$normalized/";
  }
}
