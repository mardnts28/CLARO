// lib/widgets/selectable_scanned_product_card.dart
//
// Card used inside CompareProductsScreen's "Add Product" bottom sheet to
// let the user pick which freshly-scanned product(s) to fold into the
// Product Ranking list.
//
// Visual layout is intentionally the same as HistoryScreen's
// _buildScanCard (image + name in a bordered, shadowed rounded
// container) minus the timestamp line, per the Add Product spec. The
// selected/unselected treatment mirrors the existing selection styling
// used elsewhere in the app (PersonalInfoScreen's allergen selector --
// filled tint + heavier primary border -- combined with the
// checkmark-style indicator already used by CompareProductsScreen's
// filter chips), rather than inventing a new selection style.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product_model.dart';
import '../generated/l10n/app_localizations.dart';

class SelectableScannedProductCard extends StatelessWidget {
  final Product product;
  final bool selected;
  final bool alreadyRanked;
  final VoidCallback? onTap;

  const SelectableScannedProductCard({
    super.key,
    required this.product,
    required this.selected,
    this.alreadyRanked = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bool isSelected = selected && !alreadyRanked;

    return Opacity(
      opacity: alreadyRanked ? 0.55 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: alreadyRanked ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withOpacity(0.08)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : theme.dividerColor,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Product image, matching History's scan card treatment.
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
                              size: 30),
                        )
                      : Icon(Icons.inventory_2_outlined,
                          color: colorScheme.primary, size: 30),
                ),
              ),
              const SizedBox(width: 12),
              // Product name (+ "already added" note when applicable) --
              // no time/date info, per the Add Product spec.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (alreadyRanked) ...[
                      const SizedBox(height: 2),
                      Text(
                        AppLocalizations.of(context)!.alreadyInRankingLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Selection indicator -- same checkmark treatment used by
              // the filter chips on this screen (checkmarkColor:
              // colorScheme.primary), applied here to a card instead of
              // a chip.
              Icon(
                isSelected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant.withOpacity(0.4),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}