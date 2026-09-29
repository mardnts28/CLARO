import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:claro/services/voice_assistant_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Voice assistant speech capture', () {
    tearDown(() {
      VoiceAssistantService.microphonePermissionOverride = null;
      VoiceAssistantService.openAppSettingsOverride = null;
      VoiceAssistantService.liveTranscriptNotifier.value = '';
      VoiceAssistantService.isListeningNotifier.value = false;
    });

    test('uses the last non-empty partial when the final result is empty', () {
      expect(
        VoiceAssistantService.resolveRecognizedText('Can you tell me', ''),
        'Can you tell me',
      );
      expect(
        VoiceAssistantService.resolveRecognizedText(
          'Can you tell me',
          'Can you tell me about sodium?',
        ),
        'Can you tell me about sodium?',
      );
    });

    test(
      'permission denial returns its own result and opens app settings',
      () async {
        var settingsOpened = false;
        VoiceAssistantService.microphonePermissionOverride = () async =>
            PermissionStatus.denied;
        VoiceAssistantService.openAppSettingsOverride = () async {
          settingsOpened = true;
          return true;
        };

        final result = await VoiceAssistantService.instance.listenOnce();

        expect(result.status, VoiceListenStatus.permissionDenied);
        expect(settingsOpened, isTrue);
        expect(
          VoiceAssistantService.messageForListenStatus(
            result.status,
            VoiceLang.english,
          ),
          contains('Microphone permission is needed'),
        );
        expect(
          VoiceAssistantService.messageForListenStatus(
            result.status,
            VoiceLang.tagalog,
          ),
          contains('pahintulot sa mikropono'),
        );
      },
    );
  });
}
