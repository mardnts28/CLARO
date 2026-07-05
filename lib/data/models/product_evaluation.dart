// lib/data/models/product_evaluation.dart
//
// Output shape produced by WhoCalculator (core/utils/who_calculator.dart).
// This is what Phase 2 (Gemini prompt builder) and Phase 3/4 (ranking,
// comparison) will consume -- everything downstream of the scoring engine
// works off these objects, not raw Product/UserHealthProfile data.
//
// Uses ONLY AdvisoryLevel (Suitable / Moderate / Caution) throughout, per
// Table 3.14's exact wording. A separate Safe/Caution/Avoid scale was
// considered (based on Module 4.1's spec text) but removed on team decision
// to follow the documented table terminology consistently.

import '../../core/constants/who_fda_thresholds.dart';
import 'health_profile.dart';
import 'product.dart';

// Result of classifying ONE nutrient against ONE condition's threshold band.
class NutrientEvaluation {
  final HealthCondition condition;
  final String nutrientKey; // e.g. 'sodiumMg', 'sugarsG'
  final double valuePer100g;
  final AdvisoryLevel level;

  const NutrientEvaluation({
    required this.condition,
    required this.nutrientKey,
    required this.valuePer100g,
    required this.level,
  });
}

// Result of checking a product's allergens against the user's allergy list.
class AllergenAssessment {
  final List<AllergenType> matchedContains; // definite match -> forced last
  final List<AllergenType> matchedMayContain; // cross-contamination warning
  final bool hasDirectAllergen;
  final bool hasCrossContaminationRisk;

  const AllergenAssessment({
    required this.matchedContains,
    required this.matchedMayContain,
    required this.hasDirectAllergen,
    required this.hasCrossContaminationRisk,
  });
}

// Full evaluation of one product against one user's health profile.
// This is the object that feeds Phase 2 (Gemini advisory text) and
// Phase 3 (ranking).
class ProductEvaluation {
  final Product product;
  final List<NutrientEvaluation> nutrientEvaluations;
  final AllergenAssessment allergenAssessment;
  final int riskScore; // Table 3.15 summed points
  final AdvisoryLevel overallLevel; // worst level across all evaluated nutrients
  final bool allergenOverride; // true -> forced last in ranking (Table 3.15)

  const ProductEvaluation({
    required this.product,
    required this.nutrientEvaluations,
    required this.allergenAssessment,
    required this.riskScore,
    required this.overallLevel,
    required this.allergenOverride,
  });
}