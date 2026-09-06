import 'package:flutter_test/flutter_test.dart';
import 'package:claro/models/product_model.dart';
import 'package:claro/core/utils/serving_size_calculator.dart';

void main() {
  group('ServingSizeCalculator', () {
    test('calculateCombinedNutrients should return null when all nutrients are zero', () {
      final nutrition = NutritionInfo(
        caloriesKcal: 0,
        proteinG: 0,
        totalFatG: 0,
        saturatedFatG: 0,
        sodiumMg: 0,
        sugarsG: 0,
        totalCarbohydratesG: 0,
        dietaryFiberG: 0,
        potassiumMg: 0,
      );

      final result = ServingSizeCalculator.calculateCombinedNutrients(
        nutritionPer100g: nutrition,
        servingSizeG: 100,
      );

      expect(result, isNull);
    });

    test('calculateCombinedNutrients should return correct suggestion for high sodium product', () {
      // Product with 800mg sodium per 100g (high for sodium)
      final nutrition = NutritionInfo(
        caloriesKcal: 400,
        proteinG: 10,
        totalFatG: 15,
        saturatedFatG: 5,
        sodiumMg: 800,
        sugarsG: 5,
        totalCarbohydratesG: 50,
        dietaryFiberG: 5,
        potassiumMg: 200,
      );

      final result = ServingSizeCalculator.calculateCombinedNutrients(
        nutritionPer100g: nutrition,
        servingSizeG: 100,
      );

      // WHO sodium limit: 2000mg/day, per meal: 666.67mg
      // For 800mg/100g: (666.67 / 800) * 100 = 83.33g suggested
      // Should return "No more than 83g is the suggested amount per meal"
      expect(result, isNotNull);
      expect(result, contains('83'));
    });

    test('calculateCombinedNutrients should return correct suggestion for high sugar product', () {
      // Product with 15g sugars per 100g (high for sugars)
      final nutrition = NutritionInfo(
        caloriesKcal: 400,
        proteinG: 5,
        totalFatG: 10,
        saturatedFatG: 3,
        sodiumMg: 200,
        sugarsG: 15,
        totalCarbohydratesG: 70,
        dietaryFiberG: 2,
        potassiumMg: 200,
      );

      final result = ServingSizeCalculator.calculateCombinedNutrients(
        nutritionPer100g: nutrition,
        servingSizeG: 100,
      );

      // WHO sugars limit: 50g/day, per meal: 16.67g
      // For 15g/100g: (16.67 / 15) * 100 = 111.11g suggested
      // Should return "Up to 1 full serving (100g) is the suggested amount per meal"
      expect(result, isNotNull);
      expect(result, contains('1 full serving'));
    });

    test('calculateCombinedNutrients should return correct suggestion for high saturated fat product', () {
      // Product with 10g saturated fat per 100g (high for saturated fat)
      final nutrition = NutritionInfo(
        caloriesKcal: 500,
        proteinG: 10,
        totalFatG: 25,
        saturatedFatG: 10,
        sodiumMg: 300,
        sugarsG: 5,
        totalCarbohydratesG: 40,
        dietaryFiberG: 3,
        potassiumMg: 200,
      );

      final result = ServingSizeCalculator.calculateCombinedNutrients(
        nutritionPer100g: nutrition,
        servingSizeG: 100,
      );

      // WHO saturated fat limit: 22.2g/day, per meal: 7.4g
      // For 10g/100g: (7.4 / 10) * 100 = 74g suggested
      // Should return "No more than 74g is the suggested amount per meal"
      expect(result, isNotNull);
      expect(result, contains('74'));
    });

    test('calculateCombinedNutrients should use most restrictive nutrient', () {
      // Product with moderate sodium, high sugar, and high saturated fat
      final nutrition = NutritionInfo(
        caloriesKcal: 450,
        proteinG: 8,
        totalFatG: 20,
        saturatedFatG: 8,
        sodiumMg: 500,
        sugarsG: 12,
        totalCarbohydratesG: 60,
        dietaryFiberG: 3,
        potassiumMg: 200,
      );

      final result = ServingSizeCalculator.calculateCombinedNutrients(
        nutritionPer100g: nutrition,
        servingSizeG: 100,
      );

      // Sodium: (666.67 / 500) * 100 = 133.33g
      // Sugars: (16.67 / 12) * 100 = 138.92g
      // Saturated fat: (7.4 / 8) * 100 = 92.5g (most restrictive)
      // Should use saturated fat limit: ~93g (rounded)
      expect(result, isNotNull);
      expect(result, contains('93'));
    });

    test('calculateCombinedNutrients should respect serving size limit', () {
      // Product with very low nutrients but small serving size
      final nutrition = NutritionInfo(
        caloriesKcal: 200,
        proteinG: 5,
        totalFatG: 5,
        saturatedFatG: 1,
        sodiumMg: 100,
        sugarsG: 3,
        totalCarbohydratesG: 30,
        dietaryFiberG: 2,
        potassiumMg: 100,
      );

      final result = ServingSizeCalculator.calculateCombinedNutrients(
        nutritionPer100g: nutrition,
        servingSizeG: 50,
      );

      // All nutrients would allow more than 50g, but we cap at serving size
      expect(result, isNotNull);
      expect(result, contains('1 full serving'));
      expect(result, contains('50g'));
    });
  });
}
