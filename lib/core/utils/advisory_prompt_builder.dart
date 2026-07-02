// lib/core/utils/advisory_prompt_builder.dart

import '../../data/models/health_profile.dart';
import '../../data/models/product_evaluation.dart';
import '../constants/who_fda_thresholds.dart';
import 'serving_size_calculator.dart';

class AdvisoryPromptBuilder {
  static String build({
    required ProductEvaluation evaluation,
    required UserHealthProfile user,
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

    return '''
You are a nutrition assistant inside a Filipino grocery app called CLARO, writing a short health advisory for a scanned product.

Product: ${product.name}
Decision: $decisionWord
Facts: $factsBlock

$languageInstruction

Write the "explanation" field as ONE short sentence that:
1. Starts with exactly this decision word and a dash: "$decisionWord - "
2. States the EXACT number from the facts above (never use vague words like "high", "small", or "a lot" in place of the number)
3. Briefly says why it matters for the user's condition

Example of the style to match (do not copy the numbers, use the real ones given above):
"Moderate - Contains 288mg of sodium per 100g, which may raise concern for your hypertension."

Return ONLY valid JSON, no markdown, matching exactly this shape:
{
  "warningText": "short headline, max 8 words, no decision-word prefix needed here",
  "explanation": "the single sentence following the exact format and example above",
  "safeServingSize": ${safeServing != null ? '"$safeServing"' : 'null'}
}
''';
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