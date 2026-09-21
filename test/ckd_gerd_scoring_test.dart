import 'package:flutter_test/flutter_test.dart';
import 'package:claro/core/utils/who_calculator.dart';
import 'package:claro/data/models/health_profile.dart';
import 'package:claro/models/product_model.dart';

Product _product({
  List<String> ingredients = const ['Salt'],
  double sodium = 50,
  double fat = 5,
  double potassium = 0,
  double protein = 0,
  bool hasNutritionData = true,
}) {
  return Product(
    id: 'product',
    name: 'Test product',
    brand: 'Test brand',
    ingredients: ingredients,
    nutritionalFacts: NutritionalFacts(
      servingSize: '100g',
      sodiumMg: sodium,
      totalFatG: fat,
      potassiumMg: potassium,
      proteinG: protein,
      caloriesKcal: 100,
      hasNutritionData: hasNutritionData,
    ),
  );
}

UserHealthProfile _user(List<HealthCondition> conditions) => UserHealthProfile(
  userId: 'user',
  displayName: 'User',
  conditions: conditions,
  allergies: const [],
);

void main() {
  test('CKD scores sodium once', () {
    final evaluation = WhoCalculator.evaluateProduct(
      _product(),
      _user([HealthCondition.kidneyDisease]),
    );

    expect(
      evaluation.scoredFactors.where((f) => f.factorKey == 'sodiumMg'),
      hasLength(1),
    );
    expect(
      evaluation.scoredFactors
          .firstWhere((f) => f.factorKey == 'sodiumMg')
          .points,
      1,
    );
    expect(evaluation.riskScore, 2); // sodium + verified-clean phosphate
  });

  test('hypertension scores sodium once', () {
    final evaluation = WhoCalculator.evaluateProduct(
      _product(),
      _user([HealthCondition.hypertension]),
    );

    expect(evaluation.riskScore, 1);
    expect(
      evaluation.scoredFactors.where((f) => f.factorKey == 'sodiumMg'),
      hasLength(1),
    );
  });

  test('missing sodium nutrition data scores sodium as unknown', () {
    final evaluation = WhoCalculator.evaluateProduct(
      _product(hasNutritionData: false),
      _user([HealthCondition.hypertension]),
    );

    final sodium = evaluation.scoredFactors.firstWhere(
      (f) => f.factorKey == 'sodiumMg',
    );
    expect(sodium.isUnknown, isTrue);
    expect(sodium.points, 2);
  });

  test('CKD and hypertension share one sodium score', () {
    final evaluation = WhoCalculator.evaluateProduct(
      _product(),
      _user([HealthCondition.kidneyDisease, HealthCondition.hypertension]),
    );

    expect(
      evaluation.scoredFactors.where((f) => f.factorKey == 'sodiumMg'),
      hasLength(1),
    );
    expect(evaluation.riskScore, 2); // one sodium + one phosphate factor
  });

  test('phosphate additives score 1 when the ingredient list is clean', () {
    final evaluation = WhoCalculator.evaluateProduct(
      _product(ingredients: ['Salt', 'Corn Starch']),
      _user([HealthCondition.kidneyDisease]),
    );

    final phosphate = evaluation.scoredFactors.firstWhere(
      (f) => f.factorKey == 'phosphateAdditives',
    );
    expect(phosphate.points, 1);
    expect(phosphate.explanation, contains('No phosphate additive'));
  });

  test('phosphate additives score 3 when detected', () {
    final evaluation = WhoCalculator.evaluateProduct(
      _product(ingredients: ['Salt', 'Sodium Phosphate']),
      _user([HealthCondition.kidneyDisease]),
    );

    expect(
      evaluation.scoredFactors
          .firstWhere((f) => f.factorKey == 'phosphateAdditives')
          .points,
      3,
    );
  });

  test('missing ingredients make phosphate unknown and score 2', () {
    final evaluation = WhoCalculator.evaluateProduct(
      _product(ingredients: const []),
      _user([HealthCondition.kidneyDisease]),
    );

    final phosphate = evaluation.scoredFactors.firstWhere(
      (f) => f.factorKey == 'phosphateAdditives',
    );
    expect(phosphate.isUnknown, isTrue);
    expect(phosphate.points, 2);
    expect(phosphate.explanation, contains('Not enough information'));
    expect(phosphate.explanation, isNot(contains('No phosphate additive')));
  });

  test('GERD total fat uses the existing high-fat reference', () {
    final evaluation = WhoCalculator.evaluateProduct(
      _product(fat: 22),
      _user([HealthCondition.gerd]),
    );

    final fat = evaluation.scoredFactors.firstWhere(
      (f) => f.factorKey == 'gerdTotalFat',
    );
    expect(fat.points, 3);
    expect(fat.level.name, 'caution');
  });

  test('missing GERD fat data scores 2 instead of clean', () {
    final evaluation = WhoCalculator.evaluateProduct(
      _product(hasNutritionData: false, ingredients: ['Salt']),
      _user([HealthCondition.gerd]),
    );

    final fat = evaluation.scoredFactors.firstWhere(
      (f) => f.factorKey == 'gerdTotalFat',
    );
    expect(fat.isUnknown, isTrue);
    expect(fat.points, 2);
  });

  test('GERD trigger category is scored with potential-trigger wording', () {
    final evaluation = WhoCalculator.evaluateProduct(
      _product(ingredients: ['Chili Powder']),
      _user([HealthCondition.gerd]),
    );

    final triggers = evaluation.scoredFactors.firstWhere(
      (f) => f.factorKey == 'gerdTriggers',
    );
    expect(triggers.points, 3);
    expect(triggers.explanation, contains('Potential GERD trigger'));
  });

  test('missing GERD ingredients score trigger state as unknown', () {
    final evaluation = WhoCalculator.evaluateProduct(
      _product(ingredients: const []),
      _user([HealthCondition.gerd]),
    );

    final triggers = evaluation.scoredFactors.firstWhere(
      (f) => f.factorKey == 'gerdTriggers',
    );
    expect(triggers.isUnknown, isTrue);
    expect(triggers.points, 2);
    expect(triggers.explanation, isNot(contains('No approved')));
  });

  test('warning-only kidney nutrients do not add factors or points', () {
    final withWarnings = WhoCalculator.evaluateProduct(
      _product(potassium: 500, protein: 8),
      _user([HealthCondition.kidneyDisease]),
    );
    final withoutWarnings = WhoCalculator.evaluateProduct(
      _product(),
      _user([HealthCondition.kidneyDisease]),
    );

    expect(withWarnings.riskScore, withoutWarnings.riskScore);
    expect(
      withWarnings.scoredFactors.map((f) => f.factorKey),
      isNot(contains('potassium')),
    );
    expect(
      withWarnings.scoredFactors.map((f) => f.factorKey),
      isNot(contains('protein')),
    );
  });

  test('matching allergen remains a hard block separate from score', () {
    final product = _product(ingredients: ['Milk', 'Salt']);
    final user = UserHealthProfile(
      userId: 'user',
      displayName: 'User',
      conditions: const [HealthCondition.gerd],
      allergies: const [AllergenType.dairy],
    );

    final evaluation = WhoCalculator.evaluateProduct(product, user);

    expect(evaluation.allergenOverride, isTrue);
    expect(evaluation.allergenAssessment.hasDirectAllergen, isTrue);
    expect(evaluation.riskScore, greaterThan(0));
  });

  test('GERD and CKD profiles participate in ranking', () {
    final ranked = WhoCalculator.rankProducts([
      _product(fat: 5),
      _product(fat: 22),
    ], _user([HealthCondition.gerd]));

    expect(ranked.first.riskScore, lessThan(ranked.last.riskScore));
    expect(ranked.every((e) => e.scoredFactors.isNotEmpty), isTrue);
  });
}
