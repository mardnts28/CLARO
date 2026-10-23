import 'package:flutter_test/flutter_test.dart';
import 'package:claro/models/product_model.dart';
import 'package:claro/data/models/health_profile.dart';
import 'package:claro/core/utils/advisory_prompt_builder.dart';
import 'package:claro/core/utils/who_calculator.dart';

void main() {
  group('AdvisoryPromptBuilder Tests', () {
    test('displayedPercentage computes correctly', () {
      expect(AdvisoryPromptBuilder.displayedPercentage(75.5), 75.5);
      expect(AdvisoryPromptBuilder.displayedPercentage(100.0), 100.0);
      expect(AdvisoryPromptBuilder.displayedPercentage(145.0), 45.0);
    });

    test('build generates allergen prompt with strict constraints', () {
      final user = UserHealthProfile(
        userId: 'u1',
        displayName: 'User',
        conditions: const [],
        allergies: const [AllergenType.fish],
      );

      final product = Product(
        id: 'tuna',
        name: 'Century Tuna Flakes',
        brand: 'Century',
        ingredients: const ['Tuna', 'Soybean Oil', 'Salt'],
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: 150,
          proteinG: 20,
          sodiumMg: 350,
          hasNutritionData: true,
        ),
      );

      final eval = WhoCalculator.evaluateProduct(product, user);
      final prompt = AdvisoryPromptBuilder.build(
        evaluation: eval,
        user: user,
        languageCode: 'en',
      );

      expect(prompt, contains('CLARO'));
      expect(prompt, contains('fish'));
      expect(prompt, contains('Tuna'));
      expect(prompt, contains('Do not diagnose'));
      expect(prompt, contains('never call the product "safe"'));
      expect(prompt, contains('"warningText"'));
      expect(prompt, contains('"explanation"'));
    });

    test('build generates kidney disease prompt in Tagalog', () {
      final user = UserHealthProfile(
        userId: 'u2',
        displayName: 'User',
        conditions: const [HealthCondition.kidneyDisease],
        allergies: const [],
      );

      final product = Product(
        id: 'corned_beef',
        name: 'Purefoods Corned Beef',
        brand: 'Purefoods',
        ingredients: const ['Beef', 'Water', 'Sodium Tripolyphosphate', 'Salt'],
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: 200,
          proteinG: 15,
          sodiumMg: 600,
          hasNutritionData: true,
        ),
      );

      final eval = WhoCalculator.evaluateProduct(product, user);
      final prompt = AdvisoryPromptBuilder.build(
        evaluation: eval,
        user: user,
        languageCode: 'tl',
      );

      expect(prompt, contains('kidney disease'));
      expect(prompt, contains('Sodium Tripolyphosphate'));
      expect(prompt, contains('Tagalog'));
      expect(prompt, contains('Decision (shown separately by the app): Caution'));
    });

    test('buildRankingExplanation contains exact per-100g facts and ranking', () {
      final prompt = AdvisoryPromptBuilder.buildRankingExplanation(
        nutrientName: 'sodium',
        nutrientUnit: 'mg',
        thisValue: 120,
        bestValue: 80,
        worstValue: 450,
        rank: 2,
        totalProducts: 3,
        thisIsBestNutrient: false,
        healthCondition: 'hypertension',
        languageCode: 'en',
      );

      expect(prompt, contains('sodium'));
      expect(prompt, contains('120'));
      expect(prompt, contains('80'));
      expect(prompt, contains('450'));
      expect(prompt, contains('ranks 2 of 3'));
      expect(prompt, contains('hypertension'));
      expect(prompt, contains('"explanation"'));
    });
  });
}
