import 'package:flutter/material.dart';

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

void setAppThemeMode(ThemeMode mode) {
  themeModeNotifier.value = mode;
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
