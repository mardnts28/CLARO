import 'package:flutter/material.dart';

/// Shared page-dot indicator used across the onboarding flow
/// (Get Started, Select Language, Basic Information, Health Profile).
///
/// Styling is taken from the original Get Started indicator: 7px tall
/// pills with 4px horizontal margins, where the active dot is stretched
/// to 20px wide and the inactive ones are 7px wide.
///
/// [position] is a double so the indicator can be animated between pages:
/// a dot's width/colour is blended by how close [position] is to its index
/// (position 0.0 = first dot active, 1.0 = second dot active, 0.5 = halfway).
class OnboardingPageDots extends StatelessWidget {
  static const Color _red = Color(0xFF8B1A1A);

  /// Colours used on white backgrounds (Select Language, Basic Info,
  /// Health Profile).
  static const Color redActive = _red;
  static const Color redInactive = Color(0xFFE0C9C9);

  /// Colours used on the red dome (Get Started).
  static const Color whiteActive = Colors.white;
  static const Color whiteInactive = Color(0x73FFFFFF); // white @ 45%

  static const double dotHeight = 7;
  static const double dotWidth = 7;
  static const double activeWidth = 20;

  final int count;
  final double position;
  final Color activeColor;
  final Color inactiveColor;

  const OnboardingPageDots({
    super.key,
    this.count = 2,
    required this.position,
    this.activeColor = redActive,
    this.inactiveColor = redInactive,
  });

  /// Convenience for the static (non-animated) case on a white background.
  const OnboardingPageDots.onLight({
    Key? key,
    int count = 2,
    required int activeIndex,
  }) : this(key: key, count: count, position: activeIndex + 0.0);

  /// Convenience for the static case on the red dome.
  OnboardingPageDots.onDome({
    Key? key,
    int count = 2,
    required int activeIndex,
  }) : this(
          key: key,
          count: count,
          position: activeIndex + 0.0,
          activeColor: whiteActive,
          inactiveColor: whiteInactive,
        );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        // 1.0 when this dot is the active one, 0.0 when it is a full
        // page away.
        final double weight = (1.0 - (position - index).abs()).clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: dotWidth + (activeWidth - dotWidth) * weight,
          height: dotHeight,
          decoration: BoxDecoration(
            color: Color.lerp(inactiveColor, activeColor, weight),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

/// Tells the Get Started / Select Language screens that the dome page
/// transition is running and that a single shared, animated indicator is
/// being drawn by the transition itself. While [hidden] is true the
/// screens must not paint their own (static) dots, otherwise there would
/// be two overlapping indicators.
class OnboardingDotsTransitionScope extends InheritedWidget {
  final bool hidden;

  const OnboardingDotsTransitionScope({
    super.key,
    required this.hidden,
    required super.child,
  });

  static bool isHidden(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<OnboardingDotsTransitionScope>()
            ?.hidden ??
        false;
  }

  @override
  bool updateShouldNotify(OnboardingDotsTransitionScope oldWidget) {
    return oldWidget.hidden != hidden;
  }
}
