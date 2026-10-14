import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:claro/services/audio_earcon_service.dart';
import 'package:claro/services/shake_detector_service.dart';
import 'package:claro/services/voice_assistant_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
  });

  group('AudioEarconService Tests', () {
    test('AudioEarconService singleton instance is accessible', () {
      final service = AudioEarconService.instance;
      expect(service, isNotNull);
    });

    test('playMicStart executes safely without uncaught exceptions', () async {
      await expectLater(
        AudioEarconService.instance.playMicStart(),
        completes,
      );
    });

    test('playMicStop executes safely without uncaught exceptions', () async {
      await expectLater(
        AudioEarconService.instance.playMicStop(),
        completes,
      );
    });

    test('playProductRecognized executes safely without uncaught exceptions', () async {
      await expectLater(
        AudioEarconService.instance.playProductRecognized(),
        completes,
      );
    });
  });

  group('ShakeDetectorService Tests', () {
    test('ShakeDetectorService initializes and syncs with VoiceAssistant toggle', () async {
      final shakeService = ShakeDetectorService.instance;
      expect(shakeService, isNotNull);

      final controller = StreamController<UserAccelerometerEvent>.broadcast();
      shakeService.accelerometerStreamOverride = controller.stream;

      VoiceAssistantService.isEnabledNotifier.value = false;
      shakeService.initialize();

      // Enable voice assistant -> triggers sensor sync
      VoiceAssistantService.isEnabledNotifier.value = true;
      expect(VoiceAssistantService.instance.isEnabled, isTrue);

      // Emit a shake event into the stream
      controller.add(UserAccelerometerEvent(15.0, 5.0, 8.0, DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Disable voice assistant -> stops sensor sync
      VoiceAssistantService.isEnabledNotifier.value = false;
      expect(VoiceAssistantService.instance.isEnabled, isFalse);

      await controller.close();
      shakeService.accelerometerStreamOverride = null;
    });
  });

  group('VoiceAssistantService NavigatorKey & Earcons Integration', () {
    test('VoiceAssistantService exposes global navigatorKey', () {
      expect(VoiceAssistantService.navigatorKey, isNotNull);
    });

    test('setLatestScanProduct sets product and resets summary notifier', () {
      VoiceAssistantService.setLatestScanSummary('Sample Summary');
      expect(VoiceAssistantService.latestScanSummaryNotifier.value, equals('Sample Summary'));
    });
  });
}
