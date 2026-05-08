import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🛑 ضفنا المكتبة دي للحفظ

class SettingsProvider with ChangeNotifier {
  // 1. إدارة الثيم (الافتراضي هو السيستم)
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  // 🛠️ التعديل الأول: أول ما الـ Provider يشتغل، يروح يجيب الثيم المتسيف من الذاكرة
  SettingsProvider() {
    _loadThemeMode();
  }

  // 🛠️ التعديل التاني: لما نغير الثيم، نحدث الواجهة، وكمان "نسيفه" في الذاكرة
  void setTheme(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners(); // 👈 السطر اللي بيخلي التطبيق يغير لونه فوراً
    _saveThemeMode(mode); // 👈 السطر اللي بيحفظ الاختيار للأبد
  }

  // =========================================================
  // 👇 دوال الحفظ والاسترجاع (عشان التطبيق مينساش اختيار العميل)
  // =========================================================

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    // بنحول الـ ThemeMode لنص عشان SharedPreferences بتفهم نصوص وأرقام بس
    String themeText = 'system';
    if (mode == ThemeMode.light) themeText = 'light';
    if (mode == ThemeMode.dark) themeText = 'dark';

    await prefs.setString('saved_theme', themeText);
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedTheme = prefs.getString('saved_theme');

    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners(); // نحدث التطبيق بعد ما نقرأ من الذاكرة
  }
}
