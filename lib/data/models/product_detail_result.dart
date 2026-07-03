// lib/data/models/product_detail_result.dart
//
// Everything the "solo product screen" needs in ONE object: the health
// advisory (with ranking explanation if this came from a comparison), plus
// the red/green/neutral nutrient comparison table. Bundled together
// because both are shown on the same screen at the same moment -- your UI
// layer should only need one call to get both.

import 'comparison_matrix.dart';
import 'health_advisory.dart';

class ProductDetailResult {
  final HealthAdvisory advisory;

  // Null when this product was viewed WITHOUT being compared to anything
  // (Scenario A, before the user taps Compare -- just a solo scan). Present
  // whenever 2+ products were in the comparison set this detail came from.
  final ComparisonMatrix? comparisonMatrix;

  const ProductDetailResult({
    required this.advisory,
    required this.comparisonMatrix,
  });

  bool get hasComparison => comparisonMatrix != null && !comparisonMatrix!.isEmpty;
}