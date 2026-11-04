import 'package:claro/core/constants/who_fda_thresholds.dart';
import 'package:claro/core/utils/advisory_prompt_builder.dart';
import 'package:claro/core/utils/fallback_advisory_generator.dart';
import 'package:claro/core/utils/who_calculator.dart';
import 'package:claro/data/models/health_profile.dart';
import 'package:claro/data/models/product_evaluation.dart';
import 'package:claro/models/product_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = UserHealthProfile(
    userId: 'gerd-user',
    displayName: 'User',
    conditions: [HealthCondition.gerd],
    allergies: [],
  );

  ProductEvaluation evaluateProduct({
    required List<String> ingredients,
    required double totalFatG,
    bool hasNutritionData = true,
  }) {
    final product = Product(
      id: 'gerd-test-product',
      name: 'Test Product',
      brand: 'Test Brand',
      ingredients: ingredients,
      nutritionalFacts: NutritionalFacts(
        servingSize: '100g',
        caloriesKcal: 200,
        proteinG: 5,
        carbsG: 20,
        totalFatG: totalFatG,
        saturatedFatG: 2,
        transFatG: 0,
        cholesterolMg: 0,
        sodiumMg: 100,
        potassiumMg: 100,
        calciumMg: 100,
        ironMg: 1,
        fiberG: 2,
        sugarsG: 3,
        addedSugarsG: 0,
        hasNutritionData: hasNutritionData,
      ),
    );
    return WhoCalculator.evaluateProduct(product, user);
  }

  test('GERD-only clean product keeps condition and no-serving behavior', () {
    final evaluation = evaluateProduct(
      ingredients: const ['Rice', 'Salt'],
      totalFatG: 5,
    );
    expect(evaluation.overallLevel, AdvisoryLevel.suitable);

    final advisory = FallbackAdvisoryGenerator.generate(
      evaluation,
      reason: FallbackReason.notNeeded,
      hasNoConditionsAndNoAllergens: true,
      userConditions: user.conditions,
    );

    expect(advisory.overallLevel, AdvisoryLevel.suitable);
    expect(advisory.warningText, 'Suitable');
    expect(advisory.explanation.toLowerCase(), contains('total fat'));
    expect(
      advisory.explanation,
      contains('No potential GERD-triggering ingredients'),
    );
    expect(advisory.explanation, isNot(contains('Enjoy this in moderation')));
    expect(advisory.safeServingSize, isNull);
  });

  test('GERD-only advisory reports flagged fat and trigger ingredients', () {
    final evaluation = evaluateProduct(
      ingredients: const ['Chili Powder', 'Salt'],
      totalFatG: 20,
    );
    expect(evaluation.overallLevel, AdvisoryLevel.caution);

    final advisory = FallbackAdvisoryGenerator.generate(
      evaluation,
      reason: FallbackReason.apiError,
      userConditions: user.conditions,
    );

    expect(advisory.overallLevel, evaluation.overallLevel);
    expect(advisory.warningText, 'Potential GERD trigger detected');
    expect(advisory.explanation, contains('20.0g per serving'));
    expect(advisory.explanation, contains('Chili Powder'));
    expect(advisory.safeServingSize, isNull);
  });

  test('Gemini prompt includes both GERD checks and no serving amount', () {
    final evaluation = evaluateProduct(
      ingredients: const ['Chili Powder', 'Salt'],
      totalFatG: 20,
    );
    final prompt = AdvisoryPromptBuilder.build(
      evaluation: evaluation,
      user: user,
    );

    expect(prompt, contains('Total fat: 20.0g per serving'));
    expect(
      prompt,
      contains('Potential GERD-triggering ingredients detected: Chili Powder'),
    );
    expect(prompt, contains('exactly 2 short sentences'));
    expect(prompt, contains('Do not mention a suggested serving amount'));
  });

  test('missing GERD data is not reported as suitable', () {
    final evaluation = evaluateProduct(
      ingredients: const [],
      totalFatG: 0,
      hasNutritionData: false,
    );
    final advisory = FallbackAdvisoryGenerator.generate(
      evaluation,
      reason: FallbackReason.notNeeded,
      userConditions: user.conditions,
    );

    expect(advisory.overallLevel, AdvisoryLevel.moderate);
    expect(advisory.warningText, 'Limited information');
    expect(advisory.explanation, contains('not enough nutrition information'));
    expect(advisory.explanation, contains('not enough ingredient information'));
    expect(advisory.safeServingSize, isNull);
  });
}
