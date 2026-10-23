import 'package:flutter_test/flutter_test.dart';
import 'package:claro/models/product_model.dart';
import 'package:claro/data/models/health_profile.dart';
import 'package:claro/data/repositories/product_repository.dart';
import 'package:claro/data/services/gemini_advisory_service.dart';
import 'package:claro/data/services/product_comparison_service.dart';
import 'package:claro/data/services/product_ranking_service.dart';

class MockProductRepository implements ProductRepository {
  final List<Product> mockSimilar;
  MockProductRepository({this.mockSimilar = const []});

  @override
  Future<List<Product>> getSimilarProducts(String category, {String? excludeId}) async {
    return mockSimilar.where((p) => p.id != excludeId).toList();
  }

  @override
  Future<List<Product>> getAllProducts() async => mockSimilar;

  @override
  Future<Product> getProductById(String id, {bool forceLive = false}) =>
      throw UnimplementedError();

  @override
  Future<Product> getProductByYoloLabel(String yoloLabel, {bool forceLive = false}) =>
      throw UnimplementedError();
}

void main() {
  group('ProductComparisonService Tests', () {
    final user = UserHealthProfile(
      userId: 'test_user',
      displayName: 'Test User',
      conditions: const [],
      allergies: const [],
    );

    final dummyGemini = GeminiAdvisoryService(
      proxyUrl: 'https://test.proxy',
      appSecret: 'test_secret',
    );

    Product createTestProduct({
      required String id,
      required String name,
      required String brand,
      required String category,
      bool hasNutrition = true,
      double sodiumMg = 100,
    }) {
      return Product(
        id: id,
        name: name,
        brand: brand,
        category: category,
        ingredients: const ['Water', 'Fish', 'Salt'],
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: 120,
          proteinG: 15,
          totalFatG: 5,
          saturatedFatG: 1,
          sodiumMg: sodiumMg,
          hasNutritionData: hasNutrition,
        ),
      );
    }

    test('deduplicates identical products in comparison set', () async {
      final scanned = createTestProduct(
        id: 'sardines_1',
        name: 'Sardines in Tomato Sauce',
        brand: 'Mega',
        category: 'Canned Goods',
      );

      final duplicate1 = createTestProduct(
        id: 'sardines_2',
        name: 'Sardines in Tomato Sauce',
        brand: '555',
        category: 'Canned Goods',
      );

      final duplicate2 = createTestProduct(
        id: 'sardines_3',
        name: 'Sardines in Tomato Sauce',
        brand: '555',
        category: 'Canned Goods',
      );

      final repo = MockProductRepository(mockSimilar: [duplicate1, duplicate2]);
      final rankingService = ProductRankingService(geminiService: dummyGemini);
      final comparisonService = ProductComparisonService(
        productRepository: repo,
        productRankingService: rankingService,
      );

      final results = await comparisonService.compareWithAlternatives(
        scannedProduct: scanned,
        user: user,
      );

      // Scanned (Mega) + single 555 alternative (duplicate2 eliminated)
      expect(results.length, 2);
      final brands = results.map((r) => r.evaluation.product.brand).toList();
      expect(brands, contains('Mega'));
      expect(brands, contains('555'));
    });

    test('excludes alternatives without valid nutrition facts', () async {
      final scanned = createTestProduct(
        id: 'tuna_1',
        name: 'Tuna Flakes in Oil',
        brand: 'Century',
        category: 'Canned Goods',
      );

      final validAlt = createTestProduct(
        id: 'tuna_2',
        name: 'Tuna Flakes in Water',
        brand: 'San Marino',
        category: 'Canned Goods',
        hasNutrition: true,
      );

      final invalidAlt = createTestProduct(
        id: 'tuna_3',
        name: 'Tuna Flakes with Calamansi',
        brand: 'Mega',
        category: 'Canned Goods',
        hasNutrition: false,
      );

      final repo = MockProductRepository(mockSimilar: [validAlt, invalidAlt]);
      final rankingService = ProductRankingService(geminiService: dummyGemini);
      final comparisonService = ProductComparisonService(
        productRepository: repo,
        productRankingService: rankingService,
      );

      final results = await comparisonService.compareWithAlternatives(
        scannedProduct: scanned,
        user: user,
      );

      // Only scanned + validAlt should remain
      expect(results.length, 2);
      expect(results.any((r) => r.evaluation.product.id == 'tuna_3'), isFalse);
    });

    test('ranks candidate set using nutritional risk criteria', () async {
      final scanned = createTestProduct(
        id: 'scanned_sardines',
        name: 'Sardines in Tomato Sauce',
        brand: 'Brand A',
        category: 'Canned Goods',
        sodiumMg: 350,
      );

      final healthyAlt = createTestProduct(
        id: 'healthy_sardines',
        name: 'Sardines in Tomato Sauce Low Sodium',
        brand: 'Brand B',
        category: 'Canned Goods',
        sodiumMg: 80,
      );

      final repo = MockProductRepository(mockSimilar: [healthyAlt]);
      final rankingService = ProductRankingService(geminiService: dummyGemini);
      final comparisonService = ProductComparisonService(
        productRepository: repo,
        productRankingService: rankingService,
      );

      final results = await comparisonService.compareWithAlternatives(
        scannedProduct: scanned,
        user: UserHealthProfile(
          userId: 'hypertension_user',
          displayName: 'Hypertensive User',
          conditions: const [HealthCondition.hypertension],
          allergies: const [],
        ),
      );

      expect(results.length, 2);
      // Healthier product (80mg sodium) should be ranked 1st
      expect(results.first.evaluation.product.id, 'healthy_sardines');
      expect(results.last.evaluation.product.id, 'scanned_sardines');
    });
  });
}
