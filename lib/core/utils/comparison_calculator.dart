// lib/core/utils/comparison_calculator.dart
//
// Computes WHY a product ranks where it does relative to the rest of a
// compared set -- pure Dart, no AI. Same principle as ServingSizeCalculator:
// Gemini phrases the sentence, it never derives the comparison itself.

import '../../data/models/health_profile.dart';
import '../../data/models/product_evaluation.dart';
import '../../models/product_model.dart';
import '../constants/who_fda_thresholds.dart';
import 'who_calculator.dart';

/// Same idea as [ComparisonFact], but for the conditions/factors that
/// AREN'T numeric per-100g thresholds -- e.g. GERD's trigger-ingredient
/// and high-fat checks, kidney disease's phosphate-additive check. These
/// are scored into the real overall rank via
/// [ProductEvaluation.scoredFactors] (see WhoCalculator.evaluateProduct),
/// but until now were invisible to the ranking-explanation layer, which
/// only looked at [ConditionThresholds] nutrient keys. That gap meant:
/// (a) GERD-only users got no nutrient/factor-specific explanation at
/// all (GERD has no entry in ConditionThresholds), and (b) GERD +
/// kidney-disease users' explanations always cited sodium even when
/// sodium wasn't what actually drove the rank difference.
class ComparisonFactorFact {
  final String factorKey;
  final AdvisoryLevel thisLevel;
  final bool thisIsBest; // lowest-risk level among known entries in the set
  final bool thisIsWorst;
  final bool allTied; // every known entry in the set has the same level
  final String explanation; // human-readable, already written by WhoCalculator

  const ComparisonFactorFact({
    required this.factorKey,
    required this.thisLevel,
    required this.thisIsBest,
    required this.thisIsWorst,
    required this.allTied,
    required this.explanation,
  });
}

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

  /// One [ComparisonFactorFact] per scored factor (e.g. `phosphateAdditives`,
  /// `gerdTotalFat`, `gerdTriggers`) that [target] and at least one other
  /// product in [comparisonSet] both have a *known* reading for. Only
  /// factors with an actual known reading on both sides are compared --
  /// an "unknown" status (missing ingredient/nutrition data) is never
  /// used to call a product better or worse than another.
  static List<ComparisonFactorFact> computeFactorFacts({
    required ProductEvaluation target,
    required List<ProductEvaluation> comparisonSet,
  }) {
    final factorKeys = <String>{};
    for (final e in comparisonSet) {
      factorKeys.addAll(e.scoredFactors.map((f) => f.factorKey));
    }

    final facts = <ComparisonFactorFact>[];
    for (final key in factorKeys) {
      final targetEntryMatches = target.scoredFactors.where(
        (f) => f.factorKey == key && f.status == ScoringStatus.known,
      );
      if (targetEntryMatches.isEmpty) continue; // target's own reading unknown
      final targetEntry = targetEntryMatches.first;

      final knownEntries = comparisonSet
          .map((e) => e.scoredFactors.where(
                (f) => f.factorKey == key && f.status == ScoringStatus.known,
              ))
          .where((matches) => matches.isNotEmpty)
          .map((matches) => matches.first)
          .toList();
      if (knownEntries.length < 2) continue; // nothing to compare against

      // suitable=1, moderate=2, caution=3 -- reuse the same points used for
      // the real risk score, so "best" here means the same thing it means
      // in WhoCalculator's ranking.
      int riskRank(AdvisoryLevel l) => RiskScoring.points[l] ?? 2;

      final levels = knownEntries.map((f) => f.level).toList();
      final bestLevel =
          levels.reduce((a, b) => riskRank(a) < riskRank(b) ? a : b);
      final worstLevel =
          levels.reduce((a, b) => riskRank(a) > riskRank(b) ? a : b);

      facts.add(ComparisonFactorFact(
        factorKey: key,
        thisLevel: targetEntry.level,
        thisIsBest: targetEntry.level == bestLevel,
        thisIsWorst: targetEntry.level == worstLevel,
        allTied: bestLevel == worstLevel,
        explanation: targetEntry.explanation,
      ));
    }
    return facts;
  }

  /// Picks the single most decision-useful *factor* fact to explain --
  /// same priority as [primaryFact] (prefer where target is clearly best,
  /// then clearly worst) -- but skips any factor where the whole compared
  /// set is tied, since a tied factor can't explain why THIS product's
  /// rank differs from the others.
  static ComparisonFactorFact? primaryFactorFact(
    List<ComparisonFactorFact> facts,
  ) {
    final varying = facts.where((f) => !f.allTied).toList();
    if (varying.isEmpty) return null;
    final best = varying.where((f) => f.thisIsBest);
    if (best.isNotEmpty) return best.first;
    final worst = varying.where((f) => f.thisIsWorst);
    if (worst.isNotEmpty) return worst.first;
    return null;
  }
}