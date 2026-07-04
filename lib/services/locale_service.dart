import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LocaleService {
  LocaleService._();

  static final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('en'));

  static const _prefKey = 'app_locale';

  static Future<void> setAppLocale(String languageCode) async {
    final locale = Locale(languageCode);
    localeNotifier.value = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, languageCode);
  }

  static Future<void> initializeLocale({AuthService? authService}) async {
    try {
      // Priority: Firestore user setting -> shared preferences -> system locale
      final aSvc = authService ?? AuthService();
      final uid = aSvc.currentUser?.uid;
      String? code;
      if (uid != null) {
        try {
          final doc = await aSvc.db.collection('users').doc(uid).get();
          final data = doc.data();
          if (data != null && data['language'] != null) {
            code = (data['language'] as String);
          }
        } catch (_) {}
      }

      if (code == null) {
        final prefs = await SharedPreferences.getInstance();
        code = prefs.getString(_prefKey);
      }

      if (code == null) {
        final sys = window.locale;
        code = sys.languageCode == 'tl' ? 'tl' : 'en';
      }

      localeNotifier.value = Locale(code);
    } catch (e) {
      // fallback to English
      localeNotifier.value = const Locale('en');
    }
  }
}
