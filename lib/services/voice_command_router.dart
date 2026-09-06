import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

const String claroWebsiteUrl = 'https://claro-52ia.onrender.com/';
const String privacyPolicyUrl =
    'https://claro-52ia.onrender.com/privacy-policy';
const String termsConditionsUrl =
    'https://claro-52ia.onrender.com/terms-and-conditions';
const String userGuideUrl = 'https://claro-52ia.onrender.com/user-guide';

class VoiceCommandRouter {
  VoiceCommandRouter._();

  static final VoiceCommandRouter _instance = VoiceCommandRouter._();

  static VoiceCommandRouter get instance => _instance;

  static const Map<String, int> _tabPageKeys = {
    'home': 0,
    'scan': 1,
    'history': 2,
    'profile': 3,
  };

  Future<void> handleMicTap(BuildContext context) async {
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
      }
      return;
    }

    await VoiceAssistantService.instance.stopAudio();

    final transcript =
        await VoiceAssistantService.instance.listenOnce();

    if (!context.mounted) return;

    final language =
        VoiceAssistantService.languageNotifier.value;

    final localeKey =
        language == VoiceLang.tagalog ? 'fil' : 'en';

    // ============================================================
    // 1. NO SPEECH DETECTED
    // ============================================================
    if (transcript == null || transcript.trim().isEmpty) {
      debugPrint(
        'Voice command: speech recognition returned no transcript.',
      );

      await VoiceAssistantService.instance.speak(
        localeKey == 'fil'
            ? 'Wala akong narinig na sinabi. Pakisubukan muli at magsalita pagkatapos i-tap ang mikropono.'
            : "I didn't hear anything. Please tap the microphone and speak your command again.",
      );

      return;
    }

    debugPrint(
      'Voice command transcript: "$transcript"',
    );

    // ============================================================
    // 2. SUMMARY REQUEST
    // ============================================================
    if (_isSummaryRequest(transcript)) {
      debugPrint(
        'Voice command intent: type=VoiceIntentType.summarizeScan '
        '(local match)',
      );

      try {
        await _handleSummarizeIntent(language);
      } catch (error, stackTrace) {
        debugPrint(
          'Voice summary failed: $error',
        );
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
    final productSearchQuery =
        _extractProductSearchQuery(transcript);

    if (productSearchQuery != null &&
        productSearchQuery.isNotEmpty) {
      debugPrint(
        'Voice command intent: product search for '
        '"$productSearchQuery"',
      );

      final handled =
          await _handleProductSearch(
        context,
        productSearchQuery,
        language,
      );

      if (handled) return;
    }

    // ============================================================
    // 4. FAST LOCAL NAVIGATION
    // ============================================================
    final localTarget =
        _targetFromTranscript(transcript);

    if (localTarget != null) {
      debugPrint(
        'Voice command intent: fast local navigation -> $localTarget',
      );

      final resolvedIntent = VoiceIntent(
        type: VoiceIntentType.navigate,
        targetPage: localTarget,
        spokenReply:
            _navigationReply(localTarget, localeKey),
      );

      await _handleNavigationIntent(
        context,
        resolvedIntent,
        localeKey,
      );

      return;
    }

    // ============================================================
    // 5. GEMINI INTENT CLASSIFICATION
    // ============================================================
    final intent =
        await GeminiService.instance.classifyIntent(
      transcript: transcript,
      language: language,
    );

    if (!context.mounted) return;

    final target =
        _targetFromTranscript(transcript) ??
        intent.targetPage;

    final resolvedIntent =
        target != null &&
                intent.type != VoiceIntentType.summarizeScan &&
                intent.type != VoiceIntentType.processingError
            ? VoiceIntent(
                type: VoiceIntentType.navigate,
                targetPage: target,
                spokenReply:
                    _navigationReply(
                  target,
                  localeKey,
                ),
              )
            : intent;

    debugPrint(
      'Voice command intent: '
      'type=${resolvedIntent.type} '
      'target=${resolvedIntent.targetPage}',
    );

    // ============================================================
    // 6. HANDLE INTENT
    // ============================================================
    switch (resolvedIntent.type) {
      case VoiceIntentType.navigate:
        await _handleNavigationIntent(
          context,
          resolvedIntent,
          localeKey,
        );
        break;

      case VoiceIntentType.summarizeScan:
        try {
          await _handleSummarizeIntent(language);
        } catch (error, stackTrace) {
          debugPrint(
            'Voice summary failed: $error',
          );
          debugPrint('$stackTrace');

          await VoiceAssistantService.instance.speak(
            localeKey == 'fil'
                ? 'Narinig ko ang iyong kahilingan, pero nagkaroon ng problema habang kinukuha ang resulta. Pakisubukan muli.'
                : 'I heard your request, but there was a problem retrieving the results. Please try again.',
          );
        }
        break;

      case VoiceIntentType.outOfScope:
        await VoiceAssistantService.instance.speak(
          resolvedIntent.spokenReply.isNotEmpty
              ? resolvedIntent.spokenReply
              : localeKey == 'fil'
                  ? 'Narinig ko ang iyong sinabi, pero ang kahilingang iyon ay wala sa mga function ng CLARO.'
                  : 'I heard your request, but that action is outside the functions supported by CLARO.',
        );
        break;

      case VoiceIntentType.unclear:
        await VoiceAssistantService.instance.speak(
          resolvedIntent.spokenReply.isNotEmpty
              ? resolvedIntent.spokenReply
              : localeKey == 'fil'
                  ? 'Narinig ko ang sinabi mo, pero hindi ko matukoy kung anong aksyon ang gusto mong gawin. Pakisubukan gamit ang mas simpleng utos.'
                  : 'I heard what you said, but I could not determine what action you want me to perform. Please try a simpler command.',
        );
        break;

      case VoiceIntentType.processingError:
        await VoiceAssistantService.instance.speak(
          resolvedIntent.spokenReply.isNotEmpty
              ? resolvedIntent.spokenReply
              : localeKey == 'fil'
                  ? 'Narinig ko ang iyong utos, pero nagkaroon ng problema sa pagproseso nito. Pakisubukan muli.'
                  : 'I heard your command, but there was a problem processing it. Please try again.',
        );
        break;
    }
  }

  Future<void> _handleNavigationIntent(
    BuildContext context,
    VoiceIntent intent,
    String localeKey,
  ) async {
    final target =
        _canonicalTarget(intent.targetPage);

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
          VoiceAssistantService
              .latestScanProductNotifier
              .value;

      final user =
          FirebaseAuth.instance.currentUser;

      if (currentProduct != null && user != null) {
        try {
          await BackendLocator.favoritesService
              .addFavorite(
            userId: user.uid,
            productId: currentProduct.id,
          );

          final msg = localeKey == 'fil'
              ? 'Naidagdag ang ${currentProduct.name} sa iyong mga paborito.'
              : 'Added ${currentProduct.name} to your favorites.';

          await VoiceAssistantService.instance
              .speak(msg);
        } catch (error, stackTrace) {
          debugPrint(
            'Favorite product failed: $error',
          );
          debugPrint('$stackTrace');

          await VoiceAssistantService.instance
              .speak(
            localeKey == 'fil'
                ? 'Narinig ko ang iyong utos, pero hindi ko ma-save ang produkto sa iyong mga paborito dahil nagkaroon ng problema sa pag-save.'
                : 'I heard your command, but I could not add the product to your favorites because the save operation failed.',
          );
        }
      } else {
        await VoiceAssistantService.instance
            .speak(
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
          VoiceAssistantService
              .latestScanProductNotifier
              .value;

      final user =
          FirebaseAuth.instance.currentUser;

      if (currentProduct != null && user != null) {
        try {
          await BackendLocator.favoritesService
              .removeFavorite(
            userId: user.uid,
            productId: currentProduct.id,
          );

          final msg = localeKey == 'fil'
              ? 'Inalis ang ${currentProduct.name} sa iyong mga paborito.'
              : 'Removed ${currentProduct.name} from your favorites.';

          await VoiceAssistantService.instance
              .speak(msg);
        } catch (error, stackTrace) {
          debugPrint(
            'Unfavorite product failed: $error',
          );
          debugPrint('$stackTrace');

          await VoiceAssistantService.instance
              .speak(
            localeKey == 'fil'
                ? 'Narinig ko ang iyong utos, pero hindi ko maalis ang produkto sa iyong mga paborito dahil nagkaroon ng problema sa pag-save.'
                : 'I heard your command, but I could not remove the product from your favorites because the save operation failed.',
          );
        }
      } else {
        await VoiceAssistantService.instance
            .speak(
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
                const UnknownProductSubmissionScreen(
              capturedImagePath: null,
            ),
          ),
        );

        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Binubuksan ang screen para sa pag-uulat ng produkto.'
              : 'Opening the product report screen.',
        );
      } catch (error, stackTrace) {
        debugPrint(
          'Report screen failed: $error',
        );
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
        await setAppThemeMode(
          ThemeMode.dark,
        );

        try {
          await AuthService().updateUserData({
            'theme': 'Dark Mode',
          });
        } catch (error) {
          debugPrint(
            'Theme preference save failed: $error',
          );
        }

        await VoiceAssistantService.instance
            .speak(
          localeKey == 'fil'
              ? 'Naka-on na ang dark mode.'
              : 'Dark mode turned on.',
        );
      } catch (error, stackTrace) {
        debugPrint(
          'Dark mode failed: $error',
        );
        debugPrint('$stackTrace');

        await VoiceAssistantService.instance
            .speak(
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
        await setAppThemeMode(
          ThemeMode.light,
        );

        try {
          await AuthService().updateUserData({
            'theme': 'Default',
          });
        } catch (error) {
          debugPrint(
            'Theme preference save failed: $error',
          );
        }

        await VoiceAssistantService.instance
            .speak(
          localeKey == 'fil'
              ? 'Naka-on na ang light mode.'
              : 'Light mode turned on.',
        );
      } catch (error, stackTrace) {
        debugPrint(
          'Light mode failed: $error',
        );
        debugPrint('$stackTrace');

        await VoiceAssistantService.instance
            .speak(
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

      await VoiceAssistantService.instance
          .updateEnabled(false);

      try {
        await AuthService().updateUserData({
          'voiceAssistant': false,
        });
      } catch (error) {
        debugPrint('Voice assistant preference save failed: $error');
      }

      return;
    }

    // ============================================================
    // VOICE ASSISTANT ON
    // ============================================================
    if (target == 'voice_assistant_on') {
      await VoiceAssistantService.instance
          .updateEnabled(true);

      try {
        await AuthService().updateUserData({
          'voiceAssistant': true,
        });
      } catch (error) {
        debugPrint('Voice assistant preference save failed: $error');
      }

      await VoiceAssistantService.instance.speak(
        localeKey == 'fil'
            ? 'Naka-on na ang voice assistant.'
            : 'Voice assistant enabled.',
      );

      return;
    }

    // ============================================================
    // MFA ON
    // ============================================================
    if (target == 'mfa_on') {
      try {
        HomeTabController.switchToTab(3);
        await AuthService().setMfaEnabled(
          enabled: true,
        );

        unawaited(() async {
          await Future.delayed(const Duration(milliseconds: 350));
          await VoiceAssistantService.instance.speak(
            localeKey == 'fil'
                ? 'Naka-on na ang multi-factor authentication para sa iyong account.'
                : 'Multi-factor authentication has been turned on for your account.',
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
        HomeTabController.switchToTab(3);
        await AuthService().setMfaEnabled(
          enabled: false,
        );

        unawaited(() async {
          await Future.delayed(const Duration(milliseconds: 350));
          await VoiceAssistantService.instance.speak(
            localeKey == 'fil'
                ? 'Naka-off na ang multi-factor authentication.'
                : 'Multi-factor authentication has been turned off.',
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
        HomeTabController.switchToTab(3);
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
          await VoiceAssistantService.instance.speak(msg);
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
        debugPrint(
          'Logout failed: $error',
        );
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
        await VoiceAssistantService.instance
            .updateLanguage(
          VoiceLang.tagalog,
        );

        unawaited(() async {
          await Future.delayed(const Duration(milliseconds: 350));
          await VoiceAssistantService.instance
              .speak(
            'Pinalitan ang wika sa Tagalog.',
          );
        }());
      } catch (error, stackTrace) {
        debugPrint(
          'Tagalog language change failed: $error',
        );
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

        await VoiceAssistantService.instance
            .updateLanguage(
          VoiceLang.english,
        );

        unawaited(() async {
          await Future.delayed(const Duration(milliseconds: 350));
          await VoiceAssistantService.instance.speak(
            'Language changed to English.',
          );
        }());
      } catch (error, stackTrace) {
        debugPrint(
          'English language change failed: $error',
        );
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
      final newVoiceLang = newLangCode == 'tl' ? VoiceLang.tagalog : VoiceLang.english;

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
          VoiceAssistantService
                  .activeResultProductNotifier
                  .value ??
              VoiceAssistantService
                  .latestScanProductNotifier
                  .value;

      if (currentProduct == null) {
        await VoiceAssistantService.instance
            .speak(
          localeKey == 'fil'
              ? 'Walang produktong maihahambing. Mag-scan muna ng produkto.'
              : 'No product is available to compare. Please scan a product first.',
        );
        return;
      }

      final msg = localeKey == 'fil'
          ? 'Binubuksan ang paghahambing para sa ${currentProduct.name}.'
          : 'Opening comparison for ${currentProduct.name}.';

      unawaited(
        VoiceAssistantService.instance.speak(msg),
      );

      try {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CompareProductsScreen(
              sourceProduct: currentProduct,
            ),
          ),
        );
      } catch (error, stackTrace) {
        debugPrint(
          'Comparison screen failed: $error',
        );
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
          VoiceAssistantService
                  .activeResultProductNotifier
                  .value ??
              VoiceAssistantService
                  .latestScanProductNotifier
                  .value;

      if (currentProduct == null) {
        await VoiceAssistantService.instance
            .speak(
          localeKey == 'fil'
              ? 'Walang produktong mabibigyan ng karagdagang detalye. Mag-scan muna ng produkto.'
              : 'No product is available for more details. Please scan a product first.',
        );
        return;
      }

      final msg = localeKey == 'fil'
          ? 'Binubuksan ang karagdagang detalye para sa ${currentProduct.name}.'
          : 'Opening more details for ${currentProduct.name}.';

      unawaited(
        VoiceAssistantService.instance.speak(msg),
      );

      try {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                MoreDetailsScreen(
              product: currentProduct,
            ),
          ),
        );
      } catch (error, stackTrace) {
        debugPrint(
          'More details screen failed: $error',
        );
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
    // RETURN TO ROOT
    // ============================================================
    if (Navigator.of(context).canPop()) {
      Navigator.of(context)
          .popUntil((route) => route.isFirst);
    }

    // ============================================================
    // CLEAR HISTORY
    // ============================================================
    if (target == 'clear_history') {
      HomeTabController.switchToHistorySubTab(
        'Lahat',
      );

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
      HomeTabController.switchToHistorySubTab(
        'Paborito',
      );

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
      HomeTabController.switchToTab(3);

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
      HomeTabController.switchToHistorySubTab(
        'Paborito',
      );

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
      HomeTabController.switchToHistorySubTab(
        'Kumpara',
      );

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
      HomeTabController.switchToHistorySubTab(
        'Mga Ulat',
      );

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
        HomeTabController.switchToHistorySubTab(
          'Lahat',
        );
      } else {
        HomeTabController.switchToTab(
          _tabPageKeys[target]!,
        );
      }

      final reply =
          intent.spokenReply.isNotEmpty
              ? intent.spokenReply
              : _navigationReply(
                  target,
                  localeKey,
                );

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
        unawaited(
          VoiceAssistantService.instance.speak(reply),
        );
      }

      return;
    }

    // ============================================================
    // OTHER SCREENS
    // ============================================================
    final reply =
        intent.spokenReply.isNotEmpty
            ? intent.spokenReply
            : _navigationReply(
                target,
                localeKey,
              );

    unawaited(
      VoiceAssistantService.instance.speak(reply),
    );

    try {
      final navigatorResult =
          await _navigateToScreen(
        context,
        target,
      );

      if (!navigatorResult) {
        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Narinig ko ang iyong utos, pero hindi ko mahanap o mabuksan ang pahinang iyon.'
              : 'I heard your command, but I could not find or open that page.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Navigation failed: $error',
      );
      debugPrint('$stackTrace');

      await VoiceAssistantService.instance.speak(
        localeKey == 'fil'
            ? 'Narinig ko ang iyong utos, pero nagkaroon ng problema habang binubuksan ang pahinang iyon.'
            : 'I heard your command, but there was a problem opening that page.',
      );
    }
  }

  Future<void> _handleSummarizeIntent(
    VoiceLang language,
  ) async {
    final summary =
        await GeminiService.instance.summarizeScan(
      language: language,
    );

    await VoiceAssistantService.instance.speak(
      summary,
    );
  }

  Future<bool> _navigateToScreen(
    BuildContext context,
    String targetPage,
  ) async {
    switch (targetPage) {
      case 'personal_info':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const PersonalInfoScreen(),
          ),
        );
        return true;

      case 'preference':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const PreferenceScreen(),
          ),
        );
        return true;

      case 'suggestion':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const SuggestionScreen(),
          ),
        );
        return true;

      case 'about_claro':
        try {
          return await launchUrl(
            Uri.parse(claroWebsiteUrl),
            mode:
                LaunchMode.externalApplication,
          );
        } catch (error) {
          debugPrint(
            'Open CLARO website failed: $error',
          );
          return false;
        }

      case 'privacy_policy':
        try {
          return await launchUrl(
            Uri.parse(privacyPolicyUrl),
            mode:
                LaunchMode.externalApplication,
          );
        } catch (error) {
          debugPrint(
            'Open privacy policy failed: $error',
          );
          return false;
        }

      case 'terms_conditions':
        try {
          return await launchUrl(
            Uri.parse(termsConditionsUrl),
            mode:
                LaunchMode.externalApplication,
          );
        } catch (error) {
          debugPrint(
            'Open terms failed: $error',
          );
          return false;
        }

      case 'user_guide':
        try {
          return await launchUrl(
            Uri.parse(userGuideUrl),
            mode:
                LaunchMode.externalApplication,
          );
        } catch (error) {
          debugPrint(
            'Open user guide failed: $error',
          );
          return false;
        }

      case 'change_password':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const ChangePasswordScreen(),
          ),
        );
        return true;

      case 'theme':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const ThemeScreen(),
          ),
        );
        return true;

      case 'review_history':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const ReviewHistoryScreen(),
          ),
        );
        return true;

      default:
        return false;
    }
  }

  @visibleForTesting
  String? testTargetFromTranscript(String transcript) => _targetFromTranscript(transcript);

  @visibleForTesting
  String? testExtractProductSearchQuery(String transcript) => _extractProductSearchQuery(transcript);

  String? _targetFromTranscript(
    String transcript,
  ) {
    final normalized =
        transcript.toLowerCase().replaceAll(
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
      r'\b(favorite(?: this(?: product)?)?|favorite it|add to favorites|save to favorites|save this(?: product)?|save product|like(?: this(?: product)?)?|i\s*favorite(?: ito)?|i\s*paborito(?: ito)?|paborito ito|gusto ko ito|i\s*save(?: ito)?|isave(?: ito)?|idagdag sa (?:mga )?paborito|isama sa (?:mga )?paborito|gawing paborito|ilagay sa (?:mga )?paborito)\b',
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
      r'\b(compare(?: this(?: product)?)?|compare product|compare scanned product|compare with alternatives|compare with others|ihambing(?: ang produktong ito)?|paghambingin(?: ito)?|pagkumparahin(?: ito)?|ikumpera(?: ito)?|ikumpra(?: ito)?|ihambing ito|ihambing ang produkto|paghambingin ang (?:mga )?produkto|ikumpera sa iba|ihambing sa iba)\b',
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
      if (VoiceAssistantService
              .activeResultProductNotifier
              .value !=
          null) {
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
      r'\b(about claro|tungkol sa claro|about app|about the app|about us|who made claro|app info|sino ang gumawa ng claro)\b',
    ).hasMatch(normalized)) {
      return 'about_claro';
    }

    if (RegExp(
      r'\b(privacy policy|privacy|patakaran sa privacy|data privacy|patakaran sa data)\b',
    ).hasMatch(normalized)) {
      return 'privacy_policy';
    }

    if (RegExp(
      r'\b(terms and conditions|terms and condition|terms of service|terms of use|terms|mga tuntunin at kundisyon|mga tuntunin|kundisyon)\b',
    ).hasMatch(normalized)) {
      return 'terms_conditions';
    }

    if (RegExp(
      r'\b(user guide|app guide|manual|gabay sa paggamit|gabay ng gumagamit|gabay|how to use|nutrition guide)\b',
    ).hasMatch(normalized)) {
      return 'user_guide';
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
      r'\b(summarize|summarise|summary|summaries|ibuod|buod|ipaliwanag|paliwanag|recap|overview)\b',
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

  String? _canonicalTarget(
    String? target,
  ) {
    if (target == null) return null;

    final normalized =
        target.toLowerCase().replaceAll(
          RegExp(r'[^a-z_]'),
          '_',
        );

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
    };

    return aliases[normalized] ?? normalized;
  }

  String _navigationReply(
    String target,
    String localeKey,
  ) {
    final pageName = switch (target) {
      'personal_info' =>
        localeKey == 'fil'
            ? 'personal na impormasyon'
            : 'personal information',

      'home' =>
        localeKey == 'fil'
            ? 'pangunahing screen'
            : 'home page',

      'scan' =>
        localeKey == 'fil'
            ? 'scanner ng produkto'
            : 'scanner',

      'history' =>
        localeKey == 'fil'
            ? 'kasaysayan ng pag-scan'
            : 'scan history',

      'clear_history' =>
        localeKey == 'fil'
            ? 'kasaysayan ng pag-scan'
            : 'scan history',

      'clear_favorites' =>
        localeKey == 'fil'
            ? 'mga paborito'
            : 'favorites',

      'delete_account' =>
        localeKey == 'fil'
            ? 'profile at mga setting ng account'
            : 'profile and account settings',

      'profile' =>
        localeKey == 'fil'
            ? 'profile at mga setting ng account'
            : 'profile and account settings',

      'theme' =>
        localeKey == 'fil'
            ? 'mga setting ng tema'
            : 'theme settings',

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
        localeKey == 'fil'
            ? 'kasaysayan ng mga review'
            : 'app reviews',

      'about_claro' =>
        localeKey == 'fil'
            ? 'impormasyon tungkol sa CLARO'
            : 'About CLARO',

      'privacy_policy' =>
        localeKey == 'fil'
            ? 'Patakaran sa Privacy'
            : 'Privacy Policy',

      'terms_conditions' =>
        localeKey == 'fil'
            ? 'mga Tuntunin at Kundisyon'
            : 'Terms and Conditions',

      'user_guide' =>
        localeKey == 'fil'
            ? 'Gabay sa Paggamit'
            : 'User Guide',

      'compare_products' =>
        localeKey == 'fil'
            ? 'paghahambing ng produkto'
            : 'product comparison',

      _ => target.replaceAll('_', ' '),
    };

    if (localeKey == 'fil') {
      return 'Binubuksan ang $pageName.';
    }

    return 'Opening your $pageName.';
  }

  String? _extractProductSearchQuery(
    String transcript,
  ) {
    final t =
        transcript.trim().toLowerCase();

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
      final match =
          pattern.firstMatch(t);

      if (match != null &&
          match.groupCount >= 1) {
        String query =
            match.group(1)?.trim() ?? '';

        query = query.replaceAll(
          RegExp(
            r'\s+(?:in|from)\s+(?:my\s+)?history.*$',
            caseSensitive: false,
          ),
          '',
        );

        query = query.replaceAll(
          RegExp(
            r'\s+sa\s+(?:aking\s+)?history.*$',
            caseSensitive: false,
          ),
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
    final isTagalog =
        language == VoiceLang.tagalog;

    final normalizedQuery =
        query.toLowerCase().trim();

    Product? matchedProduct;

    try {
      final localHistory =
          ScanHistoryService().localHistory;

      if (localHistory.isNotEmpty) {
        for (final p in localHistory) {
          final pName =
              p.name.toLowerCase();

          final pBrand =
              p.brand.toLowerCase();

          if (pName.contains(normalizedQuery) ||
              '$pBrand $pName'
                  .contains(normalizedQuery)) {
            matchedProduct = p;
            break;
          }
        }
      }

      if (matchedProduct == null) {
        final historyService =
            HistoryService();

        final historyItems =
            historyService.getItems(
          filter: 'Lahat',
          searchQuery: query,
        );

        if (historyItems.isNotEmpty) {
          for (final item in historyItems) {
            final pId = item.productId;

            if (pId != null &&
                pId.isNotEmpty) {
              try {
                matchedProduct =
                    await BackendLocator
                        .productRepository
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
      debugPrint(
        'Voice product search failed: $error',
      );
      debugPrint('$stackTrace');

      await VoiceAssistantService.instance
          .speak(
        isTagalog
            ? 'Narinig ko ang pangalan ng produkto, pero nagkaroon ng problema habang hinahanap ito sa iyong scan history.'
            : 'I heard the product name, but there was a problem searching for it in your scan history.',
      );

      return true;
    }

    if (!context.mounted) return true;

    if (matchedProduct != null) {
      final targetProduct =
          matchedProduct;

      VoiceAssistantService
          .setLatestScanProduct(
        targetProduct,
      );

      final reply = isTagalog
          ? 'Nahanap ang ${targetProduct.name} mula sa iyong mga na-scan na produkto. Binubuksan ang mga detalye.'
          : 'Found ${targetProduct.name} from your scan records. Opening product details.';

      if (Navigator.of(context).canPop()) {
        Navigator.of(context)
            .popUntil(
          (route) => route.isFirst,
        );
      }

      unawaited(
        VoiceAssistantService.instance
            .speak(reply),
      );

      try {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProductDetailScreen(
              product: targetProduct,
            ),
          ),
        );
      } catch (error, stackTrace) {
        debugPrint(
          'Product details navigation failed: $error',
        );
        debugPrint('$stackTrace');

        await VoiceAssistantService.instance
            .speak(
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

    await VoiceAssistantService.instance
        .speak(notFoundReply);

    return true;
  }
}