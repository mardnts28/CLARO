import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themePreferenceKey = 'selected_theme_mode';

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

Future<void> initializeThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final savedValue = prefs.getString(_themePreferenceKey);
  if (savedValue != null) {
    themeModeNotifier.value = _themeModeFromStorageValue(savedValue);
  }
}

Future<void> setAppThemeMode(ThemeMode mode) async {
  themeModeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_themePreferenceKey, _themeModeToStorageValue(mode));
}

ThemeMode parseThemeMode(String theme) {
  switch (theme.toLowerCase()) {
    case 'dark':
    case 'dark mode':
    case 'darkmode':
      return ThemeMode.dark;
    case 'light':
    case 'default':
    default:
      return ThemeMode.light;
  }
}

String themeModeLabel(ThemeMode mode) {
  return mode == ThemeMode.dark ? 'Dark' : 'Default';
}

ThemeMode _themeModeFromStorageValue(String value) {
  return value == 'dark' ? ThemeMode.dark : ThemeMode.light;
}

String _themeModeToStorageValue(ThemeMode mode) {
  return mode == ThemeMode.dark ? 'dark' : 'light';
}
