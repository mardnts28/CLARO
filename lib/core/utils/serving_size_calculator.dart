// lib/core/utils/serving_size_calculator.dart
//
// Computes the suggested serving amount deterministically (Table 3.22):
//
//   1. Identify the evaluated nutrient(s)
//        - No health condition  -> sodium, total sugars and saturated fat
//                                  combined (the most restrictive one wins).
//        - One or more health   -> only the nutrients tied to the user's
//          conditions              condition(s); the most severely flagged
//                                  one wins. When nothing is flagged, the one
//                                  closest to its daily limit wins.
//   2. Per-meal limit      M = D / 3 meals a day   (D = Recommended Daily Intake,
//                                                    WhoDailyLimits)
//   3. Per-100g value      N = nutrient per 100g
//   4. Suggested grams     G = M / N x 100         (capped at the serving size)
//   5. Compare to serving  R = G / S
//        R >= 1        -> up to 1 full serving per meal
//        0.5 <= R < 1  -> about half a serving per meal
//        R < 0.5       -> no more than G grams per meal
//
// Nutrients per condition (Table 3.18, updated):
//   - Cardiovascular disease: sodium, saturated fat, trans fat
//   - Diabetes:               total sugars, total carbohydrates
//   - Kidney disease:         sodium, protein
//   - GERD / food allergy:    NO suggested amount (see [isExcluded])
//
// This is a per-meal guideline, not a threshold derived from
// ConditionThresholds -- those Suitable/Moderate/Caution bands are used only
// for classification elsewhere (see who_calculator.dart).
//
// "Most severely flagged, otherwise closest to the limit" is the same as
// "highest percentage of the daily limit": the level bands rise with the
// percentage, so the nutrient with the highest percentage is also the one
// with the most severe level. The percentage ordering does not depend on the
// serving size (value/100 x S / D scales every nutrient by the same S).

import 'who_calculator.dart';
import '../constants/who_fda_thresholds.dart';
import '../../data/models/health_profile.dart';
import '../../models/product_model.dart';

class ServingSizeCalculator {
  static const int mealsPerDay = 3;

  // ── Who gets NO suggested amount ────────────────────────────────────

  /// True when no suggested amount may be shown at all:
  ///  - the user has GERD (alone or together with any other condition), or
  ///  - the scanned product contains a food allergen the user is allergic to.
  static bool isExcluded({
    required Iterable<HealthCondition> conditions,
    required bool hasDirectAllergen,
  }) => hasDirectAllergen || conditions.contains(HealthCondition.gerd);

  // ── Nutrients per condition ─────────────────────────────────────────

  /// The nutrient keys evaluated for [condition]. Empty for GERD (no
  /// suggested amount).
  static List<String> nutrientKeysFor(HealthCondition condition) {
    switch (condition) {
      case HealthCondition.cardiovascularDisease:
        return const ['sodiumMg', 'saturatedFatG', 'transFatG'];
      case HealthCondition.diabetes:
        return const ['sugarsG', 'totalCarbohydratesG'];
      case HealthCondition.kidneyDisease:
        return const ['sodiumMg', 'proteinG'];
      case HealthCondition.gerd:
        return const [];
    }
  }

  /// Nutrients used for a user with NO health condition (trans fat is
  /// deliberately not part of this combination).
  static const List<String> _noConditionKeys = [
    'sodiumMg',
    'sugarsG',
    'saturatedFatG',
  ];

  static double _dailyLimit(String key) {
    switch (key) {
      case 'sodiumMg':
        return WhoDailyLimits.sodiumMgPerDay;
      case 'sugarsG':
        return WhoDailyLimits.sugarsGPerDay;
      case 'totalCarbohydratesG':
        return WhoDailyLimits.totalCarbohydratesGPerDay;
      case 'saturatedFatG':
        return WhoDailyLimits.saturatedFatGPerDay;
      case 'transFatG':
        return WhoDailyLimits.transFatGPerDay;
      case 'proteinG':
        return WhoDailyLimits.proteinGPerDay;
      default:
        return WhoCalculator.getWhoDailyLimit(key);
    }
  }

  static double _valueFor(NutritionInfo n, String key) {
    switch (key) {
      case 'sodiumMg':
        return n.sodiumMg;
      case 'sugarsG':
        return n.sugarsG;
      case 'totalCarbohydratesG':
        return n.totalCarbohydratesG;
      case 'saturatedFatG':
        return n.saturatedFatG;
      case 'transFatG':
        return n.transFatG;
      case 'proteinG':
        return n.proteinG;
      default:
        return 0;
    }
  }

  static double _safeSize(double servingSizeG) =>
      servingSizeG > 0 ? servingSizeG : 100.0;

  /// Steps 2-4 for ONE nutrient: grams of the product per meal, capped at the
  /// serving size. A nutrient the product doesn't contain (N = 0) puts no
  /// limit on the amount, so the answer is one full serving.
  static double _gramsForKey(
    String key,
    double valuePer100g,
    double servingSizeG,
  ) {
    final size = _safeSize(servingSizeG);
    if (valuePer100g <= 0) return size;
    final perMealLimit = _dailyLimit(key) / mealsPerDay;
    final grams = (perMealLimit / valuePer100g) * 100;
    return grams.clamp(0.0, size).toDouble();
  }

  // ── Step 5: wording ─────────────────────────────────────────────────

  /// The phrase for [grams] against [servingSizeG] (the three bands of
  /// Step 5).
  static String phraseFor(double grams, double servingSizeG) {
    final size = _safeSize(servingSizeG);
    final ratio = grams / size;
    if (ratio >= 1.0) {
      return 'Up to 1 full serving (${size.toStringAsFixed(0)}g) is the suggested amount per meal';
    } else if (ratio >= 0.5) {
      return 'About half a serving (${grams.toStringAsFixed(0)}g) is the suggested amount per meal';
    } else {
      return 'No more than ${grams.toStringAsFixed(0)}g is the suggested amount per meal';
    }
  }

  // ── Main entry point (used by every caller) ─────────────────────────

  /// Suggested grams per meal for a user with [conditions], following
  /// Table 3.22. Returns null ONLY when no amount may be shown
  /// (see [isExcluded]); otherwise always returns a value.
  ///
  /// [smallestAmongNutrients] is for group members: instead of the single
  /// most severely flagged nutrient, the smallest gram amount across ALL of
  /// the member's condition nutrients is returned.
  static double? gramsForProfile({
    required Iterable<HealthCondition> conditions,
    required NutritionInfo nutritionPer100g,
    required double servingSizeG,
    required bool hasDirectAllergen,
    bool smallestAmongNutrients = false,
  }) {
    if (isExcluded(
      conditions: conditions,
      hasDirectAllergen: hasDirectAllergen,
    )) {
      return null;
    }

    // Keys to evaluate: the nutrients tied to the user's conditions, or the
    // combined sodium / sugars / saturated fat set for a user with none.
    final keys = <String>[];
    for (final c in conditions) {
      for (final k in nutrientKeysFor(c)) {
        if (!keys.contains(k)) keys.add(k);
      }
    }
    if (keys.isEmpty) keys.addAll(_noConditionKeys);

    // No condition at all: the most restrictive nutrient wins. A group
    // member (smallestAmongNutrients) also takes the smallest amount.
    final useSmallest = smallestAmongNutrients || conditions.isEmpty;
    if (useSmallest) {
      double? smallest;
      for (final k in keys) {
        final g = _gramsForKey(
          k,
          _valueFor(nutritionPer100g, k),
          servingSizeG,
        );
        if (smallest == null || g < smallest) smallest = g;
      }
      return smallest;
    }

    // One or more conditions: the most severely flagged nutrient, i.e. the
    // one with the highest percentage of its daily limit (also the closest
    // to its limit when nothing is flagged).
    String? worstKey;
    var worstPct = -1.0;
    for (final k in keys) {
      final value = _valueFor(nutritionPer100g, k);
      final pct = (value / _dailyLimit(k)) * 100;
      if (pct > worstPct) {
        worstPct = pct;
        worstKey = k;
      }
    }
    return _gramsForKey(
      worstKey!,
      _valueFor(nutritionPer100g, worstKey),
      servingSizeG,
    );
  }

  /// [gramsForProfile] worded as the suggested-amount phrase. Null only when
  /// no amount may be shown (GERD or a detected food allergen).
  static String? forProfile({
    required Iterable<HealthCondition> conditions,
    required NutritionInfo nutritionPer100g,
    required double servingSizeG,
    required bool hasDirectAllergen,
    bool smallestAmongNutrients = false,
  }) {
    final grams = gramsForProfile(
      conditions: conditions,
      nutritionPer100g: nutritionPer100g,
      servingSizeG: servingSizeG,
      hasDirectAllergen: hasDirectAllergen,
      smallestAmongNutrients: smallestAmongNutrients,
    );
    if (grams == null) return null;
    return phraseFor(grams, servingSizeG);
  }

}