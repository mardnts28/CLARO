import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'voice_assistant_service.dart';
import 'gemini_service.dart';
import 'home_tab_controller.dart';
import '../screens/personal_info_screen.dart';
import '../screens/preference_screen.dart';
import '../screens/suggestion_screen.dart';
import '../screens/change_password_screen.dart';
import '../screens/theme_screen.dart';
import '../screens/review_history_screen.dart';
import '../screens/compare_products_screen.dart';
import '../screens/product_detail_screen.dart';
import 'history_service.dart';
import '../data/services/backend_locator.dart';
import '../models/product_model.dart';

// Placeholder URL - replace with actual CLARO website URL when available
const String claroWebsiteUrl = 'https://example.com/about-claro';

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
    if (_isSummaryRequest(transcript)) {
      debugPrint('Voice command intent: type=VoiceIntentType.summarizeScan (local match)');
      await _handleSummarizeIntent(language);
      return;
    }

    // Check if user is searching for a specific product from history
    final productSearchQuery = _extractProductSearchQuery(transcript);
    if (productSearchQuery != null && productSearchQuery.isNotEmpty) {
      debugPrint('Voice command intent: product search for "$productSearchQuery"');
      final handled = await _handleProductSearch(context, productSearchQuery, language);
      if (handled) return;
    }

    final intent = await GeminiService.instance.classifyIntent(
      transcript: transcript,
      language: language,
    );
    if (!context.mounted) return;

    final target = _targetFromTranscript(transcript);
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

    if (target == 'compare_products' &&
        VoiceAssistantService.latestScanProductNotifier.value == null) {
      await VoiceAssistantService.instance.speak(
        localeKey == 'fil'
            ? 'Walang produktong maihahambing. Mag-scan muna ng produkto.'
            : 'No product available to compare. Please scan a product first.',
      );
      return;
    }

    if (_tabPageKeys.containsKey(target)) {
      HomeTabController.switchToTab(_tabPageKeys[target]!);
      await VoiceAssistantService.instance.speak(
        intent.spokenReply.isNotEmpty
            ? intent.spokenReply
            : _navigationReply(target, localeKey),
      );
      return;
    }

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
        final Uri url = Uri.parse(claroWebsiteUrl);
        try {
          final bool launched = await launchUrl(
            url,
            mode: LaunchMode.externalApplication,
          );
          return launched;
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
      case 'compare_products':
        final currentProduct = VoiceAssistantService.latestScanProductNotifier.value;
        if (currentProduct == null) return false;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CompareProductsScreen(
              sourceProduct: currentProduct,
            ),
          ),
        );
        return true;
      default:
        return false;
    }
  }

  String? _targetFromTranscript(String transcript) {
    final normalized = transcript.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), ' ');
    if (RegExp(r'\b(compare|comparison|comparisons|compare products|compare product|ihambing|paghambingin|pagkumparahin|ikumpera|ikumpra)\b')
        .hasMatch(normalized)) {
      return 'compare_products';
    }
    if (RegExp(r'\b(personal information|personal info|my information|account information)\b')
        .hasMatch(normalized)) {
      return 'personal_info';
    }
    if (RegExp(r'\b(profile|account|dashboard)\b').hasMatch(normalized)) {
      return normalized.contains('dashboard') ? 'home' : 'profile';
    }
    if (RegExp(r'\b(home|main)\b').hasMatch(normalized)) return 'home';
    if (RegExp(r'\b(scan|scanner)\b').hasMatch(normalized)) return 'scan';
    if (RegExp(r'\b(history|records|previous scans)\b').hasMatch(normalized)) {
      return 'history';
    }
    return null;
  }

  bool _isSummaryRequest(String transcript) {
    final normalized = transcript.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), ' ');
    return RegExp(
      r'\b(summarize|summarise|summary|explain|describe)\b.*\b(result|results|scan|report|product|nutrition)\b',
    ).hasMatch(normalized);
  }

  String? _canonicalTarget(String? target) {
    if (target == null) return null;
    final normalized = target.toLowerCase().replaceAll(RegExp(r'[^a-z_]'), '_');
    const aliases = {
      'dashboard': 'home',
      'main': 'home',
      'scanner': 'scan',
      'records': 'history',
      'my_history': 'history',
      'account': 'profile',
      'my_profile': 'profile',
      'profile_page': 'profile',
      'personal_information': 'personal_info',
      'personal_info_page': 'personal_info',
      'my_information': 'personal_info',
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
      'home' => localeKey == 'fil' ? 'home page' : 'home page',
      'scan' => localeKey == 'fil' ? 'scanner' : 'scanner',
      'history' => localeKey == 'fil' ? 'history' : 'history',
      'profile' => localeKey == 'fil' ? 'profile' : 'profile',
      'compare_products' => localeKey == 'fil' ? 'paghahambing ng produkto' : 'product comparison',
      _ => target.replaceAll('_', ' '),
    };
    if (localeKey == 'fil') {
      return 'Binubuksan ko ang $pageName.';
    }
    return 'Opening your $pageName.';
  }

  String? _extractProductSearchQuery(String transcript) {
    final t = transcript.trim().toLowerCase();

    // General navigation destinations to exclude from product search
    const excludedPages = {
      'home', 'main', 'scan', 'scanner', 'camera', 'history', 'records',
      'profile', 'account', 'personal info', 'personal information',
      'compare', 'compare products', 'comparison', 'settings', 'theme',
      'change password', 'suggestion', 'preference', 'about claro',
      'review history'
    };

    final patterns = [
      RegExp(r'^(?:please\s+)?(?:find|search(?:\s+for)?|look\s+for|show|open)\s+(?:me\s+)?(.+?)(?:\s+(?:in|from)\s+(?:my\s+)?history|\s+from\s+last\s+week|\s+from\s+yesterday|\s+product|\s+details)?$', caseSensitive: false),
      RegExp(r'^(?:paki-?)?(?:hanapin|hanap|pahanap|buksan|tingnan|ipakita)\s+(?:po\s+)?(?:ang|yung|ng)?\s*(.+?)(?:\s+sa\s+(?:aking\s+)?history|\s+sa\s+mga\s+na-?scan)?$', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(t);
      if (match != null && match.groupCount >= 1) {
        String query = match.group(1)?.trim() ?? '';
        query = query.replaceAll(RegExp(r'\s+(?:in|from)\s+(?:my\s+)?history.*$', caseSensitive: false), '');
        query = query.replaceAll(RegExp(r'\s+sa\s+(?:aking\s+)?history.*$', caseSensitive: false), '');
        query = query.replaceAll(RegExp(r'\s+(?:from\s+)?(?:last\s+week|yesterday|earlier|kanina).*$', caseSensitive: false), '');
        query = query.replaceAll(RegExp(r'\s+(?:product|details|screen|scan)$', caseSensitive: false), '').trim();

        if (query.isNotEmpty && !excludedPages.contains(query)) {
          return query;
        }
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

    // 1. Search in user's scan history first
    final historyService = HistoryService();
    final historyItems = historyService.getItems(
      filter: 'Lahat',
      searchQuery: query,
    );

    Product? matchedProduct;

    if (historyItems.isNotEmpty) {
      for (final item in historyItems) {
        final pId = item.productId;
        if (pId != null && pId.isNotEmpty) {
          try {
            matchedProduct = await BackendLocator.productRepository.getProductById(pId);
            if (matchedProduct != null) break;
          } catch (e) {
            debugPrint('Voice search: failed to fetch product by id: $e');
          }
        }
      }
    }

    // 2. Fallback: Search all products in catalog
    if (matchedProduct == null) {
      try {
        final allProducts = await BackendLocator.productRepository.getAllProducts();
        final matches = allProducts.where((p) {
          final pName = p.name.toLowerCase();
          final pBrand = p.brand.toLowerCase();
          return pName.contains(normalizedQuery) ||
              normalizedQuery.contains(pName) ||
              '$pBrand $pName'.toLowerCase().contains(normalizedQuery);
        }).toList();

        if (matches.isNotEmpty) {
          matchedProduct = matches.first;
        }
      } catch (e) {
        debugPrint('Voice search: failed to search all products: $e');
      }
    }

    if (!context.mounted) return true;

    if (matchedProduct != null) {
      VoiceAssistantService.setLatestScanProduct(matchedProduct);

      final reply = isTagalog
          ? 'Nahanap ko ang ${matchedProduct.name} sa iyong history. Binubuksan ang mga detalye ng produkto.'
          : 'Found ${matchedProduct.name} from your history. Opening product details.';

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
            product: matchedProduct!,
          ),
        ),
      );

      await VoiceAssistantService.instance.speak(reply);
      return true;
    } else {
      final notFoundReply = isTagalog
          ? 'Hindi ko mahanap ang "$query" sa iyong history.'
          : 'I could not find "$query" in your history.';
      await VoiceAssistantService.instance.speak(notFoundReply);
      return true;
    }
  }
}
