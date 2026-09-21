// lib/widgets/health_info_warning_card.dart
//
// Generic, reusable "health information" warning card -- amber/orange
// informational styling (NOT the red Suitable/Moderate/Caution scoring
// used elsewhere in CLARO). Used by awareness-only conditions (GERD today;
// Kidney Disease reuses this same widget later) that surface potential
// triggers/considerations without producing a suitability verdict.
//
// Deliberately generic: no GERD-specific or Kidney-specific text lives
// here. Callers pass in the title/icon/copy/items.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// One detected item shown in the card's list, e.g. a detected trigger.
/// [detail] is optional extra context (e.g. the matched ingredient text or
/// a measured value) shown after the label.
class HealthInfoWarningItem {
  final String label;
  final String? detail;

  const HealthInfoWarningItem({required this.label, this.detail});
}

class HealthInfoWarningCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String intro;

  /// Detected items to list. Leave empty and use [neutralMessage] instead
  /// for the "no triggers found" / "not enough information" states.
  final List<HealthInfoWarningItem> items;

  /// Shown instead of/alongside [items] when there's nothing to list --
  /// e.g. "No common triggers detected" or "Not enough information".
  final String? neutralMessage;

  /// Optional expert consultation advice shown at the bottom of the card.
  final String? expertAdvice;

  const HealthInfoWarningCard({
    super.key,
    required this.title,
    required this.icon,
    required this.intro,
    this.items = const [],
    this.neutralMessage,
    this.expertAdvice,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Amber/orange informational accent -- distinct from the red used for
    // Caution elsewhere, since this card never issues a suitability
    // verdict.
    final accentColor = isDark ? Colors.orange[300]! : Colors.orange[800]!;
    final backgroundColor =
        isDark ? Colors.orange.withValues(alpha: 0.14) : Colors.orange.withValues(alpha: 0.08);
    final borderColor = accentColor.withValues(alpha: 0.5);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accentColor, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            intro,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: colorScheme.onSurface.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 6, color: accentColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: item.label,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (item.detail != null)
                              TextSpan(
                                text: ' — ${item.detail}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (neutralMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              neutralMessage!,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (expertAdvice != null) ...[
            Divider(height: 1, color: borderColor),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    expertAdvice!,
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
    );
  }
}
