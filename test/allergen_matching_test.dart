import 'package:flutter_test/flutter_test.dart';
import 'package:claro/models/product_model.dart';
import 'package:claro/data/models/health_profile.dart';
import 'package:claro/core/utils/who_calculator.dart';
import 'package:claro/core/constants/who_fda_thresholds.dart';

void main() {
  group('Allergen Matching Tests', () {
    test('Should detect milk allergen in ingredients (skim milk powder)', () {
      // Create product with milk-derived ingredient
      final product = Product(
        id: 'test1',
        name: 'Chocolate Drink',
        brand: 'Test Brand',
        ingredients: ['Sugar', 'Cocoa', 'Skim Milk Powder', 'Salt'],
        allergens: [], // No explicit allergens declared
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: 100,
          sodiumMg: 50,
          sugarsG: 10,
          saturatedFatG: 2,
        ),
      );

      // Create user with milk allergy
      final user = UserHealthProfile(
        userId: 'user1',
        displayName: 'Test User',
        conditions: [],
        allergies: [AllergenType.dairy],
      );

      // Evaluate product
      final evaluation = WhoCalculator.evaluateProduct(product, user);

      // Verify allergen is detected
      expect(evaluation.allergenAssessment.hasDirectAllergen, true);
      expect(evaluation.allergenAssessment.matchedContains, contains(AllergenType.dairy));
      expect(evaluation.allergenAssessment.matchedIngredients, contains('Skim Milk Powder'));
      
      // Verify overall level is forced to Caution
      expect(evaluation.overallLevel, AdvisoryLevel.caution);
      
      // Verify allergen override is set
      expect(evaluation.allergenOverride, true);
    });

    test('Should detect multiple allergen matches in ingredients', () {
      final product = Product(
        id: 'test2',
        name: 'Cookie',
        brand: 'Test Brand',
        ingredients: ['Wheat Flour', 'Milk Powder', 'Egg Whites', 'Sugar'],
        allergens: [],
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: 100,
          sodiumMg: 50,
          sugarsG: 10,
          saturatedFatG: 2,
        ),
      );

      final user = UserHealthProfile(
        userId: 'user2',
        displayName: 'Test User',
        conditions: [],
        allergies: [AllergenType.dairy, AllergenType.eggs, AllergenType.wheatGluten],
      );

      final evaluation = WhoCalculator.evaluateProduct(product, user);

      expect(evaluation.allergenAssessment.hasDirectAllergen, true);
      expect(evaluation.allergenAssessment.matchedContains.length, 3);
      expect(evaluation.allergenAssessment.matchedIngredients, contains('Milk Powder'));
      expect(evaluation.allergenAssessment.matchedIngredients, contains('Egg Whites'));
      expect(evaluation.allergenAssessment.matchedIngredients, contains('Wheat Flour'));
      expect(evaluation.overallLevel, AdvisoryLevel.caution);
    });

    test('Should be case-insensitive (MILK vs milk)', () {
      final product = Product(
        id: 'test3',
        name: 'Product',
        brand: 'Test Brand',
        ingredients: ['SUGAR', 'COCOA', 'SKIM MILK POWDER', 'SALT'],
        allergens: [],
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: 100,
          sodiumMg: 50,
          sugarsG: 10,
          saturatedFatG: 2,
        ),
      );

      final user = UserHealthProfile(
        userId: 'user3',
        displayName: 'Test User',
        conditions: [],
        allergies: [AllergenType.dairy],
      );

      final evaluation = WhoCalculator.evaluateProduct(product, user);

      expect(evaluation.allergenAssessment.hasDirectAllergen, true);
      expect(evaluation.allergenAssessment.matchedIngredients, contains('SKIM MILK POWDER'));
    });

    test('Should prioritize allergen over nutrient suitability', () {
      // Product with perfect nutrients but allergen
      final product = Product(
        id: 'test4',
        name: 'Healthy Product',
        brand: 'Test Brand',
        ingredients: ['Skim Milk Powder'],
        allergens: [],
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: 50,
          sodiumMg: 10, // Very low sodium
          sugarsG: 2, // Very low sugar
          saturatedFatG: 0.5, // Very low saturated fat
        ),
      );

      final user = UserHealthProfile(
        userId: 'user4',
        displayName: 'Test User',
        conditions: [HealthCondition.hypertension],
        allergies: [AllergenType.dairy],
      );

      final evaluation = WhoCalculator.evaluateProduct(product, user);

      // Even though nutrients are suitable, allergen should force Caution
      expect(evaluation.overallLevel, AdvisoryLevel.caution);
      expect(evaluation.allergenOverride, true);
    });

    test('Should not detect allergen when no match in ingredients', () {
      final product = Product(
        id: 'test5',
        name: 'Safe Product',
        brand: 'Test Brand',
        ingredients: ['Sugar', 'Cocoa', 'Salt'],
        allergens: [],
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: 100,
          sodiumMg: 50,
          sugarsG: 10,
          saturatedFatG: 2,
        ),
      );

      final user = UserHealthProfile(
        userId: 'user5',
        displayName: 'Test User',
        conditions: [],
        allergies: [AllergenType.dairy],
      );

      final evaluation = WhoCalculator.evaluateProduct(product, user);

      expect(evaluation.allergenAssessment.hasDirectAllergen, false);
      expect(evaluation.allergenAssessment.matchedContains, isEmpty);
      expect(evaluation.allergenAssessment.matchedIngredients, isEmpty);
    });

    test('Should match Filipino allergen terms (gatas for milk)', () {
      final product = Product(
        id: 'test6',
        name: 'Local Product',
        brand: 'Test Brand',
        ingredients: ['Gatas', 'Sugar'],
        allergens: [],
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: 100,
          sodiumMg: 50,
          sugarsG: 10,
          saturatedFatG: 2,
        ),
      );

      final user = UserHealthProfile(
        userId: 'user6',
        displayName: 'Test User',
        conditions: [],
        allergies: [AllergenType.dairy],
      );

      final evaluation = WhoCalculator.evaluateProduct(product, user);

      expect(evaluation.allergenAssessment.hasDirectAllergen, true);
      expect(evaluation.allergenAssessment.matchedIngredients, contains('Gatas'));
    });

    test('Should work with both explicit allergens and ingredient matching', () {
      final product = Product(
        id: 'test7',
        name: 'Product',
        brand: 'Test Brand',
        ingredients: ['Wheat Flour', 'Cheese'],
        allergens: ['milk'], // Explicit allergen declaration
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: 100,
          sodiumMg: 50,
          sugarsG: 10,
          saturatedFatG: 2,
        ),
      );

      final user = UserHealthProfile(
        userId: 'user7',
        displayName: 'Test User',
        conditions: [],
        allergies: [AllergenType.dairy, AllergenType.wheatGluten],
      );

      final evaluation = WhoCalculator.evaluateProduct(product, user);

      // Should detect both from explicit allergens and ingredients
      expect(evaluation.allergenAssessment.hasDirectAllergen, true);
      expect(evaluation.allergenAssessment.matchedContains.length, 2);
      expect(evaluation.allergenAssessment.matchedIngredients, contains('Cheese'));
      expect(evaluation.allergenAssessment.matchedIngredients, contains('Wheat Flour'));
    });

    test('Should use nutrient-based logic when no allergen detected', () {
      final product = Product(
        id: 'test8',
        name: 'Safe Product',
        brand: 'Test Brand',
        ingredients: ['Sugar', 'Cocoa', 'Salt'],
        allergens: [],
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: 100,
          sodiumMg: 50,
          sugarsG: 10,
          saturatedFatG: 2,
        ),
      );

      final user = UserHealthProfile(
        userId: 'user8',
        displayName: 'Test User',
        conditions: [HealthCondition.hypertension],
        allergies: [], // No allergies
      );

      final evaluation = WhoCalculator.evaluateProduct(product, user);

      // Should NOT trigger allergen logic
      expect(evaluation.allergenAssessment.hasDirectAllergen, false);
      expect(evaluation.allergenOverride, false);

      // Should use nutrient-based evaluation
      expect(evaluation.nutrientEvaluations, isNotEmpty);
      expect(evaluation.overallLevel, isA<AdvisoryLevel>());
    });
  });
}
