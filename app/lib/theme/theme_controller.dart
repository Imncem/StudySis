import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({SharedPreferences? preferences})
      : _preferences = preferences;

  static const preferenceKey = 'studysis_theme_mode';

  final SharedPreferences? _preferences;
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> load() async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    final value = prefs.getString(preferenceKey);
    _themeMode = value == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() {
    return setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode != ThemeMode.light && mode != ThemeMode.dark) {
      mode = ThemeMode.light;
    }
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    await prefs.setString(preferenceKey, isDark ? 'dark' : 'light');
  }
}
