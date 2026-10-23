import 'package:flutter_test/flutter_test.dart';
import 'package:claro/models/product_model.dart';
import 'package:claro/core/utils/nutrition_availability.dart';

void main() {
  group('NutritionAvailability Tests', () {
    Product makeProduct(String id, bool hasData) {
      return Product(
        id: id,
        name: 'Product $id',
        brand: 'Brand $id',
        ingredients: const ['Water'],
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: hasData ? 150 : 0,
          hasNutritionData: hasData,
        ),
      );
    }

    test('isAvailable returns true only when hasNutritionData is true', () {
      final valid = makeProduct('p1', true);
      final invalid = makeProduct('p2', false);

      expect(NutritionAvailability.isAvailable(valid), isTrue);
      expect(NutritionAvailability.isAvailable(invalid), isFalse);
    });

    test('allAvailable checks entire list strictly', () {
      final p1 = makeProduct('p1', true);
      final p2 = makeProduct('p2', true);
      final p3 = makeProduct('p3', false);

      expect(NutritionAvailability.allAvailable([p1, p2]), isTrue);
      expect(NutritionAvailability.allAvailable([p1, p2, p3]), isFalse);
    });

    test('unavailableAmong correctly filters missing products', () {
      final p1 = makeProduct('p1', true);
      final p2 = makeProduct('p2', false);
      final p3 = makeProduct('p3', false);

      final unavailable = NutritionAvailability.unavailableAmong([p1, p2, p3]);
      expect(unavailable.length, 2);
      expect(unavailable.map((p) => p.id), containsAll(['p2', 'p3']));
    });
  });
}
