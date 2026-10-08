import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  static const String _themeKey = 'theme_mode';

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> loadTheme() async {
    final preferences =
        await SharedPreferences.getInstance();

    final savedTheme =
        preferences.getString(_themeKey);

    switch (savedTheme) {
      case 'light':
        themeMode.value = ThemeMode.light;
        break;

      case 'dark':
        themeMode.value = ThemeMode.dark;
        break;

      case 'system':
      default:
        themeMode.value = ThemeMode.system;
        break;
    }
  }

  static Future<void> setTheme(
    ThemeMode mode,
  ) async {
    themeMode.value = mode;

    final preferences =
        await SharedPreferences.getInstance();

    String value;

    switch (mode) {
      case ThemeMode.light:
        value = 'light';
        break;

      case ThemeMode.dark:
        value = 'dark';
        break;

      case ThemeMode.system:
        value = 'system';
        break;
    }

    await preferences.setString(
      _themeKey,
      value,
    );
  }
}