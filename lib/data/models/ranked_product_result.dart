// lib/data/models/ranked_product_result.dart
//
// Free, Dart-only ranking data for the "multiple product compared
// interface" (list of names). NO Gemini call happens to produce this --
// that only happens later, per-product, when the user taps into detail
// (see ProductRankingService.getProductDetail).

import 'product_evaluation.dart';

const int kTopRecommendationCount = 3;

// Table 3.15's "Suitability Rank" column. Labels are derived from POSITION
// within the full compared list, not from each product's own advisory
// level in isolation -- exactly ONE product gets mostSuitable and exactly
// ONE gets leastSuitable, even if several share the same underlying
// Suitable/Moderate/Caution level. "Middle" can apply to more than one
// product when comparing 4+ items. Products with a matching allergen are
// always forcedLast and excluded from mostSuitable/leastSuitable entirely.
enum SuitabilityRankLabel { mostSuitable, middle, leastSuitable, forcedLast }

// Call this ONCE on the full sorted list from WhoCalculator.rankProducts(),
// not per-item -- the labels are only meaningful relative to the whole set.
List<SuitabilityRankLabel> computeSuitabilityRankLabels(
  List<ProductEvaluation> ranked,
) {
  final nonAllergenCount = ranked.where((e) => !e.allergenOverride).length;
  final labels = <SuitabilityRankLabel>[];
  var nonAllergenPosition = 0;

  for (final e in ranked) {
    if (e.allergenOverride) {
      labels.add(SuitabilityRankLabel.forcedLast);
      continue;
    }
    nonAllergenPosition++;
    if (nonAllergenPosition == 1) {
      labels.add(SuitabilityRankLabel.mostSuitable);
    } else if (nonAllergenPosition == nonAllergenCount) {
      labels.add(SuitabilityRankLabel.leastSuitable);
    } else {
      labels.add(SuitabilityRankLabel.middle);
    }
  }
  return labels;
}

class RankedProductResult {
  final int rank; // 1-based position after sorting (1 = most suitable)
  final ProductEvaluation evaluation;
  final SuitabilityRankLabel suitabilityRankLabel;

  const RankedProductResult({
    required this.rank,
    required this.evaluation,
    required this.suitabilityRankLabel,
  });

  bool get isTopRecommendation => rank <= kTopRecommendationCount;
}