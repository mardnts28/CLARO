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
import 'kidney_advisory_facts.dart';
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
      final servingSizeG =
          servingSizeGOverride ?? evaluation.product.servingSizeG;

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
                : 'Consider a $servingAmount serving per meal (for 3 meals a day).')
          : (isTagalog
                ? 'Mainit ito nang maayos bilang bahagi ng balanced na pagkain.'
                : 'Enjoy this in moderation as part of a balanced diet.');

      // Overall level stays Suitable regardless -- this branch is only
      // reached for users with no health conditions and no allergens, and
      // "Suitable" here reflects that nothing was flagged *against a
      // condition*. But a full labeled serving can still deliver more
      // than 100% of the WHO daily reference amount for sodium, total
      // sugars, and/or saturated fat even for someone with no diagnosed
      // condition -- worth surfacing so the suggested per-meal amount
      // above doesn't read as an arbitrary downsize. Checked at the
      // product's own full serving size (not the possibly-smaller
      // suggested amount), using the same WhoCalculator daily limits used
      // everywhere else, so this can't drift from the rest of the app.
      final exceededNutrientKeys = <String>[];
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

    final servingSizeG =
        servingSizeGOverride ?? evaluation.product.servingSizeG;

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

    // Kidney Disease: same 3-sentence structure as every other condition,
    // but narrating sodium + protein (each as a % of the WHO daily reference
    // amount) and any detected phosphate additives. Null for everyone else,
    // so no other condition's advisory changes.
    final kidneyFacts = KidneyAdvisoryFacts.build(
      evaluation,
      servingSizeG: servingSizeG,
    );
    if (kidneyFacts != null) {
      return _kidneyAdvisory(evaluation, kidneyFacts, isTagalog);
    }

    // IMPORTANT: this check must come AFTER `flagged` is computed, and
    // must only fire when there is no flagged *nutrient* to report.
    // `evaluation.scoredFactors` is populated for every scored condition
    // (e.g. plain hypertension contributes a 'sodiumMg' scored factor),
    // not just the GERD/Kidney awareness-only factors it was originally
    // written for -- so `scoredFactors.isNotEmpty` is true for almost
    // every user with any condition on file. Checking it BEFORE `flagged`
    // (as this used to) meant the proper amount/impact/serving 3-sentence
    // advisory below was skipped in favor of this generic factor-by-factor
    // dump for nearly all single (non-group) users, even when a specific
    // nutrient really was flagged for their condition. Awareness-only
    // factors that have no nutrient-evaluation counterpart (GERD triggers,
    // GERD total fat) are surfaced by the GERD warning card elsewhere in the
    // UI (kidney phosphate additives are handled by the kidney branch
    // above), so this fallback text is only needed when nothing else is
    // available to say.
    if (flagged.isEmpty && evaluation.scoredFactors.isNotEmpty) {
      final factorText = evaluation.scoredFactors
          .map((factor) {
            final label = _factorLabel(factor.factorKey, isTagalog);
            if (factor.isUnknown) {
              return isTagalog
                  ? '$label: kulang ang impormasyon para matukoy ito.'
                  : '$label: not enough information to determine this.';
            }
            return '$label: ${factor.explanation}';
          })
          .join(' ');
      return HealthAdvisory(
        overallLevel: evaluation.overallLevel,
        warningText: isTagalog
            ? 'Suriin ang mga health factor'
            : 'Review health factors',
        explanation: factorText,
        safeServingSize: null,
        source: AdvisorySource.fallbackRuleBased,
        generatedAt: DateTime.now(),
      );
    }

    if (flagged.isEmpty) {
      return HealthAdvisory(
        overallLevel: AdvisoryLevel.suitable,
        warningText: isTagalog ? 'Angkop' : 'Suitable',
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

    // Build concise advisory in exactly 2 sentences (mirrors the Gemini
    // prompt's structure -- see AdvisoryPromptBuilder):
    // 1. Nutrient amount + % of WHO daily reference amount (no serving
    //    size, no math explanation).
    // 2. What that means for the user's condition, without implying this
    //    product causes/worsens/triggers it.
    // The suggested per-meal amount (safeServing) is no longer stated as a
    // sentence here -- the UI shows it separately as a badge, using the
    // safeServingSize field below, matching how the group health analysis
    // card already presents a member's suggested amount.
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

  // Builds the Kidney Disease advisory in the same exactly-3-sentence shape
  // the other conditions use (mirrors the kidney branch of
  // AdvisoryPromptBuilder):
  //   1. Sodium and protein amounts, each with its % of the WHO daily
  //      reference amount.
  //   2. Detected phosphate additive ingredients -- or, when there are none,
  //      a short "worth watching" note (phosphate additives are never
  //      mentioned unless actually detected).
  // The suggested per-meal amount (sodium-based) is no longer stated as a
  // sentence here -- the UI shows it separately as a badge, using the
  // safeServingSize field below, matching how the group health analysis
  // card already presents a member's suggested amount.
  // The "consult an expert" footer is shown by the UI, not repeated here.
  static HealthAdvisory _kidneyAdvisory(
    ProductEvaluation evaluation,
    KidneyAdvisoryFacts k,
    bool isTagalog,
  ) {
    final sodiumAmount = '${k.sodiumMg.toStringAsFixed(1)}mg';
    final sodiumPct = k.sodiumPercentage.toStringAsFixed(1);
    final proteinAmount = '${k.proteinG.toStringAsFixed(1)}g';
    final proteinPct = k.proteinPercentage.toStringAsFixed(1);

    final amountSentence = isTagalog
        ? 'Naglalaman ang produktong ito ng $sodiumAmount na sodium '
              '($sodiumPct% ng WHO daily reference amount) at $proteinAmount na protein '
              '($proteinPct% ng WHO daily reference amount).'
        : 'This product contains $sodiumAmount of sodium '
              '($sodiumPct% of the WHO daily reference amount) and $proteinAmount of protein '
              '($proteinPct% of the WHO daily reference amount).';

    final meaningSentence = k.hasPhosphateAdditives
        ? (isTagalog
              ? 'Naglalaman din ito ng mga phosphate additive (${k.phosphateIngredients}), na maaaring may kaugnayan sa kalusugan ng bato.'
              : 'It also contains phosphate additives (${k.phosphateIngredients}), which may be relevant to kidney health.')
        : (isTagalog
              ? 'Mahalagang bantayan ang mga halagang ito kung mayroon kang sakit sa bato.'
              : 'These amounts are worth watching if you have kidney disease.');

    // Suggested amount stays sodium-based, exactly as it was for kidney
    // users before (protein is informational only, not scored).
    final safeServing = k.sodiumFlagged
        ? ServingSizeCalculator.calculate(
            nutrientKey: 'sodiumMg',
            valuePer100g: evaluation.product.nutritionPer100g.sodiumMg,
            servingSizeG: k.servingSizeG,
          )
        : null;

    // Level/headline follow only what is actually scored for kidney users
    // (sodium and phosphate additives) -- protein stays informational.
    final phosphateLevel = !k.ingredientDataKnown
        ? AdvisoryLevel.moderate
        : (k.hasPhosphateAdditives
              ? AdvisoryLevel.caution
              : AdvisoryLevel.suitable);
    final overallLevel = _severityRank(phosphateLevel) >
            _severityRank(k.sodiumLevel)
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
          : (isTagalog
                ? '$severityWord sa sodium'
                : '$severityWord in sodium');
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
      case HealthCondition.gerd:
        return 'GERD';
      case HealthCondition.kidneyDisease:
        return isTagalog ? 'sakit sa bato' : 'kidney disease';
    }
  }

  static String _factorLabel(String key, bool isTagalog) {
    switch (key) {
      case 'sodiumMg':
        return 'Sodium';
      case 'phosphateAdditives':
        return isTagalog ? 'phosphate additives' : 'phosphate additives';
      case 'gerdTotalFat':
        return 'GERD total fat';
      case 'gerdTriggers':
        return 'GERD trigger categories';
      default:
        return key;
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
  /// nutrient. Previously this method always appended a "X% more than
  /// the best option" clause whenever the numbers differed, even for the
  /// #1-overall product -- producing a self-contradictory sentence like
  /// "ranks 1 of 4 (highest-ranked) ... which is 31% more than the lowest
  /// value." [thisIsBestNutrient] lets the #1-overall branch tell the
  /// two apart and phrase the not-literally-lowest case honestly instead
  /// of contradicting the rank badge the user is looking at.
  ///
  /// [supportingReason] is an optional, already-worded clause (e.g. "it
  /// has the lowest saturated fat in this comparison (2.1g per 100g)")
  /// naming a DIFFERENT nutrient where [target] genuinely is the lowest
  /// in the set. Only meaningful when [thisIsBestNutrient] is false and
  /// [rank] is 1 -- lets that sentence point to a concrete number
  /// instead of a vague "every relevant factor" phrase. Null when no
  /// such nutrient exists, in which case the generic phrasing is used.
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

    // NOTE: renamed "best option" -> "lowest in this comparison" here.
    // "Best option" was ambiguous with "best/top-ranked *product*"
    // (a different, overall-rank concept) and was itself part of what
    // made the contradiction confusing to read.
    final comparisonClause = percentageDiffStr != null
        ? (isTagalog
              ? ', na $percentageDiffStr% mas mataas kumpara sa pinakamababa sa paghahambingang ito ($bestValueStr$nutrientUnit kada 100g)'
              : ', which is $percentageDiffStr% more than the lowest in this comparison ($bestValueStr$nutrientUnit per 100g)')
        : (isTagalog
              ? ' (ang pinakamababa sa paghahambingang ito ay may $bestValueStr$nutrientUnit kada 100g)'
              : ' (the lowest in this comparison has $bestValueStr$nutrientUnit per 100g)');

    // Derived from rank/totalProducts ONLY, never from a separately
    // computed "lowest value of this one nutrient" check -- that mismatch
    // (a product can be #1 overall without having the single lowest value
    // of one nutrient) was the root cause of the rank/explanation
    // contradiction. Every branch also states the numeric rank so the
    // sentence is checkable against the badge shown on screen.
    final isBestRank = rank == 1;
    final isWorstRank = rank == totalProducts;

    if (isBestRank) {
      if (thisIsBestNutrient) {
        // This product really is both #1 overall AND the single lowest
        // for this nutrient -- no tension, no extra clause needed.
        return isTagalog
            ? 'Ang produktong ito ay nangunguna ($rank sa $totalProducts) na may $thisValueStr$nutrientUnit na $nutrientName kada 100g$conditionClause.'
            : 'This product ranks $rank of $totalProducts (highest-ranked) with $thisValueStr$nutrientUnit $nutrientName per 100g$conditionClause.';
      }
      // #1 overall, but NOT the single lowest for this one nutrient --
      // other factors on this product's profile made up the difference.
      // Say so plainly instead of implying it lost on this nutrient. If
      // we have a concrete other nutrient it wins on, name it instead of
      // the vague "every relevant factor" fallback.
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