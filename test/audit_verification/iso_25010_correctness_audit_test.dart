import 'package:flutter_test/flutter_test.dart';
import 'package:claro/models/product_model.dart';
import 'package:claro/data/models/health_profile.dart';
import 'package:claro/core/constants/who_fda_thresholds.dart';
import 'package:claro/core/utils/who_calculator.dart';
import 'package:claro/core/utils/fallback_advisory_generator.dart';

void main() {
  group('ISO/IEC 25010 Correctness Audit - Condition Boundary Tests', () {
    Product makeProduct({
      String id = 'test_product',
      String name = 'Test Product',
      double sodiumMg = 0,
      double sugarsG = 0,
      double saturatedFatG = 0,
      double totalFatG = 5,
      String servingSize = '100g',
      List<String> ingredients = const ['Salt'],
    }) {
      return Product(
        id: id,
        name: name,
        brand: 'Test Brand',
        category: 'Canned Goods',
        ingredients: ingredients,
        nutritionalFacts: NutritionalFacts(
          servingSize: servingSize,
          caloriesKcal: 100,
          proteinG: 5,
          totalFatG: totalFatG,
          saturatedFatG: saturatedFatG,
          sodiumMg: sodiumMg,
          potassiumMg: 100,
          sugarsG: sugarsG,
          hasNutritionData: true,
        ),
      );
    }

    UserHealthProfile makeUser({
      List<HealthCondition> conditions = const [],
      List<AllergenType> allergies = const [],
    }) {
      return UserHealthProfile(
        userId: 'audit_user',
        displayName: 'Audit User',
        conditions: conditions,
        allergies: allergies,
      );
    }

    test('1. Hypertension: boundary checks at 100mg and 400mg per 100g', () {
      final user = makeUser(conditions: [HealthCondition.hypertension]);

      // Boundary 1: <= 100mg is Suitable (per 100g ranking basis)
      final pSuitable = makeProduct(sodiumMg: 100);
      final evalSuitable = WhoCalculator.evaluateProduct(pSuitable, user);
      expect(evalSuitable.scoredFactors.first.level, AdvisoryLevel.suitable);
      expect(evalSuitable.riskScore, 1);

      // Boundary 2: 101mg - 399mg is Moderate
      final pModerate = makeProduct(sodiumMg: 250);
      final evalModerate = WhoCalculator.evaluateProduct(pModerate, user);
      expect(evalModerate.scoredFactors.first.level, AdvisoryLevel.moderate);
      expect(evalModerate.riskScore, 2);

      // Boundary 3: >= 400mg is Caution
      final pCaution = makeProduct(sodiumMg: 400);
      final evalCaution = WhoCalculator.evaluateProduct(pCaution, user);
      expect(evalCaution.scoredFactors.first.level, AdvisoryLevel.caution);
      expect(evalCaution.riskScore, 3);
    });

    test('2. Diabetes: boundary checks at 2.5g and 10.0g per 100g', () {
      final user = makeUser(conditions: [HealthCondition.diabetes]);

      // Boundary 1: <= 2.5g is Suitable
      final pSuitable = makeProduct(sugarsG: 2.5);
      final evalSuitable = WhoCalculator.evaluateProduct(pSuitable, user);
      expect(evalSuitable.scoredFactors.first.level, AdvisoryLevel.suitable);
      expect(evalSuitable.riskScore, 1);

      // Boundary 2: 2.51g - 9.99g is Moderate
      final pModerate = makeProduct(sugarsG: 5.0);
      final evalModerate = WhoCalculator.evaluateProduct(pModerate, user);
      expect(evalModerate.scoredFactors.first.level, AdvisoryLevel.moderate);
      expect(evalModerate.riskScore, 2);

      // Boundary 3: >= 10.0g is Caution
      final pCaution = makeProduct(sugarsG: 10.0);
      final evalCaution = WhoCalculator.evaluateProduct(pCaution, user);
      expect(evalCaution.scoredFactors.first.level, AdvisoryLevel.caution);
      expect(evalCaution.riskScore, 3);
    });

    test('3. Heart Condition: boundary checks at 1.11g and 4.44g per 100g', () {
      final user = makeUser(conditions: [HealthCondition.heartCondition]);

      // Boundary 1: <= 1.11g is Suitable
      final pSuitable = makeProduct(saturatedFatG: 1.11);
      final evalSuitable = WhoCalculator.evaluateProduct(pSuitable, user);
      expect(evalSuitable.scoredFactors.first.level, AdvisoryLevel.suitable);
      expect(evalSuitable.riskScore, 1);

      // Boundary 2: 1.12g - 4.43g is Moderate
      final pModerate = makeProduct(saturatedFatG: 2.5);
      final evalModerate = WhoCalculator.evaluateProduct(pModerate, user);
      expect(evalModerate.scoredFactors.first.level, AdvisoryLevel.moderate);
      expect(evalModerate.riskScore, 2);

      // Boundary 3: >= 4.44g is Caution
      final pCaution = makeProduct(saturatedFatG: 4.44);
      final evalCaution = WhoCalculator.evaluateProduct(pCaution, user);
      expect(evalCaution.scoredFactors.first.level, AdvisoryLevel.caution);
      expect(evalCaution.riskScore, 3);
    });

    test('4. Kidney Disease: scores sodium and detects phosphate additives', () {
      final user = makeUser(conditions: [HealthCondition.kidneyDisease]);

      // Suitable sodium, no phosphate
      final pClean = makeProduct(
        sodiumMg: 90,
        ingredients: ['Water', 'Beef', 'Salt'],
      );
      final evalClean = WhoCalculator.evaluateProduct(pClean, user);
      // Sodium: 1 pt, Phosphate: 1 pt -> Total: 2 pts
      expect(evalClean.riskScore, 2);

      // Caution sodium + phosphate additive present
      final pPhosphate = makeProduct(
        sodiumMg: 500,
        ingredients: ['Water', 'Chicken', 'Sodium Polyphosphate'],
      );
      final evalPhosphate = WhoCalculator.evaluateProduct(pPhosphate, user);
      // Sodium: 3 pts, Phosphate: 3 pts -> Total: 6 pts
      expect(evalPhosphate.riskScore, 6);
    });

    test('5. GERD: scores fat threshold (>=20% DV) and trigger ingredients', () {
      final user = makeUser(conditions: [HealthCondition.gerd]);

      // Low fat (< 15.6g per serving), no triggers
      final pClean = makeProduct(
        totalFatG: 2.0,
        ingredients: ['Tuna', 'Water', 'Salt'],
      );
      final evalClean = WhoCalculator.evaluateProduct(pClean, user);
      // Fat: 1 pt, Triggers: 1 pt -> Total: 2 pts
      expect(evalClean.riskScore, 2);

      // Triggers present (Tomato/chili)
      final pSpicy = makeProduct(
        totalFatG: 2.0,
        ingredients: ['Tuna', 'Tomato Paste', 'Chili Pepper'],
      );
      final evalSpicy = WhoCalculator.evaluateProduct(pSpicy, user);
      // Fat: 1 pt, Triggers: 3 pts -> Total: 4 pts
      expect(evalSpicy.riskScore, 4);
    });

    test('6. Food Allergy: Allergen override forces Caution and ranks last', () {
      final user = makeUser(
        conditions: [HealthCondition.hypertension],
        allergies: [AllergenType.fish],
      );

      // Product 1: High sodium (Caution, 3 pts), NO fish allergen
      final p1 = makeProduct(
        id: 'p1',
        name: 'Salty Beef',
        sodiumMg: 800,
        ingredients: ['Beef', 'Salt', 'Water'],
      );

      // Product 2: Very Low sodium (Suitable, 1 pt), BUT contains Tuna (fish)
      final p2 = makeProduct(
        id: 'p2',
        name: 'Tuna Flakes',
        sodiumMg: 50,
        ingredients: ['Tuna Flakes', 'Water', 'Salt'],
      );

      final eval2 = WhoCalculator.evaluateProduct(p2, user);
      expect(eval2.allergenOverride, isTrue);
      expect(eval2.overallLevel, AdvisoryLevel.caution);

      // Rank products: even though p2 has a much lower risk score (1 vs 3),
      // the allergen override forces p2 to be ranked AFTER p1!
      final ranked = WhoCalculator.rankProducts([p2, p1], user);
      expect(ranked.first.product.id, 'p1');
      expect(ranked.last.product.id, 'p2');
    });

    test('7. Gemini fallback generation for timeout and parse error', () {
      final user = makeUser(conditions: [HealthCondition.hypertension]);
      final product = makeProduct(sodiumMg: 450);
      final eval = WhoCalculator.evaluateProduct(product, user);

      // Timeout fallback
      final timeoutAdvisory = FallbackAdvisoryGenerator.generate(
        eval,
        reason: FallbackReason.timeout,
        languageCode: 'en',
      );
      expect(timeoutAdvisory.isFallback, isTrue);
      expect(timeoutAdvisory.overallLevel, AdvisoryLevel.caution);
      expect(timeoutAdvisory.explanation.isNotEmpty, isTrue);

      // Malformed / parse error fallback in Tagalog
      final parseErrorAdvisory = FallbackAdvisoryGenerator.generate(
        eval,
        reason: FallbackReason.parseError,
        languageCode: 'tl',
      );
      expect(parseErrorAdvisory.isFallback, isTrue);
      expect(parseErrorAdvisory.warningText.isNotEmpty, isTrue);
    });
  });
}
