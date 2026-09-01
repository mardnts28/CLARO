import 'package:flutter/foundation.dart';

import 'voice_assistant_service.dart';

class HomeTabController {
  HomeTabController._();

  static final ValueNotifier<int> tabNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<String> historySubTabNotifier = ValueNotifier<String>('Lahat');

  static void switchToTab(int index) {
    VoiceAssistantService.instance.stopAudio();
    tabNotifier.value = index;
  }

  static void switchToHistorySubTab(String subTab) {
    VoiceAssistantService.instance.stopAudio();
    historySubTabNotifier.value = subTab;
    tabNotifier.value = 2; // History tab index
  }
}
