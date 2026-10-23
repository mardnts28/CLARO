// lib/screens/product_detail/nutrition_breakdown_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/who_fda_thresholds.dart';
import '../../core/utils/number_format_utils.dart';
import '../../generated/l10n/app_localizations.dart';

/// Evaluation data for a single nutrient row (sodium, free sugar, saturated fat, etc.)
/// comparing the value per serving against WHO daily recommended limits.
class DisplayNutrientEval {
  final String label;
  final String shortLabel;
  final String nutrientKey;
  final double valuePerServing;
  final double limit;
  final double percentage;
  final AdvisoryLevel level;
  final String unit;

  DisplayNutrientEval({
    required this.label,
    required this.shortLabel,
    required this.nutrientKey,
    required this.valuePerServing,
    required this.limit,
    required this.percentage,
    required this.level,
    required this.unit,
  });
}

/// Custom painter for the triangular tip of the speech bubble on nutrition badges.
class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant TrianglePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Visual row representing a single nutrient evaluation against WHO/FDA limits.
class NutrientRowWidget extends StatelessWidget {
  final DisplayNutrientEval evaluation;
  final bool isRelatedToUserCondition;
  final ColorScheme colorScheme;
  final AppLocalizations loc;

  const NutrientRowWidget({
    super.key,
    required this.evaluation,
    this.isRelatedToUserCondition = false,
    required this.colorScheme,
    required this.loc,
  });

  String _formatValue(double val) => NumberFormatUtils.formatValue(val);

  @override
  Widget build(BuildContext context) {
    final isDark = colorScheme.brightness == Brightness.dark;
    Color progressColor;
    Color badgeBgColor;
    Color badgeTextColor;
    String badgeLabel;

    String capitalize(String s) =>
        s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;

    switch (evaluation.level) {
      case AdvisoryLevel.suitable:
        progressColor = const Color(0xFF2E7D32);
        badgeBgColor =
            isDark ? const Color(0xFF1B3320) : const Color(0xFFE8F5E9);
        badgeTextColor =
            isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
        badgeLabel = capitalize(loc.levelLow);
        break;
      case AdvisoryLevel.moderate:
        progressColor = const Color(0xFFE65100);
        badgeBgColor =
            isDark ? const Color(0xFF3A2A12) : const Color(0xFFFFF3E0);
        badgeTextColor =
            isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100);
        badgeLabel = capitalize(loc.levelMedium);
        break;
      case AdvisoryLevel.caution:
        progressColor = const Color(0xFFC62828);
        badgeBgColor =
            isDark ? const Color(0xFF3A1B1D) : const Color(0xFFFFEBEE);
        badgeTextColor =
            isDark ? const Color(0xFFE57373) : const Color(0xFFC62828);
        badgeLabel = capitalize(loc.levelHigh);
        break;
    }

    final isRelated = isRelatedToUserCondition;
    final displayLabel = isRelated ? evaluation.label : evaluation.shortLabel;
    final highlightAccentColor = isDark
        ? colorScheme.secondary
        : colorScheme.primary;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                displayLabel,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeLabel,
                style: GoogleFonts.inter(
                  color: badgeTextColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (evaluation.percentage / 100).clamp(0.0, 1.0),
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text:
                    '${_formatValue(evaluation.valuePerServing)}${evaluation.unit} / ${_formatValue(evaluation.limit)}${evaluation.unit} ${loc.dailySuffix} · ',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text:
                    '${evaluation.percentage.toStringAsFixed(0)}% ${evaluation.nutrientKey == 'sugarsG' ? loc.ofWhoFreeSugarReference : loc.ofWhoLimit}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isRelatedToUserCondition
                      ? highlightAccentColor
                      : colorScheme.onSurfaceVariant,
                  fontWeight: isRelatedToUserCondition
                      ? FontWeight.bold
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (!isRelatedToUserCondition) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: content,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: badgeBgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: content,
      ),
    );
  }
}
