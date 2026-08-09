import 'package:flutter/foundation.dart';

import 'voice_assistant_service.dart';

class HomeTabController {
  HomeTabController._();

  static final ValueNotifier<int> tabNotifier = ValueNotifier<int>(0);

  static void switchToTab(int index) {
    VoiceAssistantService.instance.stopAudio();
    tabNotifier.value = index;
  }
}
