// lib/core/utils/serving_size_calculator.dart
//
// Computes the suggested serving amount deterministically, based on the
// WHO daily reference limit for the flagged nutrient (see WhoDailyLimits in
// who_fda_thresholds.dart), split evenly across 3 meals per day. This is a
// per-meal guideline, not a threshold derived from ConditionThresholds --
// those Suitable/Moderate/Caution bands are used only for classification
// elsewhere (see who_calculator.dart) and are intentionally not used here.

import 'who_calculator.dart';
import '../../models/product_model.dart';

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

  /// Calculates suggested serving amount based on combined limits for
  /// sodium, total sugars, and saturated fat. This is for users without
  /// specific health conditions, providing a general population serving
  /// recommendation that considers all three key nutrients together.
  /// 
  /// The calculation finds the most restrictive nutrient (the one that
  /// allows the smallest serving size) to ensure all three nutrients
  /// stay within per-meal WHO limits.
  static String? calculateCombinedNutrients({
    required NutritionInfo nutritionPer100g,
    required double servingSizeG,
  }) {
    final nutrients = [
      {'key': 'sodiumMg', 'value': nutritionPer100g.sodiumMg},
      {'key': 'sugarsG', 'value': nutritionPer100g.sugarsG},
      {'key': 'saturatedFatG', 'value': nutritionPer100g.saturatedFatG},
    ];

    // Calculate suggested grams for each nutrient and find the most restrictive
    double? mostRestrictiveGrams;
    String? limitingNutrient;

    for (final nutrient in nutrients) {
      final value = nutrient['value'] as double;
      if (value <= 0) continue;

      final key = nutrient['key'] as String;
      final dailyLimit = WhoCalculator.getWhoDailyLimit(key);
      final perMealLimit = dailyLimit / mealsPerDay;
      final gramsForPerMealLimit = (perMealLimit / value) * 100;
      final suggestedGrams = gramsForPerMealLimit.clamp(0.0, servingSizeG);

      if (mostRestrictiveGrams == null || suggestedGrams < mostRestrictiveGrams) {
        mostRestrictiveGrams = suggestedGrams;
        limitingNutrient = key;
      }
    }

    if (mostRestrictiveGrams == null || limitingNutrient == null) {
      return null;
    }

    final ratio = mostRestrictiveGrams / servingSizeG;

    if (ratio >= 1.0) {
      return 'Up to 1 full serving (${servingSizeG.toStringAsFixed(0)}g) is the suggested amount per meal';
    } else if (ratio >= 0.5) {
      return 'About half a serving (${mostRestrictiveGrams.toStringAsFixed(0)}g) is the suggested amount per meal';
    } else {
      return 'No more than ${mostRestrictiveGrams.toStringAsFixed(0)}g is the suggested amount per meal';
    }
  }
}