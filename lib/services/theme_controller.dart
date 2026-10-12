import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the selected appearance and supports following the device theme.
///
/// ThemeMode.system means Flutter follows the operating system's brightness
/// automatically. Keep this notifier as the single source of truth for the app.
class ThemeController {
  ThemeController._();

  static const String _preferenceKey = 'ledgerpro_theme_mode';

  // Use the device setting for a fresh install unless the user has explicitly
  // selected Light or Dark mode before.
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> loadTheme() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_preferenceKey);

    themeMode.value = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      // Do not force Light mode on first launch. Follow the device instead.
      _ => ThemeMode.system,
    };
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };

    // Persist the choice and then notify the MaterialApp to rebuild.
    await preferences.setString(_preferenceKey, saved);
    themeMode.value = mode;
  }

  /// Compatibility method used by the Settings screen.
  static Future<void> setTheme(ThemeMode mode) => setThemeMode(mode);

  static Future<void> toggleTheme() async {
    // A manual toggle switches explicitly between Light and Dark.
    // Selecting "Use device setting" in Settings returns to system mode.
    await setThemeMode(
      themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}
