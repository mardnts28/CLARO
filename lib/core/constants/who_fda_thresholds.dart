// lib/core/constants/who_fda_thresholds.dart
//
// Pure threshold/config values. Source: Table 3.14 "Condition-Specific
// Advisory Thresholds" (per 100g basis) and Table 3.15 (risk scoring points).
//
// This file holds ONLY constants -- no logic. The calculator that reads
// these values lives in core/utils/who_calculator.dart, per your leader's
// planned structure.
//
// *** FLAG FOR TEAM REVIEW ***
// Your Module 4.2 spec text describes sodium/sugar limits "per serving"
// (sodium >400mg, sugar >5g), while Table 3.14 defines them per 100g
// (sodium >=400mg/100g, sugar >=9.5g/100g). These are NOT equivalent unless
// serving size happens to be exactly 100g. This file implements the
// Table 3.14 (per-100g) version since it's the more detailed, formally
// documented source -- confirm with your adviser/team before Phase 1 locks
// this in, since it changes scoring results for every product.

import '../../data/models/health_profile.dart';

// A single nutrient's three-band threshold, all evaluated per 100g.
class NutrientThreshold {
  final double suitableMaxInclusive; // <= this value => Suitable
  final double cautionMinInclusive; // >= this value => Caution
  // Anything strictly between the two bands => Moderate Consumption

  const NutrientThreshold({
    required this.suitableMaxInclusive,
    required this.cautionMinInclusive,
  });
}

enum AdvisoryLevel { suitable, moderate, caution }

// WHO Healthy Diet daily limits (2,000 kcal/day reference diet)
class WhoDailyLimits {
  static const double sodiumMgPerDay = 2000;
  static const double sugarsGPerDay = 50;
}

// Table 3.14 thresholds, keyed by condition -> nutrient
class ConditionThresholds {
  static const Map<HealthCondition, Map<String, NutrientThreshold>> thresholds = {
    HealthCondition.hypertension: {
      'sodiumMg': NutrientThreshold(suitableMaxInclusive: 100, cautionMinInclusive: 400),
    },
    HealthCondition.diabetes: {
      'sugarsG': NutrientThreshold(suitableMaxInclusive: 2.5, cautionMinInclusive: 9.5),
    },
  };
}

// Table 3.15 risk scoring: Suitable=1, Moderate=2, Caution=3 points
class RiskScoring {
  static const Map<AdvisoryLevel, int> points = {
    AdvisoryLevel.suitable: 1,
    AdvisoryLevel.moderate: 2,
    AdvisoryLevel.caution: 3,
  };
}
