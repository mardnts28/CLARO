import 'package:flutter/material.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/haptic_service.dart';
import '../services/get_started_service.dart';

/// Shown once, right after Select Language and before Login/Sign Up (see
/// RootGate in main.dart). Previously this content lived as the second
/// page of the post-login OnboardingScreen PageView, sandwiched between
/// Basic Information and Health Profile -- it has been pulled out into
/// its own screen and moved earlier in the flow.
///
/// Because this screen is now reached straight from SelectLanguageScreen
/// (which has no text fields) rather than from the Login screen (which
/// does), it no longer inherits any leftover keyboard/field focus from a
/// previous screen, which is what used to cause the
/// "BOTTOM OVERFLOWED BY 71 PIXELS" error here.
class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  static const _red = Color(0xFF8B1A1A);
  static const _bg = Color(0xFFF5F0EE);

  Future<void> _onGetStarted() async {
    HapticService().vibrate();
    // Flips GetStartedService.hasSeenGetStartedNotifier to true, which
    // RootGate listens to -- it will swap this screen out for AuthGate
    // (Login/Sign Up, or Home if already authenticated) automatically.
    await GetStartedService.markSeen();
  }

  @override
  Widget build(BuildContext context) {
    // Force Light Mode, matching the rest of the onboarding flow.
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        primaryColor: _red,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.light(
          primary: _red,
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
              // A screen with no text fields can never have a keyboard
              // push it up, so `resizeToAvoidBottomInset: false` isn't
              // needed here. SafeArea + SingleChildScrollView keep this
              // responsive on smaller devices (so the grid + button don't
              // overflow), which is why this can't just be a fixed
              // Column with Spacer like the rest of onboarding -- but
              // Spacer/Expanded need a bounded height, which a
              // SingleChildScrollView's child doesn't have. Wrapping in
              // IntrinsicHeight to get around that (as an earlier version
              // of this screen did) breaks GridView specifically: a
              // GridView is a viewport, and viewports can't report
              // intrinsic dimensions ("RenderShrinkWrappingViewport does
              // not support returning intrinsic dimensions") -- so this
              // uses fixed spacing instead of Spacer, which needs neither.
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: Column(
                    children: [
                      _buildLogo(theme),
                      const SizedBox(height: 20),
                      Text(
                        loc.getStartedTagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc.getStartedSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: colorScheme.onSurface, height: 1.5),
                      ),
                      const SizedBox(height: 36),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.4,
                        children: [
                          _buildFeatureCard('assets/images/scan.png', loc.featureScan, theme),
                          _buildFeatureCard('assets/images/nutrisyon.png', loc.featureNutrition, theme),
                          _buildFeatureCard('assets/images/gabay.png', loc.featureHealth, theme),
                          _buildFeatureCard('assets/images/compare.png', loc.featureCompare, theme),
                        ],
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _onGetStarted,
                          child: Text(
                            loc.getStarted,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
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

  Widget _buildLogo(ThemeData theme) {
    return Column(
      children: [
        Image.asset('assets/images/logo.png', height: 80),
        const SizedBox(height: 6),
        Text(
          'CLARO',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(String imagePath, String label, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            height: 36,
            width: 36,
            errorBuilder: (_, __, ___) => const Icon(
                Icons.image_not_supported,
                size: 36,
                color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}
