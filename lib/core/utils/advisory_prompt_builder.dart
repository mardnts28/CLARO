// lib/core/utils/advisory_prompt_builder.dart

import '../../data/models/health_profile.dart';
import '../../data/models/product_evaluation.dart';
import '../../data/models/ranked_product_result.dart';
import '../constants/who_fda_thresholds.dart';
import 'comparison_calculator.dart';
import 'serving_size_calculator.dart';
import '../../models/product_model.dart';

class AdvisoryPromptBuilder {
  static String build({
    required ProductEvaluation evaluation,
    required UserHealthProfile user,
    ComparisonFact? comparisonFact, // only set on compare-detail flow
    SuitabilityRankLabel? rankLabel,
    String languageCode = 'en',
  }) {
    final product = evaluation.product;
    final allergen = evaluation.allergenAssessment;

    final flagged = evaluation.nutrientEvaluations
        .where((e) => e.level != AdvisoryLevel.suitable)
        .toList();

    NutrientEvaluation? worst;
    if (flagged.isNotEmpty) {
      worst = flagged.reduce(
        (a, b) => _severityRank(b.level) > _severityRank(a.level) ? b : a,
      );
    }

    final safeServing = worst == null
        ? null
        : ServingSizeCalculator.calculate(
            nutrientKey: worst.nutrientKey,
            valuePer100g: worst.valuePer100g,
            servingSizeG: product.servingSizeG,
          );

    final decisionWord = allergen.hasDirectAllergen
        ? 'Caution'
        : _levelLabel(evaluation.overallLevel);

    final languageInstruction = languageCode == 'tl'
        ? 'Respond in simple, conversational Tagalog.'
        : 'Respond in simple, conversational English.';

    String factsBlock;
    if (allergen.hasDirectAllergen) {
      final allergenLabels = allergen.matchedContains.map(_allergenLabel).join(', ');
      // Per-allergen ingredient attribution, using ONLY what
      // WhoCalculator.assessAllergens reliably established -- direct
      // or derived. Never invent or guess an ingredient beyond this.
      final sourceLines = allergen.ingredientSources.map((m) {
        final label = _allergenLabel(m.allergen);
        switch (m.matchType) {
          case AllergenMatchType.direct:
            return '- $label: the ingredient "${m.ingredient}" directly IS/contains $label.';
          case AllergenMatchType.derived:
            return '- $label: the ingredient "${m.ingredient}" is a confirmed $label derivative (not literally named "$label").';
          case AllergenMatchType.undetermined:
            // This case should no longer occur since we removed undetermined matches
            // from allergen assessment. Kept for safety but should never be hit.
            return '- $label: flagged on the product, but NO specific ingredient in the list could be reliably confirmed as the source (e.g. only a generic "flavors"-type entry with no confirmed derivation). Do not guess or name any ingredient for this one.';
        }
      }).join('\n');
      factsBlock =
          'This product CONTAINS an allergen the user is allergic to: $allergenLabels.\n'
          'Ingredient attribution (use exactly this, do not add, guess, or invent beyond it):\n$sourceLines';
    } else if (worst == null) {
      factsBlock =
          'All evaluated nutrients are within the suitable range for this user\'s condition(s).';
    } else {
      final sugarsNote = worst.nutrientKey == 'sugarsG'
          ? '\nData limitation: This app only records TOTAL sugars -- it cannot distinguish free/added sugars from naturally occurring sugars. '
              'The WHO daily reference used here (50g/day) is the WHO reference for free sugars, but the percentage above was calculated using total sugars as a stand-in. '
              'Never call this value "free sugars" or "added sugars" -- always call it "total sugars", and phrase the amount/percentage sentence using the wording given in the instructions below.'
          : '';
      factsBlock =
          'Nutrient of concern: ${_nutrientLabel(worst.nutrientKey)}.\n'
          'Exact amount per serving: ${worst.valuePerServing.toStringAsFixed(1)}${_nutrientUnit(worst.nutrientKey)}.\n'
          'Serving size: ${product.servingSizeG.toStringAsFixed(0)}g.\n'
          'Supplied percentage of the daily reference amount from one serving: ${worst.whoDailyLimitPercentage.toStringAsFixed(1)}%.\n'
          'Classification level for this nutrient: ${_levelLabel(worst.level)}.\n'
          'Relevant health condition: ${_conditionLabel(worst.condition)}.\n'
          '${safeServing != null ? 'Application-calculated suggested amount per meal (use this EXACT text, do not calculate, convert, or restate the math yourself): "$safeServing".' : 'No suggested serving amount was supplied for this nutrient.'}'
          '$sugarsNote';
    }

    String comparisonBlock = '';
    if (comparisonFact != null && rankLabel != null) {
      final rankText = _rankLabelText(rankLabel);
      final nutrientName = _nutrientLabel(comparisonFact.nutrientKey);
      final unit = _nutrientUnit(comparisonFact.nutrientKey);

      comparisonBlock = '''

Comparison context: This product is ranked "$rankText" among the products the user compared.
Exact comparison numbers to cite: this product has ${comparisonFact.thisValue}$unit of $nutrientName per 100g.
The best value in the compared set is ${comparisonFact.bestValueInSet}$unit. The worst value in the compared set is ${comparisonFact.worstValueInSet}$unit.
${comparisonFact.thisIsBest ? 'This product has the BEST (lowest) $nutrientName among all compared products.' : ''}
${comparisonFact.thisIsWorst ? 'This product has the WORST (highest) $nutrientName among all compared products.' : ''}
Note: Product rankings are standardized using nutrient content per 100g to ensure fair comparisons regardless of serving size.

Also write a "comparisonExplanation" field: ONE short sentence explaining why this product is ranked "$rankText" compared to the others, citing the EXACT numbers above. Example style:
"This product is most suitable compared to the others because it contains the least sodium (${comparisonFact.bestValueInSet}$unit vs up to ${comparisonFact.worstValueInSet}$unit in other options)."
''';
    }

    final jsonFields = comparisonFact != null
        ? '''{
  "warningText": "short headline, max 8 words",
  "explanation": "the single sentence following the decision-first format",
  "safeServingSize": ${safeServing != null ? '"$safeServing"' : 'null'},
  "comparisonExplanation": "the single comparison sentence described above"
}'''
        : '''{
  "warningText": "short headline, max 8 words",
  "explanation": "the single sentence following the decision-first format",
  "safeServingSize": ${safeServing != null ? '"$safeServing"' : 'null'}
}''';

    final instructionsBlock = allergen.hasDirectAllergen
        ? '''Write a concise health advisory (20-50 words, short sentences) following this exact format:

1. Open by naming the allergen(s) the product is flagged for
2. For EACH allergen line in the ingredient attribution above, report it using ONLY what that line says:
   - If it names an ingredient that directly contains the allergen, say so plainly (e.g. "Detected ingredient: Tuna (fish)")
   - If it names a derived ingredient, say it's derived, not a direct match (e.g. "Detected ingredient: Whey (dairy-derived)")
3. End with a short recommendation to consume with caution or avoid this product

IMPORTANT: For the "warningText" field, do NOT include the decision word ("Caution") at the beginning. The UI already displays the decision separately. The warningText should only describe the allergen, e.g. "Fish allergen detected" not "Caution: Fish allergen detected".

Do NOT mention: calculations, algorithms, risk scores, WHO, "recommended maximum daily intake"'''
        : '''IMPORTANT:
- The application has already calculated all nutrient amounts, percentages, classification levels, and suitable/recommended serving amounts.
- You must NOT calculate, derive, estimate, reinterpret, or invent any numerical value.
- Every number in the advisory must come directly from the supplied facts above.
- Do not calculate daily limits, remaining amounts, maximum servings, nutrient amounts, percentages, or serving sizes.
- If a suggested serving amount is supplied above, communicate that exact value without modifying it.
- Never describe any amount as "safe." Use non-medical, non-diagnostic, and non-prescriptive language.

The advisory should, when the information is available:
1. State the nutrient of concern and its exact amount per serving.
2. State the serving size in grams.
3. State the supplied percentage of the daily reference amount/limit.
4. Briefly explain why the nutrient matters for the user's specific health condition, without implying this product directly causes, worsens, or triggers it.
5. Give one simple, practical, non-medical recommendation.
6. If the classification level is "Caution", "Moderate", or a similar higher-intake level AND a suggested serving amount is supplied above, include that exact amount in the recommendation.
7. If the serving is already within the supplied suitable range, you may mention the supplied recommended amount instead.
8. If no suggested serving amount is supplied above, give a general recommendation instead. Do not create one.
9. If a "Data limitation" note about sugars appears in the facts above, use this exact wording for the amount/percentage sentence instead of the general format in rules 1-3: "This serving contains [supplied amount] of total sugars, which is about [supplied percentage]% of the WHO reference for free sugars." Fill in [supplied amount] and [supplied percentage] with the exact supplied values only. Never call this value "free sugars" or "added sugars" on its own.

WORDING:
- Use simple language suitable for an ordinary grocery shopper.
- Prefer "daily reference amount" or "suggested daily amount" over "daily limit."
- Do not imply that one serving directly causes, worsens, or triggers a medical condition.
- Do not diagnose or prescribe treatment.
- Use cautious wording since the classification level is Moderate or Caution.
- Avoid unnecessary disclaimers, repetition, or introductory phrases.
- For sugars specifically: always say "total sugars", never "free sugars" or "added sugars" as a standalone label -- the app only has total sugars data, not a free/added sugars breakdown.
- If a suggested serving amount is supplied above, make clear that it is a suggested amount PER MEAL, intended for up to 3 meals in a day without exceeding 100% of the supplied WHO daily reference limit for that nutrient from this product alone.
- Do not calculate or restate the 3-meal math yourself -- just state that it applies.

OUTPUT:
Write a concise advisory of approximately 30-50 words, in this logical order:
1. Nutrient amount + serving size
2. Daily percentage, if supplied
3. Health relevance
4. Practical recommendation, including the exact supplied suggested serving amount when applicable
5. End with one sentence stating that the suggested serving amount is intended for 3 meals a day without exceeding 100% of the supplied WHO daily reference limit for that nutrient from this product alone.
Do not force every sentence if required information is unavailable, but do not omit supplied facts that are required above.''';

    final introBlock = allergen.hasDirectAllergen
        ? 'You are a friendly grocery assistant inside a Filipino grocery app called CLARO, writing a quick health tip for a scanned product.'
        : 'You are a wording assistant for the non-allergen Health Advisory card in a Filipino grocery app called CLARO. '
            'Generate a short, clear, cautious, user-friendly health advisory using ONLY the nutrient and health facts supplied below.';

    return '''
$introBlock

Decision: $decisionWord
Facts: $factsBlock
$comparisonBlock

$languageInstruction

$instructionsBlock

Use ONLY the exact numbers/ingredients provided in the facts. Do not calculate, change, invent, or guess any values or ingredient names beyond what's given.

Return ONLY valid JSON, no markdown, matching exactly this shape:
$jsonFields
''';
  }

  static String _rankLabelText(SuitabilityRankLabel label) {
    switch (label) {
      case SuitabilityRankLabel.mostSuitable:
        return 'most suitable';
      case SuitabilityRankLabel.middle:
        return 'middle';
      case SuitabilityRankLabel.leastSuitable:
        return 'least suitable';
      case SuitabilityRankLabel.forcedLast:
        return 'not recommended due to an allergen match';
    }
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
  /// or a comma-joined list like "diabetes, heart condition" for multiple
  /// conditions). Passed through so the ranking explanation ties the
  /// nutrient back to why it matters for THIS user, not just the raw
  /// per-100g numbers. May be empty when the user has no conditions on
  /// file, in which case the prompt just omits the condition framing.
  static String buildRankingExplanation({
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
    final languageInstruction = languageCode == 'tl'
        ? 'Respond in simple, conversational Tagalog.'
        : 'Respond in simple, conversational English.';

    final conditionLine = healthCondition.isNotEmpty
        ? 'User\'s health condition(s): $healthCondition.'
        : 'User has no specific health condition on file.';

    final conditionInstruction = healthCondition.isNotEmpty
        ? '7. Briefly connect the $nutrientName level to the user\'s $healthCondition (e.g. why it matters for that condition), without sounding clinical'
        : '';

    // Derived from rank/totalProducts ONLY -- this is the same numbered
    // position shown on the ranking list the user already saw, so the
    // wording below can never contradict it. Do NOT pass a separately
    // computed "is this the best nutrient value" flag into this prompt:
    // that was the original bug -- a product can win on rank overall
    // (across every condition + allergens) while not having the single
    // best value for just one nutrient, which produced explanations that
    // flatly contradicted the badge the user was looking at.
    final isBestRank = rank == 1;
    final isWorstRank = rank == totalProducts;

    return '''
You are a nutrition assistant inside a Filipino grocery app called CLARO, writing a short ranking explanation for a product.

Nutrient: $nutrientName
Unit: $nutrientUnit
This product value: $thisValue
Best value in comparison: $bestValue
Worst value in comparison: $worstValue
This product's overall rank: $rank of $totalProducts (based on the user's full health profile, not on this nutrient alone)
Is this product ranked #1 overall: $isBestRank
Is this product ranked last overall: $isWorstRank
$conditionLine

$languageInstruction

Write a concise ranking explanation (1-2 sentences, maximum 50 words) that:
1. States the product's overall rank ($rank of $totalProducts) and explains it primarily through the $nutrientName content as the most relevant contributing nutrient
2. Compares this product against others using per 100g values only
3. States whether this product contains more or less of $nutrientName than other products
4. Includes the percentage difference from the best option when applicable
5. Uses clear, natural, user-friendly language
6. Does not mention risk scores, internal calculations, variable names, or implementation details
7. Must never describe this product as "top choice", "best", "first place", etc. unless rank is 1, and never as "worst" or "least recommended" unless rank equals $totalProducts -- always stay consistent with rank $rank of $totalProducts
$conditionInstruction

Return ONLY valid JSON, no markdown, matching exactly this shape:
{
  "explanation": "the ranking explanation"
}
''';
  }
}