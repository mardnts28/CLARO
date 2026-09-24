// lib/core/utils/kidney_advisory_facts.dart
//
// Deterministic facts for the Kidney Disease version of the Health Advisory
// (the 3-sentence banner text on the product detail screen). This replaces
// the standalone "Kidney Disease Warning" card: the same information --
// sodium, protein and phosphate additives -- is now narrated by the Health
// Advisory itself.
//
// Both the AI prompt (AdvisoryPromptBuilder) and the rule-based fallback
// (FallbackAdvisoryGenerator) read from this one place, as does the banner
// footer note on the screen, so the numbers and the "does the kidney
// advisory apply here?" decision can never drift apart.
//
// Nothing here changes scoring, ranking, or any other condition's advisory.
// Protein is informational only (it is NOT part of WhoCalculator's scored
// factors), exactly as before.

import '../../data/models/product_evaluation.dart';
import '../../models/product_model.dart'; // Product.servingSizeG / nutritionPer100g extension
import '../constants/who_fda_thresholds.dart';
import 'kidney_nutrient_detector.dart';
import 'who_calculator.dart';

class KidneyAdvisoryFacts {
  /// The serving size (g) every per-serving figure below was computed for.
  final double servingSizeG;

  /// Sodium per serving (mg), its % of the WHO daily reference amount, and
  /// its classification level at that serving size.
  final double sodiumMg;
  final double sodiumPercentage;
  final AdvisoryLevel sodiumLevel;

  /// Protein per serving (g) and its % of the WHO daily reference amount
  /// (~75 g/day, the upper bound of 10-15% of energy on 2,000 kcal).
  final double proteinG;
  final double proteinPercentage;

  /// Matched phosphate additive ingredient text (e.g. "Sodium Phosphate;
  /// Phosphoric Acid"), or null when none were detected.
  final String? phosphateIngredients;

  /// False when the product has no ingredient list, so "no phosphate
  /// additives detected" cannot be claimed.
  final bool ingredientDataKnown;

  const KidneyAdvisoryFacts({
    required this.servingSizeG,
    required this.sodiumMg,
    required this.sodiumPercentage,
    required this.sodiumLevel,
    required this.proteinG,
    required this.proteinPercentage,
    required this.phosphateIngredients,
    required this.ingredientDataKnown,
  });

  bool get hasPhosphateAdditives => phosphateIngredients != null;
  bool get sodiumFlagged => sodiumLevel != AdvisoryLevel.suitable;

  /// WhoCalculator.evaluateProduct() adds a 'phosphateAdditives' scored
  /// factor if and only if the user has Kidney Disease, so this identifies a
  /// kidney user's evaluation without needing the profile itself.
  static bool isKidneyEvaluation(ProductEvaluation evaluation) => evaluation
      .scoredFactors
      .any((f) => f.factorKey == 'phosphateAdditives');

  /// Returns the kidney facts when the Kidney Disease advisory should be
  /// written for [evaluation], or null when the existing advisory logic
  /// should be used instead. Null when:
  ///  * the evaluation is not for a user with Kidney Disease;
  ///  * the product matches one of the user's allergens (the allergen
  ///    advisory always takes priority, as before); or
  ///  * the worst-flagged nutrient at this serving size is NOT sodium (e.g.
  ///    a user with Kidney Disease + Diabetes whose sugars are the main
  ///    concern) -- the existing "worst nutrient" advisory is kept then.
  ///
  /// [servingSizeG] defaults to the product's labelled serving; pass the
  /// user-selected size to mirror the screen's dropdown.
  static KidneyAdvisoryFacts? build(
    ProductEvaluation evaluation, {
    double? servingSizeG,
  }) {
    if (!isKidneyEvaluation(evaluation)) return null;
    if (evaluation.allergenAssessment.hasDirectAllergen) return null;

    final product = evaluation.product;
    final size = servingSizeG ?? product.servingSizeG;

    // Same "worst flagged nutrient" selection the existing advisory uses
    // (first of the most severe wins), re-derived at [size].
    NutrientEvaluation? worst;
    var worstLevel = AdvisoryLevel.suitable;
    for (final e in evaluation.nutrientEvaluations) {
      final perServing = (e.valuePer100g / 100) * size;
      final pct =
          (perServing / WhoCalculator.getWhoDailyLimit(e.nutrientKey)) * 100;
      final level = WhoCalculator.classifyByWhoPercentage(pct);
      if (level == AdvisoryLevel.suitable) continue;
      if (worst == null || _severity(level) > _severity(worstLevel)) {
        worst = e;
        worstLevel = level;
      }
    }
    if (worst != null && worst.nutrientKey != 'sodiumMg') return null;

    final per100g = product.nutritionPer100g;
    final sodiumMg = (per100g.sodiumMg / 100) * size;
    final sodiumPct = (sodiumMg / WhoDailyLimits.sodiumMgPerDay) * 100;
    final proteinG = (per100g.proteinG / 100) * size;
    final proteinPct = (proteinG / WhoDailyLimits.proteinGPerDay) * 100;

    final detected = KidneyNutrientDetector.detect(product);
    String? phosphate;
    for (final n in detected.nutrients) {
      if (n.type == KidneyNutrientType.phosphorus &&
          (n.matchedIngredient?.trim().isNotEmpty ?? false)) {
        phosphate = n.matchedIngredient!.trim();
        break;
      }
    }

    return KidneyAdvisoryFacts(
      servingSizeG: size,
      sodiumMg: sodiumMg,
      sodiumPercentage: sodiumPct,
      sodiumLevel: WhoCalculator.classifyByWhoPercentage(sodiumPct),
      proteinG: proteinG,
      proteinPercentage: proteinPct,
      phosphateIngredients: phosphate,
      ingredientDataKnown: detected.hasIngredientData,
    );
  }

  static int _severity(AdvisoryLevel level) {
    switch (level) {
      case AdvisoryLevel.suitable:
        return 0;
      case AdvisoryLevel.moderate:
        return 1;
      case AdvisoryLevel.caution:
        return 2;
    }
  }
}