import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  bool _isEnabled = false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool('vibrationFeedback') ?? false;
  }

  bool get isEnabled => _isEnabled;

  set isEnabled(bool value) {
    _isEnabled = value;
    _savePreference(value);
  }

  Future<void> _savePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibrationFeedback', value);
  }

  void updateEnabled(bool value) {
    _isEnabled = value;
  }

  /// Triggers a light haptic impact if vibration feedback is enabled.
  Future<void> vibrate() async {
    if (_isEnabled) {
      await HapticFeedback.lightImpact();
    }
  }

  /// Triggers a medium haptic impact for alerts or important actions.
  Future<void> vibrateMedium() async {
    if (_isEnabled) {
      await HapticFeedback.mediumImpact();
    }
  }

  /// Triggers a success vibration.
  Future<void> vibrateSuccess() async {
    if (_isEnabled) {
      await HapticFeedback.vibrate();
    }
  }
}
