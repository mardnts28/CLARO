// lib/core/utils/advisory_prompt_builder.dart

import '../../data/models/health_profile.dart';
import '../../data/models/product_evaluation.dart';
import '../../data/models/ranked_product_result.dart';
import '../constants/who_fda_thresholds.dart';
import 'comparison_calculator.dart';
import 'serving_size_calculator.dart';

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
          'Exact nutrient value to cite: ${worst.valuePer100g}${_nutrientUnit(worst.nutrientKey)} of '
          '${_nutrientLabel(worst.nutrientKey)} per 100g. '
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
You are a nutrition assistant inside a Filipino grocery app called CLARO, writing a short health advisory for a scanned product.

Product: ${product.name}
Decision: $decisionWord
Facts: $factsBlock
$comparisonBlock

$languageInstruction

Write the "explanation" field as ONE short sentence that:
1. Starts with exactly this decision word and a dash: "$decisionWord - "
2. States the EXACT number from the facts above (never use vague words like "high" or "small")
3. Briefly says why it matters for the user's condition

Example: "Moderate - Contains 288mg of sodium per 100g, which may raise concern for your hypertension."

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
    }
  }

  static String _nutrientLabel(String key) {
    switch (key) {
      case 'sodiumMg':
        return 'sodium';
      case 'sugarsG':
        return 'added sugars';
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
}