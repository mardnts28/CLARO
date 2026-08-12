import 'package:flutter/material.dart';
import '../core/utils/success_feedback_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/voice_assistant_service.dart';
import '../widgets/voice_assistant_fab.dart';

class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  static const _primaryRed = Color(0xFF8B1A1A);
  String _selected = 'Default';
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    if (_authService.currentUser != null && VoiceAssistantService.instance.isEnabled) {
      VoiceAssistantService.instance.announcePage('theme');
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        // Try to get the latest server value first
        try {
          final userDoc = await _authService.db.collection('users').doc(uid).get(GetOptions(source: Source.server));
          final data = userDoc.data();
          if (data != null) {
            setState(() => _selected = (data['theme'] ?? 'Default').toString());
            setAppThemeMode(parseThemeMode(_selected));
            return;
          }
        } catch (_) {}

        // Fallback to cache if server read fails
        final userDoc = await _authService.db.collection('users').doc(uid).get();
        final data = userDoc.data();
        if (data != null) {
          setState(() => _selected = (data['theme'] ?? 'Default').toString());
          setAppThemeMode(parseThemeMode(_selected));
        }
      }
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  Future<void> _choose(String theme) async {
    final loc = AppLocalizations.of(context)!;
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) return;
      final ok = await _authService.updateUserData({'theme': theme});
      if (ok) {
        // reload server value to be sure
        await _load();
        setAppThemeMode(parseThemeMode(theme));
        if (mounted) SuccessFeedbackUtils.showSuccessSnackBar(context, loc.themeSaved);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.themeSaveError)),
        );
      }
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  Widget _option(String label, String asset) {
    final theme = Theme.of(context);
    final selected = _selected.toLowerCase() == label.toLowerCase();
    return Expanded(
      child: GestureDetector(
        onTap: () => _choose(label),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : theme.dividerColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Image.asset(asset, height: 100, fit: BoxFit.contain),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: selected ? theme.colorScheme.primary : theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.primary),
        title: Text(AppLocalizations.of(context)!.theme, style: TextStyle(color: colorScheme.primary)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildCardOption(
              label: AppLocalizations.of(context)!.themeDefault,
              asset: 'assets/images/default.png',
              description: AppLocalizations.of(context)!.themeDefaultDescription,
              selected: _selected.toLowerCase() == 'default',
              onTap: () => _choose('Default'),
            ),
            const SizedBox(height: 12),
            _buildCardOption(
              label: AppLocalizations.of(context)!.themeDarkMode,
              asset: 'assets/images/dark.png',
              description: AppLocalizations.of(context)!.themeDarkModeDescription,
              selected: _selected.toLowerCase() == 'dark' || _selected.toLowerCase() == 'dark mode',
              onTap: () => _choose('Dark Mode'),
            ),
          ],
        ),
      ),
      floatingActionButton: const VoiceAssistantFab(),
    );
  }

  Widget _buildCardOption({
    required String label,
    required String asset,
    required String description,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final bodyLarge = theme.textTheme.bodyLarge;
    final bodyMedium = theme.textTheme.bodyMedium;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? theme.colorScheme.primary : theme.dividerColor, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(asset, fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: bodyLarge?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: selected ? theme.colorScheme.primary : bodyLarge.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        selected ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: bodyMedium?.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}