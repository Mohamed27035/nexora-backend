import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  static const _key = "app_language";
  static final ValueNotifier<String> notifier = ValueNotifier<String>("fr");

  static bool get isArabic => notifier.value == "ar";

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    notifier.value = prefs.getString(_key) ?? "fr";
  }

  static Future<void> setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    notifier.value = language;
    await prefs.setString(_key, language);
  }

  static Future<void> toggle() {
    return setLanguage(isArabic ? "fr" : "ar");
  }

  static String t(String fr, String ar) {
    return isArabic ? ar : fr;
  }
}
