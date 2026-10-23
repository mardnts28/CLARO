import 'package:flutter_test/flutter_test.dart';
import 'package:claro/models/product_model.dart';
import 'package:claro/data/models/health_profile.dart';
import 'package:claro/data/models/ranked_product_result.dart';
import 'package:claro/data/services/gemini_advisory_service.dart';
import 'package:claro/data/services/product_ranking_service.dart';

void main() {
  group('ProductRankingService Tests', () {
    final dummyGemini = GeminiAdvisoryService(
      proxyUrl: 'https://dummy.proxy',
      appSecret: 'secret',
    );
    final service = ProductRankingService(geminiService: dummyGemini);

    final user = UserHealthProfile(
      userId: 'test_user',
      displayName: 'Test User',
      conditions: const [HealthCondition.hypertension],
      allergies: const [AllergenType.fish],
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

    test('rankProducts with empty list returns empty list', () {
      final results = service.rankProducts(products: [], user: user);
      expect(results, isEmpty);
    });

    test('rankProducts enforces maximum cap of 5 by default', () {
      final sixProducts = List.generate(
        6,
        (i) => makeProduct('p$i', 100.0 * (i + 1)),
      );

      expect(
        () => service.rankProducts(products: sixProducts, user: user, enforceMaxCap: true),
        throwsArgumentError,
      );

      // Does not throw when enforceMaxCap is false
      final results = service.rankProducts(
        products: sixProducts,
        user: user,
        enforceMaxCap: false,
      );
      expect(results.length, 6);
    });

    test('correctly computes rank labels and handles allergen forcedLast', () {
      final healthy = makeProduct('healthy', 50); // Suitable sodium, no fish
      final moderate = makeProduct('moderate', 200); // Moderate sodium, no fish
      final salty = makeProduct('salty', 500); // Caution sodium, no fish
      final fishAllergen = makeProduct('tuna_fish', 30, ingredients: ['Tuna Flakes', 'Salt']); // Fish allergy

      final results = service.rankProducts(
        products: [salty, fishAllergen, healthy, moderate],
        user: user,
      );

      expect(results.length, 4);

      // Rank 1: healthy (lowest sodium) -> mostSuitable
      expect(results[0].evaluation.product.id, 'healthy');
      expect(results[0].rank, 1);
      expect(results[0].suitabilityRankLabel, SuitabilityRankLabel.mostSuitable);
      expect(results[0].isTopRecommendation, isTrue);

      // Rank 2: moderate -> middle
      expect(results[1].evaluation.product.id, 'moderate');
      expect(results[1].rank, 2);
      expect(results[1].suitabilityRankLabel, SuitabilityRankLabel.middle);
      expect(results[1].isTopRecommendation, isTrue);

      // Rank 3: salty -> leastSuitable (among non-allergen products)
      expect(results[2].evaluation.product.id, 'salty');
      expect(results[2].rank, 3);
      expect(results[2].suitabilityRankLabel, SuitabilityRankLabel.leastSuitable);
      expect(results[2].isTopRecommendation, isTrue);

      // Rank 4: fishAllergen -> forcedLast
      expect(results[3].evaluation.product.id, 'tuna_fish');
      expect(results[3].rank, 4);
      expect(results[3].suitabilityRankLabel, SuitabilityRankLabel.forcedLast);
      expect(results[3].isTopRecommendation, isFalse);
    });
  });
}
