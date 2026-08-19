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
import '../../models/product_model.dart';

// Result of classifying ONE nutrient against ONE condition's threshold band.
class NutrientEvaluation {
  final HealthCondition condition;
  final String nutrientKey; // e.g. 'sodiumMg', 'sugarsG', 'saturatedFatG'
  final double valuePer100g; // For ranking/comparison (maintained for consistency)
  final double valuePerServing; // For health advisory display
  final double whoDailyLimitPercentage; // Percentage of WHO daily limit per serving
  final AdvisoryLevel level; // Based on WHO daily limit percentage

  const NutrientEvaluation({
    required this.condition,
    required this.nutrientKey,
    required this.valuePer100g,
    required this.valuePerServing,
    required this.whoDailyLimitPercentage,
    required this.level,
  });
}

// How reliably an ingredient-level match was established for a matched
// allergen. Powers the Health Advisory's ingredient attribution: we only
// ever claim "direct" or "derived" when the ingredient list actually
// supports it -- never a guess dressed up as a fact.
enum AllergenMatchType {
  // The ingredient text IS the allergen (or an unambiguous synonym/species
  // of it) -- e.g. ingredient "Milk" or "Tuna" for a milk/fish allergy.
  direct,
  // The ingredient text is not the allergen by name, but is a well-known
  // derivative/component of it that the product data confirms -- e.g.
  // "Whey" or "Casein" for a dairy allergy, "Surimi" for a fish allergy.
  derived,
  // DEPRECATED: This value is kept for enum compatibility but is no longer
  // used in allergen assessment. Label declarations alone are no longer
  // sufficient for a caution warning - only explicit ingredient matches
  // (direct or derived) trigger allergen cautions.
  undetermined,
}

// Ties ONE matched allergen back to the specific ingredient (if any) that
// reliably explains it, and how confident that attribution is.
class AllergenIngredientMatch {
  final AllergenType allergen;
  final String? ingredient; // always non-null in current implementation (direct/derived matches only)
  final AllergenMatchType matchType;

  const AllergenIngredientMatch({
    required this.allergen,
    required this.matchType,
    this.ingredient,
  });
}

// Result of checking a product's allergens against the user's allergy list.
class AllergenAssessment {
  final List<AllergenType> matchedContains; // definite match -> forced last
  final bool hasDirectAllergen;
  final List<String> matchedIngredients; // specific ingredient strings that matched (direct + derived only)
  // One entry per allergen in [matchedContains], describing exactly which
  // ingredient (if any) reliably explains that match and whether it's a
  // direct or derived source. See AllergenMatchType for the rules.
  final List<AllergenIngredientMatch> ingredientSources;

  const AllergenAssessment({
    required this.matchedContains,
    required this.hasDirectAllergen,
    this.matchedIngredients = const [],
    this.ingredientSources = const [],
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