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
    // When true, uses combined nutrient calculation (sodium + sugars + saturated fat)
    // instead of single worst nutrient. Intended for users without health conditions.
    bool useCombinedNutrients = false,
    // When true, user has no health conditions and no allergens - use simplified advisory
    bool hasNoConditionsAndNoAllergens = false,
  }) {
    final allergen = evaluation.allergenAssessment;
    final isTagalog = languageCode == 'tl';

    // Handle users with no health conditions and no allergens
    if (hasNoConditionsAndNoAllergens) {
      final servingSizeG = servingSizeGOverride ?? evaluation.product.servingSizeG;
      
      // Use combined nutrient calculation
      final safeServing = ServingSizeCalculator.calculateCombinedNutrients(
        nutritionPer100g: evaluation.product.nutritionPer100g,
        servingSizeG: servingSizeG,
      );

      // Extract the numeric amount from the safeServing string for formatting
      String? servingAmount;
      if (safeServing != null) {
        // Parse the amount from strings like "Up to 1 full serving (100g) is the suggested amount per meal"
        // or "About half a serving (50g) is the suggested amount per meal"
        // or "No more than 83g is the suggested amount per meal"
        final amountMatch = RegExp(r'(\d+(?:\.\d+)?)\s*g').firstMatch(safeServing);
        if (amountMatch != null) {
          servingAmount = '${amountMatch.group(1)}g';
        }
      }

      final explanation = servingAmount != null
          ? (isTagalog
              ? 'Isipin ang $servingAmount serving per meal (para sa 3 beses na pagkain sa isang araw).'
              : 'Consider a $servingAmount serving per meal (for 3 meals a day).')
          : (isTagalog
              ? 'Mainit ito nang maayos bilang bahagi ng balanced na pagkain.'
              : 'Enjoy this in moderation as part of a balanced diet.');

      return HealthAdvisory(
        overallLevel: AdvisoryLevel.suitable,
        warningText: isTagalog ? 'Angkop' : 'Suitable',
        explanation: explanation,
        safeServingSize: safeServing,
        source: AdvisorySource.fallbackRuleBased,
        generatedAt: DateTime.now(),
      );
    }

    if (allergen.hasDirectAllergen) {
      final allergenLabels = allergen.matchedContains.map(_allergenLabel).join(', ');

      // One sentence per matched allergen, built from the reliable
      // ingredient-level attribution computed in WhoCalculator.assessAllergens
      // -- never a guess. See AllergenMatchType for what each branch means.
      final sourceSentences = allergen.ingredientSources
          .map((m) => _ingredientSourceSentence(m, isTagalog))
          .toList();
      final sourceText = sourceSentences.join(' ');

      final explanation = isTagalog
          ? 'Ang produktong ito ay minarkahan para sa iyong naitalang food allergy ($allergenLabels). $sourceText Inirerekomenda naming kumain nang maingat o iwasan ang produktong ito.'
          : 'This product is flagged for your recorded food allergy ($allergenLabels). $sourceText Consume with caution or avoid this product.';

      return HealthAdvisory(
        overallLevel: AdvisoryLevel.caution,
        warningText: isTagalog
            ? 'Naglalaman ng ${allergenLabels} – allergen na natukoy'
            : 'Contains $allergenLabels – allergen detected',
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
    // "severityWord" feeds the warningText headline only -- it must NOT
    // repeat one of the three decision-level words ("Caution"/"Moderate"/
    // "Suitable") the UI already shows separately as the badge, so
    // "Moderate" specifically is replaced with a different descriptive
    // word here ("Elevated"/"Medyo Mataas") even though the underlying
    // classification level is still exactly `worst.level` -- unchanged.
    final severityWord = worst.level == AdvisoryLevel.caution
        ? (isTagalog ? 'Mataas' : 'High')
        : (isTagalog ? 'Medyo Mataas' : 'Elevated');

    // Calculate suggested serving amount
    // Use combined nutrient calculation when flag is set, otherwise use single worst nutrient
    final safeServing = useCombinedNutrients
        ? ServingSizeCalculator.calculateCombinedNutrients(
            nutritionPer100g: evaluation.product.nutritionPer100g,
            servingSizeG: servingSizeG,
          )
        : ServingSizeCalculator.calculate(
            nutrientKey: worst.nutrientKey,
            valuePer100g: worst.valuePer100g,
            servingSizeG: servingSizeG,
          );

    // Sentence 1: "This product contains [amount] ([% of WHO daily
    // reference amount])." -- no serving size mentioned here. Sugars
    // keeps its own exact wording -- the app only records TOTAL sugars
    // (no free/added sugars breakdown), but the WHO 50g/day reference
    // it's compared against is specifically for free sugars. This
    // sentence must be explicit about that so we never imply the app
    // measured free/added sugars directly.
    final isSugars = worst.nutrientKey == 'sugarsG';
    final amountSentence = isSugars
        ? (isTagalog
            ? 'Naglalaman ang serving na ito ng ${worst.valuePerServing.toStringAsFixed(1)}${_nutrientUnit(worst.nutrientKey)} ng total sugars, na humigit-kumulang ${worst.whoDailyLimitPercentage.toStringAsFixed(1)}% ng WHO reference para sa free sugars.'
            : 'This serving contains ${worst.valuePerServing.toStringAsFixed(1)}${_nutrientUnit(worst.nutrientKey)} of total sugars, which is about ${worst.whoDailyLimitPercentage.toStringAsFixed(1)}% of the WHO reference for free sugars.')
        : (isTagalog
            ? 'Naglalaman ang produktong ito ng ${worst.valuePerServing.toStringAsFixed(1)}${_nutrientUnit(worst.nutrientKey)} na $nutrientName '
                '(${worst.whoDailyLimitPercentage.toStringAsFixed(1)}% ng WHO daily reference amount).'
            : 'This product contains ${worst.valuePerServing.toStringAsFixed(1)}${_nutrientUnit(worst.nutrientKey)} of $nutrientName '
                '(${worst.whoDailyLimitPercentage.toStringAsFixed(1)}% of the WHO daily reference amount).');

    // Build concise advisory in exactly 3 sentences (mirrors the Gemini
    // prompt's structure -- see AdvisoryPromptBuilder):
    // 1. Nutrient amount + % of WHO daily reference amount (no serving
    //    size, no math explanation).
    // 2. What that means for the user's condition, without implying this
    //    product causes/worsens/triggers it.
    // 3. The supplied suggested per-meal amount, exactly as supplied,
    //    with the 3-meals-a-day context kept in parentheses and no
    //    restatement of the underlying 100%/WHO math. Falls back to a
    //    short general recommendation when no serving amount was supplied.
    final perMealSentence = safeServing != null
        ? (isTagalog
            ? '$safeServing (para sa hanggang 3 beses na pagkain sa isang araw).'
            : '$safeServing (for up to 3 meals a day).')
        : (isTagalog
            ? 'Kainin ito nang katamtaman bilang bahagi ng balanced na pagkain.'
            : 'Enjoy this in moderation as part of a balanced diet.');

    final explanation = isTagalog
        ? '$amountSentence '
          'Mahalagang bantayan ito kung mayroon kang ${_conditionLabel(worst.condition, isTagalog)}. '
          '$perMealSentence'
        : '$amountSentence '
          'This is worth watching if you have ${_conditionLabel(worst.condition, isTagalog)}. '
          '$perMealSentence';

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
        return isTagalog ? 'total sugars' : 'total sugars';
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

  /// Renders ONE matched allergen's ingredient attribution as a sentence,
  /// following exactly what [AllergenMatchType] was established for it --
  /// never presenting a derived source as if it were a direct match.
  static String _ingredientSourceSentence(AllergenIngredientMatch match, bool isTagalog) {
    final allergenLabel = _allergenLabel(match.allergen);
    switch (match.matchType) {
      case AllergenMatchType.direct:
        return isTagalog
            ? 'Nakitang sangkap: ${match.ingredient} ($allergenLabel).'
            : 'Detected ingredient: ${match.ingredient} ($allergenLabel).';
      case AllergenMatchType.derived:
        return isTagalog
            ? 'Nakitang sangkap: ${match.ingredient} (galing sa $allergenLabel).'
            : 'Detected ingredient: ${match.ingredient} ($allergenLabel-derived).';
      case AllergenMatchType.undetermined:
        // This case should no longer occur since we removed undetermined matches
        // from allergen assessment. Kept for safety but should never be hit.
        return isTagalog
            ? 'Hindi matukoy sa available na impormasyon kung aling partikular na sangkap ang pinagmulan ng $allergenLabel.'
            : 'Ingredient source could not be determined from the available information.';
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