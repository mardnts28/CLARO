// test/who_calculator_test.dart
//
// NOTE: these imports assume your pubspec.yaml `name:` field is "claro"
// (i.e. you ran `flutter create claro`). If your package name is different,
// update the import paths below to match.
//
// Run with: flutter test test/who_calculator_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:claro/core/constants/who_fda_thresholds.dart';
import 'package:claro/core/utils/who_calculator.dart';
import 'package:claro/data/models/health_profile.dart';
import 'package:claro/data/models/product.dart';

Product _buildProduct({
  required String id,
  required double sodiumMg,
  required double sugarsG,
  double saturatedFatG = 3,
  double servingSizeG = 100,
  List<AllergenType> containsAllergens = const [],
  List<AllergenType> mayContainAllergens = const [],
}) {
  return Product(
    id: id,
    name: 'Test Product $id',
    brand: 'TestBrand',
    category: ProductCategory.cannedFood,
    subCategory: 'testSubCategory',
    servingSizeG: servingSizeG,
    nutritionPer100g: NutritionInfo(
      caloriesKcal: 200,
      sodiumMg: sodiumMg,
      sugarsG: sugarsG,
      saturatedFatG: saturatedFatG,
      totalCarbohydratesG: 10,
      dietaryFiberG: 1,
      potassiumMg: 200,
      totalFatG: 10,
      proteinG: 10,
    ),
    containsAllergens: containsAllergens,
    mayContainAllergens: mayContainAllergens,
    fdaStatus: FdaApprovalStatus.verified,
  );
}

UserHealthProfile _buildUser({
  required List<HealthCondition> conditions,
  List<AllergenType> allergies = const [],
}) {
  return UserHealthProfile(
    userId: 'test-user',
    displayName: 'Test User',
    conditions: conditions,
    allergies: allergies,
  );
}

void main() {
  group('classifyByWhoPercentage - WHO daily limit percentage thresholds', () {
    test('≤10% of WHO daily limit is Suitable', () {
      expect(
        WhoCalculator.classifyByWhoPercentage(10),
        AdvisoryLevel.suitable,
      );
      expect(
        WhoCalculator.classifyByWhoPercentage(5),
        AdvisoryLevel.suitable,
      );
    });

    test('>10-20% of WHO daily limit is Moderate', () {
      expect(
        WhoCalculator.classifyByWhoPercentage(15),
        AdvisoryLevel.moderate,
      );
      expect(
        WhoCalculator.classifyByWhoPercentage(20),
        AdvisoryLevel.moderate,
      );
    });

    test('>20% of WHO daily limit is Caution', () {
      expect(
        WhoCalculator.classifyByWhoPercentage(21),
        AdvisoryLevel.caution,
      );
      expect(
        WhoCalculator.classifyByWhoPercentage(50),
        AdvisoryLevel.caution,
      );
    });
  });

  group('classifyNutrient - Table 3.14 boundaries (legacy for ranking)', () {
    test('sodium at exactly 100mg is Suitable (boundary inclusive)', () {
      final level = WhoCalculator.classifyNutrient(
        HealthCondition.hypertension,
        'sodiumMg',
        100,
      );
      expect(level, AdvisoryLevel.suitable);
    });

    test('sodium at 250mg is Moderate', () {
      final level = WhoCalculator.classifyNutrient(
        HealthCondition.hypertension,
        'sodiumMg',
        250,
      );
      expect(level, AdvisoryLevel.moderate);
    });

    test('sodium at exactly 400mg is Caution (boundary inclusive)', () {
      final level = WhoCalculator.classifyNutrient(
        HealthCondition.hypertension,
        'sodiumMg',
        400,
      );
      expect(level, AdvisoryLevel.caution);
    });

    test('sugars at 2.5g is Suitable, 9.5g is Caution (diabetes)', () {
      expect(
        WhoCalculator.classifyNutrient(HealthCondition.diabetes, 'sugarsG', 2.5),
        AdvisoryLevel.suitable,
      );
      expect(
        WhoCalculator.classifyNutrient(HealthCondition.diabetes, 'sugarsG', 9.5),
        AdvisoryLevel.caution,
      );
    });

    test('saturated fat at 2.2g is Suitable, 4.4g is Caution (heart condition)', () {
      expect(
        WhoCalculator.classifyNutrient(HealthCondition.heartCondition, 'saturatedFatG', 2.2),
        AdvisoryLevel.suitable,
      );
      expect(
        WhoCalculator.classifyNutrient(HealthCondition.heartCondition, 'saturatedFatG', 4.4),
        AdvisoryLevel.caution,
      );
    });
  });

  group('evaluateProduct - WHO percentage-based classification', () {
    test('single condition, ≤10% WHO daily limit => Suitable', () {
      // 100g serving, 200mg sodium per 100g = 200mg per serving
      // WHO limit: 2000mg/day => 200mg is 10% => Suitable
      final product = _buildProduct(id: 'p1', sodiumMg: 200, sugarsG: 1, servingSizeG: 100);
      final user = _buildUser(conditions: [HealthCondition.hypertension]);

      final result = WhoCalculator.evaluateProduct(product, user);

      expect(result.riskScore, 1);
      expect(result.overallLevel, AdvisoryLevel.suitable);
      expect(result.nutrientEvaluations.first.whoDailyLimitPercentage, 10.0);
      expect(result.nutrientEvaluations.first.valuePerServing, 200.0);

      print('WHO Percentage Classification Test:');
      print('  Product: ${product.name}');
      print('  Serving size: ${product.servingSizeG}g');
      print('  Per 100g sodium: ${result.nutrientEvaluations.first.valuePer100g}mg');
      print('  Per serving sodium: ${result.nutrientEvaluations.first.valuePerServing}mg');
      print('  WHO daily limit %: ${result.nutrientEvaluations.first.whoDailyLimitPercentage}%');
      print('  Advisory level: ${result.overallLevel}');
      print('  Risk score: ${result.riskScore}');
    });

    test('single condition, >20% WHO daily limit => Caution', () {
      // 100g serving, 500mg sodium per 100g = 500mg per serving
      // WHO limit: 2000mg/day => 500mg is 25% => Caution
      final product = _buildProduct(id: 'p2', sodiumMg: 500, sugarsG: 1, servingSizeG: 100);
      final user = _buildUser(conditions: [HealthCondition.hypertension]);

      final result = WhoCalculator.evaluateProduct(product, user);

      expect(result.riskScore, 3);
      expect(result.overallLevel, AdvisoryLevel.caution);
      expect(result.nutrientEvaluations.first.whoDailyLimitPercentage, 25.0);

      print('WHO Percentage Classification Test (Caution):');
      print('  Product: ${product.name}');
      print('  Per 100g sodium: ${result.nutrientEvaluations.first.valuePer100g}mg');
      print('  Per serving sodium: ${result.nutrientEvaluations.first.valuePerServing}mg');
      print('  WHO daily limit %: ${result.nutrientEvaluations.first.whoDailyLimitPercentage}%');
      print('  Advisory level: ${result.overallLevel}');
      print('  Risk score: ${result.riskScore}');
    });

    test('heart condition with saturated fat at 15% WHO daily limit => Moderate', () {
      // 100g serving, 3.3g saturated fat per 100g = 3.3g per serving
      // WHO limit: 22g/day => 3.3g is 15% => Moderate
      final product = _buildProduct(id: 'p3', sodiumMg: 100, sugarsG: 1, saturatedFatG: 3.3, servingSizeG: 100);
      final user = _buildUser(conditions: [HealthCondition.heartCondition]);

      final result = WhoCalculator.evaluateProduct(product, user);

      expect(result.riskScore, 2);
      expect(result.overallLevel, AdvisoryLevel.moderate);
      expect(result.nutrientEvaluations.first.whoDailyLimitPercentage, closeTo(15.0, 0.1));

      print('WHO Percentage Classification Test (Heart Condition):');
      print('  Product: ${product.name}');
      print('  Per 100g saturated fat: ${result.nutrientEvaluations.first.valuePer100g}g');
      print('  Per serving saturated fat: ${result.nutrientEvaluations.first.valuePerServing}g');
      print('  WHO daily limit %: ${result.nutrientEvaluations.first.whoDailyLimitPercentage}%');
      print('  Advisory level: ${result.overallLevel}');
      print('  Risk score: ${result.riskScore}');
    });

    test('different serving sizes calculate correct per-serving values', () {
      // 50g serving, 400mg sodium per 100g = 200mg per serving
      // WHO limit: 2000mg/day => 200mg is 10% => Suitable
      final product = _buildProduct(id: 'p4', sodiumMg: 400, sugarsG: 1, servingSizeG: 50);
      final user = _buildUser(conditions: [HealthCondition.hypertension]);

      final result = WhoCalculator.evaluateProduct(product, user);

      expect(result.nutrientEvaluations.first.valuePer100g, 400.0);
      expect(result.nutrientEvaluations.first.valuePerServing, 200.0); // 400mg/100g * 50g
      expect(result.nutrientEvaluations.first.whoDailyLimitPercentage, 10.0);

      print('WHO Percentage Classification Test (Different Serving Size):');
      print('  Product: ${product.name}');
      print('  Serving size: ${product.servingSizeG}g');
      print('  Per 100g sodium: ${result.nutrientEvaluations.first.valuePer100g}mg');
      print('  Per serving sodium: ${result.nutrientEvaluations.first.valuePerServing}mg');
      print('  WHO daily limit %: ${result.nutrientEvaluations.first.whoDailyLimitPercentage}%');
      print('  Advisory level: ${result.overallLevel}');
    });
  });

  group('evaluateProduct - legacy risk scoring (Table 3.15)', () {
    test('single condition, suitable nutrient => risk score 1', () {
      final product = _buildProduct(id: 'p1', sodiumMg: 80, sugarsG: 1);
      final user = _buildUser(conditions: [HealthCondition.hypertension]);

      final result = WhoCalculator.evaluateProduct(product, user);

      expect(result.riskScore, 1);
      expect(result.overallLevel, AdvisoryLevel.suitable);
    });

    test('dual condition (hypertension+diabetes) sums both nutrient scores', () {
      // sodium=450 -> caution (3pts), sugars=1 -> suitable (1pt) => total 4
      final product = _buildProduct(id: 'p2', sodiumMg: 450, sugarsG: 1);
      final user = _buildUser(
        conditions: [HealthCondition.hypertension, HealthCondition.diabetes],
      );

      final result = WhoCalculator.evaluateProduct(product, user);

      expect(result.riskScore, 4);
      expect(result.overallLevel, AdvisoryLevel.caution); // worst nutrient wins
    });

    test('triple condition (hypertension+diabetes+heart) sums all three nutrient scores', () {
      // sodium=450 -> caution (3pts), sugars=1 -> suitable (1pt), saturatedFat=5 -> caution (3pts) => total 7
      final product = _buildProduct(id: 'p2b', sodiumMg: 450, sugarsG: 1, saturatedFatG: 5);
      final user = _buildUser(
        conditions: [HealthCondition.hypertension, HealthCondition.diabetes, HealthCondition.heartCondition],
      );

      final result = WhoCalculator.evaluateProduct(product, user);

      expect(result.riskScore, 7);
      expect(result.overallLevel, AdvisoryLevel.caution);
    });

    test('no conditions => risk score 0, overall suitable', () {
      final product = _buildProduct(id: 'p3', sodiumMg: 900, sugarsG: 20);
      final user = _buildUser(conditions: []);

      final result = WhoCalculator.evaluateProduct(product, user);

      expect(result.riskScore, 0);
      expect(result.overallLevel, AdvisoryLevel.suitable);
      expect(result.nutrientEvaluations, isEmpty);
    });

    test('Table 3.14 3rd condition row: allergy-only user, matching allergen '
        '=> overallLevel is Caution even with zero nutrient conditions', () {
      final product = _buildProduct(
        id: 'p6',
        sodiumMg: 50, // would be Suitable on its own
        sugarsG: 0.5, // would be Suitable on its own
        containsAllergens: [AllergenType.peanuts],
      );
      final user = _buildUser(conditions: [], allergies: [AllergenType.peanuts]);

      final result = WhoCalculator.evaluateProduct(product, user);

      // riskScore stays 0 -- Table 3.15 marks allergen row as N/A for score
      expect(result.riskScore, 0);
      // but overallLevel must reflect the allergy per Table 3.14
      expect(result.overallLevel, AdvisoryLevel.caution);
    });

    test('allergy user with NO matching allergen => overallLevel stays suitable', () {
      final product = _buildProduct(
        id: 'p7',
        sodiumMg: 50,
        sugarsG: 0.5,
        containsAllergens: [AllergenType.shellfish],
      );
      final user = _buildUser(conditions: [], allergies: [AllergenType.peanuts]);

      final result = WhoCalculator.evaluateProduct(product, user);

      expect(result.overallLevel, AdvisoryLevel.suitable);
    });
  });

  group('assessAllergens', () {
    test('direct allergen match flags hasDirectAllergen', () {
      final product = _buildProduct(
        id: 'p4',
        sodiumMg: 100,
        sugarsG: 1,
        containsAllergens: [AllergenType.fish],
      );
      final user = _buildUser(conditions: [], allergies: [AllergenType.fish]);

      final assessment = WhoCalculator.assessAllergens(product, user);

      expect(assessment.hasDirectAllergen, true);
      expect(assessment.matchedContains, contains(AllergenType.fish));
    });

    test('may-contain match flags cross-contamination risk only', () {
      final product = _buildProduct(
        id: 'p5',
        sodiumMg: 100,
        sugarsG: 1,
        mayContainAllergens: [AllergenType.soy],
      );
      final user = _buildUser(conditions: [], allergies: [AllergenType.soy]);

      final assessment = WhoCalculator.assessAllergens(product, user);

      expect(assessment.hasDirectAllergen, false);
      expect(assessment.hasCrossContaminationRisk, true);
    });
  });

  group('rankProducts - Table 3.15 ranking rules', () {
    test('lower risk score ranks first (most suitable first)', () {
      final safe = _buildProduct(id: 'safe', sodiumMg: 80, sugarsG: 1);
      final risky = _buildProduct(id: 'risky', sodiumMg: 450, sugarsG: 1);
      final user = _buildUser(conditions: [HealthCondition.hypertension]);

      final ranked = WhoCalculator.rankProducts([risky, safe], user);

      expect(ranked.first.product.id, 'safe');
      expect(ranked.last.product.id, 'risky');
    });

    test('allergen match forces product to last regardless of risk score', () {
      // "allergenProduct" has the best nutrient profile but matches user's
      // allergy -- should still be ranked LAST.
      final allergenProduct = _buildProduct(
        id: 'allergen',
        sodiumMg: 50,
        sugarsG: 0.5,
        containsAllergens: [AllergenType.fish],
      );
      final worseButSafeProduct = _buildProduct(id: 'safe-ish', sodiumMg: 450, sugarsG: 10);
      final user = _buildUser(
        conditions: [HealthCondition.hypertension, HealthCondition.diabetes],
        allergies: [AllergenType.fish],
      );

      final ranked = WhoCalculator.rankProducts([allergenProduct, worseButSafeProduct], user);

      expect(ranked.last.product.id, 'allergen');
      expect(ranked.last.allergenOverride, true);
    });

    test('tie-break: equal risk score, higher raw nutrient value ranks worse', () {
      // Both classify as Moderate for sodium (same risk score of 2), but
      // productB has a higher raw sodium value -> should rank after productA.
      final productA = _buildProduct(id: 'A', sodiumMg: 150, sugarsG: 1);
      final productB = _buildProduct(id: 'B', sodiumMg: 350, sugarsG: 1);
      final user = _buildUser(conditions: [HealthCondition.hypertension]);

      final ranked = WhoCalculator.rankProducts([productB, productA], user);

      expect(ranked.first.product.id, 'A');
      expect(ranked.last.product.id, 'B');
    });
  });

  group('topRecommendations', () {
    test('returns top N from a ranked list', () {
      final products = List.generate(
        5,
        (i) => _buildProduct(id: 'p$i', sodiumMg: 50.0 + i * 100, sugarsG: 1),
      );
      final user = _buildUser(conditions: [HealthCondition.hypertension]);

      final ranked = WhoCalculator.rankProducts(products, user);
      final top3 = WhoCalculator.topRecommendations(ranked, count: 3);

      expect(top3.length, 3);
      expect(top3.first.riskScore, lessThanOrEqualTo(top3.last.riskScore));
    });
  });
}