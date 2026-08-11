import 'package:flutter/material.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/haptic_service.dart';
import '../services/locale_service.dart';

/// First-launch language picker. Shown once, before Get Started and
/// Login/Sign Up (see RootGate in main.dart) -- the very first screen a
/// new install sees. Once a language is chosen it is applied immediately
/// (LocaleService.setAppLocale updates the app-wide locale right away, so
/// every screen after this one -- including this one, if it rebuilt --
/// already reflects the choice) and persists until the user changes it
/// from Profile/Settings; it is never reset on app restart.
///
/// This screen intentionally follows the *system* locale for its own
/// copy (via AppLocalizations, same as the rest of the app) rather than
/// hardcoding English, since LocaleService already defaults
/// `localeNotifier` to the system locale before any explicit choice is
/// made -- so a Tagalog-language phone already sees this screen in
/// Tagalog, which is a better first impression than defaulting to
/// English for everyone.
class SelectLanguageScreen extends StatefulWidget {
  const SelectLanguageScreen({super.key});

  @override
  State<SelectLanguageScreen> createState() => _SelectLanguageScreenState();
}

class _SelectLanguageScreenState extends State<SelectLanguageScreen> {
  bool _isSaving = false;

  Future<void> _select(String code) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticService().vibrate();
    // This flips LocaleService.hasSelectedLanguageNotifier to true, which
    // is what RootGate is listening to -- it will swap this screen out
    // for GetStartedScreen automatically, no explicit navigation needed.
    await LocaleService.setAppLocale(code);
  }

  @override
  Widget build(BuildContext context) {
    // Force Light Mode, matching the rest of the onboarding flow.
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF8B1A1A),
        scaffoldBackgroundColor: const Color(0xFFF5F0EE),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF8B1A1A),
          onPrimary: Colors.white,
          secondary: Color(0xFFD32F2F),
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF1A1A1A),
          error: Colors.redAccent,
          onError: Colors.white,
          surfaceContainerHighest: Color(0xFFE0E0E0),
          outlineVariant: Color(0xFFBDBDBD),
          onSurfaceVariant: Color(0xFF757575),
        ),
        useMaterial3: true,
      ),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final loc = AppLocalizations.of(context)!;

          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: Column(
                    children: [
                      const Spacer(),
                      Image.asset('assets/images/logo.png', height: 80),
                      const SizedBox(height: 6),
                      Text(
                        'CLARO',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        loc.chooseLanguage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        loc.selectLanguage,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 32),
                      _buildLanguageOption(
                        context,
                        label: loc.english,
                        code: 'en',
                      ),
                      const SizedBox(height: 16),
                      _buildLanguageOption(
                        context,
                        label: loc.tagalog,
                        code: 'tl',
                      ),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context, {
    required String label,
    required String code,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: _isSaving ? null : () => _select(code),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.language, color: colorScheme.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}