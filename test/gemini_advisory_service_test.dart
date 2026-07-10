// test/gemini_advisory_service_test.dart
//
// Manual integration check -- makes a REAL call to Gemini and consumes
// real tokens. Run on demand only, not part of routine `flutter test` runs.
//
// Run with:
// flutter test test/gemini_advisory_service_test.dart --dart-define-from-file=.env

import 'package:flutter_test/flutter_test.dart';
import 'package:claro/core/utils/who_calculator.dart';
import 'package:claro/data/services/gemini_advisory_service.dart';
import 'package:claro/data/repositories/product_repository.dart';
import 'package:claro/data/repositories/user_repository.dart';
import 'package:claro/data/models/health_profile.dart';
import 'package:claro/data/models/product.dart';
import 'package:claro/data/models/health_advisory.dart';

void main() {
  test('generateAdvisory returns a real AI advisory for a mock product/user', () async {
    const apiKey = String.fromEnvironment('GEMINI_API_KEY');
    expect(apiKey.isNotEmpty, true);

    final productRepo = MockProductRepository();
    final userRepo = MockUserRepository();

    final product = await productRepo.getProductById('p006');
final user = await userRepo.getHealthProfile('u004');
    
    // Modify product to have 56g serving size for realistic comparison
    final modifiedProduct = Product(
      id: product.id,
      name: product.name,
      brand: product.brand,
      category: product.category,
      subCategory: product.subCategory,
      servingSizeG: 56.0, // 56g serving size
      nutritionPer100g: product.nutritionPer100g,
      containsAllergens: product.containsAllergens,
      mayContainAllergens: product.mayContainAllergens,
      fdaStatus: product.fdaStatus,
      imageUrl: product.imageUrl,
      barcode: product.barcode,
    );
    
    final evaluation = WhoCalculator.evaluateProduct(modifiedProduct, user);

    // Verify new WHO percentage-based evaluation fields are populated
    expect(evaluation.nutrientEvaluations, isNotEmpty);
    final firstNutrient = evaluation.nutrientEvaluations.first;
    expect(firstNutrient.valuePerServing, greaterThan(0));
    expect(firstNutrient.whoDailyLimitPercentage, greaterThan(0));

    final geminiService = GeminiAdvisoryService(apiKey: apiKey);
    final advisory = await geminiService.generateAdvisory(
      scanEventId: 'manual-test-1',
      evaluation: evaluation,
      user: user,
    );

    // Print only source and final advisory paragraph
    print('Source: ${advisory.source == AdvisorySource.aiGenerated ? "Gemini" : "Fallback generator"}');
    print('Advisory: ${advisory.explanation}');

    expect(advisory.warningText, isNotEmpty);
    expect(advisory.explanation, isNotEmpty);
  });

  test('generateAdvisory with heart condition user', () async {
    const apiKey = String.fromEnvironment('GEMINI_API_KEY');
    expect(apiKey.isNotEmpty, true);

    final productRepo = MockProductRepository();
    final userRepo = MockUserRepository();

    final product = await productRepo.getProductById('p001');
    final user = await userRepo.getHealthProfile('u004');
    
    // Modify product to have 56g serving size for realistic comparison
    final modifiedProduct = Product(
      id: product.id,
      name: product.name,
      brand: product.brand,
      category: product.category,
      subCategory: product.subCategory,
      servingSizeG: 56.0, // 56g serving size
      nutritionPer100g: product.nutritionPer100g,
      containsAllergens: product.containsAllergens,
      mayContainAllergens: product.mayContainAllergens,
      fdaStatus: product.fdaStatus,
      imageUrl: product.imageUrl,
      barcode: product.barcode,
    );
    
    // Create a heart condition user for testing
    final heartConditionUser = UserHealthProfile(
      userId: user.userId,
      displayName: user.displayName,
      conditions: [HealthCondition.heartCondition],
      allergies: user.allergies,
    );
    
    final evaluation = WhoCalculator.evaluateProduct(modifiedProduct, heartConditionUser);

    // Verify saturated fat evaluation is present
    final satFatEval = evaluation.nutrientEvaluations
        .where((e) => e.nutrientKey == 'saturatedFatG')
        .firstOrNull;
    expect(satFatEval, isNotNull);

    final geminiService = GeminiAdvisoryService(apiKey: apiKey);
    final advisory = await geminiService.generateAdvisory(
      scanEventId: 'manual-test-heart',
      evaluation: evaluation,
      user: heartConditionUser,
    );

    // Print only source and final advisory paragraph
    print('Source: ${advisory.source == AdvisorySource.aiGenerated ? "Gemini" : "Fallback generator"}');
    print('Advisory: ${advisory.explanation}');

    expect(advisory.warningText, isNotEmpty);
    expect(advisory.explanation, isNotEmpty);
  });
}