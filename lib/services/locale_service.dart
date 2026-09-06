import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

import 'voice_assistant_service.dart';

class LocaleService {
  LocaleService._();

  static final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('en'));

  // Tracks whether the user has ever *explicitly* chosen a language --
  // either on the first-launch Select Language screen or later from
  // Profile/Settings. This is intentionally separate from `localeNotifier`
  // itself: `localeNotifier` always has a value (it falls back to the
  // system locale when nothing has been chosen yet), so it can't be used
  // on its own to decide whether the Select Language screen should be
  // shown. `hasSelectedLanguageNotifier` is what the app's root routing
  // checks for that.
  static final ValueNotifier<bool> hasSelectedLanguageNotifier = ValueNotifier(false);

  static const _prefKey = 'app_locale';
  static const _languageSelectedPrefKey = 'language_selected';

  static Future<void> setAppLocale(String languageCode) async {
    final locale = Locale(languageCode);
    localeNotifier.value = locale;
    hasSelectedLanguageNotifier.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, languageCode);
    await prefs.setBool(_languageSelectedPrefKey, true);

    // Keep voice assistant language in sync with app locale
    final targetVoiceLang = languageCode == 'tl' ? VoiceLang.tagalog : VoiceLang.english;
    if (VoiceAssistantService.languageNotifier.value != targetVoiceLang) {
      await VoiceAssistantService.instance.updateLanguage(targetVoiceLang);
    }

    // Persist to user doc in Firestore so Profile & reload keep it in sync
    final aSvc = AuthService();
    final uid = aSvc.currentUser?.uid;
    if (uid != null) {
      try {
        await aSvc.updateUserData({
          'language': languageCode,
          'voiceLanguage': targetVoiceLang.storageValue,
        });
      } catch (e) {
        debugPrint('Failed to save language to Firestore: $e');
      }
    }
  }

  static Future<void> initializeLocale({AuthService? authService}) async {
    try {
      // Priority: Firestore user setting -> shared preferences -> system locale
      final aSvc = authService ?? AuthService();
      final uid = aSvc.currentUser?.uid;
      String? code;
      bool explicitlySelected = false;

      if (uid != null) {
        try {
          final doc = await aSvc.db.collection('users').doc(uid).get();
          final data = doc.data();
          if (data != null && data['language'] != null) {
            code = (data['language'] as String);
            // An account that already has a saved language preference
            // (e.g. an existing user, or one who picked a language on
            // another device) has effectively already made this choice.
            explicitlySelected = true;
          }
        } catch (_) {}
      }

      final prefs = await SharedPreferences.getInstance();
      if (!explicitlySelected) {
        explicitlySelected = prefs.getBool(_languageSelectedPrefKey) ?? false;
      }

      if (code == null) {
        code = prefs.getString(_prefKey);
      }

      if (code == null) {
        final sys = window.locale;
        code = sys.languageCode == 'tl' ? 'tl' : 'en';
      }

      localeNotifier.value = Locale(code);
      hasSelectedLanguageNotifier.value = explicitlySelected;
    } catch (e) {
      // fallback to English
      localeNotifier.value = const Locale('en');
    }
  }
}