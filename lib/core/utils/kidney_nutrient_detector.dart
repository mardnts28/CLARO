// lib/core/utils/kidney_nutrient_detector.dart
//
// Pure-Dart, awareness-only detector for nutrients relevant to kidney health.
// This is NOT part of the Suitable/Moderate/Caution scoring pipeline
// (WhoCalculator/ConditionThresholds) -- Kidney Disease is an
// awareness-only condition (see HealthConditionKind.isAwarenessOnly in
// data/models/health_profile.dart). This file only extracts relevant
// nutrients from a Product's nutrition facts; it never assigns a
// Suitable/Moderate/Caution verdict and never claims a product is
// "safe"/"unsafe".

import '../../models/product_model.dart';
import 'nutrition_availability.dart';

enum KidneyNutrientType {
  sodium,
  potassium,
  protein,
}

/// One detected nutrient with its per-serving value.
class KidneyNutrientMatch {
  final KidneyNutrientType type;
  final double valuePerServing;

  const KidneyNutrientMatch({
    required this.type,
    required this.valuePerServing,
  });
}

/// Result of running the detector against a product. Callers (the Kidney
/// Disease warning card) use [hasNutritionData] to tell apart
/// "checked and found nothing" from "couldn't check, data missing".
class KidneyNutrientResult {
  final List<KidneyNutrientMatch> nutrients;
  final bool hasNutritionData;

  const KidneyNutrientResult({
    required this.nutrients,
    required this.hasNutritionData,
  });

  bool get hasAnyNutrients => nutrients.isNotEmpty;
}

class KidneyNutrientDetector {
  KidneyNutrientDetector._();

  /// Detects kidney-relevant nutrients for [product]. Null-safe: a product
  /// with no nutrition data simply returns an empty result -- see
  /// [KidneyNutrientResult.hasNutritionData] for what was actually checked.
  static KidneyNutrientResult detect(Product product) {
    final hasNutritionData = NutritionAvailability.isAvailable(product);
    final nutrients = <KidneyNutrientMatch>[];

    if (!hasNutritionData) {
      return KidneyNutrientResult(
        nutrients: nutrients,
        hasNutritionData: false,
      );
    }

    final facts = product.nutritionalFacts;

    // Sodium
    if (facts.sodiumMg != null && facts.sodiumMg! > 0) {
      nutrients.add(KidneyNutrientMatch(
        type: KidneyNutrientType.sodium,
        valuePerServing: facts.sodiumMg!,
      ));
    }

    // Potassium
    if (facts.potassiumMg != null && facts.potassiumMg! > 0) {
      nutrients.add(KidneyNutrientMatch(
        type: KidneyNutrientType.potassium,
        valuePerServing: facts.potassiumMg!,
      ));
    }

    // Protein
    if (facts.proteinG != null && facts.proteinG! > 0) {
      nutrients.add(KidneyNutrientMatch(
        type: KidneyNutrientType.protein,
        valuePerServing: facts.proteinG!,
      ));
    }

    return KidneyNutrientResult(
      nutrients: nutrients,
      hasNutritionData: true,
    );
  }
}
