import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/haptic_service.dart';
import '../services/text_size_service.dart';
import '../services/locale_service.dart';
import '../widgets/voice_assistant_fab.dart';

class PreferenceScreen extends StatefulWidget {
  const PreferenceScreen({super.key});

  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends State<PreferenceScreen> {
  static const _primaryRed = Color(0xFF8B1A1A);
  final _authService = AuthService();

  String _selectedLanguage = 'en'; // store language code ('en'|'tl')
  double _speechRate = 0.5;
  bool _vibrationFeedback = false;
  bool _notificationsEnabled = true;
  double _textSize = 1.0;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        final doc = await _authService.db.collection('users').doc(uid).get();
        final data = doc.data();
        if (data != null) {
          setState(() {
            // keep the stored language code directly
            _selectedLanguage = data['language'] ?? 'en';
            _speechRate = (data['speechRate'] != null) ? (data['speechRate'] as num).toDouble() : 0.5;
            _vibrationFeedback = data['vibrationFeedback'] ?? false;
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
              // store and keep language code directly
              _selectedLanguage = data['language'] ?? _selectedLanguage;
              _speechRate = (data['speechRate'] != null) ? (data['speechRate'] as num).toDouble() : _speechRate;
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
        iconTheme: const IconThemeData(color: _primaryRed),
        title: Text(loc.preferenceTitle, style: const TextStyle(color: _primaryRed)),
      ),
      body: SingleChildScrollView(
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
                  Text(loc.voiceSoundTitle, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLanguage,
                        dropdownColor: theme.cardColor,
                        items: [
                          DropdownMenuItem(value: 'en', child: Text(loc.english, style: TextStyle(color: theme.colorScheme.onSurface))),
                          DropdownMenuItem(value: 'tl', child: Text(loc.tagalog, style: TextStyle(color: theme.colorScheme.onSurface))),
                        ],
                        onChanged: (v) async {
                          if (v == null) return;
                          HapticService().vibrate();
                          // store the language code directly
                          setState(() => _selectedLanguage = v);
                          await LocaleService.setAppLocale(v);
                          final ok = await _savePref('language', v);
                          if (!ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.preferenceSaveError)));
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(loc.speechRate, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurface)),
                  Slider(
                    value: _speechRate,
                    min: 0.3,
                    max: 1.2,
                    divisions: 9,
                    onChanged: (v) async {
                      HapticService().vibrate();
                      setState(() => _speechRate = v);
                      final ok = await _savePref('speechRate', v);
                      if (!ok && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.preferenceSaveError)));
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticService().vibrate();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.previewAudioShort)));
                      },
                      icon: const Icon(Icons.play_arrow, color: _primaryRed),
                      label: Text(loc.previewAudio, style: const TextStyle(color: _primaryRed)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _primaryRed),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: theme.colorScheme.surfaceContainerHighest),
                        child: const Icon(Icons.vibration_outlined, color: _primaryRed),
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
                      const SizedBox(width: 8),
                      Switch(
                        value: _vibrationFeedback,
                        onChanged: (v) async {
                          HapticService().vibrate();
                          setState(() => _vibrationFeedback = v);
                          final ok = await _savePref('vibrationFeedback', v);
                          if (!ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.preferenceSaveError)));
                          }
                        },
                        activeThumbColor: _primaryRed,
                        activeTrackColor: _primaryRed.withAlpha(120),
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
                  Text(loc.multiFactorAuthentication, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: theme.colorScheme.surfaceContainerHighest),
                        child: const Icon(Icons.notifications_outlined, color: _primaryRed),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.multiFactorAuthentication, style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                            const SizedBox(height: 4),
                            Text(loc.safetyPriorityMessage, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _notificationsEnabled,
                        onChanged: (v) async {
                          HapticService().vibrate();
                          setState(() => _notificationsEnabled = v);
                          final ok = await _savePref('notificationsEnabled', v);
                          if (!ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.preferenceSaveError)));
                          }
                        },
                        activeThumbColor: _primaryRed,
                        activeTrackColor: _primaryRed.withAlpha(120),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: const VoiceAssistantFab(),
    );
  }
}
