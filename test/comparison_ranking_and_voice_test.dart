import 'package:flutter_test/flutter_test.dart';
import 'package:claro/models/product_model.dart';
import 'package:claro/data/models/health_profile.dart';
import 'package:claro/data/services/product_comparison_service.dart';
import 'package:claro/data/services/product_ranking_service.dart';
import 'package:claro/data/repositories/product_repository.dart';
import 'package:claro/data/services/gemini_advisory_service.dart';
import 'package:claro/services/voice_assistant_service.dart';

class MockProductRepo implements ProductRepository {
  final List<Product> mockProducts;
  MockProductRepo(this.mockProducts);

  @override
  Future<Product> getProductById(String id) async =>
      mockProducts.firstWhere((p) => p.id == id);

  @override
  Future<List<Product>> getAllProducts() async => mockProducts;

  @override
  Future<Product> getProductByYoloLabel(String yoloLabel) async =>
      mockProducts.first;

  @override
  Future<List<Product>> getSimilarProducts(String category, {String? excludeId}) async {
    return mockProducts.where((p) => p.category == category && p.id != excludeId).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Comparison and Ranking Tests', () {
    final scannedProduct = Product(
      id: 'sardines_01',
      name: 'Mega Sardines in Tomato Sauce',
      brand: 'Mega',
      category: 'Canned Goods',
      variant: '155g',
      fdaStatus: 'Registered',
      ingredients: ['Sardines', 'Tomato Sauce', 'Salt'],
      allergens: ['Fish'],
      nutritionalFacts: NutritionalFacts(
        servingSize: '100g',
        caloriesKcal: 120,
        proteinG: 12,
        totalFatG: 4,
        saturatedFatG: 1,
        transFatG: 0,
        cholesterolMg: 30,
        sodiumMg: 300,
        carbsG: 2,
        fiberG: 0,
        sugarsG: 1,
        hasNutritionData: true,
      ),
    );

    final alternativeWithNutrition = Product(
      id: 'sardines_02',
      name: '555 Sardines in Tomato Sauce',
      brand: '555',
      category: 'Canned Goods',
      variant: '155g',
      fdaStatus: 'Registered',
      ingredients: ['Sardines', 'Tomato Sauce', 'Salt'],
      allergens: ['Fish'],
      nutritionalFacts: NutritionalFacts(
        servingSize: '100g',
        caloriesKcal: 130,
        proteinG: 14,
        totalFatG: 5,
        saturatedFatG: 1.5,
        transFatG: 0,
        cholesterolMg: 35,
        sodiumMg: 280,
        carbsG: 2,
        fiberG: 0,
        sugarsG: 1,
        hasNutritionData: true,
      ),
    );

    final alternativeNoNutrition = Product(
      id: 'sardines_03',
      name: 'Ligo Sardines in Tomato Sauce',
      brand: 'Ligo',
      category: 'Canned Goods',
      variant: '155g',
      fdaStatus: 'Registered',
      ingredients: [],
      allergens: [],
      nutritionalFacts: NutritionalFacts(
        servingSize: '',
        caloriesKcal: 0,
        proteinG: 0,
        totalFatG: 0,
        saturatedFatG: 0,
        transFatG: 0,
        cholesterolMg: 0,
        sodiumMg: 0,
        carbsG: 0,
        fiberG: 0,
        sugarsG: 0,
      ),
    );

    test('compareWithAlternatives excludes products with missing nutrition data', () async {
      final repo = MockProductRepo([
        scannedProduct,
        alternativeWithNutrition,
        alternativeNoNutrition,
      ]);
      final rankingService = ProductRankingService(
        geminiService: GeminiAdvisoryService(apiKey: 'test_key'),
      );
      final comparisonService = ProductComparisonService(
        productRepository: repo,
        productRankingService: rankingService,
      );

      const user = UserHealthProfile(
        userId: 'user_1',
        displayName: 'Test',
        conditions: [HealthCondition.hypertension],
        allergies: [],
      );

      final results = await comparisonService.compareWithAlternatives(
        scannedProduct: scannedProduct,
        user: user,
      );

      expect(results.length, equals(2));
      final resultIds = results.map((r) => r.evaluation.product.id).toList();
      expect(resultIds, contains('sardines_01'));
      expect(resultIds, contains('sardines_02'));
      expect(resultIds, isNot(contains('sardines_03')));
    });

    test('Voice assistant is disabled by default and only enabled via its explicit state', () {
      VoiceAssistantService.isEnabledNotifier.value = false;
      expect(VoiceAssistantService.instance.isEnabled, isFalse);

      VoiceAssistantService.isEnabledNotifier.value = true;
      expect(VoiceAssistantService.instance.isEnabled, isTrue);

      VoiceAssistantService.isEnabledNotifier.value = false;
      expect(VoiceAssistantService.instance.isEnabled, isFalse);
    });
  });
}
