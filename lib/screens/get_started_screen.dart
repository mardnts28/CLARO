import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/haptic_service.dart';
import '../services/get_started_service.dart';

/// CLARO Get Started / Welcome Screen
///
/// The main visual design is provided by:
/// assets/images/startbg.png
///
/// The background image contains:
/// - CLARO logo
/// - Shopping cart illustration
/// - Red curved/dome background
/// - Tagline
/// - Subtitle
/// - Page indicator
///
/// Interactive elements placed above the background:
/// - Get Started button
/// - Learn More About CLARO
///
/// Existing functionality is preserved:
/// - Haptic feedback
/// - GetStartedService.markSeen()
/// - External Learn More URL
/// - Error handling if the URL cannot be opened
class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  // ---------------------------------------------------------------------------
  // COLORS
  // ---------------------------------------------------------------------------

  static const Color _red = Color(0xFF8B1A1A);

  // ---------------------------------------------------------------------------
  // BACKGROUND ASSET
  // ---------------------------------------------------------------------------

  static const String _backgroundAsset =
      'assets/images/startbg.png';

  // ---------------------------------------------------------------------------
  // LEARN MORE URL
  // ---------------------------------------------------------------------------

  static final Uri _learnMoreUrl = Uri.parse(
    'https://claro-52ia.onrender.com/?fbclid=IwY2xjawUXIttwZG9mA2V4dG4DYWVtAjExAHNydGMGYXBwX2lkATAAAR4YhO9Wsy20CCgjm8jxB2PI5wbOiV-pNHmZudjQn6MwtJvBLUNr-69vEw0aIA_aem_Y_mwxTMVzZKOGXKFa2OutQ',
  );

  // ---------------------------------------------------------------------------
  // GET STARTED FUNCTION
  // ---------------------------------------------------------------------------

  Future<void> _onGetStarted() async {
    // Preserve haptic feedback.
    HapticService().vibrate();

    // Preserve the existing GetStartedService behavior.
    //
    // RootGate listens to this and moves the user to the
    // authentication/home flow.
    await GetStartedService.markSeen();
  }

  // ---------------------------------------------------------------------------
  // LEARN MORE FUNCTION
  // ---------------------------------------------------------------------------

  Future<void> _onLearnMore(BuildContext context) async {
    // Preserve haptic feedback.
    HapticService().vibrate();

    final bool ok = await launchUrl(
      _learnMoreUrl,
      mode: LaunchMode.externalApplication,
    );

    // Preserve the original error handling.
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the link.'),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // MAIN BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        primaryColor: _red,
        scaffoldBackgroundColor: Colors.white,
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
          final AppLocalizations loc =
              AppLocalizations.of(context)!;

          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              // Prevent system font-size settings from changing
              // the proportions of this highly visual welcome screen.
              textScaler: TextScaler.noScaling,
            ),
            child: Scaffold(
              backgroundColor: Colors.white,

              // Prevent the Scaffold from automatically moving the
              // entire design when the keyboard/system UI appears.
              resizeToAvoidBottomInset: false,

              body: LayoutBuilder(
                builder: (
                  BuildContext context,
                  BoxConstraints constraints,
                ) {
                  final double width = constraints.maxWidth;
                  final double height = constraints.maxHeight;

                  final EdgeInsets viewPadding =
                      MediaQuery.of(context).viewPadding;

                  final double bottomInset =
                      MediaQuery.of(context).padding.bottom;

                  final double topInset =
                      MediaQuery.of(context).padding.top;

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // ======================================================
                      // FULL SCREEN BACKGROUND
                      // ======================================================

                      _buildBackground(
                        width: width,
                        height: height,
                      ),

                      // ======================================================
                      // INTERACTIVE CONTROLS
                      // ======================================================

                      _buildActionArea(
                        context: context,
                        loc: loc,
                        width: width,
                        height: height,
                        topInset: topInset,
                        bottomInset: bottomInset,
                        viewPadding: viewPadding,
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BACKGROUND
  // ---------------------------------------------------------------------------

  Widget _buildBackground({
    required double width,
    required double height,
  }) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.white,
        child: Image.asset(
          _backgroundAsset,

          // COVER ensures the image fills the entire screen.
          //
          // This means:
          // - No white bars
          // - No empty space
          // - No stretching
          //
          // On devices with a significantly different aspect ratio,
          // the edges may be cropped slightly, which is preferable
          // for this full-screen visual design.
          fit: BoxFit.cover,

          // Keep the center of startbg aligned with the center
          // of the device screen.
          alignment: Alignment.center,

          // Improve image quality when the image is scaled.
          filterQuality: FilterQuality.high,

          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
            return _buildBackgroundError();
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BACKGROUND ERROR FALLBACK
  // ---------------------------------------------------------------------------

  Widget _buildBackgroundError() {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Unable to load CLARO background.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _red,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTION AREA
  // ---------------------------------------------------------------------------

  Widget _buildActionArea({
    required BuildContext context,
    required AppLocalizations loc,
    required double width,
    required double height,
    required double topInset,
    required double bottomInset,
    required EdgeInsets viewPadding,
  }) {
    // ---------------------------------------------------------
    // RESPONSIVE BUTTON WIDTH
    // ---------------------------------------------------------
    //
    // Typical phone:
    // 390px * 0.34 = 132.6px
    //
    // This keeps the button close to the reference.
    //
    // On very narrow phones, it won't become too small.
    // On tablets, it won't become unnecessarily huge.
    final double buttonWidth = (width * 0.46).clamp(
      160.0,
      220.0,
    );

    // ---------------------------------------------------------
    // RESPONSIVE BUTTON HEIGHT
    // ---------------------------------------------------------

    final double buttonHeight = (width / 390 * 52).clamp(
      48.0,
      58.0,
    );

    // ---------------------------------------------------------
    // RESPONSIVE BOTTOM POSITION
    // ---------------------------------------------------------
    //
    // Instead of using one fixed pixel value, calculate the
    // position relative to the screen height.
    //
    // This keeps the button visually consistent on:
    // 360x800
    // 390x844
    // 393x873
    // 412x915
    // etc.
    //
    // The clamp prevents the button from moving too far away
    // from the bottom on unusually tall/short devices.
    final double bottomSpacing = (height * 0.05).clamp(
      28.0,
      56.0,
    );

    // ---------------------------------------------------------
    // SAFE AREA
    // ---------------------------------------------------------
    //
    // Android navigation bars can have different heights.
    // Add the actual bottom inset so the Learn More link
    // does not get hidden behind the system navigation area.
    final double safeBottom = bottomInset > 0
        ? bottomInset
        : viewPadding.bottom;

    // ---------------------------------------------------------
    // VERY SHORT DEVICE PROTECTION
    // ---------------------------------------------------------

    final bool isVeryShortScreen = height < 650;

    final double adjustedBottomSpacing =
        isVeryShortScreen
            ? 30.0
            : bottomSpacing;

    return Positioned(
      left: 0,
      right: 0,

      // Keep the controls inside the visible safe area.
      bottom: adjustedBottomSpacing + safeBottom,

      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===============================================================
            // GET STARTED BUTTON
            // ===============================================================

            SizedBox(
              width: buttonWidth,
              height: buttonHeight,
              child: ElevatedButton(
                onPressed: _onGetStarted,

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _red,

                  // The reference uses a flat white button.
                  elevation: 0,
                  shadowColor: Colors.transparent,

                  padding: EdgeInsets.zero,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),

                child: Text(
                  loc.getStarted,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(
                    color: _red,
                    fontSize: _responsiveFont(
                      width,
                      base: 15,
                    ),
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
            ),

            // ===============================================================
            // GAP
            // ===============================================================

            const SizedBox(height: 12),

            // ===============================================================
            // LEARN MORE
            // ===============================================================

            GestureDetector(
              behavior: HitTestBehavior.opaque,

              onTap: () {
                _onLearnMore(context);
              },

              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),

                child: Text(
                  'Learn More About CLARO',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _responsiveFont(
                      width,
                      base: 12,
                    ),
                    fontWeight: FontWeight.w400,

                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white,

                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RESPONSIVE FONT
  // ---------------------------------------------------------------------------

  double _responsiveFont(
    double width, {
    required double base,
  }) {
    final double factor = (width / 390).clamp(
      0.88,
      1.15,
    );

    return base * factor;
  }
}