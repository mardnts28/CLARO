// lib/core/utils/fallback_advisory_generator.dart
//
// Module 4.1: "Fallback message if API unavailable." Builds a usable
// HealthAdvisory directly from Phase 1's ProductEvaluation with zero AI
// dependency. Templated, not generated -- deliberately less nuanced than
// the AI version but always available and always accurate to the score.

import 'dart:developer' as dev;

import 'package:flutter/foundation.dart' show debugPrint;

import '../../data/models/health_advisory.dart';
import '../../data/models/health_profile.dart';
import '../../data/models/product_evaluation.dart';
import '../constants/who_fda_thresholds.dart';
import 'gerd_trigger_detector.dart';
import 'kidney_advisory_facts.dart';
import 'serving_size_calculator.dart';
import 'who_calculator.dart';
import '../../models/product_model.dart';

/// Formats percentage wording for health advisories.
/// If percentage <= 100%, returns "takes up X% of the recommended daily intake"
/// If percentage > 100%, returns "(X-100)% exceeding the recommended daily intake"
String _formatPercentageWording(double percentage, bool isTagalog) {
  if (percentage <= 100) {
    return isTagalog
        ? '${percentage.toStringAsFixed(1)}% ng inererekomendang pang araw-araw na pagkain'
        : 'takes up ${percentage.toStringAsFixed(1)}% of the recommended daily intake';
  } else {
    final above = percentage - 100;
    return isTagalog
        ? 'lumagpas sa ${above.toStringAsFixed(1)}% ng inererekomendang pang araw-araw na pagkain'
        : '${above.toStringAsFixed(1)}% exceeding the recommended daily intake';
  }
}

// notNeeded added for Phase 3 (product_ranking_service.dart): used when a
// product falls below the top-N cutoff and deliberately skips the AI call
// for cost reasons, rather than the AI having failed.
enum FallbackReason { timeout, apiError, emptyResponse, parseError, notNeeded }

class FallbackAdvisoryGenerator {
  /// The user's health conditions, worked out from the evaluation itself.
  /// Only used when the caller did not pass `userConditions`:
  ///  - every condition that has a nutrient evaluation (cardiovascular
  ///    disease, diabetes, kidney sodium),
  ///  - GERD, which has no nutrient evaluation but always has `gerd*`
  ///    scored factors,
  ///  - kidney disease, which also shows up as kidney facts / phosphate
  ///    additive factors.
  /// Passing the real profile conditions is always preferred.
  static List<HealthCondition> _inferConditions(ProductEvaluation evaluation) {
    final conditions = <HealthCondition>{
      ...evaluation.nutrientEvaluations.map((e) => e.condition),
    };
    if (evaluation.scoredFactors.any((f) => f.factorKey.startsWith('gerd'))) {
      conditions.add(HealthCondition.gerd);
    }
    if (evaluation.scoredFactors.any(
          (f) => f.factorKey == 'phosphateAdditives',
        ) ||
        KidneyAdvisoryFacts.build(evaluation) != null) {
      conditions.add(HealthCondition.kidneyDisease);
    }
    return conditions.toList();
  }

  static HealthAdvisory generate(
    ProductEvaluation evaluation, {
    required FallbackReason reason,
    String languageCode = 'en',
    // When provided, re-derives every per-serving figure in this text
    // (and the overall level it reports) against THIS size instead of
    // `evaluation.product.servingSizeG`. Lets a UI keep its advisory text
    // in lockstep with a badge/level the user has already recomputed for
    // a size they picked on a dropdown -- without an extra AI call, and
    // without duplicating the Recommended Daily Intake percentage math (reuses the exact same
    // WhoCalculator functions the backend used to build `evaluation` in
    // the first place, so it can't silently drift out of sync).
    double? servingSizeGOverride,
    // When true, user has no health conditions and no allergens - use
    // simplified advisory TEXT.
    bool hasNoConditionsAndNoAllergens = false,
    // The user's saved health conditions. Drives the suggested serving
    // amount (GERD and detected food allergens get none). When null, the
    // conditions are inferred from [evaluation].
    Iterable<HealthCondition>? userConditions,
  }) {
    // Visible in the normal flutter console (dev.log is not), so a real
    // failure (timeout/apiError/parseError) can be told apart from the
    // intentional "notNeeded" skip.
    debugPrint('FallbackAdvisory reason: ${reason.name}');

    final allergen = evaluation.allergenAssessment;
    final isTagalog = languageCode == 'tl';

    final servingSizeG =
        servingSizeGOverride ?? evaluation.product.servingSizeG;
    final conditions = userConditions?.toList() ?? _inferConditions(evaluation);

    // The suggested per-meal amount (Table 3.22). Null ONLY for GERD users
    // and when a food allergen is detected in the product; in every other
    // case an amount is returned, even when nothing is flagged.
    final String? suggestedAmount = ServingSizeCalculator.forProfile(
      conditions: conditions,
      nutritionPer100g: evaluation.product.nutritionPer100g,
      servingSizeG: servingSizeG,
      hasDirectAllergen: allergen.hasDirectAllergen,
    );

    // Do not let an incorrect caller flag turn an active condition (such as
    // GERD) into the no-condition advisory.
    final useNoConditionAdvisory =
        hasNoConditionsAndNoAllergens &&
        conditions.isEmpty &&
        !allergen.hasDirectAllergen;

    // Handle users with no health conditions and no allergens
    if (useNoConditionAdvisory) {
      final safeServing = suggestedAmount;

      // Extract the numeric amount from the safeServing string for formatting
      String? servingAmount;
      if (safeServing != null) {
        // Parse the amount from strings like "Up to 1 full serving (100g) is the suggested amount per meal"
        // or "About half a serving (50g) is the suggested amount per meal"
        // or "No more than 83g is the suggested amount per meal"
        final amountMatch = RegExp(
          r'(\d+(?:\.\d+)?)\s*g',
        ).firstMatch(safeServing);
        if (amountMatch != null) {
          servingAmount = '${amountMatch.group(1)}g';
        }
      }

      final explanation = servingAmount != null
          ? (isTagalog
                ? 'Isipin ang $servingAmount serving per meal (para sa 3 beses na pagkain sa isang araw).'
                : 'Consider a $servingAmount amount per meal (for 3 meals a day).')
          : (isTagalog
                ? 'Maaari itong ikonsumo nang katamtaman bilang bahagi ng balanseng pagkain.'
                : 'Enjoy this in moderation as part of a balanced diet.');

      // Overall level stays Suitable regardless -- this branch is only
      // reached for users with no health conditions and no allergens, and
      // "Suitable" here reflects that nothing was flagged *against a
      // condition*. But a full labeled serving can still deliver more
      // than 100% of the Recommended Daily Intake for sodium, total
      // sugars, or saturated fat even for someone with no diagnosed
      // condition -- worth surfacing so the suggested per-meal amount
      // above doesn't read as an arbitrary downsize. Checked at the
      // product's own full serving size (not the possibly-smaller
      // suggested amount), using the same WhoCalculator daily limits used
      // everywhere else, so this can't drift from the rest of the app.
      //
      // Sodium, total sugars and saturated fat are exactly the nutrients the
      // no-condition suggested amount is built from (Table 3.22), so each
      // reason named here really explains the amount. This also matches
      // AdvisoryPromptBuilder._exceededDailyLimitKeys.
      //
      // Skipped when no amount is shown (e.g. a GERD-only user whose product
      // has no GERD triggers), since there is no smaller portion to explain.
      final exceededNutrientKeys = <String>[];
      if (suggestedAmount != null) {
        final fullServingChecks = <String, double>{
          'sodiumMg': evaluation.product.nutritionPer100g.sodiumMg,
          'sugarsG': evaluation.product.nutritionPer100g.sugarsG,
          'saturatedFatG': evaluation.product.nutritionPer100g.saturatedFatG,
        };
        fullServingChecks.forEach((key, valuePer100g) {
          if (valuePer100g <= 0) return;
          final valuePerServing = (valuePer100g / 100) * servingSizeG;
          final whoDailyLimit = WhoCalculator.getWhoDailyLimit(key);
          final whoPercentage = (valuePerServing / whoDailyLimit) * 100;
          if (whoPercentage > 100) exceededNutrientKeys.add(key);
        });
      }

      String reasonSentence = '';
      if (exceededNutrientKeys.isNotEmpty) {
        final names = exceededNutrientKeys
            .map((k) => _nutrientLabel(k, isTagalog))
            .join(isTagalog ? ' at ' : ' and ');
        reasonSentence = isTagalog
            ? ' Mataas ang $names sa isang buong serving nito kaysa sa inirerekomendang pang-araw-araw na limitasyon, kaya iminumungkahi namin ang mas maliit na bahagi.'
            : ' A full serving of this product is higher in $names than the recommended daily reference amount, which is why a smaller portion is suggested.';
      }

      return HealthAdvisory(
        overallLevel: AdvisoryLevel.suitable,
        warningText: isTagalog
            ? 'Angkop - Walang Minarkahang Nutrient o Sangkap'
            : 'Suitable - No Flagged Nutrient or Ingredient',
        explanation: '$explanation$reasonSentence',
        safeServingSize: safeServing,
        source: AdvisorySource.fallbackRuleBased,
        generatedAt: DateTime.now(),
      );
    }

    if (allergen.hasDirectAllergen) {
      final allergenLabels = allergen.matchedContains
          .map(_allergenLabel)
          .join(', ');

      // One sentence per matched allergen, built from the reliable
      // ingredient-level attribution computed in WhoCalculator.assessAllergens
      // -- never a guess. See AllergenMatchType for what each branch means.
      final sourceSentences = allergen.ingredientSources
          .map((m) => _ingredientSourceSentence(m, isTagalog))
          .toList();
      final sourceText = sourceSentences.join(' ');

      final sentence1 = isTagalog
          ? 'Ang produktong ito ay minarkahan para sa iyong naitalang food allergy ($allergenLabels).'
          : 'This product is flagged for your recorded food allergy ($allergenLabels).';
      final sentence2 = sourceText;
      final sentence3 = isTagalog
          ? 'Inirerekomenda naming kumain nang maingat o iwasan ang produktong ito.'
          : 'Consume with caution or avoid this product.';

      final explanation = '$sentence1 $sentence2 $sentence3';

      // A smaller portion does not make an allergen match acceptable, so
      // no suggested amount is given here.
      return HealthAdvisory(
        overallLevel: AdvisoryLevel.caution,
        warningText: isTagalog
            ? 'Naglalaman ng $allergenLabels – allergen na natukoy'
            : 'Contains $allergenLabels – allergen detected',
        explanation: explanation,
        safeServingSize: null,
        source: AdvisorySource.fallbackRuleBased,
        generatedAt: DateTime.now(),
      );
    }

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

    // Kidney Disease: same structure as every other condition, but
    // narrating sodium + protein (each as a % of the Recommended Daily
    // Intake amount) and any detected phosphate additives. Null for
    // everyone else, so no other condition's advisory changes.
    final kidneyFacts = KidneyAdvisoryFacts.build(
      evaluation,
      servingSizeG: servingSizeG,
    );
    if (kidneyFacts != null) {
      return _kidneyAdvisory(
        evaluation,
        kidneyFacts,
        isTagalog,
        suggestedAmount,
      );
    }

    if (conditions.length == 1 &&
        conditions.single == HealthCondition.gerd) {
      return _gerdOnlyAdvisory(
        evaluation: evaluation,
        suggestedAmount: suggestedAmount,
        isTagalog: isTagalog,
      );
    }

    if (flagged.isEmpty) {
      // No nutrient is flagged per serving, but GERD (which has no nutrient
      // thresholds) can still be flagged by a fat/trigger factor. The screen
      // builds its verdict badge from these same factors, so the text must
      // report them too -- otherwise the banner reads e.g.
      // "Caution - Suitable".
      final gerdConcerns = evaluation.scoredFactors
          .where(
            (f) =>
                f.factorKey.startsWith('gerd') &&
                f.level != AdvisoryLevel.suitable,
          )
          .toList();
      if (gerdConcerns.isNotEmpty) {
        final level = gerdConcerns.any((f) => f.level == AdvisoryLevel.caution)
            ? AdvisoryLevel.caution
            : AdvisoryLevel.moderate;

        final triggerFlagged = gerdConcerns.any(
          (f) =>
              f.factorKey == 'gerdTriggers' &&
              f.status == ScoringStatus.known,
        );
        final fatFlagged = gerdConcerns.any(
          (f) =>
              f.factorKey == 'gerdTotalFat' && f.status == ScoringStatus.known,
        );

        final sentences = <String>[];
        if (triggerFlagged) {
          sentences.add(
            isTagalog
                ? 'May natukoy na posibleng GERD trigger sa mga sangkap; magkakaiba ang reaksyon ng bawat tao.'
                : 'A potential GERD trigger was detected in the ingredients; reactions differ from person to person.',
          );
        }
        if (fatFlagged) {
          sentences.add(
            isTagalog
                ? 'Medyo mataas ang total fat para sa GERD.'
                : 'Total fat is on the higher side for GERD.',
          );
        }
        if (sentences.isEmpty) {
          sentences.add(
            isTagalog
                ? 'Kulang ang impormasyon para lubos na masuri ang produktong ito para sa GERD.'
                : 'There is not enough information to fully check this product for GERD.',
          );
        }

        final String headline;
        if (triggerFlagged) {
          headline = isTagalog
              ? 'Natukoy ang posibleng GERD trigger'
              : 'Potential GERD trigger detected';
        } else if (fatFlagged) {
          headline = isTagalog ? 'Mataas sa total fat' : 'High in total fat';
        } else {
          headline = isTagalog
              ? 'Limitado ang impormasyon'
              : 'Limited information';
        }

        // GERD users never get a suggested amount.
        return HealthAdvisory(
          overallLevel: level,
          warningText: headline,
          explanation: sentences.join(' '),
          safeServingSize: null,
          source: AdvisorySource.fallbackRuleBased,
          generatedAt: DateTime.now(),
        );
      }

      if (conditions.length == 1 &&
          conditions.single == HealthCondition.diabetes) {
        return _diabetesAdvisory(
          nutrients: scaledEvals,
          worst: null,
          overallLevel: AdvisoryLevel.suitable,
          suggestedAmount: suggestedAmount,
          isTagalog: isTagalog,
        );
      }

      // Nothing flagged for this user's conditions. A suggested amount is
      // still given (Table 3.22) unless the user has GERD, so the badge no
      // longer depends on whether anything happened to be flagged.
      dev.log(
        'Suitable product (conditions on file, nothing flagged), serving=$servingSizeG',
        name: 'FallbackAdvisory',
      );

      return HealthAdvisory(
        overallLevel: AdvisoryLevel.suitable,
        warningText: isTagalog ? 'Angkop' : 'Suitable',
        explanation: isTagalog
            ? 'Ang mga nutrients na sinuri namin para sa iyong kundisyon ay pasok sa inirerekomendang limitasyon.'
            : 'The nutrients we checked for your condition(s) are within the recommended range for this product.',
        safeServingSize: suggestedAmount,
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

    if (conditions.length == 1 &&
        conditions.single == HealthCondition.diabetes) {
      return _diabetesAdvisory(
        nutrients: scaledEvals,
        worst: worst,
        overallLevel: overallLevel,
        suggestedAmount: suggestedAmount,
        isTagalog: isTagalog,
      );
    }

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

    // The suggested amount (`suggestedAmount`, Table 3.22) was already
    // worked out above from the user's conditions: the most severely
    // flagged nutrient tied to them. It is null for GERD users.
    final safeServing = suggestedAmount;

    // Sentence 1: "This product contains [amount] ([% of Recommended Daily
    // Intake])." -- no serving size mentioned here. Sugars keeps its own
    // wording -- the app only records TOTAL sugars (no free/added sugars
    // breakdown), but the 50g/day reference it's compared against is
    // specifically for free sugars. This sentence must be explicit about
    // that so we never imply the app measured free/added sugars directly.
    // The percentage wording sits inside parentheses so it reads correctly
    // both below and above 100%.
    final isSugars = worst.nutrientKey == 'sugarsG';
    final amountText =
        '${worst.valuePerServing.toStringAsFixed(1)}${_nutrientUnit(worst.nutrientKey)}';
    final amountSentence = isSugars
        ? (isTagalog
              ? 'Naglalaman ang serving na ito ng $amountText ng total sugars (${_formatPercentageWording(worst.whoDailyLimitPercentage, true)}, batay sa reference para sa free sugars).'
              : 'This serving contains $amountText of total sugars (${_formatPercentageWording(worst.whoDailyLimitPercentage, false)}, measured against the reference for free sugars).')
        : (isTagalog
              ? 'Naglalaman ang produktong ito ng $amountText na $nutrientName '
                    '(${_formatPercentageWording(worst.whoDailyLimitPercentage, true)}).'
              : 'This product contains $amountText of $nutrientName '
                    '(${_formatPercentageWording(worst.whoDailyLimitPercentage, false)}).');

    // Build concise advisory in exactly 2 sentences (mirrors the Gemini
    // prompt's structure -- see AdvisoryPromptBuilder):
    // 1. Nutrient amount + % of Recommended Daily Intake (no serving
    //    size, no math explanation).
    // 2. What that means for the user's condition, without implying this
    //    product causes/worsens/triggers it.
    // The suggested per-meal amount (safeServing) is not stated as a
    // sentence here -- the UI shows it separately as a badge, using the
    // safeServingSize field below.
    final sentence1 = amountSentence;
    final sentence2 = isTagalog
        ? 'Mahalagang bantayan ito kung mayroon kang ${_conditionLabel(worst.condition, isTagalog)}.'
        : 'This is worth watching if you have ${_conditionLabel(worst.condition, isTagalog)}.';

    final explanation = '$sentence1 $sentence2';

    return HealthAdvisory(
      overallLevel: overallLevel,
      warningText: isTagalog
          ? '$severityWord sa $nutrientName'
          : '$severityWord in $nutrientName',
      explanation: explanation,
      safeServingSize: safeServing,
      source: AdvisorySource.fallbackRuleBased,
      generatedAt: DateTime.now(),
    );
  }

  static HealthAdvisory _gerdOnlyAdvisory({
    required ProductEvaluation evaluation,
    required String? suggestedAmount,
    required bool isTagalog,
  }) {
    final factors = evaluation.scoredFactors;
    final fat = factors.firstWhere((f) => f.factorKey == 'gerdTotalFat');
    final triggerFactor = factors.firstWhere(
      (f) => f.factorKey == 'gerdTriggers',
    );
    final detection = GerdTriggerDetector.detect(evaluation.product);
    final ingredientTriggers = detection.triggers
        .where((t) => t.type != GerdTriggerType.highFat)
        .map((t) => t.matchedIngredient)
        .whereType<String>()
        .toSet()
        .toList();

    final fatSentence = fat.isUnknown
        ? (isTagalog
              ? 'Kulang ang impormasyon sa nutrisyon para masuri ang total fat kaugnay ng GERD.'
              : 'There is not enough nutrition information to check total fat for GERD.')
        : (isTagalog
              ? 'Ang total fat na ${fat.valuePerServing?.toStringAsFixed(1)}g bawat serving ay ${fat.level == AdvisoryLevel.suitable ? 'mas mababa sa' : 'umabot o lumampas sa'} umiiral na mataas na sanggunian para sa GERD.'
              : 'Total fat is ${fat.valuePerServing?.toStringAsFixed(1)}g per serving and ${fat.level == AdvisoryLevel.suitable ? 'below' : 'at or above'} the existing high-fat reference for GERD.');

    final triggerSentence = triggerFactor.isUnknown
        ? (isTagalog
              ? 'Kulang ang impormasyon sa mga sangkap para masuri ang mga posibleng GERD trigger.'
              : 'There is not enough ingredient information to check for potential GERD triggers.')
        : ingredientTriggers.isEmpty
        ? (isTagalog
              ? 'Walang natukoy na mga sangkap na posibleng GERD trigger.'
              : 'No potential GERD-triggering ingredients were detected.')
        : (isTagalog
              ? 'May natukoy na mga posibleng GERD trigger sa mga sangkap na ${ingredientTriggers.join(', ')}; magkakaiba ang reaksyon ng bawat tao.'
              : 'Potential GERD triggers were detected in ${ingredientTriggers.join(', ')}; reactions differ from person to person.');

    final overallLevel = factors.fold<AdvisoryLevel>(
      AdvisoryLevel.suitable,
      (current, factor) => _severityRank(factor.level) > _severityRank(current)
          ? factor.level
          : current,
    );
    final warningText = ingredientTriggers.isNotEmpty
        ? (isTagalog
              ? 'Natukoy ang posibleng GERD trigger'
              : 'Potential GERD trigger detected')
        : !fat.isUnknown && fat.level != AdvisoryLevel.suitable
        ? (isTagalog ? 'Mataas sa total fat' : 'High in total fat')
        : (fat.isUnknown || triggerFactor.isUnknown)
        ? (isTagalog ? 'Limitado ang impormasyon' : 'Limited information')
        : (isTagalog ? 'Angkop' : 'Suitable');

    return HealthAdvisory(
      overallLevel: overallLevel,
      warningText: warningText,
      explanation: '$fatSentence $triggerSentence',
      safeServingSize: suggestedAmount,
      source: AdvisorySource.fallbackRuleBased,
      generatedAt: DateTime.now(),
    );
  }

  // Builds the Kidney Disease advisory in the same shape the other
  // conditions use (mirrors the kidney branch of AdvisoryPromptBuilder):
  //   1. Sodium and protein amounts, each with its % of the Recommended Daily
  //      Intake.
  //   2. Detected phosphate additive ingredients -- or, when there are none,
  //      a short "worth watching" note (phosphate additives are never
  //      mentioned unless actually detected).
  // The suggested per-meal amount ([suggestedAmount], Table 3.22: sodium and
  // protein, the most severely flagged one) is shown by the UI as a badge,
  // using the safeServingSize field below. It is null for GERD users and
  // when a food allergen is detected.
  // The "consult an expert" footer is shown by the UI, not repeated here.
  static HealthAdvisory _kidneyAdvisory(
    ProductEvaluation evaluation,
    KidneyAdvisoryFacts k,
    bool isTagalog,
    String? suggestedAmount,
  ) {
    final sodiumAmount = '${k.sodiumMg.toStringAsFixed(1)}mg';
    final proteinAmount = '${k.proteinG.toStringAsFixed(1)}g';

    final amountSentence = isTagalog
        ? 'Naglalaman ang produktong ito ng $sodiumAmount na sodium '
              '(${_formatPercentageWording(k.sodiumPercentage, true)}) at $proteinAmount na protein '
              '(${_formatPercentageWording(k.proteinPercentage, true)}).'
        : 'This product contains $sodiumAmount of sodium '
              '(${_formatPercentageWording(k.sodiumPercentage, false)}) and $proteinAmount of protein '
              '(${_formatPercentageWording(k.proteinPercentage, false)}).';

    final meaningSentence = k.hasPhosphateAdditives
        ? (isTagalog
              ? 'Naglalaman din ito ng mga phosphate additive (${k.phosphateIngredients}), na maaaring may kaugnayan sa kalusugan ng bato.'
              : 'It also contains phosphate additives (${k.phosphateIngredients}), which may be relevant to kidney health.')
        : (isTagalog
              ? 'Mahalagang bantayan ang mga halagang ito kung mayroon kang sakit sa bato.'
              : 'These amounts are worth watching if you have kidney disease.');

    // Level/headline follow only what is actually scored for kidney users
    // (sodium and phosphate additives) -- protein stays informational.
    final phosphateLevel = !k.ingredientDataKnown
        ? AdvisoryLevel.moderate
        : (k.hasPhosphateAdditives
              ? AdvisoryLevel.caution
              : AdvisoryLevel.suitable);
    final overallLevel =
        _severityRank(phosphateLevel) > _severityRank(k.sodiumLevel)
        ? phosphateLevel
        : k.sodiumLevel;

    final String warningText;
    if (k.sodiumFlagged) {
      final severityWord = k.sodiumLevel == AdvisoryLevel.caution
          ? (isTagalog ? 'Mataas' : 'High')
          : (isTagalog ? 'Medyo Mataas' : 'Elevated');
      warningText = k.hasPhosphateAdditives
          ? (isTagalog
                ? '$severityWord sa sodium at phosphate additives'
                : '$severityWord in sodium and phosphate additives')
          : (isTagalog ? '$severityWord sa sodium' : '$severityWord in sodium');
    } else if (k.hasPhosphateAdditives) {
      warningText = isTagalog
          ? 'Natukoy ang phosphate additives'
          : 'Phosphate additives detected';
    } else if (overallLevel == AdvisoryLevel.suitable) {
      warningText = isTagalog ? 'Angkop' : 'Suitable';
    } else {
      warningText = isTagalog
          ? 'Limitado ang impormasyon sa sangkap'
          : 'Limited ingredient information';
    }

    final sentence1 = amountSentence;
    final sentence2 = meaningSentence;

    return HealthAdvisory(
      overallLevel: overallLevel,
      warningText: warningText,
      explanation: '$sentence1 $sentence2',
      safeServingSize: suggestedAmount,
      source: AdvisorySource.fallbackRuleBased,
      generatedAt: DateTime.now(),
    );
  }

  static HealthAdvisory _diabetesAdvisory({
    required List<NutrientEvaluation> nutrients,
    required NutrientEvaluation? worst,
    required AdvisoryLevel overallLevel,
    required String? suggestedAmount,
    required bool isTagalog,
  }) {
    final sugars = nutrients.firstWhere(
      (e) => e.condition == HealthCondition.diabetes && e.nutrientKey == 'sugarsG',
    );
    final carbohydrates = nutrients.firstWhere(
      (e) =>
          e.condition == HealthCondition.diabetes &&
          e.nutrientKey == 'totalCarbohydratesG',
    );
    final sugarsPercentage = _formatPercentageWording(
      sugars.whoDailyLimitPercentage,
      isTagalog,
    );
    final carbohydratesPercentage = _formatPercentageWording(
      carbohydrates.whoDailyLimitPercentage,
      isTagalog,
    );
    final sentence1 = isTagalog
        ? 'Naglalaman ang produktong ito ng ${sugars.valuePerServing.toStringAsFixed(1)}g na total sugars ($sugarsPercentage, batay sa reference para sa free sugars) at ${carbohydrates.valuePerServing.toStringAsFixed(1)}g na total carbohydrates ($carbohydratesPercentage).'
        : 'This product contains ${sugars.valuePerServing.toStringAsFixed(1)}g of total sugars ($sugarsPercentage, measured against the reference for free sugars) and ${carbohydrates.valuePerServing.toStringAsFixed(1)}g of total carbohydrates ($carbohydratesPercentage).';
    final sentence2 = worst == null
        ? (isTagalog
              ? 'Ang dalawang antas ng nutrient ay pasok sa inirerekomendang saklaw para sa diabetes.'
              : 'Both nutrient levels are within the recommended range for diabetes.')
        : (isTagalog
              ? 'Mahalagang isaalang-alang ang mga halagang ito kung may diabetes.'
              : 'These amounts are worth keeping in mind with diabetes.');

    final nutrientName = worst == null
        ? null
        : _nutrientLabel(worst.nutrientKey, isTagalog);
    final severityWord = worst == null
        ? null
        : worst.level == AdvisoryLevel.caution
        ? (isTagalog ? 'Mataas' : 'High')
        : (isTagalog ? 'Medyo Mataas' : 'Elevated');

    return HealthAdvisory(
      overallLevel: overallLevel,
      warningText: worst == null
          ? (isTagalog ? 'Angkop' : 'Suitable')
          : isTagalog
          ? '$severityWord sa $nutrientName'
          : '$severityWord in $nutrientName',
      explanation: '$sentence1 $sentence2',
      safeServingSize: suggestedAmount,
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
        return 'sodium'; // generally untranslated
      case 'sugarsG':
        return 'total sugars';
      case 'totalCarbohydratesG':
        return 'total carbohydrates';
      case 'saturatedFatG':
        return 'saturated fat';
      case 'transFatG':
        return 'trans fat';
      case 'proteinG':
        return 'protein';
      default:
        return key;
    }
  }

  static String _nutrientUnit(String key) {
    switch (key) {
      case 'sodiumMg':
        return 'mg';
      case 'sugarsG':
      case 'totalCarbohydratesG':
      case 'saturatedFatG':
      case 'transFatG':
      case 'proteinG':
        return 'g';
      default:
        return '';
    }
  }

  static String _conditionLabel(HealthCondition c, bool isTagalog) {
    switch (c) {
      case HealthCondition.cardiovascularDisease:
        return isTagalog
            ? 'sakit sa puso (cardiovascular disease)'
            : 'cardiovascular disease';
      case HealthCondition.diabetes:
        return 'diabetes';
      case HealthCondition.gerd:
        return 'GERD';
      case HealthCondition.kidneyDisease:
        return isTagalog ? 'sakit sa bato' : 'kidney disease';
    }
  }

  /// Renders ONE matched allergen's ingredient attribution as a sentence,
  /// following exactly what [AllergenMatchType] was established for it --
  /// never presenting a derived source as if it were a direct match.
  static String _ingredientSourceSentence(
    AllergenIngredientMatch match,
    bool isTagalog,
  ) {
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
  ///
  /// [thisIsBestNutrient] tells us whether [target]'s value for
  /// [nutrientName] is literally the lowest ("best") one in the compared
  /// set -- i.e. [ComparisonFact.thisIsBest] for the fact being narrated.
  /// This is NOT the same thing as the product's overall [rank]: a
  /// product can be #1 overall (across every condition + allergens)
  /// while still not holding the single lowest value for just one
  /// nutrient. [thisIsBestNutrient] lets the #1-overall branch tell the
  /// two apart and phrase the not-literally-lowest case honestly instead
  /// of contradicting the rank badge the user is looking at.
  ///
  /// [supportingReason] is an optional, already-worded clause (e.g. "it
  /// has the lowest saturated fat in this comparison (2.1g per 100g)")
  /// naming a DIFFERENT nutrient where [target] genuinely is the lowest
  /// in the set. Only meaningful when [thisIsBestNutrient] is false and
  /// [rank] is 1. Null when no such nutrient exists, in which case the
  /// generic phrasing is used.
  static String generateRankingExplanation({
    required String nutrientName,
    required String nutrientUnit,
    required double thisValue,
    required double bestValue,
    required double worstValue,
    required int rank,
    required int totalProducts,
    required bool thisIsBestNutrient,
    String? supportingReason,
    String healthCondition = '',
    String languageCode = 'en',
  }) {
    final isTagalog = languageCode == 'tl';
    final conditionClause = healthCondition.isNotEmpty
        ? (isTagalog
              ? ' base sa iyong $healthCondition'
              : ' given your $healthCondition')
        : '';

    // Always format to a fixed number of decimals -- raw doubles (e.g.
    // 12.345678923) were leaking straight into the sentence before.
    final thisValueStr = thisValue.toStringAsFixed(1);
    final bestValueStr = bestValue.toStringAsFixed(1);

    // Guard against division by zero. When the lowest-in-set value is 0
    // (e.g. a product with 0mg sodium), (thisValue - 0) / 0 produces
    // Infinity, which rendered as "Infinity%". In that case we just state
    // the lowest value instead of a percentage difference.
    final canShowPercentage = bestValue > 0 && thisValue != bestValue;
    final percentageDiffStr = canShowPercentage
        ? (((thisValue - bestValue) / bestValue) * 100).abs().toStringAsFixed(0)
        : null;

    final comparisonClause = percentageDiffStr != null
        ? (isTagalog
              ? ', na $percentageDiffStr% mas mataas kumpara sa pinakamababa sa paghahambingang ito ($bestValueStr$nutrientUnit kada 100g)'
              : ', which is $percentageDiffStr% more than the lowest in this comparison ($bestValueStr$nutrientUnit per 100g)')
        : (isTagalog
              ? ' (ang pinakamababa sa paghahambingang ito ay may $bestValueStr$nutrientUnit kada 100g)'
              : ' (the lowest in this comparison has $bestValueStr$nutrientUnit per 100g)');

    // Derived from rank/totalProducts ONLY, never from a separately
    // computed "lowest value of this one nutrient" check. Every branch
    // also states the numeric rank so the sentence is checkable against
    // the badge shown on screen.
    final isBestRank = rank == 1;
    final isWorstRank = rank == totalProducts;

    if (isBestRank) {
      if (thisIsBestNutrient) {
        return isTagalog
            ? 'Ang produktong ito ay nangunguna ($rank sa $totalProducts) na may $thisValueStr$nutrientUnit na $nutrientName kada 100g$conditionClause.'
            : 'This product ranks $rank of $totalProducts (highest-ranked) with $thisValueStr$nutrientUnit $nutrientName per 100g$conditionClause.';
      }
      final tailClause =
          (supportingReason != null && supportingReason.isNotEmpty)
          ? (isTagalog
                ? ', pero $supportingReason, kaya\'t pinakamataas pa rin ang ranggo nito sa kabuuan.'
                : ', but $supportingReason, which keeps it highest-ranked overall.')
          : (isTagalog
                ? ', pero pinakamataas pa rin ang ranggo nito kapag isinaalang-alang ang lahat ng kaugnay na salik.'
                : ', but it remains highest-ranked when every relevant factor is considered.');
      return isTagalog
          ? 'Ang produktong ito ay nangunguna ($rank sa $totalProducts) na may $thisValueStr$nutrientUnit na $nutrientName kada 100g$conditionClause. Hindi ito ang pinakamababa sa $nutrientName sa paghahambingang ito (ang pinakamababa ay $bestValueStr$nutrientUnit kada 100g)$tailClause'
          : 'This product ranks $rank of $totalProducts with $thisValueStr$nutrientUnit $nutrientName per 100g$conditionClause. It is not the single lowest in $nutrientName in this comparison (the lowest is $bestValueStr$nutrientUnit per 100g)$tailClause';
    } else if (isWorstRank) {
      return isTagalog
          ? 'Ang produktong ito ay pang-$rank sa $totalProducts (pinakakonting angkop) na may $thisValueStr$nutrientUnit na $nutrientName kada 100g$conditionClause$comparisonClause.'
          : 'This product ranks $rank of $totalProducts (lowest-ranked) with $thisValueStr$nutrientUnit $nutrientName per 100g$conditionClause$comparisonClause.';
    } else {
      return isTagalog
          ? 'Ang produktong ito ay pang-$rank sa $totalProducts na may $thisValueStr$nutrientUnit na $nutrientName kada 100g$conditionClause$comparisonClause.'
          : 'This product ranks $rank of $totalProducts with $thisValueStr$nutrientUnit $nutrientName per 100g$conditionClause$comparisonClause.';
    }
  }
}