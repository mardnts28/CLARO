import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'voice_assistant_service.dart';
import 'voice_command_router.dart';

/// ShakeDetectorService provides Shake-to-Talk capabilities, allowing
/// low-vision and accessibility users to activate voice commands without
/// having to locate or tap the on-screen microphone icon.
class ShakeDetectorService with WidgetsBindingObserver {
  ShakeDetectorService._();
  static final ShakeDetectorService instance = ShakeDetectorService._();

  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;

  /// Accelerometer threshold in m/s^2 (excluding gravity).
  /// Normal device handling stays below 5 m/s^2; an intentional shake peaks at 12-25 m/s^2.
  static const double _shakeThreshold = 13.0;

  /// Minimum time in milliseconds required between consecutive shake events to avoid jitter.
  static const int _shakeDebounceMs = 1500;

  DateTime? _lastShakeTime;
  bool _isInitialized = false;
  bool _isListeningToSensors = false;

  /// Starts listening to device shakes if voice assistant is enabled.
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    WidgetsBinding.instance.addObserver(this);

    // Synchronize sensor listener with voice assistant master toggle
    VoiceAssistantService.isEnabledNotifier.addListener(_syncSensorState);
    _syncSensorState();
  }

  void _syncSensorState() {
    final enabled = VoiceAssistantService.instance.isEnabled;
    if (enabled && !_isListeningToSensors) {
      _startListening();
    } else if (!enabled && _isListeningToSensors) {
      _stopListening();
    }
  }

  @visibleForTesting
  Stream<UserAccelerometerEvent>? accelerometerStreamOverride;

  void _startListening() {
    if (_isListeningToSensors) return;
    try {
      final stream = accelerometerStreamOverride ?? userAccelerometerEventStream();
      _accelerometerSubscription = stream.listen(
        _handleAccelerometerEvent,
        onError: (error) {
          debugPrint('ShakeDetectorService accelerometer error: $error');
        },
        cancelOnError: false,
      );
      _isListeningToSensors = true;
      debugPrint('ShakeDetectorService: Shake-to-Talk active.');
    } catch (e) {
      debugPrint('ShakeDetectorService failed to start accelerometer stream: $e');
    }
  }

  void _stopListening() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _isListeningToSensors = false;
    debugPrint('ShakeDetectorService: Shake-to-Talk stopped.');
  }

  void _handleAccelerometerEvent(UserAccelerometerEvent event) {
    if (!VoiceAssistantService.instance.isEnabled) return;

    // Calculate total linear acceleration magnitude
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    if (magnitude > _shakeThreshold) {
      final now = DateTime.now();
      if (_lastShakeTime != null &&
          now.difference(_lastShakeTime!).inMilliseconds < _shakeDebounceMs) {
        return;
      }

      _lastShakeTime = now;
      _onShakeDetected();
    }
  }

  Future<void> _onShakeDetected() async {
    // Immediate Barge-in: if currently speaking, stop speech immediately on shake
    if (VoiceAssistantService.isSpeakingNotifier.value) {
      await VoiceAssistantService.instance.stopAudio();
    }

    // Avoid double triggering if mic is already listening
    if (VoiceAssistantService.isListeningNotifier.value) {
      debugPrint('Shake detected, but voice assistant is already listening.');
      return;
    }

    final context = VoiceAssistantService.navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      debugPrint('Shake detected, but no mounted context is available.');
      return;
    }

    debugPrint('Shake-to-Talk triggered by shake gesture.');

    // Tactile confirmation of shake detection
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}

    if (!context.mounted) return;
    // Trigger voice recognition flow through router
    await VoiceCommandRouter.instance.handleMicTap(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;

    if (state == AppLifecycleState.resumed) {
      _syncSensorState();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopListening();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    VoiceAssistantService.isEnabledNotifier.removeListener(_syncSensorState);
    _stopListening();
    _isInitialized = false;
  }
}
