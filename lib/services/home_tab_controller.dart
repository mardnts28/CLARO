import 'package:flutter/foundation.dart';

class HomeTabController {
  HomeTabController._();

  static final ValueNotifier<int> tabNotifier = ValueNotifier<int>(0);

  static void switchToTab(int index) {
    tabNotifier.value = index;
  }
}
