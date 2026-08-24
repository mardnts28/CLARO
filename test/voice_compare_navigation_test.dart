import 'package:flutter_test/flutter_test.dart';
import 'package:claro/models/product_model.dart';
import 'package:claro/services/voice_assistant_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Voice Compare Navigation Tests', () {
    test('latestScanProductNotifier stores active product for comparison', () {
      final sampleProduct = Product(
        id: 'test-can-001',
        name: 'Century Tuna Flakes in Oil',
        brand: 'Century',
        category: 'canned_goods',
        variant: '155g',
        fdaStatus: 'Registered',
        ingredients: ['Tuna', 'Water', 'Vegetable Oil', 'Salt'],
        allergens: ['Fish'],
        nutritionalFacts: NutritionalFacts(
          servingSize: '50g',
          caloriesKcal: 120,
          proteinG: 15,
          totalFatG: 5,
          saturatedFatG: 2.5,
          transFatG: 0,
          cholesterolMg: 20,
          sodiumMg: 350,
          carbsG: 0,
          fiberG: 0,
          sugarsG: 0,
        ),
      );

      VoiceAssistantService.setLatestScanProduct(sampleProduct);
      expect(VoiceAssistantService.latestScanProductNotifier.value, equals(sampleProduct));
      expect(VoiceAssistantService.latestScanProductNotifier.value?.name, equals('Century Tuna Flakes in Oil'));
    });
  });
}
