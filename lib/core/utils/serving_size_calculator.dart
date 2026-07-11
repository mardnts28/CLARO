// lib/core/utils/serving_size_calculator.dart
//
// Computes a safe serving size deterministically, using the SAME
// Caution threshold already established in Table 3.14 / who_fda_thresholds.dart
// -- not a separate assumption. "Safe" here means: how much of this product
// can be consumed before its contribution to this nutrient crosses the
// Caution line for the user's condition.

import '../../data/models/health_profile.dart';
import '../constants/who_fda_thresholds.dart';

class ServingSizeCalculator {
  static String? calculate({
    required HealthCondition condition,
    required String nutrientKey,
    required double valuePer100g,
    required double servingSizeG,
  }) {
    final band = ConditionThresholds.thresholds[condition]?[nutrientKey];
    if (band == null || valuePer100g <= 0) return null;

    final cautionThreshold = band.cautionMinInclusive; // e.g. 400mg sodium, 9.5g sugars (Table 3.14)

    // Grams of THIS product that would bring its contribution up to the
    // Caution boundary -- i.e. the max amount before this product alone
    // pushes the nutrient into Caution territory.
    final maxGramsBeforeCaution = (cautionThreshold / valuePer100g) * 100;

    final ratio = maxGramsBeforeCaution / servingSizeG;

    if (ratio >= 1.0) {
      return 'Up to 1 full serving (${servingSizeG.toStringAsFixed(0)}g) stays within the suggested limit';
    } else if (ratio >= 0.5) {
      return 'About half a serving (${(servingSizeG * ratio).toStringAsFixed(0)}g) stays within the suggested limit';
    } else {
      final safeGrams = (servingSizeG * ratio).clamp(0, servingSizeG);
      return 'No more than ${safeGrams.toStringAsFixed(0)}g stays within the suggested limit';
    }
  }
}