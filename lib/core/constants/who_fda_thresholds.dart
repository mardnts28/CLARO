// lib/core/constants/who_fda_thresholds.dart
//
// Pure threshold/config values. Source: Table 3.14 "Condition-Specific
// Advisory Thresholds" (per 100g basis) and Table 3.15 (risk scoring points).
//
// This file holds ONLY constants -- no logic. The calculator that reads
// these values lives in core/utils/who_calculator.dart, per your leader's
// planned structure.
//


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
  static const double saturatedFatGPerDay = 22.2;
}

class ConditionThresholds {
  static const Map<HealthCondition, Map<String, NutrientThreshold>> thresholds = {
    HealthCondition.hypertension: {
      'sodiumMg': NutrientThreshold(suitableMaxInclusive: 100, cautionMinInclusive: 400),
      // unchanged
    },
    HealthCondition.diabetes: {
      'sugarsG': NutrientThreshold(suitableMaxInclusive: 2.5, cautionMinInclusive: 10),
      // 9.5 → 10
    },
    HealthCondition.heartCondition: {
      'saturatedFatG': NutrientThreshold(suitableMaxInclusive: 1.11, cautionMinInclusive: 4.44),
      // 2.2/4.4 → 1.11/4.44
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
