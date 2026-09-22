import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/haptic_service.dart';
import '../services/get_started_service.dart';
import '../widgets/dome_clipper.dart';
import '../widgets/dome_page_route.dart';
import 'select_language_screen.dart';

/// CLARO Get Started / Welcome Screen
///
/// Previously this screen was a single flat image
/// (assets/images/startbg.png) with the dome, logo, illustration
/// cluster, and tagline all baked into one PNG. That made the dome's
/// red shade impossible to keep in sync with the app's real primary
/// red, and made it impossible to animate individual illustration
/// pieces.
///
/// This version rebuilds the same layout from real widgets:
/// - The dome is drawn in code with `_red` (0xFF8B1A1A), the same
///   constant used everywhere else in the app.
/// - The logo, "CLARO" wordmark, and illustration cluster
///   (assets/images/startscreen-elements/*.png, each a standalone
///   transparent PNG) are positioned individually, using the exact
///   coordinates measured from the original design.
/// - Each illustration piece gently bobs/pulses in a continuous,
///   staggered loop so the cluster feels alive instead of static.
/// - The tagline/subtitle are real, localized `Text` widgets instead
///   of baked-in pixels, so the Tagalog locale renders correctly here
///   too.
///
/// Existing functionality is preserved:
/// - Haptic feedback
/// - GetStartedService.markSeen()
/// - External Learn More URL
/// - Error handling if the URL cannot be opened
class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen>
    with TickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // COLORS
  // ---------------------------------------------------------------------------

  static const Color _red = Color(0xFF8B1A1A);

  // ---------------------------------------------------------------------------
  // ILLUSTRATION ASSETS
  // ---------------------------------------------------------------------------

  static const String _elementsPath = 'assets/images/startscreen-elements/';

  // ---------------------------------------------------------------------------
  // LEARN MORE URL
  // ---------------------------------------------------------------------------

  static final Uri _learnMoreUrl = Uri.parse(
    'https://claro-52ia.onrender.com/?fbclid=IwY2xjawUXIttwZG9mA2V4dG4DYWVtAjExAHNydGMGYXBwX2lkATAAAR4YhO9Wsy20CCgjm8jxB2PI5wbOiV-pNHmZudjQn6MwtJvBLUNr-69vEw0aIA_aem_Y_mwxTMVzZKOGXKFa2OutQ',
  );

  // ---------------------------------------------------------------------------
  // FLOAT ANIMATION
  // ---------------------------------------------------------------------------
  //
  // A single continuously-repeating controller drives every illustration
  // piece. Each piece reads its own phase offset into a sine wave, so
  // they all move on the same clock but never in sync with each other.

  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // GET STARTED FUNCTION
  // ---------------------------------------------------------------------------

  Future<void> _onGetStarted() async {
    // Preserve haptic feedback.
    HapticService().vibrate();

    if (!mounted) return;

    Navigator.of(context).push(
      DomeTransitionPageRoute(
        exitPage: widget,
        enterPage: const SelectLanguageScreen(),
        // Mark as seen only once the dome transition has finished playing.
        //
        // RootGate (in main.dart) listens to this flag and instantly swaps
        // in SelectLanguageScreen the moment it flips — with no animation
        // of its own. Flipping it up front (before the push) made that
        // instant swap happen first, so the animated dome transition never
        // had a chance to be seen. Deferring it to completion means the
        // instant swap happens only after this transition has already
        // shown the same final screen, so it's invisible.
        onAnimationComplete: () {
          GetStartedService.markSeen();
        },
      ),
    );
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
          final AppLocalizations loc = AppLocalizations.of(context)!;

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
                      // WHITE BASE
                      // ======================================================

                      const ColoredBox(color: Colors.white),

                      // ======================================================
                      // RED DOME
                      // ======================================================

                      _buildDome(
                        width: width,
                        height: height,
                      ),

                      // ======================================================
                      // DOME TEXT (TAGLINE + SUBTITLE)
                      // ======================================================

                      _buildDomeText(
                        loc: loc,
                        width: width,
                        height: height,
                      ),

                      // ======================================================
                      // LOGO
                      // ======================================================

                      _buildLogoArea(
                        width: width,
                        height: height,
                      ),

                      // ======================================================
                      // ANIMATED ILLUSTRATION CLUSTER
                      // ======================================================

                      ..._buildIllustrationCluster(
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
  // RED DOME
  // ---------------------------------------------------------------------------
  //
  // Measured from the original design: the curve peaks at ~49% of the
  // screen height and the sides settle at ~62.5%, then the dome fills
  // solid down to the bottom of the screen.

  Widget _buildDome({
    required double width,
    required double height,
  }) {
    return Positioned.fill(
      child: ClipPath(
        clipper: const StandardDomeClipper(isTop: false),
        child: Container(color: _red),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DOME TEXT
  // ---------------------------------------------------------------------------

  Widget _buildDomeText({
    required AppLocalizations loc,
    required double width,
    required double height,
  }) {
    // Sits just below where the curve settles, inside the solid
    // portion of the dome.
    final double top = height * 0.625 + (height * 0.035);

    return Positioned(
      left: 0,
      right: 0,
      top: top,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: (width * 0.08).clamp(20.0, 48.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc.getStartedTagline,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: _responsiveFont(width, base: 19),
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),

            SizedBox(height: (height * 0.018).clamp(10.0, 22.0)),

            Text(
              loc.getStartedSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: _responsiveFont(width, base: 14.5),
                fontWeight: FontWeight.w400,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LOGO
  // ---------------------------------------------------------------------------
  //
  // Scanner-frame corners + logo.png + "CLARO" wordmark, positioned to
  // match the original design (centered, ~11%-22% of screen height).

  Widget _buildLogoArea({
    required double width,
    required double height,
  }) {
    final double frameSize = (width * 0.231).clamp(72.0, 130.0);
    final double cornerSize = frameSize * 0.32;
    final double cornerThickness = (width / 390 * 3.2).clamp(2.4, 4.0);
    final double logoSize = frameSize * 0.72;

    return Positioned(
      left: 0,
      right: 0,
      top: height * 0.09,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: frameSize,
            height: frameSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: _corner(
                    size: cornerSize,
                    thickness: cornerThickness,
                    top: true,
                    left: true,
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: _corner(
                    size: cornerSize,
                    thickness: cornerThickness,
                    top: true,
                    left: false,
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: _corner(
                    size: cornerSize,
                    thickness: cornerThickness,
                    top: false,
                    left: true,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _corner(
                    size: cornerSize,
                    thickness: cornerThickness,
                    top: false,
                    left: false,
                  ),
                ),
                Image.asset(
                  'assets/images/logo-launch/logo-can.png',
                  height: logoSize,
                  width: logoSize,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) {
                    return Icon(
                      Icons.qr_code_scanner,
                      color: _red,
                      size: logoSize * 0.78,
                    );
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: (width / 390 * 8).clamp(5.0, 11.0)),

          Text(
            'CLARO',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _responsiveFont(width, base: 26),
              fontWeight: FontWeight.w800,
              color: _red,
              letterSpacing: 1.5,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _corner({
    required double size,
    required double thickness,
    required bool top,
    required bool left,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
          color: _red,
          thickness: thickness,
          top: top,
          left: left,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ILLUSTRATION CLUSTER
  // ---------------------------------------------------------------------------
  //
  // Each item's center position and width are fractions of the screen,
  // measured directly from the original design so the composition
  // matches it. Every item bobs/pulses continuously and independently
  // (see `_FloatingElement`).

  List<Widget> _buildIllustrationCluster({
    required double width,
    required double height,
  }) {
    final items = <_ClusterItem>[
      _ClusterItem(
        asset: 'sardine_can.png',
        centerX: 0.47,
        centerY: 0.31,
        widthFraction: 0.115,
        phase: 0.0,
      ),
      _ClusterItem(
        asset: 'pie_chart.png',
        centerX: 0.57,
        centerY: 0.365,
        widthFraction: 0.20,
        phase: 0.4,
      ),
      _ClusterItem(
        asset: 'clipboard.png',
        centerX: 0.43,
        centerY: 0.40,
        widthFraction: 0.13,
        phase: 0.2,
      ),
      _ClusterItem(
        asset: 'cart.png',
        centerX: 0.480,
        centerY: 0.515,
        widthFraction: 0.335,
        phase: 0.8,
      ),
      _ClusterItem(
        asset: 'noodle_pack.png',
        centerX: 0.53,
        centerY: 0.445,
        widthFraction: 0.175,
        phase: 0.6,
      ),
    ];

    return items.map((item) {
      final double itemWidth = width * item.widthFraction;

      return Positioned(
        left: width * item.centerX - itemWidth / 2,
        top: height * item.centerY - itemWidth / 2,
        width: itemWidth,
        height: itemWidth,
        child: _FloatingElement(
          controller: _floatController,
          phase: item.phase,
          child: Image.asset(
            '$_elementsPath${item.asset}',
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      );
    }).toList();
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

            // ===============================================================
            // GAP
            // ===============================================================

            const SizedBox(height: 14),

            // ===============================================================
            // PAGE INDICATOR
            // ===============================================================
            //
            // This is the first step of the onboarding flow (Get Started
            // -> Select Language), so the first dot is active. Added here
            // to match the reference design and the indicator already
            // present on the Select Language screen — the original
            // baked-in image did not clearly show one.

            _buildPageIndicator(activeIndex: 0),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PAGE INDICATOR
  // ---------------------------------------------------------------------------

  Widget _buildPageIndicator({
    required int activeIndex,
    int count = 2,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final bool isActive = index == activeIndex;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 20 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
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

// =============================================================================
// CLUSTER ITEM DATA
// =============================================================================

class _ClusterItem {
  final String asset;
  final double centerX;
  final double centerY;
  final double widthFraction;
  final double phase;

  const _ClusterItem({
    required this.asset,
    required this.centerX,
    required this.centerY,
    required this.widthFraction,
    required this.phase,
  });
}

// =============================================================================
// FLOATING ELEMENT
// =============================================================================
//
// Wraps a single illustration piece in a continuous, looping "breathe"
// motion: a gentle scale pulse combined with a small forward/upward
// drift, giving the effect of each item floating just off the surface.
// `phase` (0-1) offsets where in the cycle this item starts, so a
// cluster of these never moves in unison.

class _FloatingElement extends StatelessWidget {
  final Animation<double> controller;
  final double phase;
  final Widget child;

  const _FloatingElement({
    required this.controller,
    required this.phase,
    required this.child,
  });

  static const double _scaleAmount = 0.055;
  static const double _driftAmount = 6.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, cachedChild) {
        final double t = math.sin(
          (controller.value + phase) * 2 * math.pi,
        );

        final double scale = 1.0 + _scaleAmount * (0.5 + 0.5 * t);
        final double dy = -_driftAmount * (0.5 + 0.5 * t);

        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(
            scale: scale,
            child: cachedChild,
          ),
        );
      },
    );
  }
}

// =============================================================================
// SCANNER CORNER PAINTER
// =============================================================================

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool top;
  final bool left;

  const _CornerPainter({
    required this.color,
    required this.thickness,
    required this.top,
    required this.left,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final path = Path();

    final horizontalLength = size.width;
    final verticalLength = size.height;

    if (top && left) {
      path.moveTo(0, verticalLength);
      path.lineTo(0, 0);
      path.lineTo(horizontalLength, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(horizontalLength, 0);
      path.lineTo(horizontalLength, verticalLength);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, verticalLength);
      path.lineTo(horizontalLength, verticalLength);
    } else {
      path.moveTo(0, verticalLength);
      path.lineTo(horizontalLength, verticalLength);
      path.lineTo(horizontalLength, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.thickness != thickness ||
        oldDelegate.top != top ||
        oldDelegate.left != left;
  }
}