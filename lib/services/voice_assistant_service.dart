import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'auth_service.dart';
import 'locale_service.dart';
import '../models/product_model.dart';

enum VoiceLang { english, tagalog }

enum VoiceListenStatus {
  recognized,
  noSpeech,
  couldNotUnderstand,
  unavailable,
  permissionDenied,
  alreadyListening,
}

class VoiceListenResult {
  final VoiceListenStatus status;
  final String? transcript;

  const VoiceListenResult(this.status, {this.transcript});
}

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
  Future<bool>? _speechInitialization;
  bool _listenSessionActive = false;
  void Function(String?)? _completeCurrentListen;
  Completer<void>? _activeSpeechCompletion;

  static final NavigatorObserver navigatorObserver = _VoiceNavigatorObserver();

  /// ValueNotifier for voice assistant enabled state
  static final ValueNotifier<bool> isEnabledNotifier = ValueNotifier<bool>(
    false,
  );

  static final ValueNotifier<bool> isListeningNotifier = ValueNotifier<bool>(
    false,
  );
  static final ValueNotifier<bool> isSpeakingNotifier = ValueNotifier<bool>(
    false,
  );
  static final ValueNotifier<String> liveTranscriptNotifier =
      ValueNotifier<String>('');
  static final ValueNotifier<VoiceLang> languageNotifier =
      ValueNotifier<VoiceLang>(VoiceLang.english);
  static final ValueNotifier<double> speechRateNotifier = ValueNotifier<double>(
    0.5,
  );
  static final ValueNotifier<Product?> latestScanProductNotifier =
      ValueNotifier<Product?>(null);
  static final ValueNotifier<String?> latestScanSummaryNotifier =
      ValueNotifier<String?>(null);

  /// Stores the currently open product on ProductDetailScreen, or null when closed
  static final ValueNotifier<Product?> activeResultProductNotifier =
      ValueNotifier<Product?>(null);

  @visibleForTesting
  static Future<PermissionStatus> Function()? microphonePermissionOverride;

  @visibleForTesting
  static Future<bool> Function()? openAppSettingsOverride;

  static void setLatestScanProduct(Product product) {
    latestScanProductNotifier.value = product;
    latestScanSummaryNotifier.value = null;
  }

  static void setLatestScanSummary(String summary) {
    latestScanSummaryNotifier.value = summary;
  }

  static const Map<String, Map<String, String>> _pageAnnouncements = {
    'home': {
      'en':
          'Hello! This is CLARO, your voice assistant. Tap the mic button anytime you need help.',
      'fil':
          'Kumusta! Ako ang CLARO, ang iyong voice assistant. I-tap ang mic button anumang oras kung kailangan mo ng tulong.',
    },
    'scan': {
      'en':
          'Hold the product in the frame — CLARO will detect it and read the nutrition result.',
      'fil':
          'Ilagay ang produkto sa loob ng frame — ide-detect ito ng CLARO at babasahin ang nutrition result.',
    },
    'history': {
      'en': 'Your past scans are listed here — tap any item to review it.',
      'fil':
          'Ang iyong mga nakaraang scan ay nakalista dito — i-tap ang alinman para suriin.',
    },
    'profile': {
      'en':
          'Your profile is here — edit personal info, preferences, or send feedback.',
      'fil':
          'Nandito ang iyong profile — i-edit ang impormasyon, mga preference, o magpadala ng feedback.',
    },
    'personal_info': {
      'en':
          'Update your name, age, health conditions, and allergens here — save so CLARO gives better advice.',
      'fil':
          'I-update ang pangalan, edad, kondisyon sa kalusugan, at allergens dito — i-save para mas mapabuti ang payo ng CLARO.',
    },
    'preference': {
      'en':
          'Adjust language, speech rate, vibration, notifications, and text size here.',
      'fil':
          'Baguhin ang wika, bilis ng pananalita, vibration, notification, at laki ng teksto dito.',
    },
    'product_detail': {
      'en':
          'Health advice and ingredient warnings are listed — tap Compare to see alternatives.',
      'fil':
          'Nakalista ang health advice at ingredient warnings — i-tap ang Compare para makita ang mga alternatibo.',
    },
    'compare_products': {
      'en':
          'Ranked alternatives are listed here — tap one to see its nutrition details.',
      'fil':
          'Ang mga alternatibong naka-rank ay nakalista dito — i-tap ang isa para makita ang nutrition details.',
    },
    'multi_scan_results': {
      'en': 'Ranked products from your scan are here — tap one to learn more.',
      'fil':
          'Ang mga naka-rank na produkto mula sa iyong scan ay nandito — i-tap ang isa para malaman pa.',
    },
    'product_not_found': {
      'en':
          'Product could not be identified — scan again or report it for review.',
      'fil':
          'Hindi natukoy ang produkto — mag-scan muli o i-report para suriin.',
    },
    'unknown_product_submission': {
      'en':
          'Submit the unknown product with front and back photos so CLARO can learn it.',
      'fil':
          'Isumite ang hindi kilalang produkto kasama ang front at back photo para matutuhan ito ng CLARO.',
    },
    'suggestion': {
      'en':
          'Rate your experience and write a suggestion to help improve CLARO.',
      'fil':
          'I-rate ang iyong karanasan at magsulat ng suhestiyon para mapabuti ang CLARO.',
    },
    'review_history': {
      'en':
          'Your submitted feedback is here — check status and read replies from the team.',
      'fil':
          'Ang iyong mga isinubmit na feedback ay nandito — suriin ang status at basahin ang mga reply.',
    },
    'about_claro': {
      'en': 'Learn what CLARO does and who built the app.',
      'fil': 'Alamin kung ano ang ginagawa ng CLARO at sino ang gumawa ng app.',
    },
    'change_password': {
      'en':
          'Enter your current and new password to update your account security.',
      'fil':
          'Ilagay ang kasalukuyang at bagong password para i-update ang seguridad ng account.',
    },
    'theme': {
      'en': 'Choose default or dark mode to change the app look.',
      'fil': 'Pumili ng default o dark mode para baguhin ang itsura ng app.',
    },
    'report_detail': {
      'en':
          'Your submitted report is here — check its status and review the product images.',
      'fil':
          'Ang iyong isinubmit na report ay nandito — suriin ang status at ang mga larawan ng produkto.',
    },
    'more_details': {
      'en': 'Ingredients, allergen warnings, and storage tips are listed here.',
      'fil':
          'Nakalista dito ang ingredients, allergen warnings, at storage tips.',
    },
    'favorites': {
      'en': 'Your saved products are here — tap one to view its details.',
      'fil':
          'Ang iyong mga na-save na produkto ay nandito — i-tap ang isa para makita ang detalye.',
    },
    'compare': {
      'en':
          'Products you queued for comparison are listed here — tap one to compare.',
      'fil':
          'Ang mga produktong naka-pila para sa paghahambing ay nakalista dito — i-tap ang isa para ikumpara.',
    },
    'reports': {
      'en': 'Your submitted reports are here — check their review status.',
      'fil':
          'Ang iyong mga isinubmit na ulat ay nandito — suriin ang kanilang review status.',
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

      final appDefaultLang =
          LocaleService.localeNotifier.value.languageCode == 'tl'
          ? VoiceLang.tagalog
          : VoiceLang.english;

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        isEnabledNotifier.value = data['voiceAssistant'] ?? false;
        languageNotifier.value = VoiceLang.values.firstWhere(
          (lang) => lang.name == (data['voiceLanguage'] as String? ?? ''),
          orElse: () => appDefaultLang,
        );
        speechRateNotifier.value =
            (data['voiceRate'] as num?)?.toDouble() ?? 0.5;
      } else {
        isEnabledNotifier.value = false;
        languageNotifier.value = appDefaultLang;
        speechRateNotifier.value = 0.5;
      }
    } catch (e) {
      debugPrint('Error initializing voice assistant: $e');
      final fallbackLang =
          LocaleService.localeNotifier.value.languageCode == 'tl'
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
      final configuredLanguage = await _configureLanguage(
        languageNotifier.value,
      );
      languageNotifier.value = configuredLanguage;
      await _flutterTts.setSpeechRate(speechRateNotifier.value);
      await _flutterTts.awaitSpeakCompletion(true);
      _flutterTts.setCompletionHandler(_completeActiveSpeech);
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
        await _instance._authService.updateUserData({
          'voiceAssistant': enabled,
        });
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
        await _instance._authService.updateUserData({
          'voiceLanguage': selectedLanguage.storageValue,
        });
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
      _completeActiveSpeech();
      _activeSpeechCompletion = Completer<void>();
      isSpeakingNotifier.value = true;
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Error speaking text: $e');
    } finally {
      _completeActiveSpeech();
    }
  }

  void _completeActiveSpeech() {
    isSpeakingNotifier.value = false;
    final completion = _activeSpeechCompletion;
    if (completion != null && !completion.isCompleted) {
      completion.complete();
    }
    _activeSpeechCompletion = null;
  }

  Future<void> stopAudio({bool stopListening = true}) async {
    try {
      await _flutterTts.stop();
      _completeActiveSpeech();
      if (stopListening && _listenSessionActive) {
        await _speechToText.stop();
      }
    } catch (e) {
      debugPrint('Voice audio stop error: $e');
    } finally {
      isSpeakingNotifier.value = false;
      if (stopListening) {
        isListeningNotifier.value = false;
      }
    }
  }

  Future<VoiceListenResult> listenOnce() async {
    if (_listenSessionActive) {
      return const VoiceListenResult(VoiceListenStatus.alreadyListening);
    }

    try {
      final requestPermission = microphonePermissionOverride;
      final permission = await (requestPermission == null
          ? Permission.microphone.request()
          : requestPermission());
      if (!permission.isGranted) {
        await _openSettings();
        return const VoiceListenResult(VoiceListenStatus.permissionDenied);
      }

      if (!await _speechToText.hasPermission) {
        await _openSettings();
        return const VoiceListenResult(VoiceListenStatus.permissionDenied);
      }

      final activeSpeech = _activeSpeechCompletion;
      if (isSpeakingNotifier.value && activeSpeech != null) {
        try {
          await activeSpeech.future.timeout(
            const Duration(seconds: 20),
            onTimeout: () {},
          );
        } catch (_) {}
      }
      await _flutterTts.stop();
      _completeActiveSpeech();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      final available = await (_speechInitialization ??= _initializeSpeech());
      if (!available) {
        return const VoiceListenResult(VoiceListenStatus.unavailable);
      }

      final locale = await _recognitionLocale();
      _listenSessionActive = true;
      isListeningNotifier.value = true;
      liveTranscriptNotifier.value = '';

      var result = await _captureSpeechAttempt(locale);
      if (result.status == VoiceListenStatus.noSpeech) {
        liveTranscriptNotifier.value = '';
        await Future<void>.delayed(const Duration(milliseconds: 250));
        result = await _captureSpeechAttempt(locale);
      }
      return result;
    } catch (e) {
      debugPrint('Speech recognition failure: $e');
      return const VoiceListenResult(VoiceListenStatus.unavailable);
    } finally {
      _completeCurrentListen = null;
      _listenSessionActive = false;
      isListeningNotifier.value = false;
      liveTranscriptNotifier.value = '';
    }
  }

  Future<bool> _initializeSpeech() => _speechToText.initialize(
    onError: (error) {
      if (kDebugMode) debugPrint('Speech recognition error: ${error.errorMsg}');
      _completeCurrentListen?.call(error.errorMsg);
    },
    onStatus: (status) {
      if (kDebugMode) debugPrint('Speech recognition status: $status');
      if (status == 'notListening' || status == 'done') {
        _completeCurrentListen?.call(null);
      }
    },
  );

  Future<void> _openSettings() async {
    final openSettings = openAppSettingsOverride;
    if (openSettings == null) {
      await openAppSettings();
    } else {
      await openSettings();
    }
  }

  Future<String> _recognitionLocale() async {
    try {
      final locales = await _speechToText.locales();
      final normalized = locales.map((locale) {
        return MapEntry(
          locale.localeId,
          locale.localeId.toLowerCase().replaceAll('-', '_'),
        );
      }).toList();
      final preferredLanguage = languageNotifier.value == VoiceLang.tagalog
          ? 'fil'
          : 'en';
      final preferences = preferredLanguage == 'fil'
          ? ['fil_ph', 'fil', 'tl_ph', 'tl']
          : ['en_us', 'en_ph', 'en_gb', 'en'];
      for (final preferred in preferences) {
        for (final locale in normalized) {
          if (locale.value == preferred ||
              (preferred == 'fil' && locale.value.startsWith('fil_')) ||
              (preferred == 'tl' && locale.value.startsWith('tl_')) ||
              (preferred == 'en' && locale.value.startsWith('en_'))) {
            return locale.key;
          }
        }
      }
      final systemLocale = await _speechToText.systemLocale();
      if (systemLocale != null) return systemLocale.localeId;
    } catch (e) {
      if (kDebugMode) debugPrint('Speech locale lookup failed: $e');
    }
    return WidgetsBinding.instance.platformDispatcher.locale
        .toLanguageTag()
        .replaceAll('-', '_');
  }

  Future<VoiceListenResult> _captureSpeechAttempt(String locale) async {
    final completer = Completer<VoiceListenResult>();
    var latestPartial = '';
    var finalText = '';
    Timer? silenceDebounce;

    void complete([String? errorCode]) {
      silenceDebounce?.cancel();
      if (completer.isCompleted) return;
      final transcript = resolveRecognizedText(latestPartial, finalText);
      if (transcript.isNotEmpty) {
        completer.complete(
          VoiceListenResult(
            VoiceListenStatus.recognized,
            transcript: transcript,
          ),
        );
      } else if (errorCode == 'error_no_match') {
        completer.complete(
          const VoiceListenResult(VoiceListenStatus.couldNotUnderstand),
        );
      } else if (errorCode == null || errorCode == 'error_speech_timeout') {
        completer.complete(const VoiceListenResult(VoiceListenStatus.noSpeech));
      } else {
        completer.complete(
          const VoiceListenResult(VoiceListenStatus.unavailable),
        );
      }
    }

    _completeCurrentListen = complete;
    try {
      await _speechToText.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) {
            if (result.finalResult) {
              finalText = words;
            } else {
              latestPartial = words;
            }
            liveTranscriptNotifier.value = words;
          }
          if (kDebugMode) {
            debugPrint(
              'Speech recognition result: "$words" (final=${result.finalResult})',
            );
          }
          if (result.finalResult) {
            complete();
          } else if (latestPartial.isNotEmpty) {
            silenceDebounce?.cancel();
            silenceDebounce = Timer(
              const Duration(milliseconds: 1500),
              complete,
            );
          }
        },
        onSoundLevelChange: (level) {
          if (kDebugMode) debugPrint('Speech input level: $level');
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
          localeId: locale,
        ),
      );

      final result = await completer.future.timeout(
        const Duration(seconds: 35),
        onTimeout: () {
          complete();
          return VoiceListenResult(
            latestPartial.isEmpty && finalText.isEmpty
                ? VoiceListenStatus.noSpeech
                : VoiceListenStatus.recognized,
            transcript: resolveRecognizedText(latestPartial, finalText),
          );
        },
      );
      await _speechToText.stop();
      return result;
    } finally {
      silenceDebounce?.cancel();
      _completeCurrentListen = null;
    }
  }

  @visibleForTesting
  static String resolveRecognizedText(String partialText, String finalText) {
    final finalTrimmed = finalText.trim();
    return finalTrimmed.isNotEmpty ? finalTrimmed : partialText.trim();
  }

  static String messageForListenStatus(
    VoiceListenStatus status,
    VoiceLang language,
  ) {
    final isTagalog = language == VoiceLang.tagalog;
    return switch (status) {
      VoiceListenStatus.permissionDenied =>
        isTagalog
            ? 'Kailangan ng pahintulot sa mikropono para gumamit ng voice assistant. I-enable ito sa settings ng app.'
            : 'Microphone permission is needed to use voice commands. Please enable it in app settings.',
      VoiceListenStatus.unavailable =>
        isTagalog
            ? 'Hindi available ang speech recognition sa device na ito.'
            : 'Speech recognition is unavailable on this device.',
      VoiceListenStatus.couldNotUnderstand =>
        isTagalog
            ? 'Hindi ko naintindihan ang sinabi mo. Pakisubukan muli.'
            : 'I could not understand that. Please try again.',
      VoiceListenStatus.noSpeech =>
        isTagalog
            ? 'Wala akong narinig. Subukan muli at magsalita pagkatapos i-tap ang mikropono.'
            : "I didn't hear anything. Please try again and speak after tapping the microphone.",
      VoiceListenStatus.alreadyListening =>
        isTagalog
            ? 'Nakikinig na ako. Sandali lang.'
            : "I'm already listening. One moment.",
      VoiceListenStatus.recognized => '',
    };
  }

  Future<void> announcePage(String pageKey) async {
    final pageMap = _pageAnnouncements[pageKey];
    if (pageMap == null) return;
    final text =
        pageMap[languageNotifier.value == VoiceLang.tagalog ? 'fil' : 'en'] ??
        '';
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
  Future<void> announcePageWithPreamble(String preamble, String pageKey) async {
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
    VoiceAssistantService.instance.stopAudio(stopListening: false);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    VoiceAssistantService.instance.stopAudio(stopListening: false);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    VoiceAssistantService.instance.stopAudio(stopListening: false);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
