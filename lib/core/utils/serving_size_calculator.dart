// lib/core/utils/serving_size_calculator.dart
//
// Computes the suggested serving amount deterministically, based on the
// WHO daily reference limit for the flagged nutrient (see WhoDailyLimits in
// who_fda_thresholds.dart), split evenly across 3 meals per day. This is a
// per-meal guideline, not a threshold derived from ConditionThresholds --
// those Suitable/Moderate/Caution bands are used only for classification
// elsewhere (see who_calculator.dart) and are intentionally not used here.

import 'who_calculator.dart';

class ServingSizeCalculator {
  static const int mealsPerDay = 3;

  static String? calculate({
    required String nutrientKey,
    required double valuePer100g,
    required double servingSizeG,
  }) {
    if (valuePer100g <= 0) return null;

    final dailyLimit = WhoCalculator.getWhoDailyLimit(nutrientKey);

    // Per-meal share of the WHO daily reference limit.
    final perMealLimit = dailyLimit / mealsPerDay;

    // Grams of THIS product that would deliver exactly the per-meal limit
    // of the nutrient.
    final gramsForPerMealLimit = (perMealLimit / valuePer100g) * 100;

    // Never suggest more than the product's normal serving size.
    final suggestedGrams = gramsForPerMealLimit.clamp(0, servingSizeG);

    final ratio = suggestedGrams / servingSizeG;

    if (ratio >= 1.0) {
      return 'Up to 1 full serving (${servingSizeG.toStringAsFixed(0)}g) is the suggested amount per meal';
    } else if (ratio >= 0.5) {
      return 'About half a serving (${suggestedGrams.toStringAsFixed(0)}g) is the suggested amount per meal';
    } else {
      return 'No more than ${suggestedGrams.toStringAsFixed(0)}g is the suggested amount per meal';
    }
  }
}