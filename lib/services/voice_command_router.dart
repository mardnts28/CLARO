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
import 'theme_service.dart';

const String claroWebsiteUrl = 'https://claro-52ia.onrender.com/';
const String privacyPolicyUrl = 'https://claro-52ia.onrender.com/privacy-policy';
const String termsConditionsUrl = 'https://claro-52ia.onrender.com/terms-and-conditions';
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
    await VoiceAssistantService.instance.stopAudio();
    final transcript = await VoiceAssistantService.instance.listenOnce();
    if (!context.mounted) return;

    final language = VoiceAssistantService.languageNotifier.value;
    final localeKey = language == VoiceLang.tagalog ? 'fil' : 'en';

    if (transcript == null || transcript.trim().isEmpty) {
      debugPrint('Voice command: speech recognition returned no transcript.');
      await VoiceAssistantService.instance.speak(
        localeKey == 'fil'
            ? 'Hindi kita narinig. Pakisubukan muli.'
            : "I didn't catch that. Please try again.",
      );
      return;
    }

    debugPrint('Voice command transcript: "$transcript"');

    // 1. Check if user is asking for summary or display of results
    if (_isSummaryRequest(transcript)) {
      debugPrint('Voice command intent: type=VoiceIntentType.summarizeScan (local match)');
      await _handleSummarizeIntent(language);
      return;
    }

    // 2. FAST LOCAL NAVIGATION FIRST (instantly handle app pages, sub-tabs, settings)
    final localTarget = _targetFromTranscript(transcript);
    if (localTarget != null) {
      debugPrint('Voice command intent: fast local navigation -> $localTarget');
      final resolvedIntent = VoiceIntent(
        type: VoiceIntentType.navigate,
        targetPage: localTarget,
        spokenReply: _navigationReply(localTarget, localeKey),
      );
      await _handleNavigationIntent(context, resolvedIntent, localeKey);
      return;
    }

    // 3. Check if user is searching for a specific product from history or catalog
    final productSearchQuery = _extractProductSearchQuery(transcript);
    if (productSearchQuery != null && productSearchQuery.isNotEmpty) {
      debugPrint('Voice command intent: product search for "$productSearchQuery"');
      final handled = await _handleProductSearch(context, productSearchQuery, language);
      if (handled) return;
    }

    // 4. Fallback to Gemini classifier
    final intent = await GeminiService.instance.classifyIntent(
      transcript: transcript,
      language: language,
    );
    if (!context.mounted) return;

    final target = _targetFromTranscript(transcript) ?? intent.targetPage;
    final resolvedIntent = target != null && intent.type != VoiceIntentType.summarizeScan
        ? VoiceIntent(
            type: VoiceIntentType.navigate,
            targetPage: target,
            spokenReply: _navigationReply(target, localeKey),
          )
        : intent;

    debugPrint(
      'Voice command intent: type=${resolvedIntent.type} '
      'target=${resolvedIntent.targetPage}',
    );

    switch (resolvedIntent.type) {
      case VoiceIntentType.navigate:
        await _handleNavigationIntent(context, resolvedIntent, localeKey);
        break;
      case VoiceIntentType.summarizeScan:
        await _handleSummarizeIntent(language);
        break;
      case VoiceIntentType.outOfScope:
      case VoiceIntentType.unclear:
        await VoiceAssistantService.instance.speak(
            resolvedIntent.spokenReply.isNotEmpty
              ? resolvedIntent.spokenReply
              : localeKey == 'fil'
                  ? 'Paumanhin, hindi ko naintindihan ang kahilingan mo.'
                  : 'Sorry, I did not understand your request.',
        );
        break;
    }
  }

  Future<void> _handleNavigationIntent(
    BuildContext context,
    VoiceIntent intent,
    String localeKey,
  ) async {
    final target = _canonicalTarget(intent.targetPage);
    if (target == null || target.isEmpty) {
      await VoiceAssistantService.instance.speak(
        localeKey == 'fil'
            ? 'Hindi ko mahanap ang pahinang iyon.'
            : 'I could not find that page.',
      );
      return;
    }

    // 1. In-screen action: Favorite/Like current product
    if (target == 'favorite_product') {
      final currentProduct = VoiceAssistantService.latestScanProductNotifier.value;
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
          await VoiceAssistantService.instance.speak(msg);
        } catch (e) {
          final msg = localeKey == 'fil' ? 'Hindi mai-save ang paborito.' : 'Could not update favorites.';
          await VoiceAssistantService.instance.speak(msg);
        }
      } else {
        final msg = localeKey == 'fil'
            ? 'Walang aktibong produkto para i-save.'
            : 'No active product to add to favorites.';
        await VoiceAssistantService.instance.speak(msg);
      }
      return;
    }

    // In-screen action: Unfavorite/Unlike current product
    if (target == 'unfavorite_product') {
      final currentProduct = VoiceAssistantService.latestScanProductNotifier.value;
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
          await VoiceAssistantService.instance.speak(msg);
        } catch (e) {
          final msg = localeKey == 'fil' ? 'Hindi maalis sa paborito.' : 'Could not remove from favorites.';
          await VoiceAssistantService.instance.speak(msg);
        }
      } else {
        final msg = localeKey == 'fil'
            ? 'Walang aktibong produkto para alisin.'
            : 'No active product to remove from favorites.';
        await VoiceAssistantService.instance.speak(msg);
      }
      return;
    }

    // 2. In-screen action: Report product
    if (target == 'report_product') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const UnknownProductSubmissionScreen(capturedImagePath: null),
        ),
      );
      final msg = localeKey == 'fil'
          ? 'Binubuksan ang screen para sa pag-uulat ng produkto.'
          : 'Opening product report screen.';
      await VoiceAssistantService.instance.speak(msg);
      return;
    }

    // 3. Direct setting: Turn on Dark Mode immediately in place
    if (target == 'dark_mode') {
      await setAppThemeMode(ThemeMode.dark);
      try {
        await AuthService().updateUserData({'theme': 'Dark Mode'});
      } catch (_) {}
      final msg = localeKey == 'fil'
          ? 'Naka-on na ang dark mode.'
          : 'Dark mode turned on.';
      await VoiceAssistantService.instance.speak(msg);
      return;
    }

    // 4. Direct setting: Turn on Light Mode immediately in place
    if (target == 'light_mode') {
      await setAppThemeMode(ThemeMode.light);
      try {
        await AuthService().updateUserData({'theme': 'Default'});
      } catch (_) {}
      final msg = localeKey == 'fil'
          ? 'Naka-on na ang light mode.'
          : 'Light mode turned on.';
      await VoiceAssistantService.instance.speak(msg);
      return;
    }

    // 5. Direct setting: Voice Assistant toggle ON / OFF
    if (target == 'voice_assistant_off') {
      final msg = localeKey == 'fil'
          ? 'Naka-off na ang voice assistant.'
          : 'Voice assistant disabled.';
      await VoiceAssistantService.instance.speak(msg);
      await VoiceAssistantService.instance.updateEnabled(false);
      return;
    }
    if (target == 'voice_assistant_on') {
      await VoiceAssistantService.instance.updateEnabled(true);
      final msg = localeKey == 'fil'
          ? 'Naka-on na ang voice assistant.'
          : 'Voice assistant enabled.';
      await VoiceAssistantService.instance.speak(msg);
      return;
    }

    // 6. Direct setting: MFA (Multi-factor authentication)
    if (target == 'mfa_on') {
      try {
        await AuthService().setMfaEnabled(enabled: true);
        final msg = localeKey == 'fil'
            ? 'Matagumpay na na-on ang multi-factor authentication para sa iyong account.'
            : 'Multi-factor authentication has been successfully enabled for your account.';
        await VoiceAssistantService.instance.speak(msg);
      } catch (_) {
        final msg = localeKey == 'fil'
            ? 'Hindi ma-on ang multi-factor authentication sa ngayon.'
            : 'Unable to enable multi-factor authentication at this time.';
        await VoiceAssistantService.instance.speak(msg);
      }
      return;
    }
    if (target == 'mfa_off') {
      try {
        await AuthService().setMfaEnabled(enabled: false);
        final msg = localeKey == 'fil'
            ? 'Matagumpay na na-off ang multi-factor authentication.'
            : 'Multi-factor authentication has been successfully disabled.';
        await VoiceAssistantService.instance.speak(msg);
      } catch (_) {
        final msg = localeKey == 'fil'
            ? 'Hindi ma-off ang multi-factor authentication sa ngayon.'
            : 'Unable to disable multi-factor authentication at this time.';
        await VoiceAssistantService.instance.speak(msg);
      }
      return;
    }
    if (target == 'mfa') {
      HomeTabController.switchToTab(3);
      final msg = localeKey == 'fil'
          ? 'Binubuksan ang mga setting ng multi-factor authentication sa iyong profile.'
          : 'Opening multi-factor authentication settings in your profile.';
      unawaited(VoiceAssistantService.instance.speak(msg));
      return;
    }

    // Logout / Sign out
    if (target == 'logout') {
      try {
        final msg = localeKey == 'fil'
            ? 'Matagumpay kang nai-log out. Babalik sa login screen.'
            : 'You have been successfully logged out. Returning to the login screen.';
        await VoiceAssistantService.instance.speak(msg);
        await AuthService().signOut();
      } catch (_) {
        final msg = localeKey == 'fil' ? 'Hindi ma-proseso ang pag-logout.' : 'Could not complete log out.';
        await VoiceAssistantService.instance.speak(msg);
      }
      return;
    }

    // 7. Direct setting: Language switching
    if (target == 'language_tagalog') {
      await LocaleService.setAppLocale('tl');
      await VoiceAssistantService.instance.updateLanguage(VoiceLang.tagalog);
      await VoiceAssistantService.instance.speak('Pinalitan ang wika sa Tagalog.');
      return;
    }
    if (target == 'language_english') {
      await LocaleService.setAppLocale('en');
      await VoiceAssistantService.instance.updateLanguage(VoiceLang.english);
      await VoiceAssistantService.instance.speak('Language changed to English.');
      return;
    }
    if (target == 'language') {
      HomeTabController.switchToTab(3);
      final msg = localeKey == 'fil'
          ? 'Maaari mong palitan ang wika sa profile settings.'
          : 'You can change the language in your profile settings.';
      unawaited(VoiceAssistantService.instance.speak(msg));
      return;
    }

    // 7. Comparison screen (from result screen or voice command)
    if (target == 'compare_products') {
      final currentProduct = VoiceAssistantService.activeResultProductNotifier.value ??
          VoiceAssistantService.latestScanProductNotifier.value;
      if (currentProduct == null) {
        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Walang produktong maihahambing. Mag-scan muna ng produkto.'
              : 'No product available to compare. Please scan a product first.',
        );
        return;
      }
      final msg = localeKey == 'fil'
          ? 'Binubuksan ang paghahambing para sa ${currentProduct.name}.'
          : 'Opening comparison for ${currentProduct.name}.';
      unawaited(VoiceAssistantService.instance.speak(msg));
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CompareProductsScreen(
            sourceProduct: currentProduct,
          ),
        ),
      );
      return;
    }

    // In-screen action: More Details (ingredients, allergens, storage)
    if (target == 'more_details') {
      final currentProduct = VoiceAssistantService.activeResultProductNotifier.value ??
          VoiceAssistantService.latestScanProductNotifier.value;
      if (currentProduct == null) {
        await VoiceAssistantService.instance.speak(
          localeKey == 'fil'
              ? 'Walang produktong mabibigyan ng karagdagang detalye. Mag-scan muna ng produkto.'
              : 'No product available for more details. Please scan a product first.',
        );
        return;
      }
      final msg = localeKey == 'fil'
          ? 'Binubuksan ang karagdagang detalye para sa ${currentProduct.name}.'
          : 'Opening more details for ${currentProduct.name}.';
      unawaited(VoiceAssistantService.instance.speak(msg));
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MoreDetailsScreen(
            product: currentProduct,
          ),
        ),
      );
      return;
    }

    // 8. Tab switches and root screens: pop to root first
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    // Sub-tab: Favorites in History
    if (target == 'history_favorites') {
      HomeTabController.switchToHistorySubTab('Paborito');
      unawaited(VoiceAssistantService.instance.speak(
        localeKey == 'fil' ? 'Binubuksan ang mga paboritong produkto.' : 'Opening your favorites.',
      ));
      return;
    }

    // Sub-tab: Comparison records in History
    if (target == 'history_compare') {
      HomeTabController.switchToHistorySubTab('Kumpara');
      unawaited(VoiceAssistantService.instance.speak(
        localeKey == 'fil' ? 'Binubuksan ang kasaysayan ng paghahambing.' : 'Opening your comparison history.',
      ));
      return;
    }

    // Sub-tab: Reports in History
    if (target == 'history_reports') {
      HomeTabController.switchToHistorySubTab('Mga Ulat');
      unawaited(VoiceAssistantService.instance.speak(
        localeKey == 'fil' ? 'Binubuksan ang iyong mga ulat.' : 'Opening your submitted reports.',
      ));
      return;
    }

    if (_tabPageKeys.containsKey(target)) {
      if (target == 'history') {
        HomeTabController.switchToHistorySubTab('Lahat');
      } else {
        HomeTabController.switchToTab(_tabPageKeys[target]!);
      }
      final reply = intent.spokenReply.isNotEmpty
          ? intent.spokenReply
          : _navigationReply(target, localeKey);
      unawaited(VoiceAssistantService.instance.speak(reply));
      return;
    }

    final reply = intent.spokenReply.isNotEmpty
        ? intent.spokenReply
        : _navigationReply(target, localeKey);
    unawaited(VoiceAssistantService.instance.speak(reply));

    final navigatorResult = await _navigateToScreen(context, target);
    if (!navigatorResult) {
      await VoiceAssistantService.instance.speak(
        localeKey == 'fil'
            ? 'Hindi ko mahanap ang pahinang iyon.'
            : 'I could not find that page.',
      );
    }
  }

  Future<void> _handleSummarizeIntent(VoiceLang language) async {
    final summary = await GeminiService.instance.summarizeScan(language: language);
    await VoiceAssistantService.instance.speak(summary);
  }

  Future<bool> _navigateToScreen(BuildContext context, String targetPage) async {
    switch (targetPage) {
      case 'personal_info':
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalInfoScreen()));
        return true;
      case 'preference':
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const PreferenceScreen()));
        return true;
      case 'suggestion':
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const SuggestionScreen()));
        return true;
      case 'about_claro':
        try {
          return await launchUrl(
            Uri.parse(claroWebsiteUrl),
            mode: LaunchMode.externalApplication,
          );
        } catch (e) {
          return false;
        }
      case 'privacy_policy':
        try {
          return await launchUrl(
            Uri.parse(privacyPolicyUrl),
            mode: LaunchMode.externalApplication,
          );
        } catch (e) {
          return false;
        }
      case 'terms_conditions':
        try {
          return await launchUrl(
            Uri.parse(termsConditionsUrl),
            mode: LaunchMode.externalApplication,
          );
        } catch (e) {
          return false;
        }
      case 'user_guide':
        try {
          return await launchUrl(
            Uri.parse(userGuideUrl),
            mode: LaunchMode.externalApplication,
          );
        } catch (e) {
          return false;
        }
      case 'change_password':
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
        return true;
      case 'theme':
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemeScreen()));
        return true;
      case 'review_history':
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewHistoryScreen()));
        return true;
      default:
        return false;
    }
  }

  String? _targetFromTranscript(String transcript) {
    final normalized = transcript.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');

    // 1. In-screen action: Unlike / Unfavorite active product
    if (RegExp(r'\b(unfavorite this|unfavorite this product|unfavorite it|remove from favorites|unlike this product|unlike this|remove favorite|alisin sa paborito|tanggalin sa paborito|i\s*unfavorite ito|i\s*unfavorite)\b')
        .hasMatch(normalized)) {
      return 'unfavorite_product';
    }

    // In-screen action: Like / Favorite active product
    if (RegExp(r'\b(favorite this|favorite this product|favorite it|add to favorites|save to favorites|like this product|like this|i\s*favorite|i\s*paborito|paborito ito|gusto ko ito|i\s*save ito|isave ito|idagdag sa paborito|isama sa paborito)\b')
        .hasMatch(normalized)) {
      return 'favorite_product';
    }

    // 2. In-screen action: Report product
    if (RegExp(r'\b(report this product|report product|report issue|report error|i\s*report ito|ireport ito|i\s*report|ireport|i\s*ulat ito|iulat ito|i\s*ulat|iulat|mali ang impormasyon|maling produkto)\b')
        .hasMatch(normalized)) {
      return 'report_product';
    }

    // In-screen action: More Details (ingredients, allergen warnings, storage instructions)
    if (RegExp(r'\b(more details|for more details|show more details|open more details|see more details|view more details|product details|ingredients|storage instructions|storage|karagdagang detalye|karagdagang impormasyon|mga sangkap|sangkap|paraan ng pag\s*imbak|imbak|detalye ng produkto|detalye)\b')
        .hasMatch(normalized)) {
      return 'more_details';
    }

    // 3. In-screen action: Explicitly compare active/scanned product with alternatives
    if (RegExp(r'\b(compare this product|compare this|compare product|compare scanned product|compare with alternatives|compare with others|ihambing ang produktong ito|paghambingin ito|pagkumparahin ito|ikumpera ito|ikumpra ito|ihambing ito)\b')
        .hasMatch(normalized)) {
      return 'compare_products';
    }

    // 4. Sub-tabs in History
    if (RegExp(r'\b(favorite|favorites|paborito|mga paborito|my favorites|paboritong produkto|mga paboritong produkto|saved products|saved product|saved items|saved|mga naka\s*save|naka\s*save)\b')
        .hasMatch(normalized)) {
      return 'history_favorites';
    }
    if (RegExp(r'\b(compare history|comparison history|comparison records|history compare|kasaysayan ng paghahambing|mga pinaghambing|mga kinumpara|past comparisons)\b')
        .hasMatch(normalized)) {
      return 'history_compare';
    }

    // Generic compare: if on the Result screen (active product open), compare that product;
    // otherwise if on any other page, navigate to History Compare sub-tab.
    if (RegExp(r'\b(compare|comparison|comparisons|compared|kumpara|ihambing|paghambingin|ikumpra|ikumpera)\b')
        .hasMatch(normalized)) {
      if (VoiceAssistantService.activeResultProductNotifier.value != null) {
        return 'compare_products';
      }
      return 'history_compare';
    }

    if (RegExp(r'\b(reports|my reports|submitted reports|mga ulat|ulat|aking mga ulat|report history|view reports|show reports|kasaysayan ng ulat)\b')
        .hasMatch(normalized)) {
      return 'history_reports';
    }

    // 5. Main Tabs
    if (RegExp(r'\b(home|main|dashboard|simula|home page|home screen|main page|main screen|tahanan|unang pahina|balik sa home|punta sa home)\b').hasMatch(normalized)) {
      return 'home';
    }
    if (RegExp(r'\b(scan|scanner|camera|mag\s*scan|magscan|mag scan|camera screen|scan screen|take a scan|scan a product|kumuha ng scan|buksan ang camera|buksan ang scanner)\b').hasMatch(normalized)) {
      return 'scan';
    }
    if (RegExp(r'\b(history|records|previous scans|mga na\s*scan|mga nascan|mga nakaraang scan|kasaysayan|scan history|all scans)\b').hasMatch(normalized)) {
      return 'history';
    }
    if (RegExp(r'\b(profile|my profile|account|my account|profile page|profile screen|settings|setting|account settings|user profile|aking profile|impormasyon ng account|mga setting)\b').hasMatch(normalized)) {
      return 'profile';
    }

    // 6. Settings & Feature Screens (Accessible from ANY page)
    if (RegExp(r'\b(personal information|personal info|my info|my information|account information|personal na impormasyon|personal details|profile details|user info|user details|my name|my email|edit profile|aking impormasyon|aking detalye|aking pangalan|aking email)\b')
        .hasMatch(normalized)) {
      return 'personal_info';
    }

    // Voice Assistant ON / OFF
    if (RegExp(r'\b(voice assistant off|voice off|turn off voice assistant|turn off voice|disable voice assistant|disable voice|i\s*off ang voice assistant|patayin ang boses|patayin ang voice assistant)\b')
        .hasMatch(normalized)) {
      return 'voice_assistant_off';
    }
    if (RegExp(r'\b(voice assistant on|voice on|turn on voice assistant|turn on voice|enable voice assistant|enable voice|i\s*on ang voice assistant|buhayin ang boses|buhayin ang voice assistant)\b')
        .hasMatch(normalized)) {
      return 'voice_assistant_on';
    }

    // MFA ON / OFF
    if (RegExp(r'\b(turn off (?:mfa|multi factor|two factor|2fa)|disable (?:mfa|multi factor|two factor|2fa)|deactivate (?:mfa|multi factor|two factor|2fa)|switch off (?:mfa|2fa)|mfa off|2fa off|i\s*off ang (?:mfa|multi factor|two factor|2fa)|patayin ang (?:mfa|multi factor|two factor|2fa)|isara ang (?:mfa|multi factor|two factor|2fa)|i\s*disable ang (?:mfa|2fa)|i\s*deactivate ang (?:mfa|2fa))\b')
        .hasMatch(normalized)) {
      return 'mfa_off';
    }
    if (RegExp(r'\b(turn on (?:mfa|multi factor|two factor|2fa)|enable (?:mfa|multi factor|two factor|2fa)|activate (?:mfa|multi factor|two factor|2fa)|switch on (?:mfa|2fa)|mfa on|2fa on|i\s*on ang (?:mfa|multi factor|two factor|2fa)|buhayin ang (?:mfa|multi factor|two factor|2fa)|buksan ang (?:mfa|multi factor|two factor|2fa)|i\s*enable ang (?:mfa|2fa)|i\s*activate ang (?:mfa|2fa))\b')
        .hasMatch(normalized)) {
      return 'mfa_on';
    }
    if (RegExp(r'\b(multi factor authentication|two factor authentication|multi factor|two factor|mfa|2fa|dalawang yugtong pagpapatunay|mfa settings|2fa settings)\b')
        .hasMatch(normalized)) {
      return 'mfa';
    }

    // Theme: Turn OFF Dark Mode -> Light Mode
    if (RegExp(r'\b(dark mode off|darkmode off|turn off dark mode|turn off darkmode|disable dark mode|disable darkmode|i\s*off ang dark mode|patayin ang dark mode)\b')
        .hasMatch(normalized)) {
      return 'light_mode';
    }

    // Theme: Turn OFF Light Mode -> Dark Mode
    if (RegExp(r'\b(light mode off|lightmode off|turn off light mode|turn off lightmode|disable light mode|disable lightmode|i\s*off ang light mode|patayin ang light mode)\b')
        .hasMatch(normalized)) {
      return 'dark_mode';
    }

    // Theme: Turn ON Dark Mode -> Dark Mode
    if (RegExp(r'\b(turn on dark mode|turn on darkmode|enable dark mode|enable darkmode|switch to dark mode|dark mode on|darkmode on|diliman ang tema|dark theme|i\s*dark mode|madilim na tema|diliman|darkmode|dark mode)\b')
        .hasMatch(normalized)) {
      return 'dark_mode';
    }

    // Theme: Turn ON Light Mode -> Light Mode
    if (RegExp(r'\b(turn on light mode|turn on lightmode|enable light mode|enable lightmode|switch to light mode|light mode on|lightmode on|liwanagan ang tema|light theme|default theme|i\s*light mode|maliwanag na tema|liwanagan|lightmode|light mode)\b')
        .hasMatch(normalized)) {
      return 'light_mode';
    }

    // Language switching
    if (RegExp(r'\b((?:change|switch|set) (?:language|voice) to (?:tagalog|filipino)|magtagalog|tagalog voice|wika tagalog|palitan sa tagalog|gawing tagalog)\b')
        .hasMatch(normalized)) {
      return 'language_tagalog';
    }
    if (RegExp(r'\b((?:change|switch|set) (?:language|voice) to english|mag\s*english|english voice|wika ingles|palitan sa english|gawing english)\b')
        .hasMatch(normalized)) {
      return 'language_english';
    }
    if (RegExp(r'\b(language change|change language|switch language|language settings|language setting|wika|palitan ang wika|magpalit ng wika)\b')
        .hasMatch(normalized)) {
      return 'language';
    }
    if (RegExp(r'\b(theme screen|theme settings|theme setting|open theme|mga setting ng tema|mga tema|tema|tema ng app|appearance)\b')
        .hasMatch(normalized)) {
      return 'theme';
    }
    if (RegExp(r'\b(preference|preferences|health preference|health preferences|dietary preference|dietary preferences|kagustuhan|mga kagustuhan|health conditions|health condition|medical conditions|medical condition|allergies|allergy|mga allergy|kondisyon sa kalusugan|pangkalusugan|my health|my preferences)\b')
        .hasMatch(normalized)) {
      return 'preference';
    }
    if (RegExp(r'\b(suggestion|suggestions|feedback|feedbacks|mungkahi|komento|comment|comments|suggest|help|support|contact|magbigay ng feedback|mungkahi at puna|tulong|suporta)\b')
        .hasMatch(normalized)) {
      return 'suggestion';
    }
    if (RegExp(r'\b(app reviews|app review|review history|reviews|mga review|kasaysayan ng review|pagsusuri ng app)\b')
        .hasMatch(normalized)) {
      return 'review_history';
    }
    if (RegExp(r'\b(about claro|tungkol sa claro|about app|about the app|about us|who made claro|app info|sino ang gumawa ng claro)\b')
        .hasMatch(normalized)) {
      return 'about_claro';
    }
    if (RegExp(r'\b(privacy policy|privacy|patakaran sa privacy|data privacy|patakaran sa data)\b')
        .hasMatch(normalized)) {
      return 'privacy_policy';
    }
    if (RegExp(r'\b(terms and conditions|terms and condition|terms of service|terms of use|terms|mga tuntunin at kundisyon|mga tuntunin|kundisyon)\b')
        .hasMatch(normalized)) {
      return 'terms_conditions';
    }
    if (RegExp(r'\b(user guide|app guide|manual|gabay sa paggamit|gabay ng gumagamit|gabay|how to use|nutrition guide)\b')
        .hasMatch(normalized)) {
      return 'user_guide';
    }
    if (RegExp(r'\b(change password|reset password|palitan ang password|baguhin ang password|update password|i-reset ang password|password|security settings)\b')
        .hasMatch(normalized)) {
      return 'change_password';
    }

    // Logout / Sign out
    if (RegExp(r'\b(log out|logout|sign out|signout|mag log out|maglog out|mag sign out|magsign out|lumabas sa account|i\s*log out)\b')
        .hasMatch(normalized)) {
      return 'logout';
    }

    return null;
  }

  bool _isSummaryRequest(String transcript) {
    final normalized = transcript.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim();
    if (RegExp(r'\b(summarize|summarise|summary|summaries|ibuod|buod|ipaliwanag|paliwanag|recap|overview)\b').hasMatch(normalized)) {
      return true;
    }
    if (RegExp(r'\b(display results|show results|read results|tell results|what are the results|comparison results|compare results|display comparison|scan results|scan result|product results|nutrition results|resulta|mga resulta|advisory|health advisory|health advisories|summarize advisory|summary advisory|payo sa kalusugan|payo|anong payo|buod ng resulta)\b').hasMatch(normalized)) {
      return true;
    }
    if (RegExp(r'^(?:the\s+)?(?:results|result|summary|resulta|advisory|health advisory|payo|buod)$').hasMatch(normalized)) {
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
      'app_reviews': 'review_history',
      'app_review': 'review_history',
      'terms_and_conditions': 'terms_conditions',
      'terms_of_service': 'terms_conditions',
      'user_guides': 'user_guide',
      'compare': 'compare_products',
      'comparison': 'compare_products',
      'compare_product': 'compare_products',
      'product_comparison': 'compare_products',
    };
    return aliases[normalized] ?? normalized;
  }

  String _navigationReply(String target, String localeKey) {
    final pageName = switch (target) {
      'personal_info' => localeKey == 'fil' ? 'personal na impormasyon' : 'personal information',
      'home' => localeKey == 'fil' ? 'pangunahing screen' : 'home page',
      'scan' => localeKey == 'fil' ? 'scanner ng produkto' : 'scanner',
      'history' => localeKey == 'fil' ? 'kasaysayan ng pag-scan' : 'scan history',
      'profile' => localeKey == 'fil' ? 'profile at mga setting ng account' : 'profile and account settings',
      'theme' => localeKey == 'fil' ? 'mga setting ng tema' : 'theme settings',
      'preference' => localeKey == 'fil' ? 'mga kagustuhan sa kalusugan at pagkain' : 'health preferences',
      'suggestion' => localeKey == 'fil' ? 'screen ng mungkahi at feedback' : 'suggestions and feedback',
      'change_password' => localeKey == 'fil' ? 'mga setting ng password at seguridad' : 'password and security settings',
      'review_history' => localeKey == 'fil' ? 'kasaysayan ng mga review' : 'app reviews',
      'about_claro' => localeKey == 'fil' ? 'impormasyon tungkol sa CLARO' : 'About CLARO',
      'privacy_policy' => localeKey == 'fil' ? 'Patakaran sa Privacy' : 'Privacy Policy',
      'terms_conditions' => localeKey == 'fil' ? 'mga Tuntunin at Kundisyon' : 'Terms and Conditions',
      'user_guide' => localeKey == 'fil' ? 'Gabay sa Paggamit' : 'User Guide',
      'compare_products' => localeKey == 'fil' ? 'paghahambing ng produkto' : 'product comparison',
      _ => target.replaceAll('_', ' '),
    };
    if (localeKey == 'fil') {
      return 'Binubuksan ang $pageName.';
    }
    return 'Opening your $pageName.';
  }

  String? _extractProductSearchQuery(String transcript) {
    final t = transcript.trim().toLowerCase();

    // If transcript itself maps to any app page/action, skip product search
    if (_targetFromTranscript(transcript) != null) return null;

    const excludedPages = {
      'home', 'main', 'dashboard', 'simula', 'home page', 'home screen',
      'scan', 'scanner', 'camera', 'mag-scan', 'magscan', 'camera screen', 'scan screen',
      'history', 'records', 'previous scans', 'all scans', 'kasaysayan', 'scan history',
      'favorites', 'favorite', 'my favorites', 'paborito', 'saved products', 'saved',
      'reports', 'my reports', 'submitted reports', 'mga ulat', 'ulat',
      'profile', 'account', 'my profile', 'my account', 'profile page', 'profile screen', 'settings', 'setting',
      'personal info', 'personal information', 'my info', 'my information', 'user info', 'personal details',
      'preference', 'preferences', 'health preferences', 'health preference', 'dietary preferences',
      'theme', 'themes', 'dark mode', 'darkmode', 'light mode', 'appearance',
      'suggestion', 'suggestions', 'feedback', 'feedbacks', 'comments',
      'change password', 'reset password', 'update password',
      'about claro', 'about app', 'about us', 'about the app',
      'compare', 'compare products', 'comparison', 'product comparison',
      'review history', 'advisory', 'health advisory', 'results', 'result',
      'log out', 'logout', 'sign out', 'signout'
    };

    if (excludedPages.contains(t)) return null;

    final patterns = [
      RegExp(r'^(?:please\s+)?(?:find|search(?:\s+for)?|look\s+for|show|open|go\s+to|view|check)\s+(?:me\s+)?(.+?)(?:\s+(?:in|from)\s+(?:my\s+)?history|\s+from\s+last\s+week|\s+from\s+yesterday|\s+product|\s+details)?$', caseSensitive: false),
      RegExp(r'^(?:paki-?)?(?:hanapin|hanap|pahanap|buksan|tingnan|ipakita|pumunta\s+sa|punta\s+sa)\s+(?:po\s+)?(?:ang|yung|ng)?\s*(.+?)(?:\s+sa\s+(?:aking\s+)?history|\s+sa\s+mga\s+na-?scan)?$', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(t);
      if (match != null && match.groupCount >= 1) {
        String query = match.group(1)?.trim() ?? '';
        query = query.replaceAll(RegExp(r'\s+(?:in|from)\s+(?:my\s+)?history.*$', caseSensitive: false), '');
        query = query.replaceAll(RegExp(r'\s+sa\s+(?:aking\s+)?history.*$', caseSensitive: false), '');
        query = query.replaceAll(RegExp(r'\s+(?:from\s+)?(?:last\s+week|yesterday|earlier|kanina).*$', caseSensitive: false), '');
        query = query.replaceAll(RegExp(r'\s+(?:product|details|screen|scan|page)$', caseSensitive: false), '').trim();

        if (query.isNotEmpty &&
            _targetFromTranscript(query) == null &&
            !excludedPages.contains(query)) {
          return query;
        }
      }
    }

    // Direct product name keywords support (e.g. user just speaks "blue bay tuna" or "century tuna")
    const brandKeywords = [
      'century', '555', 'blue bay', 'san marino', 'purefoods', 'argentina',
      'lucky 7', 'cdo', 'mega', 'ligo', 'ram', 'ufc', 'del monte', 'jolly',
      'saba', 'unipack', 'golden town', 'star carne', 'carne norte', 'corned beef',
      'tuna', 'sardine', 'sardines', 'lucky me', 'pancit canton'
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

    // Search strictly within user's scanned history:
    // 1. Check local session scan history (ScanHistoryService)
    final localHistory = ScanHistoryService().localHistory;
    if (localHistory.isNotEmpty) {
      for (final p in localHistory) {
        final pName = p.name.toLowerCase();
        final pBrand = p.brand.toLowerCase();
        if (pName.contains(normalizedQuery) || '$pBrand $pName'.contains(normalizedQuery)) {
          matchedProduct = p;
          break;
        }
      }
    }

    // 2. Search in user's saved scan history records (HistoryService)
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
              matchedProduct = await BackendLocator.productRepository.getProductById(pId);
              break;
            } catch (e) {
              debugPrint('Voice search: failed to fetch scanned product by id: $e');
            }
          }
        }
      }
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

      // Speak immediately as navigation starts
      unawaited(VoiceAssistantService.instance.speak(reply));

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            product: targetProduct,
          ),
        ),
      );

      return true;
    } else {
      final notFoundReply = isTagalog
          ? 'Wala ka pang na-i-scan na produktong tulad niyan. Mangyaring i-scan muna ang aytem upang makita ang mga detalye nito.'
          : 'You haven\'t scanned a product matching that yet. Please scan the item first to view its details.';
      await VoiceAssistantService.instance.speak(notFoundReply);
      return true;
    }
  }
}
