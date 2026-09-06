import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../services/locale_service.dart';
import '../services/text_size_service.dart';
import '../services/voice_assistant_service.dart';
import '../widgets/voice_mic_overlay.dart';

class PreferenceScreen extends StatefulWidget {
  const PreferenceScreen({super.key});

  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends State<PreferenceScreen> {
  final _authService = AuthService();

  bool _vibrationFeedback = false;
  bool _notificationsEnabled = true;
  double _textSize = 1.0;

  @override
  void initState() {
    super.initState();
    if (_authService.currentUser != null) {
      VoiceAssistantService.instance.announcePage('preference');
    }
    _loadPrefs();
    LocaleService.localeNotifier.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    LocaleService.localeNotifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        final doc = await _authService.db.collection('users').doc(uid).get(GetOptions(source: Source.server));
        final data = doc.data();
        if (data != null) {
          setState(() {
            _vibrationFeedback = data['vibrationFeedback'] ?? HapticService().isEnabled;
            _notificationsEnabled = data['notificationsEnabled'] ?? true;
            _textSize = (data['textSize'] != null) ? (data['textSize'] as num).toDouble() : 1.0;
          });
          HapticService().isEnabled = _vibrationFeedback;
        }
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  Future<bool> _savePref(String key, dynamic value) async {
    try {
      if (key == 'vibrationFeedback') {
        HapticService().isEnabled = value as bool;
      }
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        final ok = await _authService.updateUserData({key: value});
        if (!ok) return false;

        try {
          final doc = await _authService.db.collection('users').doc(uid).get(GetOptions(source: Source.server));
          final data = doc.data();
          if (data != null) {
            setState(() {
              _vibrationFeedback = data['vibrationFeedback'] ?? _vibrationFeedback;
              _notificationsEnabled = data['notificationsEnabled'] ?? _notificationsEnabled;
              _textSize = (data['textSize'] != null) ? (data['textSize'] as num).toDouble() : _textSize;
            });
          }
        } catch (_) {}
        return true;
      }
    } catch (e) {
      debugPrint('Error saving pref: $e');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.primary),
        title: Text(loc.preferenceTitle, style: TextStyle(color: theme.colorScheme.primary)),
      ),
      body: VoiceMicOverlay(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card title now reads "Voice Assistant Settings" (renamed
                  // from "Voice & sound"), so the previously-hardcoded
                  // "Voice assistant settings" sub-label below has been
                  // removed to avoid showing a duplicate heading when Voice
                  // Assistant is enabled.
                  Text(loc.voiceSoundTitle, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<bool>(
                    valueListenable: VoiceAssistantService.isEnabledNotifier,
                    builder: (context, isVoiceEnabled, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isVoiceEnabled) ...[
                            ValueListenableBuilder<double>(
                              valueListenable: VoiceAssistantService.speechRateNotifier,
                              builder: (context, speechRate, _) {
                                return Slider(
                                  value: speechRate.clamp(0.2, 1.0),
                                  min: 0.2,
                                  max: 1.0,
                                  divisions: 8,
                                  label: speechRate.toStringAsFixed(1),
                                  onChanged: (value) {
                                    VoiceAssistantService.speechRateNotifier.value = value;
                                  },
                                  onChangeEnd: (value) async {
                                    HapticService().vibrate();
                                    await VoiceAssistantService.instance.updateSpeechRate(value);
                                    await VoiceAssistantService.instance.speak('Voice speed updated.');
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            ValueListenableBuilder<VoiceLang>(
                              valueListenable: VoiceAssistantService.languageNotifier,
                              builder: (context, language, _) {
                                return SegmentedButton<VoiceLang>(
                                  segments: const [
                                    ButtonSegment<VoiceLang>(
                                      value: VoiceLang.english,
                                      label: Text('English'),
                                    ),
                                    ButtonSegment<VoiceLang>(
                                      value: VoiceLang.tagalog,
                                      label: Text('Tagalog'),
                                    ),
                                  ],
                                  selected: {language},
                                  onSelectionChanged: (selection) async {
                                    final selectedLanguage = selection.first;
                                    if (selectedLanguage == language) return;
                                    HapticService().vibrate();
                                    await VoiceAssistantService.instance.updateLanguage(selectedLanguage);

                                    // Mirror the app locale 1:1 with the selected voice language
                                    final targetLocaleCode = selectedLanguage == VoiceLang.tagalog ? 'tl' : 'en';
                                    if (LocaleService.localeNotifier.value.languageCode != targetLocaleCode) {
                                      await LocaleService.setAppLocale(targetLocaleCode);
                                      await _authService.updateUserData({'language': targetLocaleCode});
                                    }

                                    final actualLanguage = VoiceAssistantService.languageNotifier.value;
                                    await VoiceAssistantService.instance.speak(
                                      actualLanguage == VoiceLang.tagalog
                                          ? 'Napalitan ang wika sa Tagalog.'
                                          : selectedLanguage == VoiceLang.tagalog
                                              ? 'Tagalog is not available on this device. Using English.'
                                              : 'Language changed to English.',
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (isVoiceEnabled)
                            // Voice Assistant is on: keep the interactive
                            // audio-preview button.
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  HapticService().vibrate();
                                  await VoiceAssistantService.instance.speak(
                                    VoiceAssistantService.languageNotifier.value == VoiceLang.tagalog
                                        ? 'Ito ay isang preview ng boses ng CLARO.'
                                        : 'This is a preview of the CLARO voice assistant.',
                                  );
                                },
                                icon: Icon(Icons.play_arrow, color: theme.colorScheme.primary),
                                label: Text(loc.previewAudio, style: TextStyle(color: theme.colorScheme.primary)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: theme.colorScheme.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            )
                          else
                            // Voice Assistant is off (toggled from the
                            // Profile screen): there's nothing to preview,
                            // so the "Tap for audio preview" button is
                            // hidden and replaced with a hint, styled the
                            // same as the "Vibrate on scan, alerts, and
                            // reads" description text below.
                            Text(
                              loc.enableVoiceAssistant,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.vibrationFeedback, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: theme.colorScheme.surfaceContainerHighest),
                              child: Icon(Icons.vibration_outlined, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(loc.vibrationFeedback, style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                                  const SizedBox(height: 4),
                                  Text(loc.vibrateDescription, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _vibrationFeedback,
                        onChanged: (v) async {
                          // Apply the new state to HapticService FIRST --
                          // vibrate() gates on HapticService().isEnabled, so
                          // calling it before this line meant turning the
                          // switch ON always checked the stale (still-off)
                          // state and silently did nothing on that very tap.
                          HapticService().isEnabled = v;
                          HapticService().vibrate();
                          setState(() => _vibrationFeedback = v);
                          final ok = await _savePref('vibrationFeedback', v);
                          if (!ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.preferenceSaveError)));
                          }
                        },
                        activeThumbColor: theme.colorScheme.primary,
                        activeTrackColor: theme.colorScheme.primary.withAlpha(120),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.textSize, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('A', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface)),
                      Expanded(
                        child: Slider(
                          value: _textSize,
                          min: 0.8,
                          max: 1.4,
                          onChanged: (v) async {
                            HapticService().vibrate();
                            setState(() => _textSize = v);
                            // Use TextSizeService to update and sync in real-time
                            await TextSizeService.instance.updateTextSize(v);
                            if (!mounted) return;
                            final ok = await _savePref('textSize', v);
                            if (!ok && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.preferenceSaveError)));
                            }
                          },
                        ),
                      ),
                      Text('A', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface)),
                    ],
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}