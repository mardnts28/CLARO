import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/nutrition_guide_screen.dart';
import '../screens/group_screen.dart';

import 'voice_assistant_service.dart';
import 'scan_history_service.dart';
import 'gemini_service.dart';
import 'home_tab_controller.dart';
import 'locale_service.dart';
import 'auth_service.dart';
import '../screens/personal_info_screen.dart';
import '../screens/preference_screen.dart';
import '../screens/suggestion_screen.dart';
import '../screens/change_password_screen.dart';
import '../screens/theme_screen.dart';
import '../screens/review_history_screen.dart';
import '../screens/compare_products_screen.dart';
import '../screens/more_details_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/unknown_product_submission_screen.dart';
import 'history_service.dart';
import '../data/services/backend_locator.dart';
import '../models/product_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/utils/success_feedback_utils.dart';
import '../generated/l10n/app_localizations.dart';
import 'theme_service.dart';

typedef VoiceCommandInterpreter =
    Future<VoiceCommand> Function(String transcript);

const String claroWebsiteUrl = 'https://claro-52ia.onrender.com/';
const String privacyPolicyUrl =
    'https://claro-52ia.onrender.com/privacy-policy';
const String termsConditionsUrl =
    'https://claro-52ia.onrender.com/terms-and-conditions';
const String userGuideUrl = 'https://claro-52ia.onrender.com/user-guide';

class VoiceCommandRouter {
  VoiceCommandRouter._({this._interpreter});

  @visibleForTesting
  VoiceCommandRouter.forTesting({required VoiceCommandInterpreter interpreter})
    : this._(interpreter: interpreter);

  final VoiceCommandInterpreter? _interpreter;
  String? _lastUtterance;
  String? _lastIntent;

  static final VoiceCommandRouter _instance = VoiceCommandRouter._();

  static VoiceCommandRouter get instance => _instance;

  // The "Group" tab was removed from the bottom nav; Group is now
  // reached from the Profile screen's "Invite People" tab instead.
  // See home_screen.dart and profile_screen.dart.
  static const Map<String, int> _tabPageKeys = {
    'home': 0,
    'scan': 1,
    'history': 2,
    'profile': 3,
  };

  Future<void> handleMicTap(BuildContext context) async {
    // Immediate push-to-finish: If already listening, tap finishes recording and submits immediately
    if (VoiceAssistantService.isListeningNotifier.value) {
      debugPrint('handleMicTap: mic tapped while listening -> finishing early');
      VoiceAssistantService.instance.stopListeningEarly();
      return;
    }
    final hasInternet = await SuccessFeedbackUtils.hasInternetConnection();
    if (!hasInternet) {
      if (context.mounted) {
        final loc = AppLocalizations.of(context)!;
        await SuccessFeedbackUtils.showOfflineNoticeDialog(
          context,
          title: loc.noInternetTitle,
          message: loc.noInternetVoiceMessage,
          buttonText: loc.gotIt,
        );
        await VoiceAssistantService.instance.speak(loc.noInternetVoiceMessage);
      }
      return;
    }

    final result = await VoiceAssistantService.instance.listenOnce();

    if (!context.mounted) return;
    if (result.status == VoiceListenStatus.recognized) {
      await _handleTranscript(context, result.transcript);
      return;
    }
    if (result.status != VoiceListenStatus.alreadyListening) {
      await VoiceAssistantService.instance.speak(
        VoiceAssistantService.messageForListenStatus(
          result.status,
          VoiceAssistantService.languageNotifier.value,
        ),
      );
    }
  }

  @visibleForTesting
  Future<void> handleTranscriptForTesting(
    BuildContext context,
    String? transcript,
  ) => _handleTranscript(context, transcript);

  Future<void> _handleTranscript(
    BuildContext context,
    String? transcript,
  ) async {
    final language = VoiceAssistantService.languageNotifier.value;

    final localeKey = language == VoiceLang.tagalog ? 'fil' : 'en';

    // ============================================================
    // 1. NO SPEECH DETECTED
    // ============================================================
    if (transcript == null || transcript.trim().isEmpty) {
      debugPrint('Voice command: speech recognition returned no transcript.');

      await VoiceAssistantService.instance.speak(
        localeKey == 'fil'
            ? 'Wala akong narinig na sinabi. Pakisubukan muli at magsalita pagkatapos i-tap ang mikropono.'
            : "I didn't hear anything. Please tap the microphone and speak your command again.",
      );

      return;
    }

    debugPrint('Voice command transcript: "$transcript"');

    // ============================================================
    // 2. NUTRITION GUIDE QUESTIONS (FDA label, WHO limits, Kidney, GERD)
    // Evaluated first so guide inquiries (e.g. "limits on WHO", "how to read nutrition label")
    // reliably open the guide with full spoken explanation rather than triggering product slots.
    // ============================================================
    final nutritionGuide = _matchNutritionGuideQuestion(transcript);
    if (nutritionGuide != null) {
      debugPrint(
        'Voice command intent: nutrition guide -> ${nutritionGuide.name}',
      );
      await _handleNutritionGuideNavigation(
        context, nutritionGuide, localeKey,
      );
      return;
    }

    // ============================================================
    // 2b. FAST LOCAL NAVIGATION
    // Evaluated before search to ensure navigation commands (e.g. user guide,
    // about claro, privacy policy, terms, profile) are never misidentified as product searches.
    // ============================================================
    final localTarget = _targetFromTranscript(transcript);

    if (localTarget != null) {
      _rememberTurn(transcript, _intentForLocalTarget(localTarget));
      debugPrint('Voice command intent: fast local navigation -> $localTarget');

      if (_requiresActiveProduct(localTarget) &&
          VoiceAssistantService.activeResultProductNotifier.value == null) {
        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Magbukas muna ng produkto para magawa ito.'
              : 'Please open a product first so I can do that.',
        );
        return;
      }

      final resolvedIntent = LegacyVoiceIntent(
        type: VoiceIntentType.navigate,
        targetPage: localTarget,
        spokenReply: _navigationReply(localTarget, localeKey),
      );

      await _handleNavigationIntent(context, resolvedIntent, localeKey);

      return;
    }

    // ============================================================
    // 2c. OFFLINE LOCAL SLOT-FILLER (deterministic, in-store product queries)
    // ============================================================
    final offlineSlot = _matchOfflineSlot(transcript);
    if (offlineSlot != null) {
      debugPrint(
        'Voice command intent: offline slot-filler -> $offlineSlot',
      );
      await _handleOfflineSlot(context, offlineSlot, localeKey);
      return;
    }

    // ============================================================
    // 2d. SUMMARY REQUEST
    // ============================================================
    if (_isSummaryRequest(transcript)) {
      _rememberTurn(transcript, 'summarize');
      debugPrint(
        'Voice command intent: type=VoiceIntentType.summarizeScan '
        '(local match)',
      );

      try {
        await _handleSummarizeIntent(language);
      } catch (error, stackTrace) {
        debugPrint('Voice summary failed: $error');
        debugPrint('$stackTrace');

        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Narinig ko ang iyong kahilingan, pero nagkaroon ng problema habang kinukuha ang resulta. Pakisubukan muli.'
              : 'I heard your request, but there was a problem retrieving the results. Please try again.',
        );
      }

      return;
    }

    // ============================================================
    // 3. PRODUCT SEARCH
    // ============================================================
    final productSearchQuery = _extractProductSearchQuery(transcript);

    if (productSearchQuery != null && productSearchQuery.isNotEmpty) {
      _rememberTurn(transcript, 'find_product');
      debugPrint(
        'Voice command intent: product search for '
        '"$productSearchQuery"',
      );

      final handled = await _handleProductSearch(
        context,
        productSearchQuery,
        language,
      );

      if (handled) return;
      if (!context.mounted) return;
    }

    final activeProduct =
        VoiceAssistantService.activeResultProductNotifier.value;
    final appLanguage = LocaleService.localeNotifier.value.languageCode == 'tl'
        ? 'tl'
        : 'en';

    // ============================================================
    // 4. DIRECT PRODUCT QUESTIONS
    // ============================================================
    if (activeProduct != null && _looksLikeProductQuestion(transcript)) {
      final productData = jsonEncode({
        'product': activeProduct.toJson(),
        'on_screen_health_advice':
            VoiceAssistantService.latestScanSummaryNotifier.value ?? '',
      });
      final reply = await GeminiService.instance.askChat(
        question: transcript,
        appLanguage: appLanguage,
        productData: productData,
        history: const [],
      );
      if (reply.inScope && reply.topic == 'product') {
        await VoiceAssistantService.instance.speak(reply.answer);
        return;
      }
    }


    final currentTab = HomeTabController.tabNotifier.value;
    final screen = activeProduct != null
        ? 'product_detail'
        : switch (currentTab) {
            1 => 'scan',
            2 => 'history',
            3 => 'profile',
            _ => 'home',
          };
    final productData = activeProduct == null
        ? null
        : jsonEncode({
            'product': activeProduct.toJson(),
            'advisory': VoiceAssistantService.latestScanSummaryNotifier.value,
          });
    final command =
        await (_interpreter?.call(transcript) ??
            GeminiService.instance.interpret(
              transcript: transcript,
              screen: screen,
              appLanguage: appLanguage,
              darkMode: themeModeNotifier.value == ThemeMode.dark,
              voiceOn: VoiceAssistantService.instance.isEnabled,
              mfaOn: AuthService.mfaNotifier.value,
              lastUtterance: _lastUtterance,
              lastIntent: _lastIntent,
              productData: productData,
            ));
    if (!context.mounted) return;
    _lastUtterance = transcript;
    _lastIntent = command.intent.jsonValue;
    await _handleVoiceCommand(context, command);
  }

  void _rememberTurn(String transcript, String intent) {
    _lastUtterance = transcript;
    _lastIntent = intent;
  }

  String _intentForLocalTarget(String target) => switch (target) {
    'favorite_product' => 'add_favorite',
    'unfavorite_product' => 'remove_favorite',
    'compare_products' => 'compare_product',
    'more_details' => 'show_more_details',
    'report_product' => 'report_product',
    'dark_mode' || 'light_mode' => 'set_theme',
    'language' || 'language_english' || 'language_tagalog' => 'set_language',
    'voice_assistant_on' || 'voice_assistant_off' => 'set_voice_assistant',
    'mfa' || 'mfa_on' || 'mfa_off' => 'set_mfa',
    'logout' => 'logout',
    'clear_history' => 'guided_clear_history',
    'clear_favorites' => 'guided_clear_favorites',
    'delete_account' => 'guided_delete_account',
    _ => 'navigate',
  };

  Future<void> _handleVoiceCommand(
    BuildContext context,
    VoiceCommand command,
  ) async {
    final localeKey = command.replyLanguage == 'tl' ? 'fil' : 'en';
    if ((command.intent == VoiceIntent.readResults ||
            command.intent == VoiceIntent.summarize ||
            command.intent == VoiceIntent.askProductQuestion) &&
        VoiceAssistantService.activeResultProductNotifier.value == null) {
      await VoiceAssistantService.instance.speak(
        localeKey == 'fil'
            ? 'Mag-scan o magbukas muna ng produkto para mabasa ko ang impormasyon nito.'
            : 'Please scan or open a product first so I can read its information.',
      );
      return;
    }
    if (command.intent == VoiceIntent.clarify ||
        command.intent == VoiceIntent.unsupported ||
        command.intent == VoiceIntent.help ||
        command.intent == VoiceIntent.readResults ||
        command.intent == VoiceIntent.summarize ||
        command.intent == VoiceIntent.askProductQuestion) {
      await VoiceAssistantService.instance.speak(command.speech);
      return;
    }

    if (_requiresActiveProductIntent(command.intent) &&
        VoiceAssistantService.activeResultProductNotifier.value == null) {
      await VoiceAssistantService.instance.speak(
        localeKey == 'fil'
            ? 'Magbukas muna ng produkto para magawa ito.'
            : 'Please open a product first so I can do that.',
      );
      return;
    }

    if (command.intent == VoiceIntent.findProduct) {
      final query = command.entity?.trim() ?? '';
      if (query.isEmpty) {
        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Anong produkto ang gusto mong hanapin sa scan history?'
              : 'Which product should I find in your scan history?',
        );
        return;
      }
      await _handleProductSearch(
        context,
        query,
        command.replyLanguage == 'tl' ? VoiceLang.tagalog : VoiceLang.english,
      );
      return;
    }

    final target = _targetForCommand(command);

    if (target == null) {
      await VoiceAssistantService.instance.speak(
        localeKey == 'fil'
            ? 'Hindi ko matukoy ang hinihinging aksyon. Maaari mo bang linawin?'
            : 'I could not determine that action. Could you clarify?',
      );
      return;
    }

    if (command.alreadySet) {
      await VoiceAssistantService.instance.speak(command.speech);
      return;
    }

    await _handleNavigationIntent(
      context,
      LegacyVoiceIntent(
        type: VoiceIntentType.navigate,
        targetPage: target,
        spokenReply: command.speech,
      ),
      localeKey,
      commandSpeech: command.speech,
    );
  }

  @visibleForTesting
  String? testTargetForCommand(VoiceCommand command) =>
      _targetForCommand(command);

  String? _targetForCommand(VoiceCommand command) => switch (command.intent) {
    VoiceIntent.navigate => _allowedNavigationTarget(command.target),
    VoiceIntent.compareProduct => 'compare_products',
    VoiceIntent.showMoreDetails => 'more_details',
    VoiceIntent.addFavorite => 'favorite_product',
    VoiceIntent.removeFavorite => 'unfavorite_product',
    VoiceIntent.reportProduct => 'report_product',
    VoiceIntent.setTheme =>
      command.value == 'dark'
          ? 'dark_mode'
          : command.value == 'light'
          ? 'light_mode'
          : null,
    VoiceIntent.setLanguage =>
      command.value == 'tl'
          ? 'language_tagalog'
          : command.value == 'en'
          ? 'language_english'
          : null,
    VoiceIntent.setVoiceAssistant =>
      command.value == 'on'
          ? 'voice_assistant_on'
          : command.value == 'off'
          ? 'voice_assistant_off'
          : null,
    VoiceIntent.setMfa =>
      command.value == 'on'
          ? 'mfa_on'
          : command.value == 'off'
          ? 'mfa_off'
          : null,
    VoiceIntent.logout => 'logout',
    VoiceIntent.guidedClearHistory => 'clear_history',
    VoiceIntent.guidedClearFavorites => 'clear_favorites',
    VoiceIntent.guidedDeleteAccount => 'delete_account',
    _ => null,
  };

  String? _allowedNavigationTarget(String? target) {
    const targets = {
      'home',
      'scan',
      'history',
      'profile',
      'personal_info',
      'preferences',
      'theme',
      'password_settings',
      'feedback',
      'reviews',
      'about_claro',
      'privacy_policy',
      'terms',
      'user_guide',
    };
    if (target == null || !targets.contains(target)) return null;
    return switch (target) {
      'preferences' => 'preference',
      'password_settings' => 'change_password',
      'feedback' => 'suggestion',
      'reviews' => 'review_history',
      'terms' => 'terms_conditions',
      _ => target,
    };
  }

  bool _requiresActiveProduct(String target) => const {
    'compare_products',
    'more_details',
    'favorite_product',
    'unfavorite_product',
  }.contains(target);

  bool _requiresActiveProductIntent(VoiceIntent intent) => const {
    VoiceIntent.compareProduct,
    VoiceIntent.showMoreDetails,
    VoiceIntent.addFavorite,
    VoiceIntent.removeFavorite,
  }.contains(intent);

  Future<void> _handleNavigationIntent(
    BuildContext context,
    LegacyVoiceIntent intent,
    String localeKey, {
    String? commandSpeech,
  }) async {
    final target = _canonicalTarget(intent.targetPage);

    if (target == null || target.isEmpty) {
      await VoiceAssistantService.instance.speak(
        localeKey == 'fil'
            ? 'Narinig ko ang iyong utos, pero hindi ko mahanap ang pahinang iyong hinihingi.'
            : 'I heard your command, but I could not find the page you requested.',
      );
      return;
    }

    // ============================================================
    // FAVORITE
    // ============================================================
    if (target == 'favorite_product') {
      final currentProduct =
          VoiceAssistantService.latestScanProductNotifier.value;

      final user = FirebaseAuth.instance.currentUser;

      if (currentProduct != null && user != null) {
        try {
          await BackendLocator.favoritesService.addFavorite(
            userId: user.uid,
            productId: currentProduct.id,
          );

          final msg = localeKey == 'fil'
              ? 'Naidagdag ang ${currentProduct.name} sa iyong mga paborito.'
              : 'Added ${currentProduct.name} to your favorites.';

          await VoiceAssistantService.instance.speak(commandSpeech ?? msg);
        } catch (error, stackTrace) {
          debugPrint('Favorite product failed: $error');
          debugPrint('$stackTrace');

          await VoiceAssistantService.instance.speak(
            localeKey == 'fil'
                ? 'Narinig ko ang iyong utos, pero hindi ko ma-save ang produkto sa iyong mga paborito dahil nagkaroon ng problema sa pag-save.'
                : 'I heard your command, but I could not add the product to your favorites because the save operation failed.',
          );
        }
      } else {
        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Walang aktibong produkto para i-save. Mag-scan muna ng produkto.'
              : 'There is no active product to save. Please scan a product first.',
        );
      }

      return;
    }

    // ============================================================
    // UNFAVORITE
    // ============================================================
    if (target == 'unfavorite_product') {
      final currentProduct =
          VoiceAssistantService.latestScanProductNotifier.value;

      final user = FirebaseAuth.instance.currentUser;

      if (currentProduct != null && user != null) {
        try {
          await BackendLocator.favoritesService.removeFavorite(
            userId: user.uid,
            productId: currentProduct.id,
          );

          final msg = localeKey == 'fil'
              ? 'Inalis ang ${currentProduct.name} sa iyong mga paborito.'
              : 'Removed ${currentProduct.name} from your favorites.';

          await VoiceAssistantService.instance.speak(commandSpeech ?? msg);
        } catch (error, stackTrace) {
          debugPrint('Unfavorite product failed: $error');
          debugPrint('$stackTrace');

          await VoiceAssistantService.instance.speak(
            localeKey == 'fil'
                ? 'Narinig ko ang iyong utos, pero hindi ko maalis ang produkto sa iyong mga paborito dahil nagkaroon ng problema sa pag-save.'
                : 'I heard your command, but I could not remove the product from your favorites because the save operation failed.',
          );
        }
      } else {
        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Walang aktibong produkto para alisin sa mga paborito.'
              : 'There is no active product to remove from your favorites.',
        );
      }

      return;
    }

    // ============================================================
    // REPORT PRODUCT
    // ============================================================
    if (target == 'report_product') {
      try {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const UnknownProductSubmissionScreen(capturedImagePath: null),
          ),
        );

        await VoiceAssistantService.instance.speak(
          commandSpeech ??
              (localeKey == 'fil'
                  ? 'Binubuksan ang screen para sa pag-uulat ng produkto.'
                  : 'Opening the product report screen.'),
        );
      } catch (error, stackTrace) {
        debugPrint('Report screen failed: $error');
        debugPrint('$stackTrace');

        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Narinig ko ang iyong utos, pero hindi ko mabuksan ang product report screen.'
              : 'I heard your command, but I could not open the product report screen.',
        );
      }

      return;
    }

    // ============================================================
    // DARK MODE
    // ============================================================
    if (target == 'dark_mode') {
      try {
        await setAppThemeMode(ThemeMode.dark);

        try {
          await AuthService().updateUserData({'theme': 'Dark Mode'});
        } catch (error) {
          debugPrint('Theme preference save failed: $error');
        }

        await VoiceAssistantService.instance.speak(
          commandSpeech ??
              (localeKey == 'fil'
                  ? 'Naka-on na ang dark mode.'
                  : 'Dark mode turned on.'),
        );
      } catch (error, stackTrace) {
        debugPrint('Dark mode failed: $error');
        debugPrint('$stackTrace');

        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Narinig ko ang iyong utos, pero hindi ko ma-on ang dark mode.'
              : 'I heard your command, but I could not turn on dark mode.',
        );
      }

      return;
    }

    // ============================================================
    // LIGHT MODE
    // ============================================================
    if (target == 'light_mode') {
      try {
        await setAppThemeMode(ThemeMode.light);

        try {
          await AuthService().updateUserData({'theme': 'Default'});
        } catch (error) {
          debugPrint('Theme preference save failed: $error');
        }

        await VoiceAssistantService.instance.speak(
          commandSpeech ??
              (localeKey == 'fil'
                  ? 'Naka-on na ang light mode.'
                  : 'Light mode turned on.'),
        );
      } catch (error, stackTrace) {
        debugPrint('Light mode failed: $error');
        debugPrint('$stackTrace');

        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Narinig ko ang iyong utos, pero hindi ko ma-on ang light mode.'
              : 'I heard your command, but I could not turn on light mode.',
        );
      }

      return;
    }

    // ============================================================
    // VOICE ASSISTANT OFF
    // ============================================================
    if (target == 'voice_assistant_off') {
      await VoiceAssistantService.instance.speak(
        localeKey == 'fil'
            ? 'Naka-off na ang voice assistant.'
            : 'Voice assistant disabled.',
      );

      await VoiceAssistantService.instance.updateEnabled(false);

      try {
        await AuthService().updateUserData({'voiceAssistant': false});
      } catch (error) {
        debugPrint('Voice assistant preference save failed: $error');
      }

      return;
    }

    // ============================================================
    // VOICE ASSISTANT ON
    // ============================================================
    if (target == 'voice_assistant_on') {
      await VoiceAssistantService.instance.updateEnabled(true);

      try {
        await AuthService().updateUserData({'voiceAssistant': true});
      } catch (error) {
        debugPrint('Voice assistant preference save failed: $error');
      }

      await VoiceAssistantService.instance.speak(
        commandSpeech ??
            (localeKey == 'fil'
                ? 'Naka-on na ang voice assistant.'
                : 'Voice assistant enabled.'),
      );

      return;
    }

    // ============================================================
    // MFA ON
    // ============================================================
    if (target == 'mfa_on') {
      try {
        HomeTabController.switchToTab(3); // Profile tab
        await AuthService().setMfaEnabled(enabled: true);

        unawaited(() async {
          await Future.delayed(const Duration(milliseconds: 350));
          await VoiceAssistantService.instance.speak(
            commandSpeech ??
                (localeKey == 'fil'
                    ? 'Naka-on na ang multi-factor authentication para sa iyong account.'
                    : 'Multi-factor authentication has been turned on for your account.'),
          );
        }());
      } catch (error, stackTrace) {
        debugPrint('MFA enable failed: $error\n$stackTrace');
        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Narinig ko ang iyong utos, pero hindi ko ma-on ang multi-factor authentication.'
              : 'I heard your command, but I could not enable multi-factor authentication.',
        );
      }

      return;
    }

    // ============================================================
    // MFA OFF
    // ============================================================
    if (target == 'mfa_off') {
      try {
        HomeTabController.switchToTab(3); // Profile tab
        await AuthService().setMfaEnabled(enabled: false);

        unawaited(() async {
          await Future.delayed(const Duration(milliseconds: 350));
          await VoiceAssistantService.instance.speak(
            commandSpeech ??
                (localeKey == 'fil'
                    ? 'Naka-off na ang multi-factor authentication.'
                    : 'Multi-factor authentication has been turned off.'),
          );
        }());
      } catch (error, stackTrace) {
        debugPrint('MFA disable failed: $error\n$stackTrace');
        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Narinig ko ang iyong utos, pero hindi ko ma-off ang multi-factor authentication.'
              : 'I heard your command, but I could not disable multi-factor authentication.',
        );
      }

      return;
    }

    // ============================================================
    // MFA (TOGGLE / TURN ON)
    // ============================================================
    if (target == 'mfa') {
      try {
        HomeTabController.switchToTab(3); // Profile tab
        final currentMfa = AuthService.mfaNotifier.value;
        final newMfa = !currentMfa;
        await AuthService().setMfaEnabled(enabled: newMfa);

        final msg = newMfa
            ? (localeKey == 'fil'
                  ? 'Naka-on na ang multi-factor authentication para sa iyong account.'
                  : 'Multi-factor authentication has been turned on for your account.')
            : (localeKey == 'fil'
                  ? 'Naka-off na ang multi-factor authentication.'
                  : 'Multi-factor authentication has been turned off.');

        unawaited(() async {
          await Future.delayed(const Duration(milliseconds: 350));
          await VoiceAssistantService.instance.speak(commandSpeech ?? msg);
        }());
      } catch (error, stackTrace) {
        debugPrint('MFA toggle failed: $error\n$stackTrace');
        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Narinig ko ang iyong utos, pero nagkaroon ng problema sa multi-factor authentication.'
              : 'I heard your command, but there was a problem with multi-factor authentication.',
        );
      }

      return;
    }

    // ============================================================
    // LOGOUT
    // ============================================================
    if (target == 'logout') {
      try {
        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Matagumpay kang na-log out. Babalik sa login screen.'
              : 'You have been successfully logged out. Returning to the login screen.',
        );

        await AuthService().signOut();
      } catch (error, stackTrace) {
        debugPrint('Logout failed: $error');
        debugPrint('$stackTrace');

        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Narinig ko ang iyong utos, pero hindi ko makumpleto ang pag-log out dahil nagkaroon ng problema.'
              : 'I heard your command, but I could not complete the logout because an error occurred.',
        );
      }

      return;
    }

    // ============================================================
    // LANGUAGE
    // ============================================================
    if (target == 'language_tagalog') {
      try {
        await LocaleService.setAppLocale('tl');
        await VoiceAssistantService.instance.updateLanguage(VoiceLang.tagalog);

        unawaited(() async {
          await Future.delayed(const Duration(milliseconds: 350));
          await VoiceAssistantService.instance.speak(
            commandSpeech ?? 'Pinalitan ang wika sa Tagalog.',
          );
        }());
      } catch (error, stackTrace) {
        debugPrint('Tagalog language change failed: $error');
        debugPrint('$stackTrace');

        await VoiceAssistantService.instance.speak(
          'Narinig ko ang iyong utos, pero hindi ko mapalitan ang wika sa Tagalog ngayon.',
        );
      }

      return;
    }

    if (target == 'language_english') {
      try {
        await LocaleService.setAppLocale('en');

        await VoiceAssistantService.instance.updateLanguage(VoiceLang.english);

        unawaited(() async {
          await Future.delayed(const Duration(milliseconds: 350));
          await VoiceAssistantService.instance.speak(
            commandSpeech ?? 'Language changed to English.',
          );
        }());
      } catch (error, stackTrace) {
        debugPrint('English language change failed: $error');
        debugPrint('$stackTrace');

        await VoiceAssistantService.instance.speak(
          'I heard your command, but I could not change the language to English right now.',
        );
      }

      return;
    }

    if (target == 'language') {
      final currentLang = LocaleService.localeNotifier.value.languageCode;
      final newLangCode = currentLang == 'tl' ? 'en' : 'tl';
      final newVoiceLang = newLangCode == 'tl'
          ? VoiceLang.tagalog
          : VoiceLang.english;

      try {
        await LocaleService.setAppLocale(newLangCode);
        await VoiceAssistantService.instance.updateLanguage(newVoiceLang);

        final msg = newLangCode == 'tl'
            ? 'Pinalitan ang wika sa Tagalog.'
            : 'Language changed to English.';

        unawaited(() async {
          await Future.delayed(const Duration(milliseconds: 350));
          await VoiceAssistantService.instance.speak(msg);
        }());
      } catch (error, stackTrace) {
        debugPrint('Toggle language failed: $error');
        debugPrint('$stackTrace');

        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Narinig ko ang iyong utos, pero nagkaroon ng problema sa pagpalit ng wika.'
              : 'I heard your command, but there was a problem changing the language.',
        );
      }

      return;
    }

    // ============================================================
    // COMPARISON
    // ============================================================
    if (target == 'compare_products') {
      final currentProduct =
          VoiceAssistantService.activeResultProductNotifier.value ??
          VoiceAssistantService.latestScanProductNotifier.value;

      if (currentProduct == null) {
        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Walang produktong maihahambing. Mag-scan muna ng produkto.'
              : 'No product is available to compare. Please scan a product first.',
        );
        return;
      }

      final msg =
          commandSpeech ??
          (localeKey == 'fil'
              ? 'Binubuksan ang paghahambing para sa ${currentProduct.name}.'
              : 'Opening comparison for ${currentProduct.name}.');

      unawaited(VoiceAssistantService.instance.speak(msg));

      try {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CompareProductsScreen(sourceProduct: currentProduct),
          ),
        );
      } catch (error, stackTrace) {
        debugPrint('Comparison screen failed: $error');
        debugPrint('$stackTrace');

        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Narinig ko ang iyong utos, pero hindi ko mabuksan ang comparison screen.'
              : 'I heard your command, but I could not open the comparison screen.',
        );
      }

      return;
    }

    // ============================================================
    // MORE DETAILS
    // ============================================================
    if (target == 'more_details') {
      final currentProduct =
          VoiceAssistantService.activeResultProductNotifier.value ??
          VoiceAssistantService.latestScanProductNotifier.value;

      if (currentProduct == null) {
        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Walang produktong mabibigyan ng karagdagang detalye. Mag-scan muna ng produkto.'
              : 'No product is available for more details. Please scan a product first.',
        );
        return;
      }

      final msg =
          commandSpeech ??
          (localeKey == 'fil'
              ? 'Binubuksan ang karagdagang detalye para sa ${currentProduct.name}.'
              : 'Opening more details for ${currentProduct.name}.');

      unawaited(VoiceAssistantService.instance.speak(msg));

      try {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MoreDetailsScreen(product: currentProduct),
          ),
        );
      } catch (error, stackTrace) {
        debugPrint('More details screen failed: $error');
        debugPrint('$stackTrace');

        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Narinig ko ang iyong utos, pero hindi ko mabuksan ang product details.'
              : 'I heard your command, but I could not open the product details.',
        );
      }

      return;
    }

    // ============================================================
    // INVITE PEOPLE / GROUP
    // ============================================================
    if (target == 'invite_people' || target == 'group') {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      HomeTabController.switchToTab(3); // Profile tab

      final msg = localeKey == 'fil'
          ? 'Binubuksan ang mga health group at imbitasyon.'
          : 'Opening health groups and invitations.';

      unawaited(
        VoiceAssistantService.instance.announcePageWithPreamble(
          msg,
          target == 'invite_people' ? 'invite_people' : 'group',
        ),
      );

      await Future.delayed(const Duration(milliseconds: 400));

      if (!context.mounted) return;

      try {
        final loc = AppLocalizations.of(context);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => Scaffold(
              backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
              appBar: AppBar(
                backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
                elevation: 0,
                title: Text(loc?.groupTab ?? 'Health Groups'),
              ),
              body: const SafeArea(child: GroupScreen()),
            ),
          ),
        );
      } catch (error, stackTrace) {
        debugPrint('Invite people navigation failed: $error');
        debugPrint('$stackTrace');
        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Hindi ko mabuksan ang group screen.'
              : 'I could not open the groups screen.',
        );
      }

      return;
    }

    // ============================================================
    // NUTRITION GUIDE SCREENS (from Gemini target)
    // ============================================================
    if (target == 'nutrition_guide_fda') {
      await _handleNutritionGuideNavigation(
        context, NutritionGuideType.fda, localeKey,
      );
      return;
    }
    if (target == 'nutrition_guide_who') {
      await _handleNutritionGuideNavigation(
        context, NutritionGuideType.who, localeKey,
      );
      return;
    }
    if (target == 'nutrition_guide_kidney') {
      await _handleNutritionGuideNavigation(
        context, NutritionGuideType.kidney, localeKey,
      );
      return;
    }
    if (target == 'nutrition_guide_gerd') {
      await _handleNutritionGuideNavigation(
        context, NutritionGuideType.gerd, localeKey,
      );
      return;
    }

    // ============================================================
    // RETURN TO ROOT
    // ============================================================
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    // ============================================================
    // CLEAR HISTORY
    // ============================================================
    if (target == 'clear_history') {
      HomeTabController.switchToHistorySubTab('Lahat');

      final msg = localeKey == 'fil'
          ? 'Para burahin ang iyong kasaysayan ng scan, i-tap ang trash icon sa itaas ng History screen.'
          : 'To clear your scan history, please tap the trash icon at the top of the History screen.';

      unawaited(() async {
        await Future.delayed(const Duration(milliseconds: 350));
        await VoiceAssistantService.instance.speak(msg);
      }());

      return;
    }

    // ============================================================
    // CLEAR FAVORITES
    // ============================================================
    if (target == 'clear_favorites') {
      HomeTabController.switchToHistorySubTab('Paborito');

      final msg = localeKey == 'fil'
          ? 'Para burahin ang iyong mga paborito, i-tap ang trash icon sa itaas ng screen.'
          : 'To clear your favorites, please tap the trash icon at the top of the screen.';

      unawaited(() async {
        await Future.delayed(const Duration(milliseconds: 350));
        await VoiceAssistantService.instance.speak(msg);
      }());

      return;
    }

    // ============================================================
    // DELETE ACCOUNT
    // ============================================================
    if (target == 'delete_account') {
      HomeTabController.switchToTab(3); // Profile tab

      final msg = localeKey == 'fil'
          ? 'Para burahin ang iyong account, mag-scroll sa ibaba ng Profile screen at i-tap ang Delete Account.'
          : 'To delete your account, please scroll to the bottom of the Profile screen and tap Delete Account.';

      unawaited(() async {
        await Future.delayed(const Duration(milliseconds: 350));
        await VoiceAssistantService.instance.speak(msg);
      }());

      return;
    }

    // ============================================================
    // HISTORY FAVORITES
    // ============================================================
    if (target == 'history_favorites') {
      HomeTabController.switchToHistorySubTab('Paborito');

      unawaited(
        VoiceAssistantService.instance.announcePageWithPreamble(
          localeKey == 'fil'
              ? 'Binubuksan ang mga paboritong produkto.'
              : 'Opening your favorites.',
          'favorites',
        ),
      );

      return;
    }

    // ============================================================
    // HISTORY COMPARISON
    // ============================================================
    if (target == 'history_compare') {
      HomeTabController.switchToHistorySubTab('Kumpara');

      unawaited(
        VoiceAssistantService.instance.announcePageWithPreamble(
          localeKey == 'fil'
              ? 'Binubuksan ang kasaysayan ng paghahambing.'
              : 'Opening your comparison history.',
          'compare',
        ),
      );

      return;
    }

    // ============================================================
    // HISTORY REPORTS
    // ============================================================
    if (target == 'history_reports') {
      HomeTabController.switchToHistorySubTab('Mga Ulat');

      unawaited(
        VoiceAssistantService.instance.announcePageWithPreamble(
          localeKey == 'fil'
              ? 'Binubuksan ang iyong mga ulat.'
              : 'Opening your submitted reports.',
          'reports',
        ),
      );

      return;
    }

    // ============================================================
    // MAIN TABS
    // ============================================================
    if (_tabPageKeys.containsKey(target)) {
      if (target == 'history') {
        HomeTabController.switchToHistorySubTab('Lahat');
      } else {
        HomeTabController.switchToTab(_tabPageKeys[target]!);
      }

      final reply = intent.spokenReply.isNotEmpty
          ? intent.spokenReply
          : commandSpeech ?? _navigationReply(target, localeKey);

      // For history, chain the short reply with the full page description.
      // For all other tabs the short reply is sufficient.
      if (target == 'history') {
        unawaited(
          VoiceAssistantService.instance.announcePageWithPreamble(
            reply,
            'history',
          ),
        );
      } else {
        unawaited(VoiceAssistantService.instance.speak(reply));
      }

      return;
    }

    // ============================================================
    // OTHER SCREENS
    // ============================================================
    final reply = intent.spokenReply.isNotEmpty
        ? intent.spokenReply
        : _navigationReply(target, localeKey);

    unawaited(VoiceAssistantService.instance.speak(reply));

    try {
      final navigatorResult = await _navigateToScreen(context, target);

      if (!navigatorResult) {
        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Narinig ko ang iyong utos, pero hindi ko mahanap o mabuksan ang pahinang iyon.'
              : 'I heard your command, but I could not find or open that page.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Navigation failed: $error');
      debugPrint('$stackTrace');

      await VoiceAssistantService.instance.speak(
        localeKey == 'fil'
            ? 'Narinig ko ang iyong utos, pero nagkaroon ng problema habang binubuksan ang pahinang iyon.'
            : 'I heard your command, but there was a problem opening that page.',
      );
    }
  }

  Future<void> _handleSummarizeIntent(VoiceLang language) async {
    final summary = await GeminiService.instance.summarizeScan(
      language: language,
    );

    await VoiceAssistantService.instance.speak(summary);
  }

  Future<bool> _navigateToScreen(
    BuildContext context,
    String targetPage,
  ) async {
    switch (targetPage) {
      case 'personal_info':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
        );
        return true;

      case 'preference':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PreferenceScreen()),
        );
        return true;

      case 'suggestion':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SuggestionScreen()),
        );
        return true;

      case 'about_claro':
        try {
          return await launchUrl(
            Uri.parse(claroWebsiteUrl),
            mode: LaunchMode.externalApplication,
          );
        } catch (error) {
          debugPrint('Open CLARO website failed: $error');
          return false;
        }

      case 'privacy_policy':
        try {
          return await launchUrl(
            Uri.parse(privacyPolicyUrl),
            mode: LaunchMode.externalApplication,
          );
        } catch (error) {
          debugPrint('Open privacy policy failed: $error');
          return false;
        }

      case 'terms_conditions':
        try {
          return await launchUrl(
            Uri.parse(termsConditionsUrl),
            mode: LaunchMode.externalApplication,
          );
        } catch (error) {
          debugPrint('Open terms failed: $error');
          return false;
        }

      case 'user_guide':
        try {
          return await launchUrl(
            Uri.parse(userGuideUrl),
            mode: LaunchMode.externalApplication,
          );
        } catch (error) {
          debugPrint('Open user guide failed: $error');
          return false;
        }

      case 'change_password':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
        );
        return true;

      case 'theme':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ThemeScreen()),
        );
        return true;

      case 'review_history':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReviewHistoryScreen()),
        );
        return true;

      default:
        return false;
    }
  }

  @visibleForTesting
  String? testTargetFromTranscript(String transcript) =>
      _targetFromTranscript(transcript);

  @visibleForTesting
  String? testMatchOfflineSlot(String transcript) => _matchOfflineSlot(transcript);

  @visibleForTesting
  NutritionGuideType? testMatchNutritionGuideQuestion(String transcript) => _matchNutritionGuideQuestion(transcript);

  @visibleForTesting
  String testNavigationReply(String target, String localeKey) => _navigationReply(target, localeKey);

  @visibleForTesting
  String? testExtractProductSearchQuery(String transcript) =>
      _extractProductSearchQuery(transcript);

  @visibleForTesting
  String testNutritionGuideExplanation(NutritionGuideType type, String localeKey) =>
      _nutritionGuideExplanation(type, localeKey);

  @visibleForTesting
  bool testLooksLikeProductQuestion(String transcript) =>
      _looksLikeProductQuestion(transcript);

  bool _looksLikeProductQuestion(String transcript) {
    final normalized = transcript
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .trim();

    if (normalized.isEmpty) return false;

    final englishPatterns = [
      r'\b(?:what|what are|what is|which|show|tell|read|give|say|can you tell|can you say|are there|is there)\b.*\b(?:allergen|allergens|ingredients|sugar|sugars|sodium|nutrition|health|healthy|safe to eat|okay to eat|warning|warnings)\b',
      r'\b(?:allergen|allergens|ingredients|sugar|sugars|sodium|nutrition|health|healthy|safe to eat|okay to eat|warning|warnings)\b',
    ];
    final tagalogPatterns = [
      r'\b(?:ano|anong|alin|alamin|sabihin|ipasabi|show|tignan|may|meron|meron ba|may mga|may ba)\b.*\b(?:allergen|allergens|allergen ba|sangkap|mga sangkap|asukal|sodium|sodium ba|nutrisyon|kalusugan|safe ba|okay ba|babala|mga babala)\b',
      r'\b(?:allergen|allergens|sangkap|mga sangkap|asukal|sodium|nutrisyon|kalusugan|safe ba|okay ba|babala|mga babala)\b',
    ];

    final patterns = [...englishPatterns, ...tagalogPatterns];
    return patterns.any((pattern) => RegExp(pattern).hasMatch(normalized));
  }

  String? _targetFromTranscript(String transcript) {
    final normalized = transcript.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9 ]'),
      ' ',
    );

    // ============================================================
    // UNFAVORITE
    // ============================================================
    if (RegExp(
      r'\b(unfavorite(?: this(?: product)?)?|unfavorite it|remove from favorites|unlike(?: this(?: product)?)?|remove favorite|alisin sa (?:mga )?paborito|tanggalin sa (?:mga )?paborito|i\s*unfavorite(?: ito)?|wag nang paborito|di na paborito|alisin sa saved|tanggalin sa saved)\b',
    ).hasMatch(normalized)) {
      return 'unfavorite_product';
    }

    // ============================================================
    // FAVORITE
    // ============================================================
    if (RegExp(
      r'\b(favorite(?: this(?: product)?)?|favorite it|add to favorites|save to favorites|save this(?: product)?|save product|like(?: this(?: product)?)?|i\s*favorite(?: ito)?|i\s*paborito(?: ito)?|paborito ito|gusto ko ito|i\s*save(?: ito)?|isave(?: ito)?|idagdag sa (?:mga )?paborito|isama sa (?:mga )?paborito|gawing paborito|ilagay sa (?:mga )?paborito|ilagay sa favorites|ilagay ito sa favorites)\b',
    ).hasMatch(normalized)) {
      return 'favorite_product';
    }

    // ============================================================
    // REPORT
    // ============================================================
    if (RegExp(
      r'\b(report(?: this(?: product)?)?|report product|report issue|report error|i\s*report(?: ito)?|ireport(?: ito)?|i\s*ulat(?: ito)?|iulat(?: ito)?|mali ang impormasyon|maling produkto|mag\s*ulat|mag\s*report|i\s*report ang produkto|i\s*ulat ang produkto)\b',
    ).hasMatch(normalized)) {
      return 'report_product';
    }

    // ============================================================
    // MORE DETAILS
    // ============================================================
    if (RegExp(
      r'\b(more details|for more details|show more details|open more details|see more details|view more details|product details|ingredients|storage instructions|storage|karagdagang detalye|karagdagang impormasyon|mga sangkap|sangkap|paraan ng pag\s*imbak|imbak|detalye ng produkto|detalye|buksan ang (?:mga )?detalye|tingnan ang (?:mga )?detalye|ipakita ang (?:mga )?detalye|alamin ang sangkap)\b',
    ).hasMatch(normalized)) {
      return 'more_details';
    }

    // ============================================================
    // COMPARE
    // ============================================================
    if (RegExp(
      r'\b(compare(?: this(?: product)?)?|compare product|compare scanned product|compare with alternatives|compare with others|paki\s*compare(?: nito| ito| ang produkto)?|ihambing(?: ang produktong ito)?|paghambingin(?: ito)?|pagkumparahin(?: ito)?|ikumpera(?: ito)?|ikumpra(?: ito)?|ihambing ito|ihambing ang produkto|paghambingin ang (?:mga )?produkto|ikumpera sa iba|ihambing sa iba)\b',
    ).hasMatch(normalized)) {
      return 'compare_products';
    }

    // ============================================================
    // CLEAR HISTORY & FAVORITES (GUIDED ACTIONS)
    // ============================================================
    if (RegExp(
      r'\b(clear\s+(?:all\s+)?(?:my\s+)?(?:scan\s+)?history|delete\s+(?:all\s+)?(?:my\s+)?(?:scan\s+)?history|erase\s+(?:all\s+)?(?:my\s+)?(?:scan\s+)?history|wipe\s+(?:all\s+)?(?:my\s+)?(?:scan\s+)?history|remove\s+all\s+history|burahin\s+(?:ang\s+)?(?:lahat\s+ng\s+)?(?:aking\s+)?(?:scan\s+)?(?:history|kasaysayan)|tanggalin\s+(?:ang\s+)?(?:lahat\s+ng\s+)?(?:aking\s+)?(?:scan\s+)?(?:history|kasaysayan)|alisin\s+(?:ang\s+)?(?:lahat\s+ng\s+)?(?:aking\s+)?(?:scan\s+)?(?:history|kasaysayan)|linisin\s+(?:ang\s+)?(?:lahat\s+ng\s+)?(?:aking\s+)?(?:scan\s+)?(?:history|kasaysayan)|i\s*clear\s+(?:ang\s+)?(?:lahat\s+ng\s+)?(?:aking\s+)?(?:scan\s+)?(?:history|kasaysayan)|i\s*delete\s+(?:ang\s+)?(?:lahat\s+ng\s+)?(?:aking\s+)?(?:scan\s+)?(?:history|kasaysayan))\b',
    ).hasMatch(normalized)) {
      return 'clear_history';
    }

    if (RegExp(
      r'\b(clear\s+(?:all\s+)?(?:my\s+)?favorites|delete\s+(?:all\s+)?(?:my\s+)?favorites|erase\s+(?:all\s+)?(?:my\s+)?favorites|burahin\s+(?:ang\s+)?(?:lahat\s+ng\s+)?(?:aking\s+)?(?:mga\s+)?paborito|tanggalin\s+(?:ang\s+)?(?:lahat\s+ng\s+)?(?:aking\s+)?(?:mga\s+)?paborito|alisin\s+(?:ang\s+)?(?:lahat\s+ng\s+)?(?:aking\s+)?(?:mga\s+)?paborito|linisin\s+(?:ang\s+)?(?:lahat\s+ng\s+)?(?:aking\s+)?(?:mga\s+)?paborito|i\s*clear\s+(?:ang\s+)?(?:lahat\s+ng\s+)?(?:aking\s+)?(?:mga\s+)?paborito|i\s*delete\s+(?:ang\s+)?(?:lahat\s+ng\s+)?(?:aking\s+)?(?:mga\s+)?paborito)\b',
    ).hasMatch(normalized)) {
      return 'clear_favorites';
    }

    if (RegExp(
      r'\b(delete\s+(?:my\s+)?account|remove\s+(?:my\s+)?account|close\s+(?:my\s+)?account|erase\s+(?:my\s+)?account|burahin\s+(?:ang\s+)?(?:aking\s+)?account|tanggalin\s+(?:ang\s+)?(?:aking\s+)?account|alisin\s+(?:ang\s+)?(?:aking\s+)?account|isara\s+(?:ang\s+)?(?:aking\s+)?account|i\s*delete\s+(?:ang\s+)?(?:aking\s+)?account)\b',
    ).hasMatch(normalized)) {
      return 'delete_account';
    }

    // ============================================================
    // HISTORY SUB-TABS
    // ============================================================
    if (RegExp(
      r'\b(favorite|favorites|paborito|mga paborito|my favorites|paboritong produkto|mga paboritong produkto|saved products|saved product|saved items|saved|mga naka\s*save|naka\s*save)\b',
    ).hasMatch(normalized)) {
      return 'history_favorites';
    }

    if (RegExp(
      r'\b(compare history|comparison history|comparison records|history compare|kasaysayan ng paghahambing|mga pinaghambing|mga kinumpara|past comparisons|nakaraang paghahambing)\b',
    ).hasMatch(normalized)) {
      return 'history_compare';
    }

    if (RegExp(
      r'\b(compare|comparison|comparisons|compared|kumpara|ihambing|paghambingin|ikumpra|ikumpera)\b',
    ).hasMatch(normalized)) {
      if (VoiceAssistantService.activeResultProductNotifier.value != null) {
        return 'compare_products';
      }

      return 'history_compare';
    }

    if (RegExp(
      r'\b(reports|my reports|submitted reports|mga ulat|ulat|aking mga ulat|report history|view reports|show reports|kasaysayan ng ulat|mga na\s*report|mga naulat)\b',
    ).hasMatch(normalized)) {
      return 'history_reports';
    }

    // ============================================================
    // MAIN TABS
    // ============================================================
    if (RegExp(
      r'\b(home|main|dashboard|simula|home page|home screen|main page|main screen|tahanan|unang pahina|balik sa home|punta sa home|pangunahing screen)\b',
    ).hasMatch(normalized)) {
      return 'home';
    }

    if (RegExp(
      r'\b(scan|scanner|camera|mag\s*scan|magscan|mag scan|camera screen|scan screen|take a scan|scan a product|kumuha ng scan|buksan ang camera|buksan ang scanner|mag\s*picture|i\s*scan)\b',
    ).hasMatch(normalized)) {
      return 'scan';
    }

    if (RegExp(
      r'\b(history|records|previous scans|mga na\s*scan|mga nascan|mga nakaraang scan|kasaysayan|scan history|all scans|lahat ng scan)\b',
    ).hasMatch(normalized)) {
      return 'history';
    }

    // ============================================================
    // PERSONAL INFORMATION
    // ============================================================
    if (RegExp(
      r'\b(personal information|personal info|my info|my information|account information|personal na impormasyon|personal details|profile details|user info|user details|my name|my email|edit profile|aking impormasyon|aking detalye|aking pangalan|aking email|baguhin ang profile)\b',
    ).hasMatch(normalized)) {
      return 'personal_info';
    }

    // ============================================================
    // VOICE ASSISTANT
    // ============================================================
    if (RegExp(
      r'\b(voice assistant off|voice off|turn off voice assistant|turn off voice|disable voice assistant|disable voice|mute voice assistant|mute voice|i\s*off ang voice assistant|patayin ang boses|patayin ang voice assistant|i\s*off ang boses|isara ang voice assistant|i\s*mute ang boses|i\s*mute ang voice assistant)\b',
    ).hasMatch(normalized)) {
      return 'voice_assistant_off';
    }

    if (RegExp(
      r'\b(voice assistant on|voice on|turn on voice assistant|turn on voice|enable voice assistant|enable voice|unmute voice assistant|unmute voice|i\s*on ang voice assistant|buhayin ang boses|buhayin ang voice assistant|i\s*on ang boses|buksan ang voice assistant|buksan ang boses|paganahin ang voice assistant)\b',
    ).hasMatch(normalized)) {
      return 'voice_assistant_on';
    }

    // ============================================================
    // MFA
    // ============================================================
    if (RegExp(
      r'\b(turn off (?:mfa|multi factor|two factor|2fa)|disable (?:mfa|multi factor|two factor|2fa)|deactivate (?:mfa|multi factor|two factor|2fa)|switch off (?:mfa|2fa)|mfa off|2fa off|i\s*off ang (?:mfa|multi factor|two factor|2fa)|patayin ang (?:mfa|multi factor|two factor|2fa)|isara ang (?:mfa|multi factor|two factor|2fa)|i\s*disable ang (?:mfa|2fa)|i\s*deactivate ang (?:mfa|2fa)|isara ang dalawang yugtong pagpapatunay)\b',
    ).hasMatch(normalized)) {
      return 'mfa_off';
    }

    if (RegExp(
      r'\b(turn on (?:mfa|multi factor|two factor|2fa)|enable (?:mfa|multi factor|two factor|2fa)|activate (?:mfa|multi factor|two factor|2fa)|switch on (?:mfa|2fa)|mfa on|2fa on|i\s*on ang (?:mfa|multi factor|two factor|2fa)|buhayin ang (?:mfa|multi factor|two factor|2fa)|buksan ang (?:mfa|multi factor|two factor|2fa)|paganahin ang (?:mfa|multi factor|two factor|2fa)|i\s*enable ang (?:mfa|2fa)|i\s*activate ang (?:mfa|2fa)|buksan ang dalawang yugtong pagpapatunay)\b',
    ).hasMatch(normalized)) {
      return 'mfa_on';
    }

    if (RegExp(
      r'\b(multi factor authentication|two factor authentication|multi factor|two factor|mfa|2fa|dalawang yugtong pagpapatunay|mfa settings|2fa settings)\b',
    ).hasMatch(normalized)) {
      return 'mfa';
    }

    // ============================================================
    // DARK MODE
    // ============================================================
    if (RegExp(
      r'\b(dark mode off|darkmode off|turn off dark mode|turn off darkmode|disable dark mode|disable darkmode|i\s*off ang dark mode|patayin ang dark mode)\b',
    ).hasMatch(normalized)) {
      return 'light_mode';
    }

    if (RegExp(
      r'\b(light mode off|lightmode off|turn off light mode|turn off lightmode|disable light mode|disable lightmode|i\s*off ang light mode|patayin ang light mode)\b',
    ).hasMatch(normalized)) {
      return 'dark_mode';
    }

    if (RegExp(
      r'\b(turn on dark mode|turn on darkmode|enable dark mode|enable darkmode|switch to dark mode|dark mode on|darkmode on|diliman ang tema|dark theme|i\s*dark mode|madilim na tema|diliman|darkmode|dark mode|gawing madilim ang tema|buksan ang dark mode|i\s*on ang dark mode)\b',
    ).hasMatch(normalized)) {
      return 'dark_mode';
    }

    if (RegExp(
      r'\b(turn on light mode|turn on lightmode|enable light mode|enable lightmode|switch to light mode|light mode on|lightmode on|liwanagan ang tema|light theme|default theme|i\s*light mode|maliwanag na tema|liwanagan|lightmode|light mode|gawing maliwanag ang tema|buksan ang light mode|i\s*on ang light mode|orihinal na tema)\b',
    ).hasMatch(normalized)) {
      return 'light_mode';
    }

    // ============================================================
    // LANGUAGE
    // ============================================================
    if (RegExp(
      r'\b((?:change|switch|set|convert) (?:the\s+)?(?:language|voice|wika)?\s*(?:to|into|sa)?\s*(?:tagalog|filipino)|(?:palitan|magpalit|baguhin|gawin|ilipat|lumipat)\s*(?:ang\s+|ng\s+|nang\s+)?(?:wika|boses)?\s*(?:sa|ng|na|para sa)?\s*(?:tagalog|filipino)|mag\s*tagalog|magsalita\s+(?:ng|sa)\s+(?:tagalog|filipino)|gamitin\s+ang\s+(?:tagalog|filipino)|tagalog\s+(?:po|please|voice|wika|lang)|i\s*tagalog|speak\s+(?:in\s+)?(?:tagalog|filipino)|boses\s+sa\s+tagalog|^tagalog$|^filipino$)\b',
    ).hasMatch(normalized)) {
      return 'language_tagalog';
    }

    if (RegExp(
      r'\b((?:change|switch|set|convert) (?:the\s+)?(?:language|voice|wika)?\s*(?:to|into|sa)?\s*(?:english|ingles)|(?:palitan|magpalit|baguhin|gawin|ilipat|lumipat)\s*(?:ang\s+|ng\s+|nang\s+)?(?:wika|boses)?\s*(?:sa|ng|na)?\s*(?:english|ingles)|mag\s*english|magsalita\s+(?:ng|sa)\s+english|gamitin\s+ang\s+(?:english|ingles)|english\s+(?:po|please|voice|wika|lang)|i\s*english|speak\s+(?:in\s+)?english|boses\s+sa\s+english|^english$|^ingles$)\b',
    ).hasMatch(normalized)) {
      return 'language_english';
    }

    if (RegExp(
      r'\b(language change|change language|switch language|language settings|language setting|wika|palitan ang wika|magpalit ng wika|baguhin ang wika|mga setting ng wika)\b',
    ).hasMatch(normalized)) {
      return 'language';
    }

    // ============================================================
    // OTHER SETTINGS
    // ============================================================
    if (RegExp(
      r'\b(theme screen|theme settings|theme setting|open theme|mga setting ng tema|mga tema|tema|tema ng app|appearance|buksan ang tema|tingnan ang tema)\b',
    ).hasMatch(normalized)) {
      return 'theme';
    }

    if (RegExp(
      r'\b(preference|preferences|health preference|health preferences|dietary preference|dietary preferences|kagustuhan|mga kagustuhan|health conditions|health condition|medical conditions|medical condition|allergies|allergy|mga allergy|kondisyon sa kalusugan|pangkalusugan|my health|my preferences|aking kalusugan)\b',
    ).hasMatch(normalized)) {
      return 'preference';
    }

    if (RegExp(
      r'\b(?:user guide|app guide|manual|how to use(?: claro| the app| this)?|how do i use(?: claro| this app| this)?|how does (?:this|claro) work|app tutorial|instructions|gabay sa paggamit|gabay ng gumagamit|paano gamitin(?: ang claro| ang app| ito| to)?|paano (?:ito|to) gamitin|tulong sa paggamit|turuan mo ako paano gamitin|tutorial sa paggamit|paraan ng paggamit|gabay kung paano gamitin)\b',
    ).hasMatch(normalized)) {
      return 'user_guide';
    }

    if (RegExp(
      r'\b(suggestion|suggestions|feedback|feedbacks|mungkahi|komento|comment|comments|suggest|help|support|contact|magbigay ng feedback|mungkahi at puna|tulong|suporta)\b',
    ).hasMatch(normalized)) {
      return 'suggestion';
    }

    if (RegExp(
      r'\b(app reviews|app review|review history|reviews|mga review|kasaysayan ng review|pagsusuri ng app)\b',
    ).hasMatch(normalized)) {
      return 'review_history';
    }

    if (RegExp(
      r'\b(?:about claro|what is claro|tell me about claro|about (?:the )?app|about us|who (?:made|created|developed) claro|app info|claro info|information about claro|learn about claro|what does claro do|what is this app|tungkol sa claro|ano ang claro|ano itong claro|ano ba ang claro|impormasyon (?:tungkol )?sa claro|alamin ang tungkol sa claro|sino ang (?:gumawa ng )?claro|sino gumawa ng claro|tungkol sa app|ano ang app na ito|tungkol dito|kwento ng claro|ano ang layunin ng claro)\b',
    ).hasMatch(normalized)) {
      return 'about_claro';
    }

    if (RegExp(
      r'\b(?:privacy policy|data privacy|data protection|privacy statement|privacy terms|privacy|patakaran sa privacy|patakaran sa data|seguridad ng data|proteksyon ng data|privacy ng datos|paano iniingatan ang data|paano pinoprotektahan ang data|patakaran sa pribadong impormasyon|pribadong datos)\b',
    ).hasMatch(normalized)) {
      return 'privacy_policy';
    }

    if (RegExp(
      r'\b(?:terms and conditions?|terms of service|terms of use|user agreement|service terms|terms|mga tuntunin at k(?:u|o)ndisyon|tuntunin at k(?:u|o)ndisyon|mga tuntunin|mga k(?:u|o)ndisyon|k(?:u|o)ndisyon sa paggamit|tuntunin sa paggamit|tuntunin ng serbisyo|kasunduan sa paggamit|kasunduan ng gumagamit)\b',
    ).hasMatch(normalized)) {
      return 'terms_conditions';
    }

    // ============================================================
    // NUTRITION GUIDES (specific types)
    // ============================================================
    if (RegExp(
      r'\b(?:(?:how (?:to|do (?:i|you)) (?:read|understand|check|use)|explain|what (?:is|are)|reading|understand|guide (?:for|to|on)|learn (?:to )?read) (?:a |the )?(?:nutrition|food|facts )?labels?|nutrition facts labels?|nutrition labels? guide|food labels? guide|fda guide|fda nutrition|nutrition facts|food labels?|nutrition labels?|how to read label|reading label|read label|paano (?:basahin|magbasa|intindihin|tingnan) (?:ang |ng )?(?:nutrition |food )?labels?|paano (?:basahin|magbasa|intindihin) (?:ang |ng )?label|gabay sa (?:pagbasa |pagbabasa )?(?:ng )?labels?|ipaliwanag ang (?:nutrition )?labels?|ipaliwanag ang label|ano ang (?:nutrition )?labels?|ano ang label ng pagkain|label(?:s)? ng pagkain|pagbasa ng labels?)\b',
    ).hasMatch(normalized)) {
      return 'nutrition_guide_fda';
    }

    if (RegExp(
      r'\b(?:(?:who|w h o)\s*(?:guidelines?|guides?|recommendations?|limits?|thresholds?|nutrition|diet|daily limits?)|limits? (?:on|of|by|from) (?:the )?(?:who|w h o)|daily (?:nutrient|nutritional|nutrition|intake|dietary)?\s*(?:guidelines?|guides?|recommendations?|values?|requirements?|targets?|limits?)|recommended daily (?:intakes?|allowances?|nutrients?|values?|amounts?|limits?)|daily intakes?|daily nutrients?|daily nutrition|daily limits?|healthy diet (?:guidelines?|guide)|how much (?:sodium|sugar|fat|calories) (?:should|per day|daily)|daily (?:sodium|sugar|fat|calorie) limits?|limit(?:asyon)? (?:sa|ng) (?:who|w h o)|mga limitasyon (?:sa|ng) (?:who|w h o)|rekomendasyon ng (?:who|w h o)|gabay ng (?:who|w h o)|pang araw araw na (?:gabay|sustansya|nutrisyon|limitasyon)|araw araw na (?:gabay|sustansya|nutrisyon|limitasyon)|gabay sa sustansya|rekomendadong sustansya|tamang dami ng sustansya|sustansya bawat araw|limitasyon sa asukal at asin|magkano ang (?:sodium|asin|asukal) bawat araw)\b',
    ).hasMatch(normalized)) {
      return 'nutrition_guide_who';
    }

    if (RegExp(
      r'\b(?:kidneys?|renal|nephro|bato|sakit sa bato|gabay sa bato|gabay sa sakit sa bato|diyeta para sa bato|pagkain para sa (?:may )?sakit sa bato|pagkain sa sakit sa bato|nutrisyon para sa (?:may )?sakit sa bato)\b',
    ).hasMatch(normalized)) {
      return 'nutrition_guide_kidney';
    }

    if (RegExp(
      r'\b(?:gerd|acid reflux|heartburn|hyperacidity|sikmura|asim ng sikmura|gabay sa gerd|gabay sa acid reflux|pagkain para sa acid reflux|bawal sa (?:may )?acid reflux|bawal sa gerd)\b',
    ).hasMatch(normalized)) {
      return 'nutrition_guide_gerd';
    }

    // ============================================================
    // INVITE PEOPLE / HEALTH GROUPS
    // ============================================================
    if (RegExp(
      r'\b(invite people|invite member|invite family|mag imbita|mag invite|imbita|imbitahan|invite someone|invite friends|add member|add family|health group|create group|join group|lumikha ng grupo|sumali sa grupo|gumawa ng grupo|mga grupo)\b',
    ).hasMatch(normalized)) {
      return 'invite_people';
    }

    if (RegExp(
      r'\b(change password|reset password|palitan ang password|baguhin ang password|update password|i-reset ang password|password|security settings)\b',
    ).hasMatch(normalized)) {
      return 'change_password';
    }

    // ============================================================
    // PROFILE & GENERAL SETTINGS
    // ============================================================
    if (RegExp(
      r'\b(profile|my profile|account|my account|profile page|profile screen|settings|setting|account settings|user profile|aking profile|impormasyon ng account|mga setting|setting ng account)\b',
    ).hasMatch(normalized)) {
      return 'profile';
    }

    // ============================================================
    // LOGOUT
    // ============================================================
    if (RegExp(
      r'\b(log out|logout|sign out|signout|mag log out|maglog out|mag sign out|magsign out|lumabas sa account|i\s*log out)\b',
    ).hasMatch(normalized)) {
      return 'logout';
    }

    return null;
  }

  // ================================================================
  // NUTRITION GUIDE QUESTION MATCHER
  // ================================================================
  NutritionGuideType? _matchNutritionGuideQuestion(String transcript) {
    final normalized = transcript.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9 ]'), ' ',
    ).trim();

    // FDA / How to read nutrition labels
    if (RegExp(
      r'\b(?:(?:how (?:to|do (?:i|you)) (?:read|understand|check|use)|explain|what (?:is|are)|reading|understand|guide (?:for|to|on)|learn (?:to )?read) (?:a |the )?(?:nutrition|food|facts )?labels?|nutrition facts labels?|nutrition labels? guide|food labels? guide|fda guide|fda nutrition|nutrition facts|food labels?|nutrition labels?|how to read label|reading label|read label|paano (?:basahin|magbasa|intindihin|tingnan) (?:ang |ng )?(?:nutrition |food )?labels?|paano (?:basahin|magbasa|intindihin) (?:ang |ng )?label|gabay sa (?:pagbasa |pagbabasa )?(?:ng )?labels?|ipaliwanag ang (?:nutrition )?labels?|ipaliwanag ang label|ano ang (?:nutrition )?labels?|ano ang label ng pagkain|label(?:s)? ng pagkain|pagbasa ng labels?)\b',
    ).hasMatch(normalized)) {
      return NutritionGuideType.fda;
    }

    // WHO / Daily nutrient guidelines & limits
    if (RegExp(
      r'\b(?:(?:who|w h o)\s*(?:guidelines?|guides?|recommendations?|limits?|thresholds?|nutrition|diet|daily limits?)|limits? (?:on|of|by|from) (?:the )?(?:who|w h o)|daily (?:nutrient|nutritional|nutrition|intake|dietary)?\s*(?:guidelines?|guides?|recommendations?|values?|requirements?|targets?|limits?)|recommended daily (?:intakes?|allowances?|nutrients?|values?|amounts?|limits?)|daily intakes?|daily nutrients?|daily nutrition|daily limits?|healthy diet (?:guidelines?|guide)|how much (?:sodium|sugar|fat|calories) (?:should|per day|daily)|daily (?:sodium|sugar|fat|calorie) limits?|limit(?:asyon)? (?:sa|ng) (?:who|w h o)|mga limitasyon (?:sa|ng) (?:who|w h o)|rekomendasyon ng (?:who|w h o)|gabay ng (?:who|w h o)|pang araw araw na (?:gabay|sustansya|nutrisyon|limitasyon)|araw araw na (?:gabay|sustansya|nutrisyon|limitasyon)|gabay sa sustansya|rekomendadong sustansya|tamang dami ng sustansya|sustansya bawat araw|limitasyon sa asukal at asin|magkano ang (?:sodium|asin|asukal) bawat araw)\b',
    ).hasMatch(normalized)) {
      return NutritionGuideType.who;
    }

    // Kidney disease nutrition
    if (RegExp(
      r'\b(?:kidneys?|renal|nephro|bato|sakit sa bato|gabay sa bato|gabay sa sakit sa bato|diyeta para sa bato|pagkain para sa (?:may )?sakit sa bato|pagkain sa sakit sa bato|nutrisyon para sa (?:may )?sakit sa bato)\b',
    ).hasMatch(normalized)) {
      return NutritionGuideType.kidney;
    }

    // GERD / Acid reflux diet
    if (RegExp(
      r'\b(?:gerd|acid reflux|heartburn|hyperacidity|sikmura|asim ng sikmura|gabay sa gerd|gabay sa acid reflux|pagkain para sa acid reflux|bawal sa (?:may )?acid reflux|bawal sa gerd)\b',
    ).hasMatch(normalized)) {
      return NutritionGuideType.gerd;
    }

    return null;
  }

  // ================================================================
  // NUTRITION GUIDE NAVIGATION + BRIEF EXPLANATION
  // ================================================================
  Future<void> _handleNutritionGuideNavigation(
    BuildContext context,
    NutritionGuideType type,
    String localeKey,
  ) async {
    final explanation = _nutritionGuideExplanation(type, localeKey);

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    await Future.delayed(const Duration(milliseconds: 150));
    if (!context.mounted) return;

    try {
      unawaited(
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NutritionGuideScreen(
              type: type,
              suppressPageAnnouncement: true,
            ),
          ),
        ),
      );

      // Delay 400ms for Navigator.push transition and _VoiceNavigatorObserver.didPush()
      // stopAudio() to finish, then speak the full brief explanation so the user hears it completely.
      await Future.delayed(const Duration(milliseconds: 400));
      await VoiceAssistantService.instance.speak(explanation);
    } catch (error, stackTrace) {
      debugPrint('Nutrition guide navigation failed: $error');
      debugPrint('$stackTrace');
      await VoiceAssistantService.instance.speak(
        localeKey == 'fil'
            ? 'Hindi ko mabuksan ang nutrition guide.'
            : 'I could not open the nutrition guide.',
      );
    }
  }

  String _nutritionGuideExplanation(
    NutritionGuideType type,
    String localeKey,
  ) {
    switch (type) {
      case NutritionGuideType.fda:
        return localeKey == 'fil'
            ? 'Binubuksan ang gabay sa nutrition facts label. '
              'Dito matututunan kung paano basahin ang serving size, calories, '
              'at porsyento ng daily value. Ipinapakita nito kung gaano karaming sustansya '
              'ang ibinibigay ng isang serving batay sa 2,000-calorie na diyeta. '
              'Ang 5 porsyento o mas mababa ay mababa, at 20 porsyento o higit pa ay mataas.'
            : 'Opening the nutrition facts label guide. '
              'Here you will learn how to read serving sizes, calories, '
              'and percent daily values. Percent daily value shows how much a nutrient '
              'in one serving contributes to a 2,000-calorie daily diet. '
              '5 percent or less is low, and 20 percent or more is high.';
      case NutritionGuideType.who:
        return localeKey == 'fil'
            ? 'Binubuksan ang pang-araw-araw na gabay sa sustansya. '
              'Inirerekomenda ng WHO ang hindi hihigit sa 5 gramo ng asin o 2,000 milligrams '
              'ng sodium, mas mababa sa 25 gramo ng asukal, at 20 hanggang 35 porsyento '
              'ng calories mula sa taba bawat araw para sa malusog na pagkain.'
            : 'Opening daily nutrient guidelines. '
              'The WHO recommends no more than 5 grams of salt, which is about 2,000 milligrams '
              'of sodium, less than 25 grams of added sugars, and 20 to 35 percent '
              'of daily calories from fat for a healthy diet.';
      case NutritionGuideType.kidney:
        return localeKey == 'fil'
            ? 'Binubuksan ang gabay sa nutrisyon para sa sakit sa bato. '
              'Limitahan ang sodium sa 2,300 milligrams bawat araw, bantayan ang potassium '
              'at phosphorus, at kumain ng tamang dami ng protina ayon sa payo '
              'ng doktor upang maprotektahan ang mga bato.'
            : 'Opening kidney disease nutrition guide. '
              'Limit daily sodium to 2,300 milligrams, monitor potassium '
              'and phosphorus levels, and eat the right amount of protein '
              'recommended by your doctor to help protect kidney function.';
      case NutritionGuideType.gerd:
        return localeKey == 'fil'
            ? 'Binubuksan ang gabay sa pagkain para sa GERD at acid reflux. '
              'Iwasan ang mamantikang pagkain, maaasim na prutas, kamatis, kape, '
              'at tsokolate upang mabawasan ang reflux. Kumain ng maliliit na '
              'beses-beses at huwag humiga agad pagkatapos kumain.'
            : 'Opening the GERD and acid reflux diet guide. '
              'Avoid trigger foods like high fats, citrus fruits, tomatoes, coffee, '
              'and chocolate. Eat smaller, frequent meals and avoid lying down right after eating.';
    }
  }

  // ================================================================
  // OFFLINE LOCAL SLOT-FILLER
  // Fast deterministic commands for essential queries that work
  // without internet or Gemini API latency.
  // ================================================================
  String? _matchOfflineSlot(String transcript) {
    final normalized = transcript.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9 ]'), ' ',
    ).trim();

    // "Read allergens" / "What are the allergens"
    if (RegExp(
      r'\b(read (?:the )?allergen|what (?:are|is) (?:the )?allergen|show (?:the )?allergen|list (?:the )?allergen|any allergen|allergen (?:list|info|warning)|allergens?|allergic|allergy|ipakita ang (?:mga )?allergen|ano ang (?:mga )?allergen|basahin ang (?:mga )?allergen|may allergen ba|may allergy ba|nakaka allergy|bawal ba sa may allergy|anong allergy meron)\b',
    ).hasMatch(normalized)) {
      return 'read_allergens';
    }

    // "Read ingredients" / "What are the ingredients"
    if (RegExp(
      r'\b(read (?:the )?ingredient|what (?:are|is) (?:the )?ingredient|show (?:the )?ingredient|list (?:the )?ingredient|ingredient (?:list|info)|ingredients?|what is in this|what are the ingredients|what is it made of|ipakita ang (?:mga )?(?:sangkap|ingredient)|ano ang (?:mga )?(?:sangkap|ingredient)|basahin ang (?:mga )?(?:sangkap|ingredient)|mga sangkap|sangkap|anong laman|anong meron dito)\b',
    ).hasMatch(normalized)) {
      return 'read_ingredients';
    }

    // "Read calories" / "How many calories"
    if (RegExp(
      r'\b(read (?:the )?calorie|how many calorie|what (?:are|is) (?:the )?calorie|calorie (?:count|total|level)|total calorie|calories?|cals?|energy (?:count|level)|ilang calorie|ilan ang calorie|basahin ang calorie|dami ng calorie|mataas ba sa calorie|calorie nito)\b',
    ).hasMatch(normalized)) {
      return 'read_calories';
    }

    // "Read sodium" / "How much sodium"
    if (RegExp(
      r'\b(read (?:the )?sodium|how much sodium|what (?:is|are) (?:the )?sodium|sodium (?:content|level|amount)|sodium|how salty|is (?:it|this) salty|salt (?:content|level|amount)|how much salt|salt|magkano(?:ng)? sodium|asin|maalat ba|gaano kaalat|dami ng asin|sobrang alat|mataas ba sa asin)\b',
    ).hasMatch(normalized)) {
      return 'read_sodium';
    }

    // "Read sugar" / "How much sugar"
    if (RegExp(
      r'\b(read (?:the )?sugar|how much sugar|what (?:is|are) (?:the )?sugar|sugar (?:content|level|amount)|total sugar|added sugar|sugar|how sweet|is (?:it|this) sweet|sweetness|magkano(?:ng)? asukal|asukal|matamis ba|gaano katamis|dami ng asukal|mataas ba sa asukal|sobrang tamis)\b',
    ).hasMatch(normalized)) {
      return 'read_sugar';
    }

    // "Read fat" / "How much fat"
    if (RegExp(
      r'\b(read (?:the )?(?:total )?fat|how much (?:total )?fat|what (?:is|are) (?:the )?(?:total )?fat|fat (?:content|level|amount)|total fat|saturated fat|trans fat|fat|how oily|is (?:it|this) fatty|taba|mataba ba|mamantika ba|dami ng taba|magkano(?:ng)? taba|oily ba)\b',
    ).hasMatch(normalized)) {
      return 'read_fat';
    }

    // "Serving size"
    if (RegExp(
      r'\b(serving size|serving amount|one serving|portion size|how big is a serving|sukat ng serving|serving nito|gaano kalaki ang isang serving)\b',
    ).hasMatch(normalized)) {
      return 'read_serving_size';
    }

    // "Is this healthy" / "Is this safe"
    if (RegExp(
      r'\b(is (?:this|it) (?:healthy|safe|good|okay|ok|bad|dangerous)|can i (?:eat|have) this|healthy ba (?:ito|yan|to)|safe ba (?:ito|yan|to)|mabuti ba (?:ito|yan|to)|pwede ba (?:ito|yan|to|sa akin)|puwede ba (?:ito|yan|to|sa akin)|okay ba (?:ito|yan|to)|masama ba (?:ito|yan|to)|delikado ba (?:ito|yan|to))\b',
    ).hasMatch(normalized)) {
      return 'is_healthy';
    }

    // "What is the verdict" / "What is the score"
    if (RegExp(
      r'\b(what (?:is|are) (?:the )?(?:verdict|score|rating|health (?:score|rating|verdict))|ano ang (?:hatol|score|rating)|hatol|verdict|score|rating|health score|hatol nito|score nito)\b',
    ).hasMatch(normalized)) {
      return 'read_verdict';
    }

    return null;
  }

  Future<void> _handleOfflineSlot(
    BuildContext context,
    String slot,
    String localeKey,
  ) async {
    final product = VoiceAssistantService.activeResultProductNotifier.value
        ?? VoiceAssistantService.latestScanProductNotifier.value;

    if (product == null) {
      await VoiceAssistantService.instance.speak(
        localeKey == 'fil'
            ? 'Walang aktibong produkto. Mag-scan muna ng produkto.'
            : 'No active product. Please scan a product first.',
      );
      return;
    }

    switch (slot) {
      case 'read_allergens':
        final allergens = product.allergens;
        if (allergens.isEmpty) {
          await VoiceAssistantService.instance.speak(
            localeKey == 'fil'
                ? 'Walang nakalistang allergen para sa ${product.name}.'
                : 'No allergens are listed for ${product.name}.',
          );
        } else {
          final list = allergens.join(', ');
          await VoiceAssistantService.instance.speak(
            localeKey == 'fil'
                ? 'Ang mga allergen ng ${product.name} ay: $list.'
                : 'The allergens in ${product.name} are: $list.',
          );
        }
        break;

      case 'read_ingredients':
        final ingredients = product.ingredients;
        if (ingredients.isEmpty) {
          await VoiceAssistantService.instance.speak(
            localeKey == 'fil'
                ? 'Walang nakalistang sangkap para sa ${product.name}.'
                : 'No ingredients are listed for ${product.name}.',
          );
        } else {
          final list = ingredients.join(', ');
          await VoiceAssistantService.instance.speak(
            localeKey == 'fil'
                ? 'Ang mga sangkap ng ${product.name} ay: $list.'
                : 'The ingredients in ${product.name} are: $list.',
          );
        }
        break;

      case 'read_calories':
        final cal = product.nutritionalFacts.caloriesKcal;
        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Ang ${product.name} ay may ${cal.toStringAsFixed(0)} calories bawat serving.'
              : '${product.name} has ${cal.toStringAsFixed(0)} calories per serving.',
        );
        break;

      case 'read_sodium':
        final sodiumMg = product.nutritionalFacts.sodiumMg;
        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Ang sodium ng ${product.name} ay ${sodiumMg.toStringAsFixed(0)} milligrams bawat serving.'
              : '${product.name} has ${sodiumMg.toStringAsFixed(0)} milligrams of sodium per serving.',
        );
        break;

      case 'read_sugar':
        final sugarG = product.nutritionalFacts.sugarsG;
        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Ang asukal ng ${product.name} ay ${sugarG.toStringAsFixed(1)} grams bawat serving.'
              : '${product.name} has ${sugarG.toStringAsFixed(1)} grams of sugar per serving.',
        );
        break;

      case 'read_fat':
        final fatG = product.nutritionalFacts.totalFatG;
        final saturatedG = product.nutritionalFacts.saturatedFatG;
        final transG = product.nutritionalFacts.transFatG;
        final parts = <String>[];
        if (fatG > 0) parts.add('${fatG.toStringAsFixed(1)} grams total fat');
        if (saturatedG > 0) parts.add('${saturatedG.toStringAsFixed(1)} grams saturated fat');
        if (transG > 0) parts.add('${transG.toStringAsFixed(1)} grams trans fat');
        if (parts.isEmpty) {
          await VoiceAssistantService.instance.speak(
            localeKey == 'fil'
                ? 'Hindi tukoy ang fat content ng ${product.name}.'
                : 'Fat content is not specified for ${product.name}.',
          );
        } else {
          await VoiceAssistantService.instance.speak(
            localeKey == 'fil'
                ? 'Ang fat ng ${product.name} ay: ${parts.join(', ')}.'
                : '${product.name} has ${parts.join(', ')}.',
          );
        }
      case 'read_serving_size':
        final serving = product.nutritionalFacts.servingSize;
        if (serving.trim().isEmpty) {
          await VoiceAssistantService.instance.speak(
            localeKey == 'fil'
                ? 'Hindi nakalista ang serving size ng ${product.name}.'
                : 'Serving size is not specified for ${product.name}.',
          );
        } else {
          await VoiceAssistantService.instance.speak(
            localeKey == 'fil'
                ? 'Ang serving size ng ${product.name} ay $serving.'
                : 'The serving size for ${product.name} is $serving.',
          );
        }
        break;

      case 'is_healthy':
      case 'read_verdict':
        final summary = VoiceAssistantService.latestScanSummaryNotifier.value;
        if (summary != null && summary.trim().isNotEmpty) {
          await VoiceAssistantService.instance.speak(summary);
        } else {
          await VoiceAssistantService.instance.speak(
            localeKey == 'fil'
                ? 'Sandali lang, sinusuri pa ang produktong ito.'
                : 'Still analyzing this product, one moment.',
          );
        }
        break;
    }
  }

  bool _isSummaryRequest(
    String transcript,
  ) {
    final normalized =
        transcript
            .toLowerCase()
            .replaceAll(
              RegExp(r'[^a-z0-9 ]'),
              ' ',
            )
            .trim();

    if (RegExp(
      r'\b(summarize|summarise|summary|summaries|ibuod|buod|recap|overview)\b',
    ).hasMatch(normalized)) {
      return true;
    }

    if (RegExp(
      r'\b(display results|show results|read results|tell results|what are the results|comparison results|compare results|display comparison|scan results|scan result|product results|nutrition results|resulta|mga resulta|advisory|health advisory|health advisories|summarize advisory|summary advisory|payo sa kalusugan|payo|anong payo|buod ng resulta)\b',
    ).hasMatch(normalized)) {
      return true;
    }

    if (RegExp(
      r'^(?:the\s+)?(?:results|result|summary|resulta|advisory|health advisory|payo|buod)$',
    ).hasMatch(normalized)) {
      return true;
    }

    return RegExp(
      r'\b(summarize|summarise|summary|explain|describe|display|show|read|tell|what are the|anong|sabihin|ipakita|ipaliwanag|buod)\b.*\b(result|results|scan|report|product|nutrition|comparison|ranking|score|scores|resulta|advisory|health advisory|payo|rekomendasyon|kalusugan)\b',
    ).hasMatch(normalized);
  }

  String? _canonicalTarget(String? target) {
    if (target == null) return null;

    final normalized = target.toLowerCase().replaceAll(RegExp(r'[^a-z_]'), '_');

    const aliases = {
      'dashboard': 'home',
      'main': 'home',
      'scanner': 'scan',
      'camera': 'scan',
      'records': 'history',
      'my_history': 'history',
      'account': 'profile',
      'my_profile': 'profile',
      'profile_page': 'profile',
      'settings': 'profile',
      'account_settings': 'profile',
      'personal_information': 'personal_info',
      'personal_info_page': 'personal_info',
      'my_information': 'personal_info',
      'dark_mode': 'dark_mode',
      'darkmode': 'dark_mode',
      'light_mode': 'light_mode',
      'lightmode': 'light_mode',
      'themes': 'theme',
      'theme_screen': 'theme',
      'theme_settings': 'theme',
      'preferences': 'preference',
      'health_preferences': 'preference',
      'health_preference': 'preference',
      'suggestions': 'suggestion',
      'feedbacks': 'suggestion',
      'reset_password': 'change_password',
      'two_factor_authentication': 'mfa',
      'multi_factor_authentication': 'mfa',
      'two_factor': 'mfa',
      'mfa_settings': 'mfa',
      'enable_mfa': 'mfa_on',
      'turn_on_mfa': 'mfa_on',
      'mfa_on': 'mfa_on',
      'disable_mfa': 'mfa_off',
      'turn_off_mfa': 'mfa_off',
      'mfa_off': 'mfa_off',
      'enable_voice': 'voice_assistant_on',
      'turn_on_voice': 'voice_assistant_on',
      'voice_assistant_on': 'voice_assistant_on',
      'disable_voice': 'voice_assistant_off',
      'turn_off_voice': 'voice_assistant_off',
      'voice_assistant_off': 'voice_assistant_off',
      'tagalog': 'language_tagalog',
      'filipino': 'language_tagalog',
      'language_tagalog': 'language_tagalog',
      'english': 'language_english',
      'ingles': 'language_english',
      'language_english': 'language_english',
      'change_language': 'language',
      'switch_language': 'language',
      'language_settings': 'language',
      'favorite_product': 'favorite_product',
      'add_favorite': 'favorite_product',
      'save_product': 'favorite_product',
      'unfavorite_product': 'unfavorite_product',
      'remove_favorite': 'unfavorite_product',
      'app_reviews': 'review_history',
      'app_review': 'review_history',
      'terms_and_conditions': 'terms_conditions',
      'terms_of_service': 'terms_conditions',
      'user_guides': 'user_guide',
      'compare': 'compare_products',
      'comparison': 'compare_products',
      'compare_product': 'compare_products',
      'product_comparison': 'compare_products',
      'clear_history': 'clear_history',
      'clear_all_history': 'clear_history',
      'delete_history': 'clear_history',
      'delete_all_history': 'clear_history',
      'clear_favorites': 'clear_favorites',
      'delete_favorites': 'clear_favorites',
      'delete_account': 'delete_account',
      'delete_my_account': 'delete_account',
      'close_account': 'delete_account',
      'remove_account': 'delete_account',
      'invite_people': 'invite_people',
      'invite': 'invite_people',
      'invite_member': 'invite_people',
      'invite_family': 'invite_people',
      'health_groups': 'invite_people',
      'health_group': 'invite_people',
      'group': 'group',
      'groups': 'group',
      'nutrition_guide_fda': 'nutrition_guide_fda',
      'nutrition_label': 'nutrition_guide_fda',
      'read_nutrition_label': 'nutrition_guide_fda',
      'nutrition_guide_who': 'nutrition_guide_who',
      'daily_nutrient_guidelines': 'nutrition_guide_who',
      'daily_nutrients': 'nutrition_guide_who',
      'nutrition_guide_kidney': 'nutrition_guide_kidney',
      'kidney_diet': 'nutrition_guide_kidney',
      'kidney_nutrition': 'nutrition_guide_kidney',
      'nutrition_guide_gerd': 'nutrition_guide_gerd',
      'gerd_diet': 'nutrition_guide_gerd',
      'acid_reflux_diet': 'nutrition_guide_gerd',
    };

    return aliases[normalized] ?? normalized;
  }

  String _navigationReply(
    String target,
    String localeKey,
  ) {
    if (target == 'about_claro') {
      return localeKey == 'fil'
          ? 'Binubuksan ang Tungkol sa CLARO. Ididirekta ka sa impormasyon tungkol sa CLARO at sa aming misyon.'
          : 'Opening About CLARO. You will be directed to learn more about CLARO and our mission.';
    }

    if (target == 'user_guide') {
      return localeKey == 'fil'
          ? 'Binubuksan ang Gabay sa Paggamit. Ididirekta ka sa gabay kung paano gamitin ang CLARO.'
          : 'Opening the User Guide. You will be directed to the guide on how to use CLARO.';
    }

    if (target == 'privacy_policy') {
      return localeKey == 'fil'
          ? 'Binubuksan ang Patakaran sa Privacy. Ididirekta ka sa aming patakaran sa proteksyon ng datos at privacy.'
          : 'Opening the Privacy Policy. You will be directed to our privacy and data protection policy.';
    }

    if (target == 'terms_conditions') {
      return localeKey == 'fil'
          ? 'Binubuksan ang mga Tuntunin at Kundisyon. Ididirekta ka sa aming mga tuntunin ng serbisyo at kundisyon.'
          : 'Opening Terms and Conditions. You will be directed to our terms of service and conditions.';
    }

    final pageName = switch (target) {
      'personal_info' =>
        localeKey == 'fil' ? 'personal na impormasyon' : 'personal information',

      'home' => localeKey == 'fil' ? 'pangunahing screen' : 'home page',

      'scan' => localeKey == 'fil' ? 'scanner ng produkto' : 'scanner',

      'history' =>
        localeKey == 'fil' ? 'kasaysayan ng pag-scan' : 'scan history',

      'clear_history' =>
        localeKey == 'fil' ? 'kasaysayan ng pag-scan' : 'scan history',

      'clear_favorites' => localeKey == 'fil' ? 'mga paborito' : 'favorites',

      'delete_account' =>
        localeKey == 'fil'
            ? 'profile at mga setting ng account'
            : 'profile and account settings',

      'profile' =>
        localeKey == 'fil'
            ? 'profile at mga setting ng account'
            : 'profile and account settings',

      'theme' => localeKey == 'fil' ? 'mga setting ng tema' : 'theme settings',

      'preference' =>
        localeKey == 'fil'
            ? 'mga kagustuhan sa kalusugan at pagkain'
            : 'health preferences',

      'suggestion' =>
        localeKey == 'fil'
            ? 'screen ng mungkahi at feedback'
            : 'suggestions and feedback',

      'change_password' =>
        localeKey == 'fil'
            ? 'mga setting ng password at seguridad'
            : 'password and security settings',

      'review_history' =>
        localeKey == 'fil' ? 'kasaysayan ng mga review' : 'app reviews',

      'about_claro' =>
        localeKey == 'fil' ? 'impormasyon tungkol sa CLARO' : 'About CLARO',

      'privacy_policy' =>
        localeKey == 'fil' ? 'Patakaran sa Privacy' : 'Privacy Policy',

      'terms_conditions' =>
        localeKey == 'fil'
            ? 'mga Tuntunin at Kundisyon'
            : 'Terms and Conditions',

      'user_guide' => localeKey == 'fil' ? 'Gabay sa Paggamit' : 'User Guide',

      'compare_products' =>
        localeKey == 'fil' ? 'paghahambing ng produkto' : 'product comparison',

      'invite_people' =>
        localeKey == 'fil'
            ? 'mga health group at imbitasyon'
            : 'health groups and invitations',

      'group' =>
        localeKey == 'fil'
            ? 'mga health group'
            : 'health groups',

      'nutrition_guide_fda' =>
        localeKey == 'fil'
            ? 'gabay sa nutrition facts label'
            : 'nutrition facts label guide',

      'nutrition_guide_who' =>
        localeKey == 'fil'
            ? 'pang-araw-araw na gabay sa sustansya'
            : 'daily nutrient guidelines',

      'nutrition_guide_kidney' =>
        localeKey == 'fil'
            ? 'gabay sa nutrisyon para sa kidney'
            : 'kidney disease nutrition guide',

      'nutrition_guide_gerd' =>
        localeKey == 'fil'
            ? 'gabay sa pagkain para sa GERD'
            : 'GERD diet guide',

      _ => target.replaceAll('_', ' '),
    };

    if (localeKey == 'fil') {
      return 'Binubuksan ang $pageName.';
    }

    return 'Opening your $pageName.';
  }

  String? _extractProductSearchQuery(String transcript) {
    final t = transcript.trim().toLowerCase();

    const excludedPages = {
      'home',
      'main',
      'dashboard',
      'simula',
      'home page',
      'home screen',
      'scan',
      'scanner',
      'camera',
      'mag-scan',
      'magscan',
      'camera screen',
      'scan screen',
      'history',
      'records',
      'previous scans',
      'all scans',
      'kasaysayan',
      'scan history',
      'favorites',
      'favorite',
      'my favorites',
      'paborito',
      'saved products',
      'saved',
      'reports',
      'my reports',
      'submitted reports',
      'mga ulat',
      'ulat',
      'profile',
      'account',
      'my profile',
      'my account',
      'profile page',
      'profile screen',
      'settings',
      'setting',
      'personal info',
      'personal information',
      'my info',
      'my information',
      'user info',
      'personal details',
      'preference',
      'preferences',
      'health preferences',
      'health preference',
      'dietary preferences',
      'theme',
      'themes',
      'dark mode',
      'darkmode',
      'light mode',
      'appearance',
      'suggestion',
      'suggestions',
      'feedback',
      'feedbacks',
      'comments',
      'change password',
      'reset password',
      'update password',
      'about claro',
      'about app',
      'about us',
      'about the app',
      'user guide',
      'app guide',
      'manual',
      'how to use',
      'how to use claro',
      'gabay sa paggamit',
      'gabay ng gumagamit',
      'paano gamitin',
      'privacy policy',
      'privacy',
      'data privacy',
      'patakaran sa privacy',
      'terms and conditions',
      'terms of service',
      'terms',
      'mga tuntunin at kundisyon',
      'mga tuntunin',
      'compare',
      'compare products',
      'comparison',
      'product comparison',
      'review history',
      'advisory',
      'health advisory',
      'results',
      'result',
      'log out',
      'logout',
      'sign out',
      'signout',
      'nutrition guide',
      'nutrition guides',
      'nutrition facts',
      'nutrition facts label',
      'nutrition label',
      'food label',
      'food labels',
      'fda guide',
      'fda nutrition',
      'daily guidelines',
      'daily nutrient guidelines',
      'daily nutrients',
      'who guidelines',
      'who guide',
      'who limits',
      'who nutrition',
      'who diet',
      'limits on who',
      'kidney guide',
      'kidney disease',
      'kidney diet',
      'gerd guide',
      'gerd diet',
      'gerd',
      'acid reflux',
      'acid reflux guide',
      'acid reflux diet',
      'heartburn',
      'gabay sa nutrisyon',
      'gabay sa pagbasa ng label',
      'pang araw araw na gabay',
      'gabay sa bato',
      'sakit sa bato',
      'gabay sa gerd',
      'gabay sa acid reflux',
    };

    if (excludedPages.contains(t)) {
      return null;
    }

    final patterns = [
      RegExp(
        r'^(?:please\s+)?(?:find|search(?:\s+for)?|look\s+for|show|open|go\s+to|view|check)\s+(?:me\s+)?(.+?)(?:\s+(?:in|from)\s+(?:my\s+)?history|\s+from\s+last\s+week|\s+from\s+yesterday|\s+product|\s+details)?$',
        caseSensitive: false,
      ),
      RegExp(
        r'^(?:paki-?)?(?:maghanap(?:\s+ng|\s+sa)?|hanapin|hanap|pahanap|buksan|tingnan|ipakita|pumunta\s+sa|punta\s+sa)\s+(?:po\s+)?(?:ang|yung|ng)?\s*(.+?)(?:\s+sa\s+(?:aking\s+)?history|\s+sa\s+mga\s+na-?scan)?$',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(t);

      if (match != null && match.groupCount >= 1) {
        String query = match.group(1)?.trim() ?? '';

        query = query.replaceAll(
          RegExp(
            r'\s+(?:in|from)\s+(?:my\s+)?history.*$',
            caseSensitive: false,
          ),
          '',
        );

        query = query.replaceAll(
          RegExp(r'\s+sa\s+(?:aking\s+)?history.*$', caseSensitive: false),
          '',
        );

        query = query.replaceAll(
          RegExp(
            r'\s+(?:from\s+)?(?:last\s+week|yesterday|earlier|kanina).*$',
            caseSensitive: false,
          ),
          '',
        );

        query = query
            .replaceAll(
              RegExp(
                r'\s+(?:product|details|screen|scan|page)$',
                caseSensitive: false,
              ),
              '',
            )
            .trim();

        if (query.isNotEmpty &&
            _targetFromTranscript(query) == null &&
            !excludedPages.contains(query)) {
          return query;
        }
      }
    }

    const brandKeywords = [
      'century',
      '555',
      'blue bay',
      'san marino',
      'purefoods',
      'argentina',
      'lucky 7',
      'cdo',
      'mega',
      'ligo',
      'ram',
      'ufc',
      'del monte',
      'jolly',
      'saba',
      'unipack',
      'golden town',
      'star carne',
      'carne norte',
      'corned beef',
      'tuna',
      'sardine',
      'sardines',
      'lucky me',
      'pancit canton',
    ];

    for (final brand in brandKeywords) {
      if (t.contains(brand)) {
        return t;
      }
    }

    return null;
  }

  Future<bool> _handleProductSearch(
    BuildContext context,
    String query,
    VoiceLang language,
  ) async {
    final isTagalog = language == VoiceLang.tagalog;

    final normalizedQuery = query.toLowerCase().trim();

    Product? matchedProduct;

    try {
      final localHistory = ScanHistoryService().localHistory;

      if (localHistory.isNotEmpty) {
        for (final p in localHistory) {
          final pName = p.name.toLowerCase();

          final pBrand = p.brand.toLowerCase();

          if (pName.contains(normalizedQuery) ||
              '$pBrand $pName'.contains(normalizedQuery)) {
            matchedProduct = p;
            break;
          }
        }
      }

      if (matchedProduct == null) {
        final historyService = HistoryService();

        final historyItems = historyService.getItems(
          filter: 'Lahat',
          searchQuery: query,
        );

        if (historyItems.isNotEmpty) {
          for (final item in historyItems) {
            final pId = item.productId;

            if (pId != null && pId.isNotEmpty) {
              try {
                matchedProduct = await BackendLocator.productRepository
                    .getProductById(pId);

                break;
              } catch (error) {
                debugPrint(
                  'Voice search: failed to fetch scanned product by id: $error',
                );
              }
            }
          }
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Voice product search failed: $error');
      debugPrint('$stackTrace');

      await VoiceAssistantService.instance.speak(
        isTagalog
            ? 'Narinig ko ang pangalan ng produkto, pero nagkaroon ng problema habang hinahanap ito sa iyong scan history.'
            : 'I heard the product name, but there was a problem searching for it in your scan history.',
      );

      return true;
    }

    if (!context.mounted) return true;

    if (matchedProduct != null) {
      final targetProduct = matchedProduct;

      VoiceAssistantService.setLatestScanProduct(targetProduct);

      final reply = isTagalog
          ? 'Nahanap ang ${targetProduct.name} mula sa iyong mga na-scan na produkto. Binubuksan ang mga detalye.'
          : 'Found ${targetProduct.name} from your scan records. Opening product details.';

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

      unawaited(VoiceAssistantService.instance.speak(reply));

      try {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: targetProduct),
          ),
        );
      } catch (error, stackTrace) {
        debugPrint('Product details navigation failed: $error');
        debugPrint('$stackTrace');

        await VoiceAssistantService.instance.speak(
          isTagalog
              ? 'Nahanap ko ang produkto, pero hindi ko mabuksan ang mga detalye nito.'
              : 'I found the product, but I could not open its details.',
        );
      }

      return true;
    }

    final notFoundReply = isTagalog
        ? 'Narinig ko ang hinahanap mong produkto, pero wala akong nakitang produktong tulad niyan sa iyong mga na-scan. Pakisubukang i-scan muna ang produkto.'
        : 'I heard the product you are looking for, but I could not find a matching product in your scan records. Please scan the product first.';

    await VoiceAssistantService.instance.speak(notFoundReply);

    return true;
  }
}
