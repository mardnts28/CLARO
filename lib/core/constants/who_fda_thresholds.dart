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
  static const double totalCarbohydratesGPerDay = 375;
  static const double saturatedFatGPerDay = 22.2;

  // WHO: trans fat < 1% of total energy/day (~2.2 g/day on 2,000 kcal).
  static const double transFatGPerDay = 2.2;

  // WHO: protein 10-15% of daily energy; the upper bound is ~75 g/day on
  // 2,000 kcal. Used as the reference for the Kidney Disease protein row.
  static const double proteinGPerDay = 75;
}

class ConditionThresholds {
  static const NutrientThreshold _sodiumThreshold = NutrientThreshold(
    suitableMaxInclusive: 100,
    cautionMinInclusive: 400,
  );

  static const NutrientThreshold _saturatedFatThreshold = NutrientThreshold(
    suitableMaxInclusive: 1.11,
    cautionMinInclusive: 4.44,
  );

  // Trans fat threshold: < 0.22g per 100g is Suitable (1% of 2.2g daily limit)
  // >= 0.44g per 100g is Caution (20% of 2.2g daily limit)
  static const NutrientThreshold _transFatThreshold = NutrientThreshold(
    suitableMaxInclusive: 0.22,
    cautionMinInclusive: 0.44,
  );

  static const Map<HealthCondition, Map<String, NutrientThreshold>> thresholds =
      {
        HealthCondition.cardiovascularDisease: {
          'sodiumMg': _sodiumThreshold,
          'saturatedFatG': _saturatedFatThreshold,
          'transFatG': _transFatThreshold,
        },
        HealthCondition.kidneyDisease: {'sodiumMg': _sodiumThreshold},
        HealthCondition.diabetes: {
          'sugarsG': NutrientThreshold(
            suitableMaxInclusive: 2.5,
            cautionMinInclusive: 10,
          ),
          'totalCarbohydratesG': NutrientThreshold(
            suitableMaxInclusive: 37.5,
            cautionMinInclusive: 75,
          ),
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