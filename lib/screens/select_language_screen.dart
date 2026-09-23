import 'package:flutter/material.dart';
import '../generated/l10n/app_localizations.dart';
import '../services/haptic_service.dart';
import '../services/locale_service.dart';
import '../core/utils/success_feedback_utils.dart';
import '../widgets/dome_clipper.dart';
import '../widgets/onboarding_page_dots.dart';
import '../main.dart';

/// CLARO Select Language Screen
///
/// Layout (top to bottom):
/// 1. Red dome header with the logo, wordmark and a short tagline.
/// 2. A short, auto-advancing "How CLARO works" intro tutorial
///    (4 steps: scan, nutrition, health guidance, compare). It is a
///    story-style walkthrough -- step counter, progress segments,
///    swipeable -- and intentionally NOT styled like buttons/cards.
/// 3. "Choose language" title + reassurance line.
/// 4. Two selectable language cards (English / Tagalog).
/// 5. Page dots (page 2 of 2 of the welcome flow).
///
/// FUNCTIONALITY PRESERVED:
/// - English -> _select('en')
/// - Tagalog -> _select('tl')
/// - LocaleService.setAppLocale(code)
/// - HapticService().vibrate()
/// - Navigation to AuthGate after selection
/// - Page dot hand-off with the dome transition
class SelectLanguageScreen extends StatefulWidget {
  const SelectLanguageScreen({super.key});

  @override
  State<SelectLanguageScreen> createState() => _SelectLanguageScreenState();
}

class _SelectLanguageScreenState extends State<SelectLanguageScreen>
    with TickerProviderStateMixin {
  // ===========================================================================
  // COLORS
  // ===========================================================================

  static const Color _background = Colors.white;
  static const Color _red = Color(0xFF8B1A1A);
  static const Color _redLight = Color(0xFF9E2424);
  static const Color _black = Color(0xFF171717);
  static const Color _grey = Color(0xFF6B6B6B);
  static const Color _band = Color(0xFFFFF7F5);
  static const Color _tint = Color(0xFFF7E4E1);

  // ===========================================================================
  // LAYOUT
  // ===========================================================================

  /// One consistent side margin for every block on the screen.
  static const double _sideMargin = 24.0;
  static const double _maxContentWidth = 520.0;

  // ===========================================================================
  // STATE
  // ===========================================================================

  /// Language code currently being saved (null when idle).
  String? _savingCode;
  bool get _isSaving => _savingCode != null;

  // Entrance animation (staggered fade + slide up).
  late final AnimationController _entrance;
  bool _entranceScheduled = false;

  // Intro tutorial (story-style auto-advance).
  static const Duration _slideDuration = Duration(milliseconds: 4200);
  late final PageController _tutorialPager;
  late final AnimationController _tutorialProgress;
  int _slide = 0;

  static const List<IconData> _slideIcons = [
    Icons.qr_code_scanner,
    Icons.favorite_border,
    Icons.add_circle_outline,
    Icons.compare_arrows,
  ];

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _tutorialPager = PageController();

    _tutorialProgress = AnimationController(
      vsync: this,
      duration: _slideDuration,
    )..addStatusListener((status) {
        if (status != AnimationStatus.completed || !mounted) return;
        final next = (_slide + 1) % _slideIcons.length;
        if (next == 0) {
          _tutorialPager.animateToPage(
            0,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOutCubic,
          );
        } else {
          _tutorialPager.nextPage(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
          );
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceScheduled) return;
    _entranceScheduled = true;

    // When this screen is shown through the dome transition, wait until the
    // dome has mostly settled before revealing the content, so the entrance
    // animation is actually seen instead of playing while still hidden.
    final Animation<double>? routeAnimation =
        ModalRoute.of(context)?.animation;

    if (routeAnimation == null || routeAnimation.isCompleted) {
      _startAnimations();
      return;
    }

    void listener() {
      if (routeAnimation.value >= 0.55) {
        routeAnimation.removeListener(listener);
        _startAnimations();
      }
    }

    routeAnimation.addListener(listener);
  }

  void _startAnimations() {
    if (!mounted) return;
    _entrance.forward();
    _tutorialProgress.forward(from: 0);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _tutorialProgress.dispose();
    _tutorialPager.dispose();
    super.dispose();
  }

  // ===========================================================================
  // LANGUAGE SELECTION
  // ===========================================================================

  Future<void> _select(String code) async {
    if (_isSaving) return;

    final dialogContext = context;
    final loc = AppLocalizations.of(dialogContext)!;
    final hasInternet = await SuccessFeedbackUtils.hasInternetConnection();
    if (!hasInternet) {
      if (dialogContext.mounted) {
        await SuccessFeedbackUtils.showOfflineNoticeDialog(
          dialogContext,
          title: loc.noInternetTitle,
          message: loc.noInternetActionMessage,
          buttonText: loc.gotIt,
        );
      }
      return;
    }

    setState(() {
      _savingCode = code;
    });

    HapticService().vibrate();

    await LocaleService.setAppLocale(code);

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AuthGate(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
        (route) => false,
      );
    }
  }

  // ===========================================================================
  // COPY (kept local so no generated l10n files need to change)
  // ===========================================================================

  bool get _isTagalog =>
      Localizations.localeOf(context).languageCode == 'tl';

  String get _tagline => _isTagalog
      ? 'Alamin ang laman ng iyong pagkain'
      : "Know what's in your food";

  String get _howItWorks =>
      _isTagalog ? 'PAANO GUMAGANA ANG CLARO' : 'HOW CLARO WORKS';

  String get _changeLater => _isTagalog
      ? 'Mababago mo ito mamaya sa Settings.'
      : 'You can change this later in Settings.';

  String _stepLabel(int i) => _isTagalog
      ? 'HAKBANG ${i + 1} NG ${_slideIcons.length}'
      : 'STEP ${i + 1} OF ${_slideIcons.length}';

  String _slideTitle(int i) {
    const en = [
      'Scan any product',
      'Understand the nutrition',
      'Get health guidance',
      'Compare products',
    ];
    const tl = [
      'I-scan ang produkto',
      'Alamin ang nutrisyon',
      'Gabay sa kalusugan',
      'Ihambing ang mga produkto',
    ];
    return (_isTagalog ? tl : en)[i];
  }

  String _slideBody(int i) {
    const en = [
      'Point your camera at local canned food or instant noodles to view its info',
      'See calories, sugar, sodium, FDA registration status, and more.',
      'Advice matched to your health conditions and allergens, explained simply.',
      'Scan up to 3 products at once and see the recommended one.',
    ];
    const tl = [
      'Itutok ang camera sa delata o instant noodles upang makita ang impormasyon nito',
      'Tingnan ang calories, asukal, sodium, FDA registration status, at iba pa.',
      'Payong angkop sa iyong kondisyon at allergen sa simpleng paliwanag.',
      'Maaaring mag-iscan ng mahigit 3 produkto at makita ang mas bagay sa kalagayan mo',
    ];
    return (_isTagalog ? tl : en)[i];
  }

  // ===========================================================================
  // ENTRANCE HELPER
  // ===========================================================================

  Widget _reveal({
    required double start,
    required double end,
    required Widget child,
    double dy = 22,
  }) {
    final curved = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) {
        return Opacity(
          opacity: curved.value,
          child: Transform.translate(
            offset: Offset(0, (1 - curved.value) * dy),
            child: child,
          ),
        );
      },
    );
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
            data: mediaQuery.copyWith(textScaler: TextScaler.noScaling),
            child: Scaffold(
              backgroundColor: _background,
              resizeToAvoidBottomInset: true,
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;

                  final safeBottom = mediaQuery.padding.bottom > 0
                      ? mediaQuery.padding.bottom
                      : mediaQuery.viewPadding.bottom;
                  final bottomSpacing = (height * 0.05).clamp(28.0, 56.0);
                  final adjustedBottomSpacing =
                      height < 650 ? 30.0 : bottomSpacing;

                  // Same position the dome transition uses for its dots.
                  final dotsBottomInset = adjustedBottomSpacing + safeBottom;

                  // Room reserved at the end of the scroll content so the
                  // language cards never sit underneath the page dots.
                  final dotsReserve = dotsBottomInset + 7 + 18;

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildBody(loc, width, height, dotsReserve),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: dotsBottomInset,
                        child: Center(
                          // Hidden while the dome transition runs -- the
                          // transition draws the animated indicator itself.
                          child: Opacity(
                            opacity:
                                OnboardingDotsTransitionScope.isHidden(context)
                                    ? 0.0
                                    : 1.0,
                            child: const OnboardingPageDots.onLight(
                              activeIndex: 1,
                            ),
                          ),
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

  Widget _buildBody(
    AppLocalizations loc,
    double width,
    double height,
    double dotsReserve,
  ) {
    final headerHeight = (height * 0.32).clamp(220.0, 290.0);

    // Spare vertical space on tall screens is spread between sections
    // instead of piling up as a big empty gap above the page dots.
    final double spare = (height - 720).clamp(0.0, 90.0);
    final double gap = spare / 3;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Column(
          children: [
            _buildHeader(width, headerHeight),
            _reveal(
              start: 0.15,
              end: 0.6,
              child: _buildTutorial(width),
            ),
            SizedBox(height: 22 + gap),
            _reveal(
              start: 0.3,
              end: 0.75,
              child: _buildLanguageTitle(loc, width),
            ),
            SizedBox(height: 18 + gap),
            _buildLanguageCards(loc, width),
            SizedBox(height: dotsReserve),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // RED HEADER
  // ===========================================================================

  Widget _buildHeader(double width, double height) {
    return ClipPath(
      clipper: const StandardDomeClipper(isTop: true),
      child: Container(
        width: double.infinity,
        height: height,
        decoration: const BoxDecoration(
          // Subtle depth: slightly lighter at the top, brand red at the curve.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_redLight, _red],
          ),
        ),
        child: SafeArea(
          top: true,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: (height * 0.14).clamp(24.0, 44.0),
            ),
            child: Center(
              child: _reveal(
                start: 0.0,
                end: 0.45,
                dy: 12,
                child: _buildLogo(width),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(double width) {
    final logoSize = (width * 0.34).clamp(104.0, 150.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/whiteBorderLogo.png',
          height: logoSize,
          width: logoSize,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) {
            return Icon(
              Icons.qr_code_scanner,
              color: Colors.white,
              size: logoSize * 0.78,
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          'CLARO',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: (width / 390 * 17).clamp(15.0, 21.0),
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.3,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _tagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: (width / 390 * 12.5).clamp(11.0, 14.0),
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.85),
            height: 1.1,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // INTRO TUTORIAL
  // ===========================================================================
  //
  // Deliberately flat: no borders, no shadows, no rounded "tap targets".
  // It reads as a mini walkthrough -- a section label, a step counter,
  // an illustration, a title + explanation, and story-style progress
  // segments -- rather than four buttons.

  Widget _buildTutorial(double width) {
    return Container(
      width: double.infinity,
      color: _band,
      padding: const EdgeInsets.fromLTRB(_sideMargin, 14, _sideMargin, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section label with hairline
              Row(
                children: [
                  Text(
                    _howItWorks,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: _red,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: _red.withValues(alpha: 0.18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Slides
              SizedBox(
                height: 96,
                child: PageView.builder(
                  controller: _tutorialPager,
                  itemCount: _slideIcons.length,
                  onPageChanged: (i) {
                    setState(() => _slide = i);
                    // Restart the progress for the newly visible step
                    // (also covers manual swipes).
                    _tutorialProgress.forward(from: 0);
                  },
                  itemBuilder: (context, i) => _buildSlide(i),
                ),
              ),
              const SizedBox(height: 12),

              // Story-style progress segments
              _buildProgressSegments(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(int i) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Illustration: soft rings + icon, with the step number as a badge.
        SizedBox(
          width: 84,
          height: 84,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _tint.withValues(alpha: 0.55),
                ),
              ),
              Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _tint,
                ),
                child: Icon(_slideIcons[i], color: _red, size: 30),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _red,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _stepLabel(i),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: _red.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _slideTitle(i),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: _black,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _slideBody(i),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: _grey,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSegments() {
    return AnimatedBuilder(
      animation: _tutorialProgress,
      builder: (context, _) {
        return Row(
          children: List.generate(_slideIcons.length, (i) {
            final double fill = i < _slide
                ? 1.0
                : (i == _slide ? _tutorialProgress.value : 0.0);

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: i == _slideIcons.length - 1 ? 0 : 6,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(
                    children: [
                      Container(
                        height: 3,
                        color: _red.withValues(alpha: 0.15),
                      ),
                      FractionallySizedBox(
                        widthFactor: fill,
                        child: Container(height: 3, color: _red),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // ===========================================================================
  // LANGUAGE TITLE
  // ===========================================================================

  Widget _buildLanguageTitle(AppLocalizations loc, double width) {
    return Column(
      children: [
        Text(
          loc.chooseLanguage,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: (width / 390 * 22).clamp(20.0, 25.0),
            fontWeight: FontWeight.w700,
            color: _black,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 56,
          height: 3,
          decoration: BoxDecoration(
            color: _red,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _sideMargin),
          child: Text(
            _changeLater,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: _grey,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // LANGUAGE CARDS
  // ===========================================================================

  Widget _buildLanguageCards(AppLocalizations loc, double width) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _sideMargin),
          child: Column(
            children: [
              _reveal(
                start: 0.45,
                end: 0.9,
                child: _LanguageCard(
                  badge: 'EN',
                  imageAsset: 'assets/images/en.png',
                  label: loc.english,
                  subtitle: 'Continue in English',
                  loading: _savingCode == 'en',
                  enabled: !_isSaving,
                  onTap: () => _select('en'),
                ),
              ),
              const SizedBox(height: 12),
              _reveal(
                start: 0.55,
                end: 1.0,
                child: _LanguageCard(
                  badge: 'TL',
                  imageAsset: 'assets/images/tl.png',
                  label: loc.tagalog,
                  subtitle: 'Magpatuloy sa Tagalog',
                  loading: _savingCode == 'tl',
                  enabled: !_isSaving,
                  onTap: () => _select('tl'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// LANGUAGE CARD
// =============================================================================
//
// White selectable card: circular badge, language name + native subtitle,
// chevron (or a spinner while saving). Scales down slightly while pressed.

class _LanguageCard extends StatefulWidget {
  final String badge;

  /// Icon shown in the circular badge. Falls back to the [badge] letters
  /// if the image cannot be loaded.
  final String imageAsset;
  final String label;
  final String subtitle;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.badge,
    required this.imageAsset,
    required this.label,
    required this.subtitle,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_LanguageCard> createState() => _LanguageCardState();
}

class _LanguageCardState extends State<_LanguageCard> {
  static const Color _red = Color(0xFF8B1A1A);
  static const Color _black = Color(0xFF171717);
  static const Color _grey = Color(0xFF6B6B6B);

  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool dimmed = !widget.enabled && !widget.loading;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: dimmed ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _red.withValues(alpha: _pressed ? 0.06 : 0.12),
                blurRadius: _pressed ? 6 : 14,
                offset: Offset(0, _pressed ? 2 : 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFEBD6D3)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.enabled ? widget.onTap : null,
              onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
              onTapUp: (_) => _setPressed(false),
              onTapCancel: () => _setPressed(false),
              splashColor: _red.withValues(alpha: 0.08),
              highlightColor: _red.withValues(alpha: 0.04),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    // Language icon
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF7E4E1),
                        border: Border.all(
                          color: const Color(0xFFEBD6D3),
                          width: 1,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          widget.imageAsset,
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: _red,
                            alignment: Alignment.center,
                            child: Text(
                              widget.badge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Names
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.label,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: _black,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: _grey,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Trailing: spinner while saving, chevron otherwise
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: widget.loading
                          ? const Padding(
                              padding: EdgeInsets.all(4),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: _red,
                              ),
                            )
                          : Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFF7E4E1),
                              ),
                              child: const Icon(
                                Icons.chevron_right_rounded,
                                color: _red,
                                size: 22,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}