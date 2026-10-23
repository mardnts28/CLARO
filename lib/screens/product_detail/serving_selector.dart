// lib/screens/product_detail/serving_selector.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable dropdown widget allowing the user to select between available serving sizes
/// (e.g. 100g, 155g, 200g) for a product.
class ServingSelector extends StatelessWidget {
  final double selectedSizeG;
  final List<double> availableSizes;
  final ValueChanged<double> onSizeChanged;

  const ServingSelector({
    super.key,
    required this.selectedSizeG,
    required this.availableSizes,
    required this.onSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double>(
          value: selectedSizeG,
          isDense: true,
          icon: Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          items: availableSizes.map((size) {
            final label = size == size.roundToDouble()
                ? '${size.toInt()}g'
                : '${size.toStringAsFixed(1)}g';
            return DropdownMenuItem<double>(
              value: size,
              child: Text(label),
            );
          }).toList(),
          onChanged: (newSize) {
            if (newSize != null) {
              onSizeChanged(newSize);
            }
          },
        ),
      ),
    );
  }
}
