import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'haptic_service.dart';

/// AudioEarconService provides auditory cues (earcons) and tactile feedback
/// for key voice assistant and scanner interactions, especially critical for
/// low-vision and screenless accessibility.
class AudioEarconService {
  AudioEarconService._();
  static final AudioEarconService instance = AudioEarconService._();

  AudioPlayer? _player;
  bool _playerInitFailed = false;

  @visibleForTesting
  AudioPlayer? playerOverride;

  AudioPlayer? _getOrCreatePlayer() {
    if (playerOverride != null) return playerOverride;
    if (_playerInitFailed) return null;
    if (_player != null) return _player;
    try {
      _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      return _player;
    } catch (e) {
      _playerInitFailed = true;
      debugPrint('AudioEarconService player initialization failed: $e');
      return null;
    }
  }

  /// Distinct rising chime played when the microphone begins listening.
  Future<void> playMicStart() async {
    try {
      await HapticFeedback.lightImpact();
      final player = _getOrCreatePlayer();
      if (player != null) {
        await player.stop();
        await player.play(
          AssetSource('sounds/mic_start.wav'),
          mode: PlayerMode.lowLatency,
        );
        return;
      }
    } catch (e) {
      debugPrint('AudioEarconService playMicStart error: $e');
    }
    // Fallback click on platforms or test environments without audio assets
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Distinct falling chime played when the microphone stops listening.
  Future<void> playMicStop() async {
    try {
      await HapticFeedback.lightImpact();
      final player = _getOrCreatePlayer();
      if (player != null) {
        await player.stop();
        await player.play(
          AssetSource('sounds/mic_stop.wav'),
          mode: PlayerMode.lowLatency,
        );
        return;
      }
    } catch (e) {
      debugPrint('AudioEarconService playMicStop error: $e');
    }
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Distinct bright chime played when a product is successfully recognized.
  Future<void> playProductRecognized() async {
    try {
      await HapticFeedback.mediumImpact();
      final player = _getOrCreatePlayer();
      if (player != null) {
        await player.stop();
        await player.play(
          AssetSource('sounds/product_recognized.wav'),
          mode: PlayerMode.lowLatency,
        );
        return;
      }
    } catch (e) {
      debugPrint('AudioEarconService playProductRecognized error: $e');
    }
    try {
      await SystemSound.play(SystemSoundType.click);
      HapticService().vibrate();
    } catch (_) {}
  }

  void dispose() {
    _player?.dispose();
    _player = null;
    _playerInitFailed = false;
  }
}
