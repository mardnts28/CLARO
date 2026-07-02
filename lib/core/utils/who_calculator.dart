// lib/core/utils/who_calculator.dart
//
// Phase 1: full scoring engine, built out from the Phase 0 classification
// stub. Implements Table 3.14 (per-nutrient advisory bands) and Table 3.15
// (risk scoring, tie-breaking, allergen override for ranking).

import '../constants/who_fda_thresholds.dart';
import '../../data/models/health_profile.dart';
import '../../data/models/product.dart';
import '../../data/models/product_evaluation.dart';

class WhoCalculator {
  // ---------------------------------------------------------------------
  // Single-nutrient classification (Phase 0)
  // ---------------------------------------------------------------------

  static AdvisoryLevel classifyNutrient(
    HealthCondition condition,
    String nutrientKey,
    double value,
  ) {
    final band = ConditionThresholds.thresholds[condition]?[nutrientKey];
    if (band == null) {
      throw ArgumentError('No threshold defined for $condition / $nutrientKey');
    }
    if (value <= band.suitableMaxInclusive) return AdvisoryLevel.suitable;
    if (value >= band.cautionMinInclusive) return AdvisoryLevel.caution;
    return AdvisoryLevel.moderate;
  }

  // Maps a nutrientKey string (as used in ConditionThresholds) to the actual
  // value on a NutritionInfo object. Extend this when new nutrients get
  // threshold bands added to who_fda_thresholds.dart.
  static double _readNutrientValue(NutritionInfo info, String nutrientKey) {
    switch (nutrientKey) {
      case 'sodiumMg':
        return info.sodiumMg;
      case 'sugarsG':
        return info.sugarsG;
      default:
        throw ArgumentError('Unknown nutrientKey: $nutrientKey');
    }
  }

  // ---------------------------------------------------------------------
  // Allergen matching
  // ---------------------------------------------------------------------

  static AllergenAssessment assessAllergens(Product product, UserHealthProfile user) {
    final matchedContains = product.containsAllergens
        .where((a) => user.allergies.contains(a))
        .toList();
    final matchedMayContain = product.mayContainAllergens
        .where((a) => user.allergies.contains(a))
        .toList();

    return AllergenAssessment(
      matchedContains: matchedContains,
      matchedMayContain: matchedMayContain,
      hasDirectAllergen: matchedContains.isNotEmpty,
      hasCrossContaminationRisk: matchedMayContain.isNotEmpty,
    );
  }

  // ---------------------------------------------------------------------
  // Full product evaluation (Table 3.14 + Table 3.15 risk score)
  // ---------------------------------------------------------------------

  static ProductEvaluation evaluateProduct(Product product, UserHealthProfile user) {
    final nutrientEvals = <NutrientEvaluation>[];

    for (final condition in user.conditions) {
      final nutrientKeys = ConditionThresholds.thresholds[condition]?.keys ?? const <String>[];
      for (final key in nutrientKeys) {
        final value = _readNutrientValue(product.nutritionPer100g, key);
        final level = classifyNutrient(condition, key, value);
        nutrientEvals.add(NutrientEvaluation(
          condition: condition,
          nutrientKey: key,
          valuePer100g: value,
          level: level,
        ));
      }
    }

    final allergenAssessment = assessAllergens(product, user);

    final riskScore = nutrientEvals.fold<int>(
      0,
      (sum, e) => sum + (RiskScoring.points[e.level] ?? 0),
    );

    // Table 3.14: food allergy is a THIRD condition row in the same table
    // as hypertension/diabetes, with its own Suitable/Caution classification
    // (no Moderate -- N/A). A direct allergen match forces the overall
    // advisory level to Caution, even if every evaluated nutrient came back
    // Suitable. This does NOT touch riskScore -- Table 3.15 explicitly marks
    // the Allergen Detected row as N/A for score, using it only to force
    // last place in ranking (handled separately via allergenOverride below).
    final overallLevel = allergenAssessment.hasDirectAllergen
        ? AdvisoryLevel.caution
        : _worstLevel(nutrientEvals);

    return ProductEvaluation(
      product: product,
      nutrientEvaluations: nutrientEvals,
      allergenAssessment: allergenAssessment,
      riskScore: riskScore,
      overallLevel: overallLevel,
      allergenOverride: allergenAssessment.hasDirectAllergen,
    );
  }

  // No conditions evaluated (either user has none, or no nutrients matched)
  // defaults to "suitable" -- nothing flagged means nothing to warn about.
  static AdvisoryLevel _worstLevel(List<NutrientEvaluation> evals) {
    if (evals.isEmpty) return AdvisoryLevel.suitable;
    if (evals.any((e) => e.level == AdvisoryLevel.caution)) return AdvisoryLevel.caution;
    if (evals.any((e) => e.level == AdvisoryLevel.moderate)) return AdvisoryLevel.moderate;
    return AdvisoryLevel.suitable;
  }

  // ---------------------------------------------------------------------
  // Ranking (Table 3.15): ascending risk score, tie-break by raw nutrient
  // value, allergen match forces the product to the end regardless of score.
  // ---------------------------------------------------------------------

  static List<ProductEvaluation> rankProducts(
    List<Product> products,
    UserHealthProfile user,
  ) {
    final evaluations = products.map((p) => evaluateProduct(p, user)).toList();

    // Tie-break signal: sum of raw per-100g values across evaluated
    // nutrients. Table 3.15 says "higher nutrient value per 100g" without
    // specifying which nutrient when multiple are evaluated -- summing all
    // evaluated nutrients is my interpretation; confirm with your adviser
    // if a single specific nutrient should be used instead.
    double tieBreakValue(ProductEvaluation e) =>
        e.nutrientEvaluations.fold<double>(0, (sum, ev) => sum + ev.valuePer100g);

    evaluations.sort((a, b) {
      // Allergen override: any direct allergen match is forced last,
      // regardless of risk score.
      if (a.allergenOverride != b.allergenOverride) {
        return a.allergenOverride ? 1 : -1;
      }
      final scoreCompare = a.riskScore.compareTo(b.riskScore);
      if (scoreCompare != 0) return scoreCompare;
      return tieBreakValue(a).compareTo(tieBreakValue(b));
    });

    return evaluations;
  }

  // Convenience for the "Top 3 recommended products" display (Module 4.3).
  static List<ProductEvaluation> topRecommendations(
    List<ProductEvaluation> ranked, {
    int count = 3,
  }) {
    return ranked.take(count).toList();
  }
}