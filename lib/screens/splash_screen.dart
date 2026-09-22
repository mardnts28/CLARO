import 'dart:ui';
import 'package:flutter/material.dart';

/// CLARO Animated Launch / Loading Screen
///
/// Animation behavior:
/// - Scanner corners (logo-border.png) continuously pulse (zoom in and out subtly).
/// - Sardine can (logo-can.png) starts faint and blurred, gradually unblurring
///   and fading into full visibility.
/// - Once fully visible, performs 1-2 final subtle scanner pulses before
///   notifying initialization completion.
class SplashScreen extends StatefulWidget {
  final VoidCallback onInitializationComplete;

  const SplashScreen({
    super.key,
    required this.onInitializationComplete,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _focusController;

  late final Animation<double> _pulseAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Continuous subtle scanner corners pulse (zoom in/out)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // 2. Sardine can detection (faint & blurred -> clear & fully visible)
    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _focusController,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
      ),
    );

    _blurAnimation = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _focusController,
        curve: const Interval(0.1, 0.9, curve: Curves.easeOut),
      ),
    );

    _runSplashSequence();
  }

  Future<void> _runSplashSequence() async {
    // Start detection unblur & fade-in animation
    _focusController.forward();

    // Minimum splash duration: ~1.5s (allows detection animation + 1-2 final scanner pulses)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      widget.onInitializationComplete();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _focusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double frameSize = (size.width * 0.35).clamp(120.0, 180.0);
    final double canSize = frameSize * 0.72;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: frameSize,
              height: frameSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Red scanner corners continuously pulsing
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: child,
                      );
                    },
                    child: Image.asset(
                      'assets/images/logo-launch/logo-border.png',
                      width: frameSize,
                      height: frameSize,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),

                  // Sardine can fading and unblurring into view
                  AnimatedBuilder(
                    animation: _focusController,
                    builder: (context, child) {
                      final double blurValue = _blurAnimation.value;
                      final double opacityValue = _opacityAnimation.value;

                      Widget canWidget = Image.asset(
                        'assets/images/logo-launch/logo-can.png',
                        width: canSize,
                        height: canSize,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      );

                      if (blurValue > 0.05) {
                        canWidget = ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: blurValue,
                            sigmaY: blurValue,
                          ),
                          child: canWidget,
                        );
                      }

                      return Opacity(
                        opacity: opacityValue,
                        child: canWidget,
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'CLARO',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF8B1A1A),
                letterSpacing: 2.0,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
