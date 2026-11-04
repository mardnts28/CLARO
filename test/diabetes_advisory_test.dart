import 'package:claro/core/constants/who_fda_thresholds.dart';
import 'package:claro/core/utils/advisory_prompt_builder.dart';
import 'package:claro/core/utils/fallback_advisory_generator.dart';
import 'package:claro/core/utils/who_calculator.dart';
import 'package:claro/data/models/health_profile.dart';
import 'package:claro/data/models/product_evaluation.dart';
import 'package:claro/models/product_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final user = UserHealthProfile(
    userId: 'diabetes-user',
    displayName: 'User',
    conditions: const [HealthCondition.diabetes],
    allergies: const [],
  );

  ProductEvaluation evaluateProduct({
    required double sugarsG,
    required double carbohydratesG,
  }) {
    final product = Product(
      id: 'diabetes-test-product',
      name: 'Test Product',
      brand: 'Test Brand',
      nutritionalFacts: NutritionalFacts(
        servingSize: '100g',
        caloriesKcal: 200,
        proteinG: 5,
        carbsG: carbohydratesG,
        totalFatG: 4,
        saturatedFatG: 1,
        transFatG: 0,
        cholesterolMg: 0,
        sodiumMg: 100,
        potassiumMg: 100,
        calciumMg: 100,
        ironMg: 1,
        fiberG: 2,
        sugarsG: sugarsG,
        addedSugarsG: 0,
      ),
    );
    return WhoCalculator.evaluateProduct(product, user);
  }

  int sentenceCount(String text) =>
      RegExp(r'[.!?](?=\s|$)').allMatches(text.trim()).length;

  test('fallback gives Diabetes-only users two sentences when suitable', () {
    final evaluation = evaluateProduct(sugarsG: 2, carbohydratesG: 10);

    expect(evaluation.overallLevel, AdvisoryLevel.suitable);
    final advisory = FallbackAdvisoryGenerator.generate(
      evaluation,
      reason: FallbackReason.notNeeded,
      userConditions: user.conditions,
    );

    expect(sentenceCount(advisory.explanation), 2);
    expect(advisory.explanation, contains('total sugars'));
    expect(advisory.explanation, contains('total carbohydrates'));
    expect(advisory.explanation, contains('4.0%'));
    expect(advisory.explanation, contains('2.7%'));
    expect(advisory.explanation, contains('diabetes'));
    expect(advisory.overallLevel, AdvisoryLevel.suitable);
  });

  test('fallback reports both Diabetes nutrients when either is flagged', () {
    final evaluation = evaluateProduct(sugarsG: 15, carbohydratesG: 80);

    expect(evaluation.overallLevel, isNot(AdvisoryLevel.suitable));
    final advisory = FallbackAdvisoryGenerator.generate(
      evaluation,
      reason: FallbackReason.apiError,
      userConditions: user.conditions,
    );

    expect(sentenceCount(advisory.explanation), 2);
    expect(advisory.explanation, contains('total sugars'));
    expect(advisory.explanation, contains('total carbohydrates'));
    expect(advisory.explanation, contains('30.0%'));
    expect(advisory.explanation, contains('21.3%'));
    expect(advisory.explanation, contains('diabetes'));
    expect(advisory.overallLevel, evaluation.overallLevel);
  });

  test('Gemini prompt requires both Diabetes nutrients and two sentences', () {
    final evaluation = evaluateProduct(sugarsG: 15, carbohydratesG: 80);
    final prompt = AdvisoryPromptBuilder.build(
      evaluation: evaluation,
      user: user,
    );

    expect(prompt, contains('Total sugars:'));
    expect(prompt, contains('Total carbohydrates:'));
    expect(prompt, contains('exactly 2 short sentences'));
    expect(prompt, contains('30.0% of the Recommended Daily Intake'));
    expect(prompt, contains('21.3% of the Recommended Daily Intake'));
    expect(
      prompt,
      contains('the supplied evaluated levels relate to diabetes'),
    );
  });
}
