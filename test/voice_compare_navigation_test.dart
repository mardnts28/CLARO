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

    test('Voice product search patterns correctly match English and Tagalog commands', () {
      final patterns = [
        RegExp(r'^(?:please\s+)?(?:find|search(?:\s+for)?|look\s+for|show|open)\s+(?:me\s+)?(.+?)(?:\s+(?:in|from)\s+(?:my\s+)?history|\s+from\s+last\s+week|\s+from\s+yesterday|\s+product|\s+details)?$', caseSensitive: false),
        RegExp(r'^(?:paki-?)?(?:hanapin|hanap|pahanap|buksan|tingnan|ipakita)\s+(?:po\s+)?(?:ang|yung|ng)?\s*(.+?)(?:\s+sa\s+(?:aking\s+)?history|\s+sa\s+mga\s+na-?scan)?$', caseSensitive: false),
      ];

      bool matchesAny(String input) => patterns.any((p) => p.hasMatch(input.trim()));

      expect(matchesAny('find blue bay tuna from last week'), isTrue);
      expect(matchesAny('search for century tuna in my history'), isTrue);
      expect(matchesAny('look for lucky 7 carne norte'), isTrue);
      expect(matchesAny('open star carne norte'), isTrue);
      expect(matchesAny('hanapin ang blue bay tuna sa history'), isTrue);
      expect(matchesAny('buksan ang 555 sardines'), isTrue);
      expect(matchesAny('pahanap ng century tuna'), isTrue);
    });
  });
}
