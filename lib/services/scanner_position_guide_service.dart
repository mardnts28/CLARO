import 'dart:async';
import 'package:flutter/services.dart';


import 'voice_assistant_service.dart';

/// Scanner Sonification / Audio Framing Guidance.
///
/// Provides real-time haptic and brief audio cues to help low-vision users
/// position a product within the camera viewfinder. Uses YOLO detection
/// bounding-box coordinates (`x, y, width, height` normalised to [0..1])
/// to determine whether the product is centered, too far left/right/up/down,
/// or too far from the camera.
///
/// All guidance is delivered via:
/// 1. **Haptic patterns** — intensity scales with how close the product is
///    to the centre of the frame.
/// 2. **Short spoken cues** — e.g. "Move left", "Closer", "Centered".
///    Debounced so they don't fire more than once every 2 seconds.
class ScannerPositionGuideService {
  ScannerPositionGuideService._();
  static final ScannerPositionGuideService instance =
      ScannerPositionGuideService._();

  DateTime? _lastCueTime;
  static const int _cueDebounceMs = 2000;

  /// Minimum bounding-box area (fraction of full frame) to consider
  /// the product close enough. Below this, we say "Move closer."
  static const double _minAreaFraction = 0.04;

  /// Dead-zone: if centre is within this fraction of the frame centre,
  /// we consider it "centered" and don't give directional cues.
  static const double _centreDeadZone = 0.15;

  /// Called whenever YOLO returns a detection while voice assistant is ON.
  /// [detectionRect] is the raw bounding box in pixel coordinates;
  /// [frameWidth] and [frameHeight] are the camera preview dimensions so
  /// we can normalise.
  void onDetection({
    required Rect detectionRect,
    required double frameWidth,
    required double frameHeight,
  }) {
    if (!VoiceAssistantService.instance.isEnabled) return;

    final now = DateTime.now();
    if (_lastCueTime != null &&
        now.difference(_lastCueTime!).inMilliseconds < _cueDebounceMs) {
      return;
    }

    // Normalise bounding box to [0..1]
    final cx = (detectionRect.left + detectionRect.width / 2) / frameWidth;
    final cy = (detectionRect.top + detectionRect.height / 2) / frameHeight;
    final area =
        (detectionRect.width * detectionRect.height) /
        (frameWidth * frameHeight);

    final cue = _determineCue(cx, cy, area);
    if (cue == null) return;

    _lastCueTime = now;

    // Provide haptic feedback scaled to proximity
    _hapticForProximity(area);

    // Speak very short positional cue (non-blocking)
    final isTagalog =
        VoiceAssistantService.languageNotifier.value == VoiceLang.tagalog;
    final message = isTagalog ? cue.tagalog : cue.english;
    unawaited(VoiceAssistantService.instance.speak(message));
  }

  /// When the product is well-centered and close enough, give a
  /// confirmation haptic + spoken cue.
  void onCentered() {
    if (!VoiceAssistantService.instance.isEnabled) return;

    final now = DateTime.now();
    if (_lastCueTime != null &&
        now.difference(_lastCueTime!).inMilliseconds < _cueDebounceMs) {
      return;
    }
    _lastCueTime = now;

    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    final isTagalog =
        VoiceAssistantService.languageNotifier.value == VoiceLang.tagalog;
    unawaited(VoiceAssistantService.instance.speak(
      isTagalog ? 'Nakita ang produkto.' : 'Product detected.',
    ));
  }

  _PositionCue? _determineCue(double cx, double cy, double area) {
    // Too far — product bounding box is tiny
    if (area < _minAreaFraction) {
      return _PositionCue(
        english: 'Move closer to the product.',
        tagalog: 'Ilapit ang camera sa produkto.',
      );
    }

    // Horizontal guidance
    if (cx < 0.5 - _centreDeadZone) {
      return _PositionCue(
        english: 'Move right.',
        tagalog: 'Ilipat sa kanan.',
      );
    }
    if (cx > 0.5 + _centreDeadZone) {
      return _PositionCue(
        english: 'Move left.',
        tagalog: 'Ilipat sa kaliwa.',
      );
    }

    // Vertical guidance
    if (cy < 0.5 - _centreDeadZone) {
      return _PositionCue(
        english: 'Move down.',
        tagalog: 'Ibaba ang camera.',
      );
    }
    if (cy > 0.5 + _centreDeadZone) {
      return _PositionCue(
        english: 'Move up.',
        tagalog: 'Itaas ang camera.',
      );
    }

    // Centered — no cue needed (caller can use onCentered())
    return null;
  }

  void _hapticForProximity(double area) {
    try {
      if (area > 0.15) {
        HapticFeedback.heavyImpact();
      } else if (area > 0.08) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  /// Resets the debounce timer (e.g. when the user navigates away from scan).
  void reset() {
    _lastCueTime = null;
  }
}

class _PositionCue {
  final String english;
  final String tagalog;

  const _PositionCue({required this.english, required this.tagalog});
}
