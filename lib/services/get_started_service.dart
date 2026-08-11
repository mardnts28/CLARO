import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

/// Tracks whether the user has already been shown the one-time
/// "Get Started" screen (see GetStartedScreen), so it's shown once per
/// device -- right after Select Language and before Login/Sign Up --
/// rather than every time the app is opened or the user logs out.
class GetStartedService {
  GetStartedService._();

  static final ValueNotifier<bool> hasSeenGetStartedNotifier = ValueNotifier(false);

  static const _prefKey = 'get_started_seen';

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    hasSeenGetStartedNotifier.value = prefs.getBool(_prefKey) ?? false;
  }

  static Future<void> markSeen() async {
    hasSeenGetStartedNotifier.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }
}