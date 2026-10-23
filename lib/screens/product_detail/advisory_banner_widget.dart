// lib/screens/product_detail/advisory_banner_widget.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/who_fda_thresholds.dart';

/// Row data for displaying multiple detected allergens.
class MultiAllergenDisplayRow {
  final String allergen;
  final String ingredient;

  const MultiAllergenDisplayRow({
    required this.allergen,
    required this.ingredient,
  });
}

/// Formatted subtitle widget for health advisories that places bold/italic emphasis
/// on the final sentence containing the specific serving or intake recommendation.
class AdvisorySubtitleText extends StatelessWidget {
  final String subtitle;
  final ColorScheme colorScheme;
  final AdvisoryLevel level;

  const AdvisorySubtitleText({
    super.key,
    required this.subtitle,
    required this.colorScheme,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedSubtitle = subtitle.trim();

    // Don't apply emphasis when suitability level is Suitable
    if (level == AdvisoryLevel.suitable) {
      return Text(
        trimmedSubtitle,
        softWrap: true,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: colorScheme.onSurface,
          height: 1.4,
        ),
      );
    }

    final parts = trimmedSubtitle
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }

    if (parts.length == 1) {
      return Text(
        parts.first,
        softWrap: true,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: colorScheme.onSurface,
          height: 1.4,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final textSpans = <TextSpan>[];
    for (int i = 0; i < parts.length - 1; i++) {
      textSpans.add(
        TextSpan(
          text: '${parts[i]} ',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: colorScheme.onSurface,
            height: 1.4,
          ),
        ),
      );
    }

    textSpans.add(
      TextSpan(
        text: parts.last,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: colorScheme.onSurface,
          height: 1.4,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        ),
      ),
    );

    return Text.rich(
      TextSpan(children: textSpans),
      softWrap: true,
    );
  }
}

/// The Health Advisory Banner displayed prominently at the top of the product detail screen.
/// Summarizes suitability level, warning text, recommended intake, and condition-specific warnings.
class AdvisoryBannerWidget extends StatelessWidget {
  final AdvisoryLevel level;
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isTagalog;
  final List<MultiAllergenDisplayRow>? multiAllergenRows;
  final bool showKidneyFooterNote;
  final String? kidneyExpertAdviceText;

  const AdvisoryBannerWidget({
    super.key,
    required this.level,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isTagalog = false,
    this.multiAllergenRows,
    this.showKidneyFooterNote = false,
    this.kidneyExpertAdviceText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (multiAllergenRows != null) ...[
                  Text(
                    isTagalog ? 'Babala sa Allergen' : 'Allergen Warning',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isTagalog
                        ? 'Maraming allergen ang natukoy'
                        : 'Multiple allergen detected',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final row in multiAllergenRows!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text.rich(
                        TextSpan(
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: colorScheme.onSurface,
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              text: row.ingredient.isEmpty
                                  ? row.allergen
                                  : '${row.allergen}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (row.ingredient.isNotEmpty)
                              TextSpan(text: row.ingredient),
                          ],
                        ),
                      ),
                    ),
                ] else ...[
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AdvisorySubtitleText(
                    subtitle: subtitle,
                    colorScheme: colorScheme,
                    level: level,
                  ),
                ],
                if (showKidneyFooterNote && kidneyExpertAdviceText != null) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: color.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          kidneyExpertAdviceText!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
