// lib/core/utils/advisory_prompt_builder.dart
//
// Builds the prompts sent to Gemini.
//
// Gemini's ONLY job here is to put values the app has already worked out into
// short, friendly words. Every number, percentage, ingredient name, ranking
// and serving amount is decided in Dart and handed over as a finished fact.
// The prompts never ask the model to calculate, judge, or give medical advice.

import '../../data/models/health_profile.dart';
import '../../data/models/product_evaluation.dart';
import '../../data/models/ranked_product_result.dart';
import '../constants/who_fda_thresholds.dart';
import 'comparison_calculator.dart';
import 'kidney_advisory_facts.dart';
import 'serving_size_calculator.dart';
import '../../models/product_model.dart';

/// Wording for a percentage of the Recommended Daily Intake.
/// Up to 100%: "X% of the Recommended Daily Intake".
/// Over 100%: "(X-100)% above the Recommended Daily Intake".
/// Done here so the model never has to subtract anything.
String _formatPercentageWording(
  double percentage,
  bool isTagalog, {
  bool forFreeSugars = false,
}) {
  final shown = AdvisoryPromptBuilder.displayedPercentage(
    percentage,
  ).toStringAsFixed(1);
  final above = percentage > 100;
  final reference = forFreeSugars
      ? (isTagalog
            ? 'Recommended Daily Intake para sa free sugars'
            : 'Recommended Daily Intake for free sugars')
      : 'Recommended Daily Intake';
  if (isTagalog) {
    return above ? '$shown% sa taas ng $reference' : '$shown% ng $reference';
  }
  return above ? '$shown% above the $reference' : '$shown% of the $reference';
}

/// Which kind of advisory is being written. Decided once, so the facts and
/// the task instructions can never disagree about which case applies.
enum _AdvisoryMode {
  allergen,
  kidney,
  noConditions,
  allSuitable,
  factorsOnly,
  nutrientOfConcern,
}

class AdvisoryPromptBuilder {
  /// The percentage number that is actually shown to the user: the value
  /// itself up to 100, otherwise how far above 100 it is. Anything that
  /// checks the model's text for a percentage (e.g. the kidney validator in
  /// GeminiAdvisoryService) must look for THIS number, not the raw one.
  static double displayedPercentage(double percentage) =>
      percentage <= 100 ? percentage : percentage - 100;

  /// The suggested serving amount for this product and user, worked out by
  /// the app. Public so GeminiAdvisoryService can attach it to the advisory
  /// directly (the badge on the product screen) instead of trusting a copy
  /// of it that came back from the model. Null when there is nothing to
  /// suggest.
  static String? suggestedServing({
    required ProductEvaluation evaluation,
    required UserHealthProfile user,
  }) {
    final product = evaluation.product;
    // No health conditions and no allergens: the amount is based on sodium,
    // total sugars and saturated fat combined.
    final hasNoConditionsAndNoAllergens =
        user.conditions.isEmpty &&
        !evaluation.allergenAssessment.hasDirectAllergen;
    if (hasNoConditionsAndNoAllergens) {
      return ServingSizeCalculator.calculateCombinedNutrients(
        nutritionPer100g: product.nutritionPer100g,
        servingSizeG: product.servingSizeG,
      );
    }
    final worst = _worstFlagged(evaluation);
    if (worst == null) return null;
    return ServingSizeCalculator.calculate(
      nutrientKey: worst.nutrientKey,
      valuePer100g: worst.valuePer100g,
      servingSizeG: product.servingSizeG,
    );
  }

  /// The most severe flagged nutrient, or null when nothing is flagged.
  static NutrientEvaluation? _worstFlagged(ProductEvaluation evaluation) {
    final flagged = evaluation.nutrientEvaluations
        .where((e) => e.level != AdvisoryLevel.suitable)
        .toList();
    if (flagged.isEmpty) return null;
    return flagged.reduce(
      (a, b) => _severityRank(b.level) > _severityRank(a.level) ? b : a,
    );
  }

  /// Rules shared by every prompt. Stated once, here, instead of being
  /// repeated inside each branch.
  static const String _styleRules = '''
Rules:
- Use only the values and names given in the facts. Never calculate, estimate, round, convert, or add any number or ingredient.
- Stay factual and gentle. Do not make medical claims: never say the product causes, worsens, triggers, or treats anything, and never call an amount "safe", "unsafe", or "dangerous".
- Do not tell the user what they must do or avoid. Soft wording such as "worth keeping in mind" is fine.
- Use plain everyday words a grocery shopper would use. Do not mention scores, calculations, thresholds, algorithms, or how the app works.
- Do not add disclaimers; the app shows those separately.''';

  /// Rules for allergen and GERD-ingredient warnings. Cautious warning
  /// wording is acceptable there, so the "no causes/triggers/avoid" lines of
  /// [_styleRules] are replaced. Diagnosing or promising an outcome is still
  /// not allowed.
  static const String _warningStyleRules = '''
Rules:
- Use only the values and names given in the facts. Never calculate, estimate, round, convert, or add any number or ingredient.
- Warning or cautious wording is fine for this allergen or GERD ingredient detection (for example "may cause an allergic reaction", "potential GERD trigger", "consume with caution or avoid"). Do not diagnose, do not promise or guarantee any outcome, and never call the product "safe".
- Use plain everyday words a grocery shopper would use. Do not mention scores, calculations, thresholds, algorithms, or how the app works.
- Do not add disclaimers; the app shows those separately.''';

  static String build({
    required ProductEvaluation evaluation,
    required UserHealthProfile user,
    ComparisonFact? comparisonFact, // only set on compare-detail flow
    SuitabilityRankLabel? rankLabel,
    String languageCode = 'en',
  }) {
    final isTagalog = languageCode == 'tl';
    final product = evaluation.product;
    final allergen = evaluation.allergenAssessment;
    final scoredFactors = evaluation.scoredFactors;

    // Kidney Disease has its own facts (sodium and protein percentages,
    // detected phosphate additives). Null for every other user.
    final kidneyFacts = KidneyAdvisoryFacts.build(evaluation);

    final worst = _worstFlagged(evaluation);

    // No health conditions and no allergens: the suggested amount is
    // worked out from sodium, total sugars and saturated fat combined.
    final hasNoConditionsAndNoAllergens =
        user.conditions.isEmpty && !allergen.hasDirectAllergen;

    // Nutrients that already exceed 100% of the Recommended Daily Intake at
    // the product's full labeled serving. Only used to give the model a
    // reason to mention for a smaller-than-full suggested amount.
    final exceededDailyLimitKeys = hasNoConditionsAndNoAllergens
        ? _exceededDailyLimitKeys(product)
        : const <String>[];

    final safeServing = suggestedServing(evaluation: evaluation, user: user);

    final decisionWord = allergen.hasDirectAllergen
        ? 'Caution'
        : _levelLabel(evaluation.overallLevel);

    final languageInstruction = isTagalog
        ? 'Respond in simple, conversational Tagalog. Keep numbers, units, and ingredient names exactly as supplied.'
        : 'Respond in simple, conversational English.';

    final _AdvisoryMode mode;
    if (allergen.hasDirectAllergen) {
      mode = _AdvisoryMode.allergen;
    } else if (kidneyFacts != null) {
      mode = _AdvisoryMode.kidney;
    } else if (hasNoConditionsAndNoAllergens) {
      mode = _AdvisoryMode.noConditions;
    } else if (worst == null && scoredFactors.isEmpty) {
      mode = _AdvisoryMode.allSuitable;
    } else if (worst == null) {
      mode = _AdvisoryMode.factorsOnly;
    } else {
      mode = _AdvisoryMode.nutrientOfConcern;
    }

    // `factsBlock` = what the model is given. `taskBlock` = what to write
    // with it. Each mode fills in both.
    final String factsBlock;
    final String taskBlock;

    if (mode == _AdvisoryMode.allergen) {
      final allergenLabels = allergen.matchedContains
          .map(_allergenLabel)
          .join(', ');
      // Per-allergen ingredient attribution, using ONLY what
      // WhoCalculator.assessAllergens reliably established.
      final sourceLines = allergen.ingredientSources
          .map((m) {
            final label = _allergenLabel(m.allergen);
            switch (m.matchType) {
              case AllergenMatchType.direct:
                return '- $label: the ingredient "${m.ingredient}" is or contains $label.';
              case AllergenMatchType.derived:
                return '- $label: the ingredient "${m.ingredient}" is derived from $label (not literally named "$label").';
              case AllergenMatchType.undetermined:
                return '- $label: flagged on the product, but no specific ingredient could be confirmed. Do not name or guess one.';
            }
          })
          .join('\n');
      factsBlock =
          'This product contains an allergen the user is allergic to: $allergenLabels.\n'
          'Ingredients (use exactly these, add nothing):\n$sourceLines';
      taskBlock = '''
Write a short note of about 20-50 words, in this order:
1. Say which allergen(s) the product is flagged for.
2. For each allergen, mention the ingredient given in the facts and whether it is the allergen itself or derived from it (for example "Detected ingredient: Tuna (fish)" or "Detected ingredient: Whey (dairy-derived)"). Do not mention ingredients that are not listed.
3. Finish with one short line recommending that the user consume with caution or avoid this product.
Do not mention daily intake amounts.

warningText: at most 8 words, describing the allergen only (for example "Fish allergen detected"). Do not include the word "Caution"; the app shows that separately.''';
    } else if (mode == _AdvisoryMode.kidney) {
      final facts = kidneyFacts!;
      final sodiumPhrase = _formatPercentageWording(
        facts.sodiumPercentage,
        isTagalog,
      );
      final proteinPhrase = _formatPercentageWording(
        facts.proteinPercentage,
        isTagalog,
      );
      final phosphateLine = facts.hasPhosphateAdditives
          ? 'Phosphate additive ingredients found (name them exactly as written): "${facts.phosphateIngredients}".'
          : 'Phosphate additives: none to report. Do not mention them.';
      final drivers = <String>[
        if (facts.sodiumFlagged) 'sodium',
        if (facts.hasPhosphateAdditives) 'phosphate additives',
      ];
      factsBlock = [
        'Health condition on file: kidney disease.',
        'Sodium: ${facts.sodiumMg.toStringAsFixed(1)}mg, which is $sodiumPhrase.',
        'Protein: ${facts.proteinG.toStringAsFixed(1)}g, which is $proteinPhrase.',
        phosphateLine,
        'Main points for the headline: ${drivers.isEmpty ? 'none' : drivers.join(', ')}.',
      ].join('\n');
      taskBlock = '''
warningText: at most 8 words, describing only the "main points for the headline" (for example "High in sodium and phosphate additives"). Do not mention protein and do not repeat the decision word. If the main points are "none", use a short neutral phrase such as "Kidney health reminder".

explanation: exactly 2 short sentences, under 45 words in total.
1. Say what the product contains: the sodium amount and the protein amount, each followed in parentheses by its wording from the facts. Copy each percentage wording exactly as written in the facts.
   English example: "This product contains 727.3mg of sodium (36.4% of the Recommended Daily Intake) and 5.0g of protein (6.7% of the Recommended Daily Intake)."
2. If phosphate additive ingredients are listed, name them exactly and say they may be worth noting for kidney health. Otherwise say these amounts are worth keeping in mind with kidney disease.
Do not mention the serving size or a suggested amount; the app shows that separately.''';
    } else if (mode == _AdvisoryMode.noConditions) {
      final exceededLabels = exceededDailyLimitKeys
          .map(_nutrientLabel)
          .join(', ');
      factsBlock = [
        'The user has no health conditions or allergens on file.',
        safeServing != null
            ? 'Suggested amount (already written by the app): "$safeServing".'
            : 'No suggested serving amount was supplied.',
        if (exceededDailyLimitKeys.isNotEmpty)
          'At the full labeled serving (${product.servingSizeG.toStringAsFixed(0)}g), these already go above the daily reference amount: $exceededLabels. That is why a smaller amount is suggested.',
      ].join('\n');
      const suitableHeadline =
          'warningText: at most 8 words. It must clearly say "Suitable"; a short phrase after it is optional.';
      if (safeServing == null) {
        taskBlock =
            '''
$suitableHeadline

explanation: exactly 1 short sentence saying that no specific serving amount was suggested for this product. Do not add numbers.''';
      } else if (exceededDailyLimitKeys.isEmpty) {
        taskBlock =
            '''
$suitableHeadline

explanation: exactly 1 short sentence. Restate the suggested amount from the facts in friendly words, keeping the amount and the grams exactly as written, and say it is for up to ${ServingSizeCalculator.mealsPerDay} meals a day.
Do not repeat nutrient amounts or percentages.''';
      } else {
        taskBlock =
            '''
$suitableHeadline

explanation: exactly 2 short sentences.
1. Restate the suggested amount from the facts in friendly words, keeping the amount and the grams exactly as written, and say it is for up to ${ServingSizeCalculator.mealsPerDay} meals a day.
2. Give a short, plain, non-alarming reason for the smaller amount, based on the note in the facts (for example "A full serving has more sodium than the daily reference amount."). Do not use numbers or percentages.''';
      }
    } else if (mode == _AdvisoryMode.allSuitable) {
      factsBlock =
          'All checked nutrients are within the suitable range for this user\'s health profile.';
      taskBlock = '''
warningText: at most 8 words. It must clearly say "Suitable".
explanation: exactly 1 short sentence saying the checked nutrients look suitable for the user's profile. Do not add numbers.''';
    } else if (mode == _AdvisoryMode.factorsOnly) {
      // Only the plain-language result of each factor is shared. Point
      // values are internal and are deliberately not sent to the model.
      final factorLines = scoredFactors
          .map((factor) {
            final status = factor.isUnknown
                ? 'not enough information'
                : 'checked';
            return '- ${_factorLabel(factor.factorKey)} ($status): ${factor.explanation}';
          })
          .join('\n');
      factsBlock = 'Results already worked out by the app:\n$factorLines';
      taskBlock = '''
warningText: at most 8 words, describing the main point. Do not repeat the decision word.
explanation: 1-2 short sentences that put the results above into friendly words. Only mention factors listed in the facts.
- If a factor says "not enough information", say there is not enough information about it. Never treat missing information as a good sign.
- For GERD triggers, say "potential GERD trigger detected" and that reactions differ from person to person.''';
    } else {
      final nutrient = worst!;
      final isSugars = nutrient.nutrientKey == 'sugarsG';
      final percentPhrase = _formatPercentageWording(
        nutrient.whoDailyLimitPercentage,
        isTagalog,
        forFreeSugars: isSugars,
      );
      factsBlock = [
        'Nutrient to mention: ${_nutrientLabel(nutrient.nutrientKey)}.',
        'Amount: ${nutrient.valuePerServing.toStringAsFixed(1)}${_nutrientUnit(nutrient.nutrientKey)}, which is $percentPhrase.',
        'Related health condition: ${_conditionLabel(nutrient.condition)}.',
        if (isSugars)
          'Note: the app only records total sugars, and compares them with the reference for free sugars. Always say "total sugars"; never say "added sugars" or "free sugars" on their own.',
      ].join('\n');
      taskBlock = '''
warningText: at most 8 words, naming the nutrient in a neutral way (for example "Sodium worth watching"). Do not repeat the decision word.

explanation: exactly 2 short sentences, under 40 words in total.
1. Start with "This product contains", give the amount, and put the percentage wording from the facts in parentheses. Copy the percentage wording exactly as written.
   English example: "This product contains 727.3mg of sodium (36.4% of the Recommended Daily Intake)."${isSugars ? '\n   For total sugars, use: "This serving contains [amount] of total sugars, which is [percentage wording from the facts]."' : ''}
2. In one sentence, say why this amount is worth keeping in mind for the related health condition. Do not mention the serving size or a suggested amount; the app shows that separately.''';
    }

    String comparisonBlock = '';
    if (comparisonFact != null && rankLabel != null) {
      final rankText = _rankLabelText(rankLabel);
      final nutrientName = _nutrientLabel(comparisonFact.nutrientKey);
      final unit = _nutrientUnit(comparisonFact.nutrientKey);

      comparisonBlock =
          '''

Comparison context: this product is ranked "$rankText" among the products the user compared.
Values per 100g of $nutrientName: this product ${comparisonFact.thisValue}$unit; lowest in the set ${comparisonFact.bestValueInSet}$unit; highest in the set ${comparisonFact.worstValueInSet}$unit.
${comparisonFact.thisIsBest ? 'This product has the lowest $nutrientName in the set.' : ''}
${comparisonFact.thisIsWorst ? 'This product has the highest $nutrientName in the set.' : ''}

Also write "comparisonExplanation": one short sentence saying why this product is ranked "$rankText", using the exact per 100g values above.''';
    }

    // The suggested amount is attached by the app (see suggestedServing), so
    // the model is not asked to return it.
    final jsonFields = comparisonFact != null
        ? '''{
  "warningText": "short headline",
  "explanation": "the explanation described above",
  "comparisonExplanation": "the single comparison sentence described above"
}'''
        : '''{
  "warningText": "short headline",
  "explanation": "the explanation described above"
}''';

    // Allergen and GERD-ingredient warnings may use cautious warning wording.
    final usesWarningWording =
        mode == _AdvisoryMode.allergen ||
        (mode == _AdvisoryMode.factorsOnly &&
            scoredFactors.any((f) => f.factorKey.startsWith('gerd')));
    final styleRules = usesWarningWording ? _warningStyleRules : _styleRules;

    return '''
You are a friendly wording assistant inside a Filipino grocery app called CLARO. The app has already done all the checking and calculating. Your only job is to put the facts below into short, friendly, plain words.

Decision (shown separately by the app): $decisionWord

Facts:
$factsBlock
$comparisonBlock

$languageInstruction

$taskBlock

$styleRules

Return only JSON in exactly this shape:
$jsonFields
''';
  }

  static String _rankLabelText(SuitabilityRankLabel label) {
    switch (label) {
      case SuitabilityRankLabel.mostSuitable:
        return 'highest-ranked';
      case SuitabilityRankLabel.middle:
        return 'middle';
      case SuitabilityRankLabel.leastSuitable:
        return 'lowest-ranked';
      case SuitabilityRankLabel.forcedLast:
        return 'not recommended due to an allergen match';
    }
  }

  // Sodium/total sugars/saturated fat whose value at the product's own
  // full labeled serving size exceeds 100% of the Recommended Daily Intake
  // amount (WhoDailyLimits). Uses raw per-100g values directly rather
  // than `evaluation.nutrientEvaluations` because that list is only
  // populated per-condition -- this path is for users with none.
  static List<String> _exceededDailyLimitKeys(Product product) {
    final checks = <String, double>{
      'sodiumMg': product.nutritionPer100g.sodiumMg,
      'sugarsG': product.nutritionPer100g.sugarsG,
      'saturatedFatG': product.nutritionPer100g.saturatedFatG,
    };
    final exceeded = <String>[];
    checks.forEach((key, valuePer100g) {
      if (valuePer100g <= 0) return;
      final valuePerServing = (valuePer100g / 100) * product.servingSizeG;
      final dailyLimit = key == 'sodiumMg'
          ? WhoDailyLimits.sodiumMgPerDay
          : (key == 'sugarsG'
                ? WhoDailyLimits.sugarsGPerDay
                : WhoDailyLimits.saturatedFatGPerDay);
      final whoPercentage = (valuePerServing / dailyLimit) * 100;
      if (whoPercentage > 100) exceeded.add(key);
    });
    return exceeded;
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

  static String _conditionLabel(HealthCondition c) {
    switch (c) {
      case HealthCondition.hypertension:
        return 'hypertension';
      case HealthCondition.diabetes:
        return 'diabetes';
      case HealthCondition.heartCondition:
        return 'heart condition';
      case HealthCondition.gerd:
        return 'GERD';
      case HealthCondition.kidneyDisease:
        return 'kidney disease';
    }
  }

  static String _factorLabel(String key) {
    switch (key) {
      case 'sodiumMg':
        return 'Sodium';
      case 'phosphateAdditives':
        return 'Phosphate additives';
      case 'gerdTotalFat':
        return 'GERD total fat';
      case 'gerdTriggers':
        return 'GERD trigger categories';
      default:
        return key;
    }
  }

  static String _nutrientLabel(String key) {
    switch (key) {
      case 'sodiumMg':
        return 'sodium';
      case 'sugarsG':
        return 'total sugars';
      case 'saturatedFatG':
        return 'saturated fat';
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

  static String _levelLabel(AdvisoryLevel level) {
    switch (level) {
      case AdvisoryLevel.suitable:
        return 'Suitable';
      case AdvisoryLevel.moderate:
        return 'Moderate';
      case AdvisoryLevel.caution:
        return 'Caution';
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
        return 'dairy';
      case AllergenType.eggs:
        return 'eggs';
      case AllergenType.wheatGluten:
        return 'wheat/gluten';
      case AllergenType.msg:
        return 'MSG';
    }
  }

  /// [healthCondition] is the user's condition name (e.g. "hypertension",
  /// or a comma-joined list like "diabetes, heart condition"). May be empty
  /// when the user has no conditions on file.
  ///
  /// The ranking position and how the nutrient compares are decided here in
  /// Dart and passed as one finished fact, so the model only has to word it
  /// and can never contradict the rank badge the user already sees.
  static String buildRankingExplanation({
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
    final languageInstruction = languageCode == 'tl'
        ? 'Respond in simple, conversational Tagalog. Keep numbers, units, and ingredient names exactly as supplied.'
        : 'Respond in simple, conversational English.';

    final conditionLine = healthCondition.isNotEmpty
        ? 'User\'s health condition(s): $healthCondition.'
        : 'No specific health condition on file.';

    final nutrientRelation = thisIsBestNutrient
        ? 'the lowest $nutrientName'
        : 'more $nutrientName than the lowest';

    final String rankFact;
    if (rank == 1 && thisIsBestNutrient) {
      rankFact =
          'It ranks 1 of $totalProducts and has the lowest $nutrientName in this comparison.';
    } else if (rank == 1) {
      final reason = supportingReason != null
          ? 'Reason it still ranks first: $supportingReason.'
          : 'No single reason is available, so say only that its overall nutrient profile ranks best. Do not add numbers.';
      rankFact =
          'It ranks 1 of $totalProducts overall, although it does not have the lowest $nutrientName. $reason Do not describe it as losing, lacking, or worse.';
    } else if (rank == totalProducts) {
      rankFact =
          'It ranks last ($rank of $totalProducts) and has $nutrientRelation in this comparison.';
    } else {
      rankFact =
          'It ranks $rank of $totalProducts and has $nutrientRelation in this comparison.';
    }

    return '''
You are a friendly wording assistant inside a Filipino grocery app called CLARO. The app has already done all the ranking and calculating. Your only job is to put the facts below into one or two short, plain sentences.

Facts (values are per 100g):
- Nutrient: $nutrientName, in $nutrientUnit.
- This product: $thisValue.
- Lowest in the comparison: $bestValue.
- Highest in the comparison: $worstValue.
- $rankFact
- $conditionLine

$languageInstruction

Write 1-2 sentences, at most 50 words:
1. Say where the product ranks and how its $nutrientName compares, using only the per 100g values above.
2. If a health condition is listed, add a few words on why $nutrientName is worth keeping in mind for it.
Only call the product the top choice if it ranks 1, and only call it last or least suitable if it ranks $totalProducts.

$_styleRules

Return only JSON in exactly this shape:
{
  "explanation": "the ranking explanation"
}
''';
  }
}