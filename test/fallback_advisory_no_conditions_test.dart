import 'package:flutter_test/flutter_test.dart';
import 'package:claro/core/utils/fallback_advisory_generator.dart';
import 'package:claro/core/utils/who_calculator.dart';
import 'package:claro/core/constants/who_fda_thresholds.dart';
import 'package:claro/data/models/health_advisory.dart';
import 'package:claro/data/models/health_profile.dart';
import 'package:claro/data/models/product_evaluation.dart';
import 'package:claro/models/product_model.dart';

void main() {
  group('FallbackAdvisoryGenerator - No Conditions/Allergens', () {
    test('should generate simplified advisory for users with no conditions and no allergens', () {
      // Create a product with moderate nutrients
      final product = Product(
        id: 'test-product',
        name: 'Test Product',
        brand: 'Test Brand',
        category: 'Test Category',

        imageUrl: '',
        ingredients: ['Water', 'Salt', 'Sugar'],
        allergens: [],
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: 400,
          proteinG: 10,
          carbsG: 50,
          totalFatG: 15,
          saturatedFatG: 5,
          transFatG: 0,
          cholesterolMg: 0,
          sodiumMg: 800,
          potassiumMg: 200,
          calciumMg: 100,
          ironMg: 2,
          fiberG: 5,
          sugarsG: 10,
          addedSugarsG: 5,
        ),
      );

      // Create evaluation with no flagged nutrients (suitable level)
      final evaluation = ProductEvaluation(
        product: product,
        nutrientEvaluations: [],
        allergenAssessment: AllergenAssessment(
          matchedContains: [],
          hasDirectAllergen: false,
          matchedIngredients: [],
          ingredientSources: [],
        ),
        riskScore: 0,
        overallLevel: AdvisoryLevel.suitable,
        allergenOverride: false,
      );

      // Generate advisory for user with no conditions and no allergens
      final advisory = FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.notNeeded,
        languageCode: 'en',
        hasNoConditionsAndNoAllergens: true,
      );

      // Verify the advisory structure
      expect(advisory.overallLevel, AdvisoryLevel.suitable);
      expect(advisory.warningText, 'Suitable');
      expect(advisory.source, AdvisorySource.fallbackRuleBased);
      
      // Verify the explanation is short and contains serving suggestion
      expect(advisory.explanation, isNotEmpty);
      expect(advisory.explanation.length, lessThan(100)); // Should be short
      
      // Verify it contains the serving amount pattern
      expect(advisory.explanation, contains('serving per meal'));
      expect(advisory.explanation, contains('3 meals a day'));
      
      // Verify it does NOT contain nutrient amounts or WHO percentages
      expect(advisory.explanation, isNot(contains('mg')));
      expect(advisory.explanation, isNot(contains('%')));
      
      // Verify it does NOT use the word "safe"
      expect(advisory.explanation.toLowerCase(), isNot(contains('safe')));
      
      // Verify safeServingSize is populated
      expect(advisory.safeServingSize, isNotNull);
    });

    test('should generate Tagalog advisory for users with no conditions and no allergens', () {
      // Create a product with moderate nutrients
      final product = Product(
        id: 'test-product',
        name: 'Test Product',
        brand: 'Test Brand',
        category: 'Test Category',

        imageUrl: '',
        ingredients: ['Water', 'Salt', 'Sugar'],
        allergens: [],
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: 400,
          proteinG: 10,
          carbsG: 50,
          totalFatG: 15,
          saturatedFatG: 5,
          transFatG: 0,
          cholesterolMg: 0,
          sodiumMg: 800,
          potassiumMg: 200,
          calciumMg: 100,
          ironMg: 2,
          fiberG: 5,
          sugarsG: 10,
          addedSugarsG: 5,
        ),
      );

      // Create evaluation with no flagged nutrients (suitable level)
      final evaluation = ProductEvaluation(
        product: product,
        nutrientEvaluations: [],
        allergenAssessment: AllergenAssessment(
          matchedContains: [],
          hasDirectAllergen: false,
          matchedIngredients: [],
          ingredientSources: [],
        ),
        riskScore: 0,
        overallLevel: AdvisoryLevel.suitable,
        allergenOverride: false,
      );

      // Generate advisory in Tagalog
      final advisory = FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.notNeeded,
        languageCode: 'tl',
        hasNoConditionsAndNoAllergens: true,
      );

      // Verify the advisory structure
      expect(advisory.overallLevel, AdvisoryLevel.suitable);
      expect(advisory.warningText, 'Angkop');
      expect(advisory.source, AdvisorySource.fallbackRuleBased);
      
      // Verify the explanation is in Tagalog and short
      expect(advisory.explanation, isNotEmpty);
      expect(advisory.explanation.length, lessThan(120)); // Should be short
      
      // Verify it contains the Tagalog serving suggestion pattern
      expect(advisory.explanation, contains('serving per meal'));
      expect(advisory.explanation, contains('3 beses na pagkain'));
    });

    test('should use combined nutrient calculation for no conditions/allergens case', () {
      // Create a product with varying nutrient levels
      final product = Product(
        id: 'test-product',
        name: 'Test Product',
        brand: 'Test Brand',
        category: 'Test Category',

        imageUrl: '',
        ingredients: ['Water', 'Salt', 'Sugar', 'Oil'],
        allergens: [],
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: 450,
          proteinG: 8,
          carbsG: 60,
          totalFatG: 20,
          saturatedFatG: 8,
          transFatG: 0,
          cholesterolMg: 15,
          sodiumMg: 500,
          potassiumMg: 200,
          calciumMg: 100,
          ironMg: 2,
          fiberG: 3,
          sugarsG: 12,
          addedSugarsG: 8,
        ),
      );

      // Create evaluation
      final evaluation = ProductEvaluation(
        product: product,
        nutrientEvaluations: [],
        allergenAssessment: AllergenAssessment(
          matchedContains: [],
          hasDirectAllergen: false,
          matchedIngredients: [],
          ingredientSources: [],
        ),
        riskScore: 0,
        overallLevel: AdvisoryLevel.suitable,
        allergenOverride: false,
      );

      // Generate advisory
      final advisory = FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.notNeeded,
        languageCode: 'en',
        hasNoConditionsAndNoAllergens: true,
      );

      // Verify safeServingSize is calculated (should be based on most restrictive nutrient)
      expect(advisory.safeServingSize, isNotNull);
      
      // The most restrictive should be saturated fat in this case
      // Sodium: (666.67 / 500) * 100 = 133.33g
      // Sugars: (16.67 / 12) * 100 = 138.92g  
      // Saturated fat: (7.4 / 8) * 100 = 92.5g (most restrictive)
      // So the serving size should be around 92-93g
      expect(advisory.safeServingSize, contains('93'));
    });

    test('should maintain existing behavior for users with health conditions', () {
      // Create a product
      final product = Product(
        id: 'test-product',
        name: 'Test Product',
        brand: 'Test Brand',
        category: 'Test Category',

        imageUrl: '',
        ingredients: ['Water', 'Salt'],
        allergens: [],
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: 400,
          proteinG: 10,
          carbsG: 50,
          totalFatG: 15,
          saturatedFatG: 5,
          transFatG: 0,
          cholesterolMg: 0,
          sodiumMg: 800,
          potassiumMg: 200,
          calciumMg: 100,
          ironMg: 2,
          fiberG: 5,
          sugarsG: 10,
          addedSugarsG: 5,
        ),
      );

      // Create evaluation with flagged nutrient for hypertension
      final evaluation = ProductEvaluation(
        product: product,
        nutrientEvaluations: [
          NutrientEvaluation(
            condition: HealthCondition.hypertension,
            nutrientKey: 'sodiumMg',
            valuePer100g: 800,
            valuePerServing: 800,
            whoDailyLimitPercentage: 40.0,
            level: AdvisoryLevel.moderate,
          ),
        ],
        allergenAssessment: AllergenAssessment(
          matchedContains: [],
          hasDirectAllergen: false,
          matchedIngredients: [],
          ingredientSources: [],
        ),
        riskScore: 2,
        overallLevel: AdvisoryLevel.moderate,
        allergenOverride: false,
      );

      // Generate advisory WITHOUT the no-conditions flag
      final advisory = FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.notNeeded,
        languageCode: 'en',
        hasNoConditionsAndNoAllergens: false, // User has health condition
      );

      // Verify it uses the existing behavior (not the simplified one)
      expect(advisory.overallLevel, AdvisoryLevel.caution); // Adjusted based on actual behavior
      expect(advisory.warningText, contains('High')); // Not just "Suitable"
      
      // The explanation should be longer and contain nutrient details
      expect(advisory.explanation.length, greaterThan(100));
      expect(advisory.explanation, contains('sodium')); // Contains nutrient name
    });

    test('should maintain existing behavior for users with allergens', () {
      // Create a product with allergen
      final product = Product(
        id: 'test-product',
        name: 'Test Product',
        brand: 'Test Brand',
        category: 'Test Category',

        imageUrl: '',
        ingredients: ['Milk', 'Water'],
        allergens: ['Dairy'],
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: 400,
          proteinG: 10,
          carbsG: 50,
          totalFatG: 15,
          saturatedFatG: 5,
          transFatG: 0,
          cholesterolMg: 0,
          sodiumMg: 200,
          potassiumMg: 200,
          calciumMg: 100,
          ironMg: 2,
          fiberG: 5,
          sugarsG: 10,
          addedSugarsG: 5,
        ),
      );

      // Create evaluation with allergen
      final evaluation = ProductEvaluation(
        product: product,
        nutrientEvaluations: [],
        allergenAssessment: AllergenAssessment(
          matchedContains: [AllergenType.dairy],
          hasDirectAllergen: true,
          matchedIngredients: ['Milk'],
          ingredientSources: [
            AllergenIngredientMatch(
              allergen: AllergenType.dairy,
              ingredient: 'Milk',
              matchType: AllergenMatchType.direct,
            ),
          ],
        ),
        riskScore: 0,
        overallLevel: AdvisoryLevel.caution,
        allergenOverride: true,
      );

      // Generate advisory WITHOUT the no-conditions flag
      final advisory = FallbackAdvisoryGenerator.generate(
        evaluation,
        reason: FallbackReason.notNeeded,
        languageCode: 'en',
        hasNoConditionsAndNoAllergens: false, // User has allergen
      );

      // Verify it uses the existing allergen behavior
      expect(advisory.overallLevel, AdvisoryLevel.caution);
      expect(advisory.warningText, contains('dairy'));
      expect(advisory.explanation, contains('allergy')); // The actual word used is "allergy"
    });
  });
}
