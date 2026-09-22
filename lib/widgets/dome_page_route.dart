import 'package:flutter/material.dart';

/// Tracks, per-Animation, whether [_attachCompletionListenerOnce] has
/// already added its status listener.
///
/// This lives at the top level (not as an instance field/method on
/// [DomeTransitionPageRoute]) because the transition callback below is
/// built inside the route's constructor initializer list (as part of the
/// `super(...)` call), where Dart does not allow accessing `this` --
/// including implicit `this` access via an instance method call.
final Expando<bool> _domeTransitionListenerAttached = Expando<bool>();

/// Adds a one-time "animation finished" listener to [animation], calling
/// [callback] when it completes. Safe to call on every build/frame -- it
/// only ever attaches once per [animation] instance.
void _attachCompletionListenerOnce(
  Animation<double> animation,
  VoidCallback callback,
) {
  if (_domeTransitionListenerAttached[animation] == true) return;
  _domeTransitionListenerAttached[animation] = true;
  animation.addStatusListener((status) {
    if (status == AnimationStatus.completed) {
      callback();
    }
  });
}

/// Custom PageRouteBuilder that animates the red dome from the bottom of
/// GetStartedScreen to the top of SelectLanguageScreen in 1400ms with
/// Curves.easeInOutCubic for a slow, smooth glide.
class DomeTransitionPageRoute<T> extends PageRouteBuilder<T> {
  final Widget exitPage;
  final Widget enterPage;

  /// Called once the forward transition animation finishes playing.
  ///
  /// Use this (instead of firing state changes before `Navigator.push`)
  /// for any side effect that itself causes the underlying route stack to
  /// rebuild — e.g. flipping a flag that a declarative root widget listens
  /// to. If such a flag flips *before* this animated push completes, the
  /// widget underneath can swap instantly and make this whole transition
  /// invisible.
  final VoidCallback? onAnimationComplete;

  DomeTransitionPageRoute({
    required this.exitPage,
    required this.enterPage,
    this.onAnimationComplete,
  }) : super(
          transitionDuration: const Duration(milliseconds: 1400),
          reverseTransitionDuration: const Duration(milliseconds: 1400),
          pageBuilder: (context, animation, secondaryAnimation) => enterPage,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (onAnimationComplete != null) {
              _attachCompletionListenerOnce(animation, onAnimationComplete);
            }

            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
              reverseCurve: Curves.easeInOutCubic,
            );

            return AnimatedBuilder(
              animation: curvedAnimation,
              builder: (context, child) {
                final double t = curvedAnimation.value;
                final size = MediaQuery.of(context).size;
                final double height = size.height;
                final double width = size.width;

                const Color primaryRed = Color(0xFF8B1A1A);

                // Get Started dome initial boundaries: peak at 0.49*H, side at 0.625*H
                final double startPeakY = height * 0.49;
                final double startSideY = height * 0.625;

                // Select Language dome target boundaries: header height ~0.46*H
                final double targetHeaderHeight = (height * 0.46).clamp(260.0, 470.0);
                final double curveDepth = (width * 0.14).clamp(42.0, 78.0);
                final double targetPeakY = targetHeaderHeight;
                final double targetSideY = targetHeaderHeight - curveDepth;

                // Fade timing: exit page fades out early (0.0 to 0.4), enter page fades in (0.3 to 1.0)
                final double exitOpacity = (1.0 - (t / 0.45)).clamp(0.0, 1.0);
                final double enterOpacity = ((t - 0.25) / 0.75).clamp(0.0, 1.0);
                final double enterSlideY = (1.0 - enterOpacity) * 24.0;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Base background
                    const ColoredBox(color: Colors.white),

                    // Exit screen content (GetStartedScreen elements fading out)
                    Opacity(
                      opacity: exitOpacity,
                      child: exitPage,
                    ),

                    // Animated Red Dome connecting both screens
                    Positioned.fill(
                      child: ClipPath(
                        clipper: _TransitionDomeClipper(
                          progress: t,
                          startPeakY: startPeakY,
                          startSideY: startSideY,
                          targetPeakY: targetPeakY,
                          targetSideY: targetSideY,
                        ),
                        child: Container(color: primaryRed),
                      ),
                    ),

                    // Enter screen content (SelectLanguageScreen elements fading in & sliding up)
                    Opacity(
                      opacity: enterOpacity,
                      child: Transform.translate(
                        offset: Offset(0, enterSlideY),
                        child: enterPage,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
}

/// Custom Clipper used during the dome-morph transition between Get Started
/// and Select Language.
class _TransitionDomeClipper extends CustomClipper<Path> {
  final double progress;
  final double startPeakY;
  final double startSideY;
  final double targetPeakY;
  final double targetSideY;

  const _TransitionDomeClipper({
    required this.progress,
    required this.startPeakY,
    required this.startSideY,
    required this.targetPeakY,
    required this.targetSideY,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final double curveDepth = (size.width * 0.14).clamp(42.0, 78.0);

    if (progress < 0.5) {
      // First half of animation: dome moves up from bottom
      final double lerpT = progress / 0.5;
      final double currentPeakY = startPeakY - (startPeakY * 0.3) * lerpT;
      final double currentSideY = currentPeakY + curveDepth;

      path.moveTo(0, currentSideY);
      path.quadraticBezierTo(
        size.width * 0.25,
        currentPeakY,
        size.width * 0.5,
        currentPeakY,
      );
      path.quadraticBezierTo(
        size.width * 0.75,
        currentPeakY,
        size.width,
        currentSideY,
      );
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
    } else {
      // Second half of animation: dome resolves into top-down header shape
      final double lerpT = (progress - 0.5) / 0.5;
      final double currentPeakY = targetPeakY + (size.height * 0.2) * (1.0 - lerpT);
      final double currentSideY = currentPeakY - curveDepth;

      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, currentSideY.clamp(0.0, size.height));
      path.quadraticBezierTo(
        size.width * 0.75,
        currentPeakY,
        size.width * 0.5,
        currentPeakY,
      );
      path.quadraticBezierTo(
        size.width * 0.25,
        currentPeakY,
        0,
        currentSideY.clamp(0.0, size.height),
      );
      path.close();
    }

    return path;
  }

  @override
  bool shouldReclip(covariant _TransitionDomeClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}