import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  static const _key = "app_language";
  static final ValueNotifier<String> notifier = ValueNotifier<String>("fr");

  static bool get isArabic => notifier.value == "ar";

  static String _normalize(String? language) {
    return language == "ar" ? "ar" : "fr";
  }

  static Locale get locale => Locale(_normalize(notifier.value));

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    notifier.value = _normalize(prefs.getString(_key));
  }

  static Future<void> setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _normalize(language);
    notifier.value = normalized;
    await prefs.setString(_key, normalized);
  }

  static Future<void> toggle() {
    return setLanguage(isArabic ? "fr" : "ar");
  }

  static String t(String fr, String ar) {
    return isArabic ? ar : fr;
  }
}
