// lib/data/models/ranked_product_result.dart
//
// Phase 3 output. Wraps Phase 1's ProductEvaluation with its rank position
// and a Phase-2-generated reason, ready for direct UI rendering (Module 4.3
// "Top 3 recommended products display" + "Reason for recommendation").

import 'health_advisory.dart';
import 'product_evaluation.dart';

// Module 4.3 fixes this at "Top 3" -- not something the spec treats as
// configurable. Defined once here and imported by ProductRankingService so
// the two can never drift out of sync with each other.
const int kTopRecommendationCount = 3;

// Table 3.15's "Suitability Rank" column. Unlike the first version of this
// file, labels are now derived from POSITION within the full compared list,
// not from each product's own advisory level in isolation -- so exactly
// ONE product gets mostSuitable and exactly ONE gets leastSuitable, even if
// several products share the same underlying Suitable/Moderate/Caution
// level. "Middle" can still apply to more than one product when comparing
// 4+ items, since Table 3.15 only defines 4 categories total -- there's no
// finer-grained label to give a 3rd, 4th, 5th place distinctly. Products
// with a matching allergen are always forcedLast and excluded from the
// mostSuitable/leastSuitable positions entirely, since allergen matches are
// a safety flag, not part of the graded comparison. More than one product
// can be forcedLast at once -- that's expected, not a bug.
enum SuitabilityRankLabel { mostSuitable, middle, leastSuitable, forcedLast }

// Call this ONCE on the full sorted list from WhoCalculator.rankProducts(),
// not per-item -- the labels are only meaningful relative to the whole set.
List<SuitabilityRankLabel> computeSuitabilityRankLabels(
  List<ProductEvaluation> ranked,
) {
  final nonAllergenCount = ranked.where((e) => !e.allergenOverride).length;
  final labels = <SuitabilityRankLabel>[];
  var nonAllergenPosition = 0; // 1-based position among non-allergen items only

  for (final e in ranked) {
    if (e.allergenOverride) {
      labels.add(SuitabilityRankLabel.forcedLast);
      continue;
    }
    nonAllergenPosition++;
    if (nonAllergenPosition == 1) {
      labels.add(SuitabilityRankLabel.mostSuitable);
    } else if (nonAllergenPosition == nonAllergenCount) {
      // Covers the single-product case too: position 1 is checked first
      // above, so a lone non-allergen product always gets mostSuitable,
      // never leastSuitable.
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
  final HealthAdvisory reason; // reuses Phase 2's HealthAdvisory shape
  final SuitabilityRankLabel suitabilityRankLabel;

  const RankedProductResult({
    required this.rank,
    required this.evaluation,
    required this.reason,
    required this.suitabilityRankLabel,
  });

  bool get isTopRecommendation => rank <= kTopRecommendationCount;
}