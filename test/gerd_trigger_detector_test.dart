import 'package:flutter_test/flutter_test.dart';
import 'package:claro/core/utils/gerd_trigger_detector.dart';
import 'package:claro/models/product_model.dart';

void main() {
  group('GERD Trigger Detector Tests', () {
    test('Should NOT flag Vegetable Oil with Green Tea Extract as caffeine', () {
      final product = Product(
        id: '1',
        name: 'Instant Noodles',
        brand: 'Brand',
        cprNumber: 'CPR-123',
        nutritionalFacts: NutritionalFacts(
          servingSize: '55g',
          caloriesKcal: 200,
          totalFatG: 5.0,
          saturatedFatG: 2.0,
          transFatG: 0.0,
          sodiumMg: 300,
          fiberG: 1,
          sugarsG: 2,
          proteinG: 4,
        ),
        ingredients: [
          'Wheat Flour',
          'Vegetable Oil (Palm Oil with Green Tea Extract)',
          'Salt',
        ],
      );

      final result = GerdTriggerDetector.detect(product);
      final caffeineMatch = result.triggers.where((t) => t.type == GerdTriggerType.caffeine);
      expect(caffeineMatch, isEmpty, reason: 'Green tea extract in vegetable oil should not trigger caffeine warning');
    });

    test('Should flag genuine Tea as caffeine trigger', () {
      final product = Product(
        id: '2',
        name: 'Green Tea Drink',
        brand: 'TeaBrand',
        cprNumber: 'CPR-124',
        nutritionalFacts: NutritionalFacts(
          servingSize: '250ml',
          caloriesKcal: 50,
          totalFatG: 0.0,
          saturatedFatG: 0.0,
          transFatG: 0.0,
          sodiumMg: 10,
          fiberG: 0,
          sugarsG: 10,
          proteinG: 0,
        ),
        ingredients: ['Water', 'Green Tea', 'Sugar'],
      );

      final result = GerdTriggerDetector.detect(product);
      final caffeineMatch = result.triggers.where((t) => t.type == GerdTriggerType.caffeine);
      expect(caffeineMatch, isNotEmpty);
      expect(caffeineMatch.first.matchedIngredient, 'Green Tea');
    });

    test('Should NOT flag decaffeinated coffee as caffeine trigger', () {
      final product = Product(
        id: '3',
        name: 'Decaf Instant Coffee',
        brand: 'CoffeeBrand',
        cprNumber: 'CPR-125',
        nutritionalFacts: NutritionalFacts(
          servingSize: '2g',
          caloriesKcal: 5,
          totalFatG: 0.0,
          saturatedFatG: 0.0,
          transFatG: 0.0,
          sodiumMg: 0,
          fiberG: 0,
          sugarsG: 0,
          proteinG: 0,
        ),
        ingredients: ['Decaffeinated Coffee Granules'],
      );

      final result = GerdTriggerDetector.detect(product);
      final caffeineMatch = result.triggers.where((t) => t.type == GerdTriggerType.caffeine);
      expect(caffeineMatch, isEmpty);
    });

    test('Should detect spicy ingredients and avoid duplicate product name trigger', () {
      final product = Product(
        id: '4',
        name: 'Spicy Noodle Soup',
        brand: 'NoodleBrand',
        cprNumber: 'CPR-126',
        nutritionalFacts: NutritionalFacts(
          servingSize: '60g',
          caloriesKcal: 300,
          totalFatG: 10.0,
          saturatedFatG: 4.0,
          transFatG: 0.0,
          sodiumMg: 800,
          fiberG: 2,
          sugarsG: 3,
          proteinG: 6,
        ),
        ingredients: ['Wheat Flour', 'Chili Powder', 'Palm Oil'],
      );

      final result = GerdTriggerDetector.detect(product);
      final spicyMatches = result.triggers.where((t) => t.type == GerdTriggerType.spicy);
      expect(spicyMatches.length, equals(1));
      expect(spicyMatches.first.matchedIngredient, equals('Chili Powder'));
    });

    test('Should detect high fat content per serving', () {
      final product = Product(
        id: '5',
        name: 'Deep Fried Snack',
        brand: 'SnackBrand',
        cprNumber: 'CPR-127',
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: 550,
          totalFatG: 22.0,
          saturatedFatG: 10.0,
          transFatG: 0.0,
          sodiumMg: 600,
          fiberG: 3,
          sugarsG: 5,
          proteinG: 7,
        ),
        ingredients: ['Corn Meal', 'Palm Oil', 'Salt'],
      );

      final result = GerdTriggerDetector.detect(product);
      final highFatMatches = result.triggers.where((t) => t.type == GerdTriggerType.highFat);
      expect(highFatMatches, isNotEmpty);
      expect(highFatMatches.first.matchedValue, equals(22.0));
    });
  });
}
