import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

/// Service for managing personalized text size across the app.
/// Text size is stored per-user in Firestore and updates in real-time.
class TextSizeService {
  TextSizeService._();
  static final TextSizeService _instance = TextSizeService._();
  static TextSizeService get instance => _instance;

  final _authService = AuthService();
  
  /// ValueNotifier for text scale factor (1.0 = normal, 0.8 = small, 1.4 = large)
  static final ValueNotifier<double> textSizeNotifier = ValueNotifier<double>(1.0);

  /// Initialize the text size service by loading the user's preference from Firestore
  static Future<void> initialize() async {
    try {
      final user = _instance._authService.currentUser;
      if (user == null) {
        // Not logged in, use default
        textSizeNotifier.value = 1.0;
        return;
      }

      final doc = await _instance._authService.db
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final textSize = (data['textSize'] as num?)?.toDouble() ?? 1.0;
        textSizeNotifier.value = textSize;
      } else {
        textSizeNotifier.value = 1.0;
      }
    } catch (e) {
      debugPrint('Error initializing text size: $e');
      textSizeNotifier.value = 1.0;
    }
  }

  /// Update the text size for the current user
  Future<void> updateTextSize(double textSize) async {
    try {
      textSizeNotifier.value = textSize;
      
      final user = _instance._authService.currentUser;
      if (user != null) {
        await _instance._authService.updateUserData({'textSize': textSize});
      }
    } catch (e) {
      debugPrint('Error updating text size: $e');
    }
  }

  /// Get the current text scale factor
  double get currentTextSize => textSizeNotifier.value;

  /// Listen to real-time updates from Firestore
  void listenToRealTimeUpdates() {
    final user = _instance._authService.currentUser;
    if (user == null) return;

    _instance._authService.db
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        final textSize = (data['textSize'] as num?)?.toDouble();
        if (textSize != null && textSize != textSizeNotifier.value) {
          textSizeNotifier.value = textSize;
        }
      }
    });
  }
}
