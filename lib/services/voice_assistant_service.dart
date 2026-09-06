import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'auth_service.dart';
import 'locale_service.dart';
import '../models/product_model.dart';

enum VoiceLang { english, tagalog }

extension VoiceLangExtension on VoiceLang {
  String get storageValue => name;

  String get ttsLanguageCode {
    switch (this) {
      case VoiceLang.english:
        return 'en-US';
      case VoiceLang.tagalog:
        return 'fil-PH';
    }
  }
}

class VoiceAssistantService {
  VoiceAssistantService._();
  static final VoiceAssistantService _instance = VoiceAssistantService._();
  static VoiceAssistantService get instance => _instance;

  final _authService = AuthService();
  final FlutterTts _flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();

  static final NavigatorObserver navigatorObserver = _VoiceNavigatorObserver();

  /// ValueNotifier for voice assistant enabled state
  static final ValueNotifier<bool> isEnabledNotifier = ValueNotifier<bool>(false);

  static final ValueNotifier<bool> isListeningNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<VoiceLang> languageNotifier = ValueNotifier<VoiceLang>(VoiceLang.english);
  static final ValueNotifier<double> speechRateNotifier = ValueNotifier<double>(0.5);
  static final ValueNotifier<Product?> latestScanProductNotifier = ValueNotifier<Product?>(null);
  static final ValueNotifier<String?> latestScanSummaryNotifier = ValueNotifier<String?>(null);

  /// Stores the currently open product on ProductDetailScreen, or null when closed
  static final ValueNotifier<Product?> activeResultProductNotifier = ValueNotifier<Product?>(null);

  static void setLatestScanProduct(Product product) {
    latestScanProductNotifier.value = product;
    latestScanSummaryNotifier.value = null;
  }

  static void setLatestScanSummary(String summary) {
    latestScanSummaryNotifier.value = summary;
  }

  static const Map<String, Map<String, String>> _pageAnnouncements = {
    'home': {
      'en': 'Hello! This is CLARO, your voice assistant. Tap the mic button anytime you need help.',
      'fil': 'Kumusta! Ako ang CLARO, ang iyong voice assistant. I-tap ang mic button anumang oras kung kailangan mo ng tulong.',
    },
    'scan': {
      'en': 'Hold the product in the frame — CLARO will detect it and read the nutrition result.',
      'fil': 'Ilagay ang produkto sa loob ng frame — ide-detect ito ng CLARO at babasahin ang nutrition result.',
    },
    'history': {
      'en': 'Your past scans are listed here — tap any item to review it.',
      'fil': 'Ang iyong mga nakaraang scan ay nakalista dito — i-tap ang alinman para suriin.',
    },
    'profile': {
      'en': 'Your profile is here — edit personal info, preferences, or send feedback.',
      'fil': 'Nandito ang iyong profile — i-edit ang impormasyon, mga preference, o magpadala ng feedback.',
    },
    'personal_info': {
      'en': 'Update your name, age, health conditions, and allergens here — save so CLARO gives better advice.',
      'fil': 'I-update ang pangalan, edad, kondisyon sa kalusugan, at allergens dito — i-save para mas mapabuti ang payo ng CLARO.',
    },
    'preference': {
      'en': 'Adjust language, speech rate, vibration, notifications, and text size here.',
      'fil': 'Baguhin ang wika, bilis ng pananalita, vibration, notification, at laki ng teksto dito.',
    },
    'product_detail': {
      'en': 'Health advice and ingredient warnings are listed — tap Compare to see alternatives.',
      'fil': 'Nakalista ang health advice at ingredient warnings — i-tap ang Compare para makita ang mga alternatibo.',
    },
    'compare_products': {
      'en': 'Ranked alternatives are listed here — tap one to see its nutrition details.',
      'fil': 'Ang mga alternatibong naka-rank ay nakalista dito — i-tap ang isa para makita ang nutrition details.',
    },
    'multi_scan_results': {
      'en': 'Ranked products from your scan are here — tap one to learn more.',
      'fil': 'Ang mga naka-rank na produkto mula sa iyong scan ay nandito — i-tap ang isa para malaman pa.',
    },
    'product_not_found': {
      'en': 'Product could not be identified — scan again or report it for review.',
      'fil': 'Hindi natukoy ang produkto — mag-scan muli o i-report para suriin.',
    },
    'unknown_product_submission': {
      'en': 'Submit the unknown product with front and back photos so CLARO can learn it.',
      'fil': 'Isumite ang hindi kilalang produkto kasama ang front at back photo para matutuhan ito ng CLARO.',
    },
    'suggestion': {
      'en': 'Rate your experience and write a suggestion to help improve CLARO.',
      'fil': 'I-rate ang iyong karanasan at magsulat ng suhestiyon para mapabuti ang CLARO.',
    },
    'review_history': {
      'en': 'Your submitted feedback is here — check status and read replies from the team.',
      'fil': 'Ang iyong mga isinubmit na feedback ay nandito — suriin ang status at basahin ang mga reply.',
    },
    'about_claro': {
      'en': 'Learn what CLARO does and who built the app.',
      'fil': 'Alamin kung ano ang ginagawa ng CLARO at sino ang gumawa ng app.',
    },
    'change_password': {
      'en': 'Enter your current and new password to update your account security.',
      'fil': 'Ilagay ang kasalukuyang at bagong password para i-update ang seguridad ng account.',
    },
    'theme': {
      'en': 'Choose default or dark mode to change the app look.',
      'fil': 'Pumili ng default o dark mode para baguhin ang itsura ng app.',
    },
    'report_detail': {
      'en': 'Your submitted report is here — check its status and review the product images.',
      'fil': 'Ang iyong isinubmit na report ay nandito — suriin ang status at ang mga larawan ng produkto.',
    },
    'more_details': {
      'en': 'Ingredients, allergen warnings, and storage tips are listed here.',
      'fil': 'Nakalista dito ang ingredients, allergen warnings, at storage tips.',
    },
    'favorites': {
      'en': 'Your saved products are here — tap one to view its details.',
      'fil': 'Ang iyong mga na-save na produkto ay nandito — i-tap ang isa para makita ang detalye.',
    },
    'compare': {
      'en': 'Products you queued for comparison are listed here — tap one to compare.',
      'fil': 'Ang mga produktong naka-pila para sa paghahambing ay nakalista dito — i-tap ang isa para ikumpara.',
    },
    'reports': {
      'en': 'Your submitted reports are here — check their review status.',
      'fil': 'Ang iyong mga isinubmit na ulat ay nandito — suriin ang kanilang review status.',
    },
  };

  /// Initialize the service by loading the user's preference from Firestore
  static Future<void> initialize() async {
    try {
      final user = _instance._authService.currentUser;
      if (user == null) {
        isEnabledNotifier.value = false;
        languageNotifier.value = VoiceLang.english;
        speechRateNotifier.value = 0.5;
        await _instance._instanceConfigureTts();
        return;
      }

      final doc = await _instance._authService.db
          .collection('users')
          .doc(user.uid)
          .get();

      final appDefaultLang = LocaleService.localeNotifier.value.languageCode == 'tl'
          ? VoiceLang.tagalog
          : VoiceLang.english;

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        isEnabledNotifier.value = data['voiceAssistant'] ?? false;
        languageNotifier.value = VoiceLang.values.firstWhere(
          (lang) => lang.name == (data['voiceLanguage'] as String? ?? ''),
          orElse: () => appDefaultLang,
        );
        speechRateNotifier.value = (data['voiceRate'] as num?)?.toDouble() ?? 0.5;
      } else {
        isEnabledNotifier.value = false;
        languageNotifier.value = appDefaultLang;
        speechRateNotifier.value = 0.5;
      }
    } catch (e) {
      debugPrint('Error initializing voice assistant: $e');
      final fallbackLang = LocaleService.localeNotifier.value.languageCode == 'tl'
          ? VoiceLang.tagalog
          : VoiceLang.english;
      isEnabledNotifier.value = false;
      languageNotifier.value = fallbackLang;
      speechRateNotifier.value = 0.5;
    }

    await _instance._instanceConfigureTts();
  }

  Future<void> _instanceConfigureTts() async {
    try {
      final configuredLanguage = await _configureLanguage(languageNotifier.value);
      languageNotifier.value = configuredLanguage;
      await _flutterTts.setSpeechRate(speechRateNotifier.value);
      _flutterTts.setCompletionHandler(() {
        isSpeakingNotifier.value = false;
      });
      _flutterTts.setErrorHandler((message) {
        isSpeakingNotifier.value = false;
        debugPrint('FlutterTts error: $message');
      });
    } catch (e) {
      debugPrint('Error configuring FlutterTts: $e');
    }
  }

  /// Update the voice assistant state for the current user
  Future<void> updateEnabled(bool enabled) async {
    try {
      isEnabledNotifier.value = enabled;
      if (!enabled) {
        await stopAudio();
      }

      final user = _instance._authService.currentUser;
      if (user != null) {
        await _instance._authService.updateUserData({'voiceAssistant': enabled});
      }
    } catch (e) {
      debugPrint('Error updating voice assistant state: $e');
    }
  }

  Future<void> updateLanguage(VoiceLang lang) async {
    try {
      final selectedLanguage = await _configureLanguage(lang);
      languageNotifier.value = selectedLanguage;

      final user = _instance._authService.currentUser;
      if (user != null) {
        await _instance._authService.updateUserData({'voiceLanguage': selectedLanguage.storageValue});
      }
    } catch (e) {
      debugPrint('Error updating voice assistant language: $e');
    }
  }

  Future<VoiceLang> _configureLanguage(VoiceLang requestedLanguage) async {
    try {
      if (requestedLanguage == VoiceLang.tagalog) {
        // On Android, 0 = LANG_AVAILABLE, 1 = LANG_COUNTRY_AVAILABLE, 2 = LANG_COUNTRY_VAR_AVAILABLE.
        // On iOS/macOS, isLanguageAvailable returns a bool.
        final dynamic avail = await _flutterTts.isLanguageAvailable('fil-PH');
        final bool isAvailable = avail == true || (avail is int && avail >= 0);
        if (isAvailable) {
          await _flutterTts.setLanguage('fil-PH');
        } else {
          final dynamic availFil = await _flutterTts.isLanguageAvailable('fil');
          if (availFil == true || (availFil is int && availFil >= 0)) {
            await _flutterTts.setLanguage('fil');
          } else {
            await _flutterTts.setLanguage('fil-PH');
          }
        }
        return VoiceLang.tagalog;
      } else {
        await _flutterTts.setLanguage(requestedLanguage.ttsLanguageCode);
        return requestedLanguage;
      }
    } catch (e) {
      debugPrint('Error configuring TTS language: $e');
      return requestedLanguage;
    }
  }

  Future<void> updateSpeechRate(double rate) async {
    try {
      speechRateNotifier.value = rate;
      await _flutterTts.setSpeechRate(rate);

      final user = _instance._authService.currentUser;
      if (user != null) {
        await _instance._authService.updateUserData({'voiceRate': rate});
      }
    } catch (e) {
      debugPrint('Error updating voice assistant speech rate: $e');
    }
  }

  Future<void> speak(String text) async {
    if (!isEnabled || text.isEmpty) {
      return;
    }

    try {
      await _flutterTts.stop();
      isSpeakingNotifier.value = true;
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Error speaking text: $e');
      isSpeakingNotifier.value = false;
    }
  }

  Future<void> stopAudio() async {
    try {
      await _flutterTts.stop();
      await _speechToText.stop();
    } catch (e) {
      debugPrint('Voice audio stop error: $e');
    } finally {
      isSpeakingNotifier.value = false;
      isListeningNotifier.value = false;
    }
  }

  Future<String?> listenOnce() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('Speech recognition: microphone permission denied.');
      return null;
    }

    try {
      await _flutterTts.stop();
      isListeningNotifier.value = true;

      final completer = Completer<String?>();
      String recognizedText = '';
      Timer? silenceDebounce;

      void completeWithText() {
        silenceDebounce?.cancel();
        if (!completer.isCompleted) {
          final trimmed = recognizedText.trim();
          completer.complete(trimmed.isNotEmpty ? trimmed : null);
        }
      }

      final available = await _speechToText.initialize(
        onError: (error) {
          debugPrint('Speech recognition error: $error');
          completeWithText();
        },
        onStatus: (status) {
          debugPrint('Speech recognition status: $status');
          if (status == 'notListening' || status == 'done') {
            completeWithText();
          }
        },
      );
      if (!available) {
        debugPrint('Speech recognition: engine unavailable.');
        return null;
      }

      final locale = languageNotifier.value.ttsLanguageCode;

      await _speechToText.listen(
        onResult: (result) {
          recognizedText = result.recognizedWords;
          debugPrint(
            'Speech recognition result: "$recognizedText" '
            '(final=${result.finalResult})',
          );
          if (result.finalResult) {
            completeWithText();
          } else if (recognizedText.trim().isNotEmpty) {
            // Reset speech debounce: if no new words arrive within 1.5s, finish gracefully
            silenceDebounce?.cancel();
            silenceDebounce = Timer(const Duration(milliseconds: 1500), () {
              completeWithText();
            });
          }
        },
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 3),
        localeId: locale,
        partialResults: true,
        listenMode: ListenMode.dictation,
      );

      final transcript = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          completeWithText();
          return recognizedText.trim().isEmpty ? null : recognizedText.trim();
        },
      );

      silenceDebounce?.cancel();
      await _speechToText.stop();
      return transcript;
    } catch (e) {
      debugPrint('Speech recognition failure: $e');
      return null;
    } finally {
      isListeningNotifier.value = false;
    }
  }

  Future<void> announcePage(String pageKey) async {
    final pageMap = _pageAnnouncements[pageKey];
    if (pageMap == null) return;
    final text = pageMap[languageNotifier.value == VoiceLang.tagalog ? 'fil' : 'en'] ?? '';
    if (text.isEmpty) return;

    // Small delay ensures route push animation and observer didPush() stopAudio()
    // calls complete before the announcement begins speaking.
    await Future.delayed(const Duration(milliseconds: 350));
    await speak(text);
  }

  /// Speaks [preamble] (e.g. "Opening history.") immediately followed by the
  /// full page description for [pageKey] as a single uninterrupted utterance.
  /// Because [speak] calls _flutterTts.stop() internally, concatenating both
  /// into one call is the only way to guarantee they don't cut each other off.
  Future<void> announcePageWithPreamble(
    String preamble,
    String pageKey,
  ) async {
    final pageMap = _pageAnnouncements[pageKey];
    if (pageMap == null) return;
    final lang = languageNotifier.value == VoiceLang.tagalog ? 'fil' : 'en';
    final pageText = pageMap[lang] ?? '';
    if (pageText.isEmpty) return;

    await Future.delayed(const Duration(milliseconds: 350));
    final fullText = preamble.isNotEmpty ? '$preamble $pageText' : pageText;
    await speak(fullText);
  }

  bool get isEnabled => isEnabledNotifier.value;
}

class _VoiceNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    VoiceAssistantService.instance.stopAudio();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    VoiceAssistantService.instance.stopAudio();
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    VoiceAssistantService.instance.stopAudio();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
