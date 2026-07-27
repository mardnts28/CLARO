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
import 'serving_size_calculator.dart';
import 'who_calculator.dart';
import '../../models/product_model.dart';

// notNeeded added for Phase 3 (product_ranking_service.dart): used when a
// product falls below the top-N cutoff and deliberately skips the AI call
// for cost reasons, rather than the AI having failed.
enum FallbackReason { timeout, apiError, emptyResponse, parseError, notNeeded }

class FallbackAdvisoryGenerator {
  static HealthAdvisory generate(
    ProductEvaluation evaluation, {
    required FallbackReason reason,
    String languageCode = 'en',
    // When provided, re-derives every per-serving figure in this text
    // (and the overall level it reports) against THIS size instead of
    // `evaluation.product.servingSizeG`. Lets a UI keep its advisory text
    // in lockstep with a badge/level the user has already recomputed for
    // a size they picked on a dropdown -- without an extra AI call, and
    // without duplicating the WHO-percentage math (reuses the exact same
    // WhoCalculator functions the backend used to build `evaluation` in
    // the first place, so it can't silently drift out of sync).
    double? servingSizeGOverride,
  }) {
    final allergen = evaluation.allergenAssessment;
    final isTagalog = languageCode == 'tl';

    if (allergen.hasDirectAllergen) {
      // Build detailed explanation with specific matching ingredients
      final allergenLabels = allergen.matchedContains.map(_allergenLabel).join(', ');
      final ingredientList = allergen.matchedIngredients.isNotEmpty
          ? allergen.matchedIngredients.join(', ')
          : allergenLabels;

      final explanation = isTagalog
          ? 'Ang produktong ito ay naglalaman ng $ingredientList, na tumutugma sa iyong naitalang food allergy ($allergenLabels). Inirerekomenda naming kumain nang maingat o iwasan ang produktong ito.'
          : 'This product contains $ingredientList, which match your recorded food allergy ($allergenLabels). Consume with caution or avoid this product.';

      return HealthAdvisory(
        overallLevel: AdvisoryLevel.caution,
        warningText: isTagalog
            ? 'Naglalaman ng allergen na iyong tinukoy'
            : 'Contains an allergen you flagged',
        explanation: explanation,
        safeServingSize: null,
        source: AdvisorySource.fallbackRuleBased,
        generatedAt: DateTime.now(),
      );
    }

    final servingSizeG = servingSizeGOverride ?? evaluation.product.servingSizeG;

    // Re-derive valuePerServing/whoDailyLimitPercentage/level for
    // `servingSizeG` from each nutrient's stored valuePer100g, using the
    // same WhoCalculator functions the backend used. When no override is
    // given this reproduces `evaluation.nutrientEvaluations` exactly, so
    // existing (no-override) callers see no behavior change.
    final scaledEvals = evaluation.nutrientEvaluations.map((e) {
      final valuePerServing = (e.valuePer100g / 100) * servingSizeG;
      final whoDailyLimit = WhoCalculator.getWhoDailyLimit(e.nutrientKey);
      final whoPercentage = (valuePerServing / whoDailyLimit) * 100;
      return NutrientEvaluation(
        condition: e.condition,
        nutrientKey: e.nutrientKey,
        valuePer100g: e.valuePer100g,
        valuePerServing: valuePerServing,
        whoDailyLimitPercentage: whoPercentage,
        level: WhoCalculator.classifyByWhoPercentage(whoPercentage),
      );
    }).toList();

    final flagged = scaledEvals
        .where((e) => e.level != AdvisoryLevel.suitable)
        .toList();

    if (flagged.isEmpty) {
      return HealthAdvisory(
        overallLevel: AdvisoryLevel.suitable,
        warningText: isTagalog
            ? 'Angkop'
            : 'Suitable',
        explanation: isTagalog
            ? 'Ang mga nutrients na sinuri namin para sa iyong kundisyon ay pasok sa inirerekomendang limitasyon.'
            : 'The nutrients we checked for your condition(s) are within the recommended range for this product.',
        safeServingSize: null,
        source: AdvisorySource.fallbackRuleBased,
        generatedAt: DateTime.now(),
      );
    }

    final worst = flagged.reduce(
      (a, b) => _severityRank(b.level) > _severityRank(a.level) ? b : a,
    );
    final overallLevel = flagged.any((e) => e.level == AdvisoryLevel.caution)
        ? AdvisoryLevel.caution
        : AdvisoryLevel.moderate;

    final nutrientName = _nutrientLabel(worst.nutrientKey, isTagalog);
    final severityWord =
        worst.level == AdvisoryLevel.caution ? (isTagalog ? 'Mataas' : 'High') : (isTagalog ? 'Katamtaman' : 'Moderate');

    // Calculate safe serving
    final safeServing = ServingSizeCalculator.calculate(
      condition: worst.condition,
      nutrientKey: worst.nutrientKey,
      valuePer100g: worst.valuePer100g,
      servingSizeG: servingSizeG,
    );

    // Build concise advisory following the new format
    final explanation = isTagalog
        ? 'Naglalaman ng ${worst.valuePerServing.toStringAsFixed(1)}${_nutrientUnit(worst.nutrientKey)} ng '
          '$nutrientName bawat serving (${servingSizeG.toStringAsFixed(0)}g), '
          'na katumbas ng ${worst.whoDailyLimitPercentage.toStringAsFixed(1)}% ng inirerekomendang limitasyon sa isang araw. '
          'Maaari itong makaapekto sa iyong ${_conditionLabel(worst.condition, isTagalog)}. '
          '${safeServing != null ? 'Isaalang-alang ang paglimita sa $safeServing.' : ''}'
        : 'Contains ${worst.valuePerServing.toStringAsFixed(1)}${_nutrientUnit(worst.nutrientKey)} of '
          '$nutrientName per serving (${servingSizeG.toStringAsFixed(0)}g), '
          'which is ${worst.whoDailyLimitPercentage.toStringAsFixed(1)}% of the recommended healthy daily limit. '
          'This may affect your ${_conditionLabel(worst.condition, isTagalog)}. '
          '${safeServing != null ? 'Consider limiting to $safeServing.' : ''}';

    return HealthAdvisory(
      overallLevel: overallLevel,
      warningText: isTagalog ? '$severityWord sa $nutrientName' : '$severityWord in $nutrientName',
      explanation: explanation,
      safeServingSize: safeServing,
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

  static String _nutrientLabel(String key, bool isTagalog) {
    switch (key) {
      case 'sodiumMg':
        return isTagalog ? 'sodium' : 'sodium'; // generally untranslated
      case 'sugarsG':
        return isTagalog ? 'asukal' : 'sugar';
      case 'saturatedFatG':
        return isTagalog ? 'saturated fat' : 'saturated fat';
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
      case 'saturatedFatG':
        return 'g';
      default:
        return '';
    }
  }

  static String _conditionLabel(HealthCondition c, bool isTagalog) {
    switch (c) {
      case HealthCondition.hypertension:
        return isTagalog ? 'altapresyon (hypertension)' : 'hypertension';
      case HealthCondition.diabetes:
        return 'diabetes';
      case HealthCondition.heartCondition:
        return isTagalog ? 'kondisyon sa puso' : 'heart condition';
    }
  }

  static String _allergenLabel(AllergenType a) {
    switch (a) {
      case AllergenType.shellfish:
        return 'shellfish';
      case AllergenType.fish:
        return 'fish';
      case AllergenType.peanuts:
        return 'peanuts';
      case AllergenType.treeNuts:
        return 'tree nuts';
      case AllergenType.soy:
        return 'soy';
      case AllergenType.dairy:
        return 'dairy/milk';
      case AllergenType.eggs:
        return 'eggs';
      case AllergenType.wheatGluten:
        return 'wheat/gluten';
      case AllergenType.msg:
        return 'MSG';
    }
  }

  /// [healthCondition] is the user's condition name (e.g. "hypertension",
  /// or a comma-joined list for multiple conditions). Used here purely as
  /// templated text -- no AI call involved -- so the fallback sentence
  /// still ties the nutrient back to the user's condition even when
  /// Gemini is unavailable. May be empty if the user has no conditions on
  /// file, in which case the condition clause is simply omitted.
  static String generateRankingExplanation({
    required String nutrientName,
    required String nutrientUnit,
    required double thisValue,
    required double bestValue,
    required double worstValue,
    required int rank,
    required int totalProducts,
    String healthCondition = '',
    String languageCode = 'en',
  }) {
    final isTagalog = languageCode == 'tl';
    final conditionClause = healthCondition.isNotEmpty 
        ? (isTagalog ? ' base sa iyong ${healthCondition}' : ' given your $healthCondition')
        : '';

    // Always format to a fixed number of decimals -- raw doubles (e.g.
    // 12.345678923) were leaking straight into the sentence before.
    final thisValueStr = thisValue.toStringAsFixed(1);
    final bestValueStr = bestValue.toStringAsFixed(1);

    // Guard against division by zero. When the best-in-set value is 0
    // (e.g. a product with 0mg sodium), (thisValue - 0) / 0 produces
    // Infinity, which rendered as "Infinity%". In that case we just state
    // the best option's value instead of a percentage difference.
    final canShowPercentage = bestValue > 0 && thisValue != bestValue;
    final percentageDiffStr = canShowPercentage
        ? (((thisValue - bestValue) / bestValue) * 100).abs().toStringAsFixed(0)
        : null;

    final comparisonClause = percentageDiffStr != null
        ? (isTagalog 
            ? ', na $percentageDiffStr% mas mataas kumpara sa pinakamagandang opsyon (${bestValueStr}$nutrientUnit kada 100g)' 
            : ', which is $percentageDiffStr% more than the best option (${bestValueStr}$nutrientUnit per 100g)')
        : (isTagalog
            ? ' (ang pinakamagandang opsyon sa pinagkukumparahan na ito ay may ${bestValueStr}$nutrientUnit kada 100g)'
            : ' (the best option in this comparison has ${bestValueStr}$nutrientUnit per 100g)');

    // Derived from rank/totalProducts ONLY, never from a separately
    // computed "lowest value of this one nutrient" check -- that mismatch
    // (a product can be #1 overall without having the single lowest value
    // of one nutrient) was the root cause of the rank/explanation
    // contradiction. Every branch also states the numeric rank so the
    // sentence is checkable against the badge shown on screen.
    final isBestRank = rank == 1;
    final isWorstRank = rank == totalProducts;

    if (isBestRank) {
      return isTagalog
          ? 'Ang produktong ito ay nangunguna ($rank sa $totalProducts) (pinakamagandang opsyon) na may ${thisValueStr}$nutrientUnit na $nutrientName kada 100g$conditionClause$comparisonClause.'
          : 'This product ranks $rank of $totalProducts (top choice) with ${thisValueStr}$nutrientUnit $nutrientName per 100g$conditionClause$comparisonClause.';
    } else if (isWorstRank) {
      return isTagalog
          ? 'Ang produktong ito ay pang-$rank sa $totalProducts (pinakakonting angkop) na may ${thisValueStr}$nutrientUnit na $nutrientName kada 100g$conditionClause$comparisonClause.'
          : 'This product ranks $rank of $totalProducts (least suitable) with ${thisValueStr}$nutrientUnit $nutrientName per 100g$conditionClause$comparisonClause.';
    } else {
      return isTagalog
          ? 'Ang produktong ito ay pang-$rank sa $totalProducts na may ${thisValueStr}$nutrientUnit na $nutrientName kada 100g$conditionClause$comparisonClause.'
          : 'This product ranks $rank of $totalProducts with ${thisValueStr}$nutrientUnit $nutrientName per 100g$conditionClause$comparisonClause.';
    }
  }
}