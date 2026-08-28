// lib/widgets/ranked_product_card.dart
//
// Single source of truth for the ranked-product list card, shown on BOTH:
//   - compare_products_screen.dart  (Product Detail -> Compare)
//   - multi_scan_results_screen.dart (Scan Screen -> multiple products)
//
// Both screens display a RankedProductResult list but source/rank their
// products differently (recognized-from-scan vs. similar-from-database).
// This widget only owns the PRESENTATION of a single ranked row so the two
// screens stay visually identical without duplicating layout code that
// could drift out of sync -- same pattern as RankLabelHelper.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models/ranked_product_result.dart';
import '../core/utils/rank_label_helper.dart';

class RankedProductCard extends StatelessWidget {
  final RankedProductResult ranked;
  final bool isCurrent;
  final VoidCallback onTap;
  final int? quantity;

  const RankedProductCard({
    super.key,
    required this.ranked,
    required this.onTap,
    this.isCurrent = false,
    this.quantity,
  });

  Color _labelColor() => RankLabelHelper.color(
        rank: ranked.rank,
        suitabilityRankLabel: ranked.suitabilityRankLabel,
      );

  String _labelText() => RankLabelHelper.label(
        rank: ranked.rank,
        suitabilityRankLabel: ranked.suitabilityRankLabel,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final product = ranked.evaluation.product;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: isCurrent
              ? Border.all(color: colorScheme.primary.withOpacity(0.5), width: 1.5)
              : Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        // Layout:
        //   Row 1: rank badge -> product image -> product name (top-aligned
        //          beside the image, with grams/badge underneath the name).
        //   Row 2: calories / protein / sodium mini-stats, spanning the full
        //          card width directly under the image+name group so it
        //          lines up with the image's left edge, not the rank badge.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Rank badge (its own column so it never gets squeezed by
            // long product names / locales, and stays vertically centered
            // against the image + text + nutrition block beside it).
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _labelColor().withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: _labelColor()),
              ),
              child: Text(
                '${ranked.rank}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _labelColor(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Everything else: image+name up top, nutrition stats below.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image + name/grams/badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 64,
                          height: 64,
                          color: colorScheme.surfaceContainerHighest,
                          child: product.imageUrl.isNotEmpty
                              ? Image.network(
                                  product.imageUrl,
                                  fit: BoxFit.cover,
                                  cacheWidth: 150,
                                  cacheHeight: 150,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => Icon(
                                      Icons.inventory_2_outlined,
                                      color: colorScheme.primary,
                                      size: 28),
                                )
                              : Icon(Icons.inventory_2_outlined,
                                  color: colorScheme.primary, size: 28),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Product name + grams/badge, beside the image
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Product name (without quantity suffix)
                            Text(
                              product.name,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            // Grams + badge -- wrap so a long serving-size
                            // string or translated badge label can't force
                            // a RenderFlex overflow on narrow screens.
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  product.nutritionalFacts.servingSize,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _labelColor().withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _labelText(),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _labelColor(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Nutrition quick-stats row, under the image. Uses icons
                  // instead of text labels ("Calories"/"Protein"/"Sodium")
                  // -- those labels (especially translated ones) were the
                  // widest part of this row and pushed it past the
                  // available width inside the card, causing a RenderFlex
                  // overflow. A fixed-size icon can't grow with
                  // locale/text-scale the way a label can, so it keeps this
                  // row a predictable width. Wrap (rather than Row) lets it
                  // fall onto a second line instead of overflowing if the
                  // card is ever squeezed narrower than usual.
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      _miniStatImage(context, 'assets/images/calorie.png',
                          product.nutritionalFacts.calories),
                      _miniStatImage(context, 'assets/images/protein.png',
                          product.nutritionalFacts.protein),
                      _miniStatImage(context, 'assets/images/sodium.png',
                          product.nutritionalFacts.sodium),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(BuildContext context, IconData icon, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: colorScheme.onSurfaceVariant.withOpacity(0.75)),
        const SizedBox(width: 3),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _miniStatImage(BuildContext context, String assetPath, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          assetPath,
          width: 12,
          height: 12,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to icon if image fails to load
            return Icon(
              Icons.error_outline,
              size: 12,
              color: colorScheme.onSurfaceVariant.withOpacity(0.75),
            );
          },
        ),
        const SizedBox(width: 3),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}