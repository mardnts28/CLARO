import 'package:flutter/material.dart';

/// Standardized Red Dome Clipper used by both GetStartedScreen (bottom dome)
/// and SelectLanguageScreen (top header dome).
class StandardDomeClipper extends CustomClipper<Path> {
  final bool isTop;
  final double? customPeakY;
  final double? customSideY;

  const StandardDomeClipper({
    required this.isTop,
    this.customPeakY,
    this.customSideY,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final double curveDepth = (size.width * 0.14).clamp(42.0, 78.0);

    if (isTop) {
      // Top dome (Select Language header): fills from top y=0 down to curve
      final double peakY = customPeakY ?? size.height;
      final double sideY = customSideY ?? (peakY - curveDepth);

      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, sideY.clamp(0.0, size.height));
      path.quadraticBezierTo(
        size.width * 0.75,
        peakY,
        size.width * 0.5,
        peakY,
      );
      path.quadraticBezierTo(
        size.width * 0.25,
        peakY,
        0,
        sideY.clamp(0.0, size.height),
      );
      path.close();
    } else {
      // Bottom dome (Get Started welcome screen): fills from curve down to y=size.height
      final double peakY = customPeakY ?? (size.height * 0.49);
      final double sideY = customSideY ?? (peakY + curveDepth);

      path.moveTo(0, sideY);
      path.quadraticBezierTo(
        size.width * 0.25,
        peakY,
        size.width * 0.5,
        peakY,
      );
      path.quadraticBezierTo(
        size.width * 0.75,
        peakY,
        size.width,
        sideY,
      );
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
    }

    return path;
  }

  @override
  bool shouldReclip(covariant StandardDomeClipper oldClipper) {
    return oldClipper.isTop != isTop ||
        oldClipper.customPeakY != customPeakY ||
        oldClipper.customSideY != customSideY;
  }
}
