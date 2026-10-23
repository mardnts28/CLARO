import 'package:flutter_test/flutter_test.dart';
import 'package:claro/models/product_model.dart';
import 'package:claro/data/models/health_profile.dart';
import 'package:claro/core/constants/who_fda_thresholds.dart';
import 'package:claro/core/utils/comparison_calculator.dart';
import 'package:claro/core/utils/who_calculator.dart';

void main() {
  group('ComparisonCalculator Tests', () {
    final user = UserHealthProfile(
      userId: 'test_user',
      displayName: 'Test User',
      conditions: const [HealthCondition.hypertension],
      allergies: const [],
    );

    Product makeProduct(String id, double sodium, {List<String> ingredients = const ['Salt']}) {
      return Product(
        id: id,
        name: 'Product $id',
        brand: 'Brand $id',
        ingredients: ingredients,
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: 100,
          proteinG: 5,
          sodiumMg: sodium,
          hasNutritionData: true,
        ),
      );
    }

    test('computeFacts finds best, worst, and flags relative positioning', () {
      final p1 = makeProduct('p1', 100);
      final p2 = makeProduct('p2', 200);
      final p3 = makeProduct('p3', 300);

      final eval1 = WhoCalculator.evaluateProduct(p1, user);
      final eval2 = WhoCalculator.evaluateProduct(p2, user);
      final eval3 = WhoCalculator.evaluateProduct(p3, user);
      final set = [eval1, eval2, eval3];

      final factsForP1 = ComparisonCalculator.computeFacts(
        target: eval1,
        comparisonSet: set,
        user: user,
      );

      expect(factsForP1.length, 1);
      final fact = factsForP1.first;
      expect(fact.nutrientKey, 'sodiumMg');
      expect(fact.thisValue, 100);
      expect(fact.bestValueInSet, 100);
      expect(fact.worstValueInSet, 300);
      expect(fact.thisIsBest, isTrue);
      expect(fact.thisIsWorst, isFalse);

      final primary = ComparisonCalculator.primaryFact(factsForP1);
      expect(primary, isNotNull);
      expect(primary!.thisIsBest, isTrue);
    });

    test('computeFactorFacts identifies best and worst among scored factors', () {
      final gerdUser = UserHealthProfile(
        userId: 'gerd_user',
        displayName: 'GERD User',
        conditions: const [HealthCondition.gerd],
        allergies: const [],
      );

      final cleanProduct = makeProduct('clean', 50, ingredients: ['Water', 'Fish']);
      final triggerProduct = makeProduct('spicy', 50, ingredients: ['Water', 'Fish', 'Chili Pepper']);

      final evalClean = WhoCalculator.evaluateProduct(cleanProduct, gerdUser);
      final evalSpicy = WhoCalculator.evaluateProduct(triggerProduct, gerdUser);
      final set = [evalClean, evalSpicy];

      final factorFacts = ComparisonCalculator.computeFactorFacts(
        target: evalClean,
        comparisonSet: set,
      );

      expect(factorFacts.isNotEmpty, isTrue);
      final triggerFact = factorFacts.firstWhere((f) => f.factorKey == 'gerdTriggers');
      expect(triggerFact.thisIsBest, isTrue);
      expect(triggerFact.thisIsWorst, isFalse);
      expect(triggerFact.thisLevel, AdvisoryLevel.suitable);
    });
  });
}
