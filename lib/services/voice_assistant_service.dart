import 'package:flutter/material.dart';
import 'auth_service.dart';

class VoiceAssistantService {
  VoiceAssistantService._();
  static final VoiceAssistantService _instance = VoiceAssistantService._();
  static VoiceAssistantService get instance => _instance;

  final _authService = AuthService();
  
  /// ValueNotifier for voice assistant enabled state
  static final ValueNotifier<bool> isEnabledNotifier = ValueNotifier<bool>(false);

  /// Initialize the service by loading the user's preference from Firestore
  static Future<void> initialize() async {
    try {
      final user = _instance._authService.currentUser;
      if (user == null) {
        isEnabledNotifier.value = false;
        return;
      }

      final doc = await _instance._authService.db
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        isEnabledNotifier.value = data['voiceAssistant'] ?? false;
      } else {
        isEnabledNotifier.value = false;
      }
    } catch (e) {
      debugPrint('Error initializing voice assistant: $e');
      isEnabledNotifier.value = false;
    }
  }

  /// Update the voice assistant state for the current user
  Future<void> updateEnabled(bool enabled) async {
    try {
      isEnabledNotifier.value = enabled;
      
      final user = _instance._authService.currentUser;
      if (user != null) {
        await _instance._authService.updateUserData({'voiceAssistant': enabled});
      }
    } catch (e) {
      debugPrint('Error updating voice assistant state: $e');
    }
  }

  bool get isEnabled => isEnabledNotifier.value;
}
