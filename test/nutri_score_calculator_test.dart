// test/nutri_score_calculator_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:claro/core/utils/nutri_score_calculator.dart';
import 'package:claro/models/product_model.dart';

void main() {
  group('NutriScoreCalculator - Unit Normalization & Helper Tests', () {
    test('kcalToKj converts accurately', () {
      expect(NutriScoreCalculator.kcalToKj(100.0), closeTo(418.4, 0.01));
      expect(NutriScoreCalculator.kcalToKj(250.0), closeTo(1046.0, 0.01));
    });

    test('sodiumMgToSaltG converts accurately', () {
      // salt (g) = (sodium (mg) / 1000) * 2.5
      expect(NutriScoreCalculator.sodiumMgToSaltG(400.0), closeTo(1.0, 0.001));
      expect(NutriScoreCalculator.sodiumMgToSaltG(1000.0), closeTo(2.5, 0.001));
    });

    test('normalizeToPer100g scales per-serving to per-100g correctly', () {
      // 50mg sodium in 55g serving -> (50 / 55) * 100 = 90.909mg per 100g
      expect(
        NutriScoreCalculator.normalizeToPer100g(50.0, 55.0),
        closeTo(90.909, 0.01),
      );
    });
  });

  group('NutriScoreCalculator - 5 Realistic PH Product Scenarios', () {
    test('Scenario 1: Plain canned sardine in tomato sauce', () {
      // 555 Sardines in Tomato Sauce (155g)
      final sardine = Product(
        id: 'sardines_01',
        name: '555 Sardines in Tomato Sauce',
        brand: '555',
        category: 'canned_fish',
        ingredients: ['Sardines', 'Tomato Sauce', 'Water', 'Salt'],
        nutritionalFacts: NutritionalFacts(
          servingSize: '155g',
          caloriesKcal: 180.0, // ~116 kcal / 100g -> ~485 kJ / 100g (1 pt)
          saturatedFatG: 4.5,  // ~2.9g / 100g (2 pts)
          sugarsG: 2.0,        // ~1.3g / 100g (0 pts)
          sodiumMg: 775.0,     // ~500mg / 100g -> ~1.25g salt / 100g (6 pts)
          proteinG: 21.7,      // ~14.0g / 100g (5 pts)
          fiberG: 1.0,         // ~0.65g / 100g (0 pts)
          hasNutritionData: true,
        ),
      );

      final result = NutriScoreCalculator.computeFromProduct(sardine);

      expect(result.isRedMeat, isFalse);
      expect(result.category, equals(NutriScoreCategory.general));
      expect(result.negativePoints, greaterThan(0));
      // Protein points should be awarded fully (not capped)
      expect(result.proteinPoints, equals(5));
      // Sardines score well due to high protein and moderate salt
      expect(result.grade, isIn([NutriScoreGrade.B, NutriScoreGrade.C]));
    });

    test('Scenario 2: Canned corned beef (Red meat exception: protein capped at max 2)', () {
      // Argentina Corned Beef (150g)
      final cornedBeef = Product(
        id: 'corned_beef_01',
        name: 'Argentina Corned Beef',
        brand: 'Argentina',
        category: 'canned_meat',
        ingredients: ['Cooked Beef', 'Water', 'Iodized Salt', 'Sugar', 'Spices'],
        nutritionalFacts: NutritionalFacts(
          servingSize: '150g',
          caloriesKcal: 315.0, // 210 kcal/100g -> 878.6 kJ/100g (2 pts)
          saturatedFatG: 10.5, // 7.0g/100g (6 pts)
          sugarsG: 1.5,        // 1.0g/100g (0 pts)
          sodiumMg: 975.0,     // 650mg/100g -> 1.625g salt/100g (8 pts)
          proteinG: 22.5,      // 15.0g/100g -> raw protein pts would be 5
          fiberG: 0.0,
          hasNutritionData: true,
        ),
      );

      final result = NutriScoreCalculator.computeFromProduct(cornedBeef);

      expect(result.isRedMeat, isTrue);
      expect(result.category, equals(NutriScoreCategory.red_meat));
      // RED MEAT RULE VERIFICATION: Protein points MUST be capped at max 2!
      expect(result.proteinPoints, equals(2));
      // Red meat with high sat fat and salt scores D or E
      expect(result.grade, isIn([NutriScoreGrade.D, NutriScoreGrade.E]));
    });

    test('Scenario 3: Instant noodle cup (regular, high salt/sat fat)', () {
      // Lucky Me! Beef na Beef (55g)
      final instantNoodle = Product(
        id: 'noodle_01',
        name: 'Lucky Me! Beef na Beef',
        brand: 'Lucky Me!',
        category: 'instant_noodles',
        ingredients: ['Wheat Flour', 'Palm Oil', 'Salt', 'Artificial Beef Flavor'],
        nutritionalFacts: NutritionalFacts(
          servingSize: '55g',
          caloriesKcal: 242.0, // 440 kcal/100g -> 1841 kJ/100g (5 pts)
          saturatedFatG: 5.5,  // 10.0g/100g (9 pts)
          sugarsG: 1.1,        // 2.0g/100g (0 pts)
          sodiumMg: 770.0,     // 1400mg/100g -> 3.5g salt/100g (17 pts)
          proteinG: 4.95,      // 9.0g/100g (2 pts)
          fiberG: 0.825,       // 1.5g/100g (0 pts)
          hasNutritionData: true,
        ),
      );

      final result = NutriScoreCalculator.computeFromProduct(instantNoodle);

      // High N points (5+9+0+17 = 31), N >= 11 -> protein excluded from calculation!
      expect(result.negativePoints, greaterThanOrEqualTo(25));
      expect(result.grade, equals(NutriScoreGrade.E));
    });

    test('Scenario 4: Whole grain / low-sodium instant noodle variant', () {
      // Low Sodium / Whole Grain Noodle (60g)
      final healthyNoodle = Product(
        id: 'healthy_noodle_01',
        name: 'Whole Grain Low Sodium Noodle',
        brand: 'NutriNoodle',
        category: 'instant_noodles',
        ingredients: ['Whole Wheat Flour', 'Oat Fiber', 'Low Sodium Salt'],
        nutritionalFacts: NutritionalFacts(
          servingSize: '60g',
          caloriesKcal: 180.0, // 300 kcal/100g -> 1255 kJ/100g (3 pts)
          saturatedFatG: 0.9,  // 1.5g/100g (1 pt)
          sugarsG: 0.9,        // 1.5g/100g (0 pts)
          sodiumMg: 240.0,     // 400mg/100g -> 1.0g salt/100g (4 pts)
          proteinG: 5.4,       // 9.0g/100g (2 pts)
          fiberG: 3.6,         // 6.0g/100g (3 pts)
          hasNutritionData: true,
        ),
      );

      final result = NutriScoreCalculator.computeFromProduct(healthyNoodle);

      // N points = 3 + 1 + 0 + 4 = 8 (< 11), so protein IS included!
      expect(result.negativePoints, equals(8));
      expect(result.positivePoints, equals(6)); // 3 protein + 3 fibre
      expect(result.score, equals(2)); // 8 - 6 = 2
      expect(result.grade, equals(NutriScoreGrade.B));
    });

    test('Scenario 5: Canned vegetable (canned green peas)', () {
      // Mega Prime Green Peas (155g)
      final greenPeas = Product(
        id: 'peas_01',
        name: 'Mega Prime Green Peas',
        brand: 'Mega Prime',
        category: 'canned_vegetables',
        ingredients: ['Green Peas (85%)', 'Water', 'Salt', 'Sugar'],
        nutritionalFacts: NutritionalFacts(
          servingSize: '155g',
          caloriesKcal: 116.0, // 75 kcal/100g -> 313.8 kJ/100g (0 pts)
          saturatedFatG: 0.31, // 0.2g/100g (0 pts)
          sugarsG: 4.65,       // 3.0g/100g (0 pts)
          sodiumMg: 387.5,     // 250mg/100g -> 0.625g salt/100g (3 pts)
          proteinG: 7.75,      // 5.0g/100g (2 pts)
          fiberG: 7.0,         // 4.5g/100g (2 pts)
          hasNutritionData: true,
        ),
      );

      final result = NutriScoreCalculator.computeFromProduct(greenPeas);

      expect(result.fruitVegPoints, equals(5)); // >80% fruit/veg gives 5 pts
      expect(result.grade, equals(NutriScoreGrade.A));
      expect(result.score, lessThanOrEqualTo(-1));
    });
  });
}
