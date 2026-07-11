// lib/core/utils/who_calculator.dart
//
// Phase 1: full scoring engine. Implements Table 3.14 (per-nutrient
// advisory bands) and Table 3.15 (risk scoring, tie-breaking, allergen
// override for ranking).

import '../constants/who_fda_thresholds.dart';
import '../../data/models/health_profile.dart';
import '../../data/models/product_evaluation.dart';
import '../../models/product_model.dart';

class WhoCalculator {
  // Classify nutrient based on WHO daily limit percentage per serving
  // Suitable: ≤10%, Moderate: >10-20%, Caution: >20%
  static AdvisoryLevel classifyByWhoPercentage(double whoPercentage) {
    if (whoPercentage <= 10) return AdvisoryLevel.suitable;
    if (whoPercentage > 20) return AdvisoryLevel.caution;
    return AdvisoryLevel.moderate;
  }

  // Legacy method for per-100g classification (used for ranking)
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

  // Public (no underscore) so ComparisonCalculator can reuse it without
  // duplicating this switch statement.
  static double readNutrientValue(NutritionInfo info, String nutrientKey) {
    switch (nutrientKey) {
      case 'sodiumMg':
        return info.sodiumMg;
      case 'sugarsG':
        return info.sugarsG;
      case 'saturatedFatG':
        return info.saturatedFatG;
      default:
        throw ArgumentError('Unknown nutrientKey: $nutrientKey');
    }
  }

  static AllergenAssessment assessAllergens(Product product, UserHealthProfile user) {
    final matchedContains = product.containsAllergens
        .where((a) => user.allergies.contains(a))
        .toList();

    return AllergenAssessment(
      matchedContains: matchedContains,
      hasDirectAllergen: matchedContains.isNotEmpty,
    );
  }

  static ProductEvaluation evaluateProduct(Product product, UserHealthProfile user) {
    final nutrientEvals = <NutrientEvaluation>[];

    for (final condition in user.conditions) {
      final nutrientKeys = ConditionThresholds.thresholds[condition]?.keys ?? const <String>[];
      for (final key in nutrientKeys) {
        final valuePer100g = readNutrientValue(product.nutritionPer100g, key);
        
        // Calculate per-serving value
        final valuePerServing = (valuePer100g / 100) * product.servingSizeG;
        
        // Get WHO daily limit for this nutrient
        final whoDailyLimit = _getWhoDailyLimit(key);
        
        // Calculate percentage of WHO daily limit per serving
        final whoPercentage = (valuePerServing / whoDailyLimit) * 100;
        
        // Classify based on WHO percentage (for health advisory)
        final level = classifyByWhoPercentage(whoPercentage);
        
        nutrientEvals.add(NutrientEvaluation(
          condition: condition,
          nutrientKey: key,
          valuePer100g: valuePer100g,
          valuePerServing: valuePerServing,
          whoDailyLimitPercentage: whoPercentage,
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

  static double _getWhoDailyLimit(String nutrientKey) {
    switch (nutrientKey) {
      case 'sodiumMg':
        return WhoDailyLimits.sodiumMgPerDay;
      case 'sugarsG':
        return WhoDailyLimits.sugarsGPerDay;
      case 'saturatedFatG':
        return WhoDailyLimits.saturatedFatGPerDay;
      default:
        throw ArgumentError('No WHO daily limit defined for $nutrientKey');
    }
  }

  static AdvisoryLevel _worstLevel(List<NutrientEvaluation> evals) {
    if (evals.isEmpty) return AdvisoryLevel.suitable;
    if (evals.any((e) => e.level == AdvisoryLevel.caution)) return AdvisoryLevel.caution;
    if (evals.any((e) => e.level == AdvisoryLevel.moderate)) return AdvisoryLevel.moderate;
    return AdvisoryLevel.suitable;
  }

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
      if (a.allergenOverride != b.allergenOverride) {
        return a.allergenOverride ? 1 : -1;
      }
      final scoreCompare = a.riskScore.compareTo(b.riskScore);
      if (scoreCompare != 0) return scoreCompare;
      return tieBreakValue(a).compareTo(tieBreakValue(b));
    });

    return evaluations;
  }

  static List<ProductEvaluation> topRecommendations(
    List<ProductEvaluation> ranked, {
    int count = 3,
  }) {
    return ranked.take(count).toList();
  }
}