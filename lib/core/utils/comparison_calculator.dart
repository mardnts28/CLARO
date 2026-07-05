// lib/core/utils/comparison_calculator.dart
//
// Computes WHY a product ranks where it does relative to the rest of a
// compared set -- pure Dart, no AI. Same principle as ServingSizeCalculator:
// Gemini phrases the sentence, it never derives the comparison itself.

import '../../data/models/health_profile.dart';
import '../../data/models/product_evaluation.dart';
import '../constants/who_fda_thresholds.dart';
import 'who_calculator.dart';

class ComparisonFact {
  final String nutrientKey;
  final double thisValue;
  final double bestValueInSet;  // lowest per-100g value among the compared set
  final double worstValueInSet;
  final bool thisIsBest;
  final bool thisIsWorst;

  const ComparisonFact({
    required this.nutrientKey,
    required this.thisValue,
    required this.bestValueInSet,
    required this.worstValueInSet,
    required this.thisIsBest,
    required this.thisIsWorst,
  });
}

class ComparisonCalculator {
  /// One ComparisonFact per nutrient relevant to [user]'s conditions,
  /// comparing [target] against the rest of [comparisonSet] (which must
  /// include target itself).
  static List<ComparisonFact> computeFacts({
    required ProductEvaluation target,
    required List<ProductEvaluation> comparisonSet,
    required UserHealthProfile user,
  }) {
    final nutrientKeys = <String>{};
    for (final condition in user.conditions) {
      final keys = ConditionThresholds.thresholds[condition]?.keys ?? const <String>[];
      nutrientKeys.addAll(keys);
    }

    final facts = <ComparisonFact>[];
    for (final key in nutrientKeys) {
      final values = comparisonSet
          .map((e) => WhoCalculator.readNutrientValue(e.product.nutritionPer100g, key))
          .toList();

      final bestValue = values.reduce((a, b) => a < b ? a : b); // lower = better
      final worstValue = values.reduce((a, b) => a > b ? a : b);
      final thisValue = WhoCalculator.readNutrientValue(target.product.nutritionPer100g, key);

      facts.add(ComparisonFact(
        nutrientKey: key,
        thisValue: thisValue,
        bestValueInSet: bestValue,
        worstValueInSet: worstValue,
        thisIsBest: thisValue == bestValue,
        thisIsWorst: thisValue == worstValue,
      ));
    }
    return facts;
  }

  /// Picks the single most decision-useful fact to explain -- prioritizes a
  /// nutrient where this product is clearly best or worst in the set.
  static ComparisonFact? primaryFact(List<ComparisonFact> facts) {
    if (facts.isEmpty) return null;
    final best = facts.where((f) => f.thisIsBest);
    if (best.isNotEmpty) return best.first;
    final worst = facts.where((f) => f.thisIsWorst);
    if (worst.isNotEmpty) return worst.first;
    return facts.first;
  }
}