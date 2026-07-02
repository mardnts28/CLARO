// lib/core/utils/fallback_advisory_generator.dart
//
// Module 4.1: "Fallback message if API unavailable." Builds a usable
// HealthAdvisory directly from Phase 1's ProductEvaluation with zero AI
// dependency. Templated, not generated -- deliberately less nuanced than
// the AI version but always available and always accurate to the score.

import '../../data/models/health_advisory.dart';
import '../../data/models/health_profile.dart';
import '../../data/models/product_evaluation.dart';
import '../constants/who_fda_thresholds.dart';

// notNeeded added for Phase 3 (product_ranking_service.dart): used when a
// product falls below the top-N cutoff and deliberately skips the AI call
// for cost reasons, rather than the AI having failed.
enum FallbackReason { timeout, apiError, emptyResponse, parseError, notNeeded }

class FallbackAdvisoryGenerator {
  static HealthAdvisory generate(
    ProductEvaluation evaluation, {
    required FallbackReason reason,
  }) {
    final allergen = evaluation.allergenAssessment;

    if (allergen.hasDirectAllergen) {
      return HealthAdvisory(
        overallLevel: AdvisoryLevel.caution,
        warningText: 'Contains an allergen you flagged',
        explanation:
            'This product contains an ingredient matching an allergy on your '
            'profile. We recommend avoiding this product.',
        safeServingSize: null,
        source: AdvisorySource.fallbackRuleBased,
        generatedAt: DateTime.now(),
      );
    }

    final flagged = evaluation.nutrientEvaluations
        .where((e) => e.level != AdvisoryLevel.suitable)
        .toList();

    if (flagged.isEmpty) {
      return HealthAdvisory(
        overallLevel: AdvisoryLevel.suitable,
        warningText: 'Suitable for your health profile',
        explanation:
            'The nutrients we checked for your condition(s) are within the '
            'recommended range for this product.',
        safeServingSize: null,
        source: AdvisorySource.fallbackRuleBased,
        generatedAt: DateTime.now(),
      );
    }

    final worst = flagged.reduce(
      (a, b) => _severityRank(b.level) > _severityRank(a.level) ? b : a,
    );

    final nutrientName = _nutrientLabel(worst.nutrientKey);
    final severityWord =
        worst.level == AdvisoryLevel.caution ? 'High' : 'Moderate';

    return HealthAdvisory(
      overallLevel: evaluation.overallLevel,
      warningText: '$severityWord in $nutrientName',
      explanation:
          'This product is ${severityWord.toLowerCase()} in $nutrientName '
          '(${worst.valuePer100g}${_nutrientUnit(worst.nutrientKey)} per 100g), '
          'which may affect your ${_conditionLabel(worst.condition)}. '
          'Consider a smaller serving or a lower-$nutrientName alternative.',
      safeServingSize: null,
      source: AdvisorySource.fallbackRuleBased,
      generatedAt: DateTime.now(),
    );
  }

  static int _severityRank(AdvisoryLevel level) {
    switch (level) {
      case AdvisoryLevel.suitable:
        return 0;
      case AdvisoryLevel.moderate:
        return 1;
      case AdvisoryLevel.caution:
        return 2;
    }
  }

  static String _nutrientLabel(String key) {
    switch (key) {
      case 'sodiumMg':
        return 'sodium';
      case 'sugarsG':
        return 'sugar';
      default:
        return key;
    }
  }

  static String _nutrientUnit(String key) {
    switch (key) {
      case 'sodiumMg':
        return 'mg';
      case 'sugarsG':
        return 'g';
      default:
        return '';
    }
  }

  static String _conditionLabel(HealthCondition c) {
    switch (c) {
      case HealthCondition.hypertension:
        return 'hypertension';
      case HealthCondition.diabetes:
        return 'diabetes';
    }
  }
}