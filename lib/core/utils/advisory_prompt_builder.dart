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
            condition: worst.condition,
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
      factsBlock =
          'This product CONTAINS an allergen the user is allergic to: '
          '${allergen.matchedContains.map(_allergenLabel).join(', ')}.';
    } else if (worst == null) {
      factsBlock =
          'All evaluated nutrients are within the suitable range for this user\'s condition(s).';
    } else {
      factsBlock =
          'Exact nutrient value to cite: ${worst.valuePerServing.toStringAsFixed(1)}${_nutrientUnit(worst.nutrientKey)} of '
          '${_nutrientLabel(worst.nutrientKey)} per serving (${product.servingSizeG}g). '
          'One serving is about ${worst.whoDailyLimitPercentage.toStringAsFixed(1)}% of the daily limit. '
          'Relevant condition: ${_conditionLabel(worst.condition)}. '
          '${safeServing != null ? 'Pre-calculated safe serving (use this EXACT text, do not calculate your own number): "$safeServing".' : ''}';
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

    return '''
You are a friendly grocery assistant inside a Filipino grocery app called CLARO, writing a quick health tip for a scanned product.

Decision: $decisionWord
Facts: $factsBlock
$comparisonBlock

$languageInstruction

Write a concise health advisory (30-60 words, short sentences) following this exact format:

1. State the nutrient amount per serving using the exact values provided
2. Convert the percentage into natural language (e.g., "about 13% of your daily sodium limit")
3. Explain health effects simply using everyday language (e.g., "Too much sodium may raise blood pressure")
4. If a safe serving recommendation is available, end with one practical suggestion (e.g., "Enjoy up to 1 serving at a time")
5. Sound like a grocery shopping assistant giving quick advice

Do NOT mention: calculations, algorithms, risk scores, WHO, "represents", "contributes", "recommended maximum daily intake", "moderation", "excessive intake", "dietary guideline", "consume", "contributes to hypertension"

Use ONLY the exact numbers provided in the facts. Do not calculate or change any values.

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
        return 'added sugars';
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
    required bool thisIsBest,
    required bool thisIsWorst,
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

    return '''
You are a nutrition assistant inside a Filipino grocery app called CLARO, writing a short ranking explanation for a product.

Nutrient: $nutrientName
Unit: $nutrientUnit
This product value: $thisValue
Best value in comparison: $bestValue
Worst value in comparison: $worstValue
This product rank: $rank of $totalProducts
Is this the best value: $thisIsBest
Is this the worst value: $thisIsWorst
$conditionLine

$languageInstruction

Write a concise ranking explanation (1-2 sentences, maximum 50 words) that:
1. Explains why this product received its ranking based on the $nutrientName content
2. Compares this product against others using per 100g values only
3. States whether this product contains more or less of $nutrientName than other products
4. Includes the percentage difference from the best option when applicable
5. Uses clear, natural, user-friendly language
6. Does not mention risk scores, internal calculations, variable names, or implementation details
$conditionInstruction

Return ONLY valid JSON, no markdown, matching exactly this shape:
{
  "explanation": "the ranking explanation"
}
''';
  }
}