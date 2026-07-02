// lib/core/utils/who_calculator.dart
//
// Your leader's tree already reserves this exact file for WHO-threshold
// logic ("Helper classes: TTS/STT helpers, WHO calculator"). This is a
// Phase 0 stub with just enough logic to unblock testing -- the full
// scoring engine (multi-nutrient evaluation, allergen matching, risk score
// summation, tie-breaking) gets built out here in Phase 1.

import '../constants/who_fda_thresholds.dart';
import '../../data/models/health_profile.dart';

class WhoCalculator {
  // Classifies a single nutrient value against its condition's threshold band.
  // e.g. WhoCalculator.classifyNutrient(HealthCondition.hypertension, 'sodiumMg', 450)
  //      => AdvisoryLevel.caution
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

  // TODO (Phase 1): evaluateProduct(Product, UserHealthProfile) -> full
  // per-nutrient breakdown + allergen check + summed risk score (Table 3.15)
  // TODO (Phase 3): rankProducts(List<Product>, UserHealthProfile) -> sorted
  // list with tie-breaking + allergen override
}
