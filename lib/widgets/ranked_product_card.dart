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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column: Rank badge + Product image
            Column(
              children: [
                // Rank badge
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
                const SizedBox(height: 8),
                // Product image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 52,
                    height: 52,
                    color: colorScheme.surfaceContainerHighest,
                    child: product.imageUrl.isNotEmpty
                        ? Image.network(
                            product.imageUrl,
                            fit: BoxFit.cover,
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
                                size: 26),
                          )
                        : Icon(Icons.inventory_2_outlined,
                            color: colorScheme.primary, size: 26),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Right column: Product name + grams/badge + nutrition
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 4),
                  // Grams + badge
                  Row(
                    children: [
                      Text(
                        product.nutritionalFacts.servingSize,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  const SizedBox(height: 6),
                  // Nutrition quick-stats row
                  Row(
                    children: [
                      _miniStat(context, '⚡', product.nutritionalFacts.calories),
                      const SizedBox(width: 10),
                      _miniStat(context, '🥩', product.nutritionalFacts.protein),
                      const SizedBox(width: 10),
                      _miniStat(context, '🫙', product.nutritionalFacts.sodium),
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

  Widget _miniStat(BuildContext context, String emoji, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 2),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}