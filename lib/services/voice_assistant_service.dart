import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'auth_service.dart';
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
      'en': 'This is the scanning screen. Hold the product inside the guide until CLARO detects it and reads the nutrition result.',
      'fil': 'Ito ang scanning screen. Hawakan ang produkto sa loob ng gabay hanggang ma-detect ng CLARO at mabasa ang nutrition result.',
    },
    'history': {
      'en': 'This is your history screen. Tap a product to reopen a previous scan or a report to hear its status.',
      'fil': 'Ito ang history screen mo. I-tap ang produkto para buksan muli ang nakaraang scan o ulat para marinig ang status nito.',
    },
    'profile': {
      'en': 'This is your profile screen. Use the buttons here to edit personal info, preferences, or send feedback.',
      'fil': 'Ito ang profile screen mo. Gamitin ang mga button dito para i-edit ang personal na impormasyon, mga preference, o magpadala ng feedback.',
    },
    'personal_info': {
      'en': 'This screen lets you update your name, age, health conditions, and allergens. Save changes so CLARO can give better advice.',
      'fil': 'Sa screen na ito, maaari mong i-update ang pangalan, edad, kondisyon sa kalusugan, at allergens. I-save ang mga pagbabago para mas mabuting makapagbigay ng payo ang CLARO.',
    },
    'preference': {
      'en': 'This is the preferences screen. Change language, speech rate, vibration, notifications, and text size here.',
      'fil': 'Ito ang preference screen. Baguhin ang wika, bilis ng pananalita, vibration, notification, at laki ng teksto dito.',
    },
    'product_detail': {
      'en': 'This is the product detail screen. Listen for health advice, ingredient warnings, and compare this product with alternatives.',
      'fil': 'Ito ang product detail screen. Makinig sa health advice, ingredient warnings, at ikumpara ang produktong ito sa ibang mga pilihan.',
    },
    'compare_products': {
      'en': 'This is the product comparison screen. Browse ranked alternatives and tap one to see its detailed nutrition advice.',
      'fil': 'Ito ang product comparison screen. Tingnan ang mga alternatibong naka-rank at i-tap ang isa para makita ang detalye ng nutrition nito.',
    },
    'multi_scan_results': {
      'en': 'This is the multi-scan results screen. Review the ranked products found in your scan and choose one to learn more.',
      'fil': 'Ito ang multi-scan results screen. Suriin ang mga naka-rank na produkto mula sa iyong scan at piliin ang isa para malaman pa.',
    },
    'product_not_found': {
      'en': 'This screen says the product could not be identified. You can scan again or report the product for review.',
      'fil': 'Sinasabi ng screen na ito na hindi natukoy ang produkto. Puwede kang mag-scan muli o i-report ang produkto para suriin.',
    },
    'unknown_product_submission': {
      'en': 'This report screen lets you submit the unknown product with a front and back photo so CLARO can learn it later.',
      'fil': 'Sa screen na ito, isumite ang hindi kilalang produkto kasama ang front at back photo para matutuhan ito ng CLARO.',
    },
    'suggestion': {
      'en': 'This is the feedback screen. Rate your experience and write a suggestion to help improve CLARO.',
      'fil': 'Ito ang feedback screen. I-rate ang iyong karanasan at magsulat ng suhestiyon para mapabuti ang CLARO.',
    },
    'review_history': {
      'en': 'This is your review history screen. Check the status of feedback you submitted and read replies from the team.',
      'fil': 'Ito ang review history screen mo. Suriin ang status ng feedback na isinubmit mo at basahin ang mga reply mula sa team.',
    },
    'about_claro': {
      'en': 'This is the About CLARO screen. Hear what CLARO does and who built the app.',
      'fil': 'Ito ang About CLARO screen. Alamin kung ano ang ginagawa ng CLARO at sino ang gumawa ng app.',
    },
    'change_password': {
      'en': 'This is the change password screen. Enter your current password and a new password to update your account security.',
      'fil': 'Ito ang change password screen. Ilagay ang kasalukuyang password at bagong password para i-update ang seguridad ng account.',
    },
    'theme': {
      'en': 'This is the theme screen. Choose between default or dark mode to change the app look.',
      'fil': 'Ito ang theme screen. Pumili ng default o dark mode para baguhin ang itsura ng app.',
    },
    'report_detail': {
      'en': 'This is the report detail screen. Hear the submitted product report status and review the product images.',
      'fil': 'Ito ang report detail screen. Marinig ang status ng isinubmit na product report at suriin ang mga larawan ng produkto.',
    },
    'more_details': {
      'en': 'This is the more details screen. Review ingredients, allergen warnings, and storage tips for the product.',
      'fil': 'Ito ang more details screen. Suriin ang ingredients, allergen warnings, at storage tips para sa produkto.',
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

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        isEnabledNotifier.value = data['voiceAssistant'] ?? false;
        languageNotifier.value = VoiceLang.values.firstWhere(
          (lang) => lang.name == (data['voiceLanguage'] as String? ?? ''),
          orElse: () => VoiceLang.english,
        );
        speechRateNotifier.value = (data['voiceRate'] as num?)?.toDouble() ?? 0.5;
      } else {
        isEnabledNotifier.value = false;
        languageNotifier.value = VoiceLang.english;
        speechRateNotifier.value = 0.5;
      }
    } catch (e) {
      debugPrint('Error initializing voice assistant: $e');
      isEnabledNotifier.value = false;
      languageNotifier.value = VoiceLang.english;
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
    if (requestedLanguage == VoiceLang.tagalog) {
      final availability = await _flutterTts.isLanguageAvailable(
        requestedLanguage.ttsLanguageCode,
      );
      if (availability != true && availability != 1) {
        debugPrint('Tagalog TTS is unavailable; falling back to English.');
        await _flutterTts.setLanguage(VoiceLang.english.ttsLanguageCode);
        return VoiceLang.english;
      }
    }

    await _flutterTts.setLanguage(requestedLanguage.ttsLanguageCode);
    return requestedLanguage;
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
      final available = await _speechToText.initialize(
        onError: (error) => debugPrint('Speech recognition error: $error'),
        onStatus: (status) => debugPrint('Speech recognition status: $status'),
      );
      if (!available) {
        debugPrint('Speech recognition: engine unavailable.');
        return null;
      }

      final completer = Completer<String?>();
      String recognizedText = '';

      await _speechToText.listen(
        onResult: (result) {
          recognizedText = result.recognizedWords;
          debugPrint(
            'Speech recognition result: "$recognizedText" '
            '(final=${result.finalResult})',
          );
          if (result.finalResult && !completer.isCompleted) {
            completer.complete(recognizedText);
          }
        },
      );

      final transcript = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          if (!completer.isCompleted) {
            completer.complete(recognizedText);
          }
          return recognizedText.isEmpty ? null : recognizedText;
        },
      );

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
    await speak(text);
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
