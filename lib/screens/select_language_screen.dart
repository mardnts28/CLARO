import 'package:flutter/material.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/haptic_service.dart';
import '../services/locale_service.dart';

/// CLARO Select Language Screen
///
/// UI updated to closely match the provided reference:
/// - Compact red header
/// - Centered and slightly lowered logo
/// - Features positioned closer to the bottom curve
/// - Minimal empty space
/// - Large smooth curved bottom edge
/// - Compact language selection section
///
/// FUNCTIONALITY PRESERVED:
/// - English -> _select('en')
/// - Tagalog -> _select('tl')
/// - LocaleService.setAppLocale(code)
/// - HapticService().vibrate()
class SelectLanguageScreen extends StatefulWidget {
  const SelectLanguageScreen({super.key});

  @override
  State<SelectLanguageScreen> createState() =>
      _SelectLanguageScreenState();
}

class _SelectLanguageScreenState
    extends State<SelectLanguageScreen> {
  // ===========================================================================
  // STATE
  // ===========================================================================

  bool _isSaving = false;

  // ===========================================================================
  // COLORS
  // ===========================================================================

  static const Color _background = Colors.white;

  static const Color _red = Color(0xFF8B1A1A);

  static const Color _black = Color(0xFF171717);

  // ===========================================================================
  // RESPONSIVE LIMITS
  // ===========================================================================

  static const double _maxContentWidth = 520.0;

  static const double _maxButtonWidth = 240.0;

  static const double _minButtonWidth = 170.0;

  // ===========================================================================
  // LANGUAGE SELECTION
  // ===========================================================================

  Future<void> _select(String code) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    HapticService().vibrate();

    await LocaleService.setAppLocale(code);
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        primaryColor: _red,
        scaffoldBackgroundColor: _background,
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
          final loc = AppLocalizations.of(context)!;
          final mediaQuery = MediaQuery.of(context);

          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: Scaffold(
              backgroundColor: _background,
              resizeToAvoidBottomInset: true,
              body: LayoutBuilder(
                builder: (
                  context,
                  constraints,
                ) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;

                  final bottomInset = mediaQuery.padding.bottom;
                  final viewPadding = mediaQuery.viewPadding;
                  final safeBottom = bottomInset > 0 ? bottomInset : viewPadding.bottom;
                  final bottomSpacing = (height * 0.05).clamp(28.0, 56.0);
                  final isVeryShortScreen = height < 650;
                  final adjustedBottomSpacing = isVeryShortScreen ? 30.0 : bottomSpacing;
                  final dotsBottomInset = adjustedBottomSpacing + safeBottom;

                  final isLandscape =
                      width > height * 1.15;

                  final isCompact =
                      height < 620 || isLandscape;

                  final Widget mainLayout = isCompact
                      ? _buildCompactLayout(
                          context,
                          loc,
                          width,
                          height,
                        )
                      : _buildNormalLayout(
                          context,
                          loc,
                          width,
                          height,
                        );

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      mainLayout,
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: dotsBottomInset,
                        child: Center(
                          child: _buildPageIndicator(activeIndex: 1),
                        ),
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

  // ===========================================================================
  // NORMAL PORTRAIT LAYOUT
  // ===========================================================================

  Widget _buildNormalLayout(
    BuildContext context,
    AppLocalizations loc,
    double width,
    double height,
  ) {
    final contentWidth = width > _maxContentWidth
        ? _maxContentWidth
        : width;

    /*
     * Keep the red area around half of the screen,
     * similar to the reference image.
     *
     * The important change is that the contents inside
     * the header are now positioned intentionally instead
     * of simply being placed at the top of a Column.
     */
    final headerHeight = (height * 0.46).clamp(
      260.0,
      470.0,
    );

    return SafeArea(
      top: false,
      bottom: true,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: height,
          ),
          child: Column(
            children: [
              // =================================================================
              // RED HEADER
              // =================================================================

              _buildHeader(
                context,
                loc,
                width,
                headerHeight,
              ),

              // =================================================================
              // LANGUAGE SECTION
              // =================================================================

              SizedBox(
                width: contentWidth,
                child: _buildLanguageArea(
                  context,
                  loc,
                  width,
                  height,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // RED HEADER
  // ===========================================================================

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations loc,
    double width,
    double height,
  ) {
    return ClipPath(
      clipper: const _ResponsiveBottomArcClipper(),
      child: Container(
        width: double.infinity,
        height: height,
        color: _red,
        child: SafeArea(
          top: true,
          bottom: false,
          // ===================================================================
          // LOGO + FEATURES, VERTICALLY CENTERED
          // ===================================================================
          //
          // Instead of independently pinning the logo near the top and the
          // feature grid near the bottom (which made the features look like
          // they were floating too low / too small), both pieces are grouped
          // into a single column that is centered inside the dome. This keeps
          // the spacing balanced on every screen size and matches the
          // reference layout, where the whole cluster sits comfortably in the
          // upper-middle of the red area with room to breathe above the curve.
          child: Padding(
            padding: EdgeInsets.only(
              bottom: _headerBottomReserve(height),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(
                  context,
                  width,
                ),

                SizedBox(
                  height: _logoFeatureGap(width, height),
                ),

                _buildFeatureGrid(
                  context,
                  loc,
                  width,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER BOTTOM RESERVE
  // ===========================================================================
  //
  // Keeps the centered content from drifting into the curved edge itself.

  double _headerBottomReserve(double height) {
    return (height * 0.10).clamp(16.0, 40.0);
  }

  // ===========================================================================
  // LOGO / FEATURE GRID GAP
  // ===========================================================================

  double _logoFeatureGap(
    double width,
    double height,
  ) {
    return (height * 0.07).clamp(24.0, 44.0);
  }

  // ===========================================================================
  // LOGO
  // ===========================================================================

  Widget _buildLogo(
    BuildContext context,
    double width,
  ) {
    /*
     * Responsive logo size.
     *
     * Slightly smaller than the previous version so the entire
     * header looks more like the reference image.
     */
    final logoSize = (width / 390 * 62).clamp(
      52.0,
      76.0,
    );

    final scannerSize = (width / 390 * 78).clamp(
      66.0,
      92.0,
    );

    final cornerSize = (width / 390 * 23).clamp(
      20.0,
      28.0,
    );

    final cornerThickness =
        (width / 390 * 2.2).clamp(
      1.8,
      2.6,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // =====================================================================
        // SCANNER FRAME + LOGO
        // =====================================================================

        SizedBox(
          width: scannerSize,
          height: scannerSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // -----------------------------------------------------------------
              // TOP LEFT
              // -----------------------------------------------------------------

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

              // -----------------------------------------------------------------
              // TOP RIGHT
              // -----------------------------------------------------------------

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

              // -----------------------------------------------------------------
              // BOTTOM LEFT
              // -----------------------------------------------------------------

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

              // -----------------------------------------------------------------
              // BOTTOM RIGHT
              // -----------------------------------------------------------------

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

              // -----------------------------------------------------------------
              // CLARO LOGO IMAGE
              // -----------------------------------------------------------------
              //
              // `logo.png` is the same dark-red mark used on light
              // backgrounds elsewhere in the app (e.g. the Get Started
              // screen). Dropped in as-is on this red header, it renders
              // in the wrong color and nearly disappears against the red
              // background. `BlendMode.srcIn` uses the artwork purely as
              // an alpha mask and repaints it solid white, matching the
              // reference design.

              Image.asset(
                'assets/images/whiteBorderLogo.png',
                height: logoSize,
                width: logoSize,
                fit: BoxFit.contain,
                errorBuilder: (
                  _,
                  _,
                  _,
                ) {
                  return Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: logoSize * 0.78,
                  );
                },
              ),
            ],
          ),
        ),

        // =====================================================================
        // LOGO / TEXT GAP
        // =====================================================================

        SizedBox(
          height: _logoTextSpacing(width),
        ),

        // =====================================================================
        // CLARO TEXT
        // =====================================================================

        Text(
          'CLARO',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: _claroTextSize(width),
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.3,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SCANNER CORNER
  // ===========================================================================

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

  // ===========================================================================
  // FEATURE GRID
  // ===========================================================================

  Widget _buildFeatureGrid(
    BuildContext context,
    AppLocalizations loc,
    double width,
  ) {
    final gridWidth = _featureGridWidth(width);

    return SizedBox(
      width: gridWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ===================================================================
          // FIRST ROW
          // ===================================================================

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFeatureIcon(
                icon: Icons.qr_code_scanner,
                label: loc.featureScan,
                width: width,
              ),
              _buildFeatureIcon(
                icon: Icons.favorite_border,
                label: loc.featureNutrition,
                width: width,
              ),
            ],
          ),

          // ===================================================================
          // ROW GAP
          // ===================================================================

          SizedBox(
            height: _featureRowSpacing(width),
          ),

          // ===================================================================
          // SECOND ROW
          // ===================================================================

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFeatureIcon(
                icon: Icons.add_circle_outline,
                label: loc.featureHealth,
                width: width,
              ),
              _buildFeatureIcon(
                icon: Icons.compare_arrows,
                label: loc.featureCompare,
                width: width,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // FEATURE ITEM
  // ===========================================================================

  Widget _buildFeatureIcon({
    required IconData icon,
    required String label,
    required double width,
  }) {
    /*
     * Sized to match the reference: the icons read clearly at a
     * glance instead of looking like small decoration.
     */
    final iconSize = (width / 390 * 32).clamp(
      27.0,
      36.0,
    );

    final labelSize = (width / 390 * 12.5).clamp(
      11.0,
      15.0,
    );

    final itemWidth = _featureItemWidth(width);

    return SizedBox(
      width: itemWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ===================================================================
          // ICON
          // ===================================================================

          SizedBox(
            height: iconSize + 3,
            child: Icon(
              icon,
              color: Colors.white,
              size: iconSize,
            ),
          ),

          // ===================================================================
          // ICON / TEXT GAP
          // ===================================================================

          SizedBox(
            height: _featureIconTextSpacing(width),
          ),

          // ===================================================================
          // LABEL
          // ===================================================================

          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: labelSize,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LANGUAGE AREA
  // ===========================================================================

  Widget _buildLanguageArea(
    BuildContext context,
    AppLocalizations loc,
    double width,
    double height,
  ) {
    return Padding(
      padding: EdgeInsets.only(
        top: _languageTopSpacing(
          width,
          height,
        ),
        left: _horizontalPadding(width),
        right: _horizontalPadding(width),
        bottom: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ===================================================================
          // CHOOSE LANGUAGE
          // ===================================================================

          Text(
            loc.chooseLanguage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _languageTitleSize(width),
              fontWeight: FontWeight.w600,
              color: _black,
              height: 1.1,
            ),
          ),

          // ===================================================================
          // TITLE / BUTTON GAP
          // ===================================================================

          SizedBox(
            height: _titleButtonSpacing(
              width,
              height,
            ),
          ),

          // ===================================================================
          // ENGLISH
          // ===================================================================

          _buildLanguageOption(
            context,
            label: loc.english,
            code: 'en',
            width: width,
          ),

          // ===================================================================
          // BUTTON GAP
          // ===================================================================

          SizedBox(
            height: _languageButtonSpacing(width),
          ),

          // ===================================================================
          // TAGALOG
          // ===================================================================

          _buildLanguageOption(
            context,
            label: loc.tagalog,
            code: 'tl',
            width: width,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PAGE INDICATOR
  // ===========================================================================

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
                ? _red
                : const Color(0xFFE0C9C9),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  // ===========================================================================
  // LANGUAGE BUTTON
  // ===========================================================================

  Widget _buildLanguageOption(
    BuildContext context, {
    required String label,
    required String code,
    required double width,
  }) {
    final buttonWidth = (width * 0.42).clamp(
      _minButtonWidth,
      _maxButtonWidth,
    );

    final buttonHeight = (width / 390 * 56).clamp(
      48.0,
      58.0,
    );

    final fontSize = (width / 390 * 15.5).clamp(
      14.0,
      18.0,
    );

    return SizedBox(
      width: buttonWidth,
      height: buttonHeight,
      child: ElevatedButton(
        // =====================================================================
        // ORIGINAL FUNCTIONALITY
        // =====================================================================

        onPressed: _isSaving
            ? null
            : () => _select(code),

        style: ElevatedButton.styleFrom(
          backgroundColor: _red,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              _red.withValues(alpha: 0.65),
          disabledForegroundColor:
              Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),

        child: _isSaving
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
      ),
    );
  }

  // ===========================================================================
  // COMPACT / LANDSCAPE LAYOUT
  // ===========================================================================

  Widget _buildCompactLayout(
    BuildContext context,
    AppLocalizations loc,
    double width,
    double height,
  ) {
    /*
     * Compact screens use a shorter header.
     *
     * The contents are still positioned using Stack,
     * so there will not be a large empty area.
     */
    final compactHeaderHeight = (height * 0.48).clamp(
      210.0,
      300.0,
    );

    return SafeArea(
      top: false,
      bottom: true,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            // =================================================================
            // COMPACT HEADER
            // =================================================================

            _buildHeader(
              context,
              loc,
              width,
              compactHeaderHeight,
            ),

            // =================================================================
            // LANGUAGE AREA
            // =================================================================

            _buildLanguageArea(
              context,
              loc,
              width,
              height,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // HORIZONTAL PADDING
  // ===========================================================================

  double _horizontalPadding(
    double width,
  ) {
    if (width <= 320) {
      return 18.0;
    }

    if (width <= 360) {
      return 20.0;
    }

    if (width <= 430) {
      return 24.0;
    }

    if (width <= 600) {
      return 32.0;
    }

    return 40.0;
  }

  // ===========================================================================
  // LOGO TEXT SPACING
  // ===========================================================================

  double _logoTextSpacing(
    double width,
  ) {
    return (width / 390 * 5).clamp(
      3.0,
      7.0,
    );
  }

  // ===========================================================================
  // CLARO TEXT SIZE
  // ===========================================================================

  double _claroTextSize(
    double width,
  ) {
    return (width / 390 * 17).clamp(
      15.0,
      21.0,
    );
  }

  // ===========================================================================
  // FEATURE GRID WIDTH
  // ===========================================================================

  double _featureGridWidth(
    double width,
  ) {
    if (width <= 320) {
      return 280.0;
    }

    if (width <= 360) {
      return 300.0;
    }

    if (width <= 390) {
      return 320.0;
    }

    if (width <= 430) {
      return 350.0;
    }

    if (width <= 600) {
      return 380.0;
    }

    return 420.0;
  }

  // ===========================================================================
  // FEATURE ITEM WIDTH
  // ===========================================================================

  double _featureItemWidth(
    double width,
  ) {
    if (width <= 320) {
      return 120.0;
    }

    if (width <= 360) {
      return 130.0;
    }

    if (width <= 390) {
      return 140.0;
    }

    if (width <= 430) {
      return 150.0;
    }

    return 170.0;
  }

  // ===========================================================================
  // FEATURE ROW SPACING
  // ===========================================================================

  double _featureRowSpacing(
    double width,
  ) {
    if (width <= 320) {
      return 18.0;
    }

    if (width <= 360) {
      return 20.0;
    }

    if (width <= 390) {
      return 22.0;
    }

    if (width <= 430) {
      return 24.0;
    }

    return 28.0;
  }

  // ===========================================================================
  // FEATURE ICON / TEXT SPACING
  // ===========================================================================

  double _featureIconTextSpacing(
    double width,
  ) {
    return (width / 390 * 3).clamp(
      2.0,
      5.0,
    );
  }

  // ===========================================================================
  // LANGUAGE TOP SPACING
  // ===========================================================================

  double _languageTopSpacing(
    double width,
    double height,
  ) {
    /*
     * Gives the white section proper breathing room below the curve
     * instead of crowding "Choose Language" right up against it.
     */

    if (height < 600) {
      return 20.0;
    }

    if (width <= 320) {
      return 28.0;
    }

    if (width <= 390) {
      return 32.0;
    }

    if (width <= 430) {
      return 36.0;
    }

    return 40.0;
  }

  // ===========================================================================
  // LANGUAGE TITLE SIZE
  // ===========================================================================

  double _languageTitleSize(
    double width,
  ) {
    if (width <= 320) {
      return 20.0;
    }

    if (width <= 360) {
      return 21.0;
    }

    if (width <= 390) {
      return 22.0;
    }

    if (width <= 430) {
      return 23.0;
    }

    return 25.0;
  }

  // ===========================================================================
  // TITLE / BUTTON SPACING
  // ===========================================================================

  double _titleButtonSpacing(
    double width,
    double height,
  ) {
    if (height < 600) {
      return 20.0;
    }

    if (width <= 360) {
      return 32.0;
    }

    if (width <= 390) {
      return 38.0;
    }

    if (width <= 430) {
      return 44.0;
    }

    return 50.0;
  }

  // ===========================================================================
  // LANGUAGE BUTTON SPACING
  // ===========================================================================

  double _languageButtonSpacing(
    double width,
  ) {
    if (width <= 320) {
      return 12.0;
    }

    if (width <= 360) {
      return 13.0;
    }

    if (width <= 390) {
      return 14.0;
    }

    if (width <= 430) {
      return 15.0;
    }

    return 18.0;
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    super.dispose();
  }
}

// =============================================================================
// RESPONSIVE RED HEADER CURVE
// =============================================================================
//
// Creates the large smooth downward curve:
//
//        RED HEADER
//
//  ┌────────────────────────┐
//  │                        │
//  │         CLARO          │
//  │                        │
//  │   FEATURES   FEATURES  │
//  │                        │
//  └───────╮          ╭─────┘
//           ╰────────╯
//
// =============================================================================

class _ResponsiveBottomArcClipper
    extends CustomClipper<Path> {
  const _ResponsiveBottomArcClipper();

  @override
  Path getClip(Size size) {
    /*
     * Slightly shallower curve than the previous version.
     *
     * This prevents the red area from looking excessively deep
     * while preserving the visual style of the reference.
     */
    final curveDepth = (size.width * 0.13).clamp(
      38.0,
      78.0,
    );

    /*
     * The side of the red header stops slightly above
     * the center of the curve.
     */
    final sideHeight =
        (size.height - curveDepth * 0.58).clamp(
      0.0,
      size.height,
    );

    final path = Path();

    // =========================================================================
    // TOP LEFT
    // =========================================================================

    path.moveTo(
      0,
      0,
    );

    // =========================================================================
    // TOP EDGE
    // =========================================================================

    path.lineTo(
      size.width,
      0,
    );

    // =========================================================================
    // RIGHT SIDE
    // =========================================================================

    path.lineTo(
      size.width,
      sideHeight,
    );

    // =========================================================================
    // RIGHT CURVE
    // =========================================================================

    path.quadraticBezierTo(
      size.width * 0.76,
      size.height,
      size.width * 0.50,
      size.height,
    );

    // =========================================================================
    // LEFT CURVE
    // =========================================================================

    path.quadraticBezierTo(
      size.width * 0.24,
      size.height,
      0,
      sideHeight,
    );

    // =========================================================================
    // CLOSE
    // =========================================================================

    path.close();

    return path;
  }

  @override
  bool shouldReclip(
    covariant _ResponsiveBottomArcClipper oldClipper,
  ) {
    return false;
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
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final path = Path();

    final horizontalLength = size.width;

    final verticalLength = size.height;

    // =========================================================================
    // TOP LEFT
    // =========================================================================

    if (top && left) {
      path.moveTo(
        0,
        verticalLength,
      );

      path.lineTo(
        0,
        0,
      );

      path.lineTo(
        horizontalLength,
        0,
      );
    }

    // =========================================================================
    // TOP RIGHT
    // =========================================================================

    else if (top && !left) {
      path.moveTo(
        0,
        0,
      );

      path.lineTo(
        horizontalLength,
        0,
      );

      path.lineTo(
        horizontalLength,
        verticalLength,
      );
    }

    // =========================================================================
    // BOTTOM LEFT
    // =========================================================================

    else if (!top && left) {
      path.moveTo(
        0,
        0,
      );

      path.lineTo(
        0,
        verticalLength,
      );

      path.lineTo(
        horizontalLength,
        verticalLength,
      );
    }

    // =========================================================================
    // BOTTOM RIGHT
    // =========================================================================

    else {
      path.moveTo(
        0,
        verticalLength,
      );

      path.lineTo(
        horizontalLength,
        verticalLength,
      );

      path.lineTo(
        horizontalLength,
        0,
      );
    }

    canvas.drawPath(
      path,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _CornerPainter oldDelegate,
  ) {
    return oldDelegate.color != color ||
        oldDelegate.thickness != thickness ||
        oldDelegate.top != top ||
        oldDelegate.left != left;
  }
}