import 'package:flutter_test/flutter_test.dart';
import 'package:claro/models/product_model.dart';
import 'package:claro/core/utils/product_characteristics.dart';

void main() {
  group('ProductCharacteristics Tests', () {
    Product makeProduct(String name, {String brand = 'Mega'}) {
      return Product(
        id: 'test_p',
        name: name,
        brand: brand,
        ingredients: const ['Fish'],
        nutritionalFacts: NutritionalFacts(),
      );
    }

    test('extracts typeTags correctly from name', () {
      final p1 = makeProduct('Mega Sardines in Tomato Sauce');
      final p2 = makeProduct('Century Tuna Flakes in Oil');
      final p3 = makeProduct('Purefoods Corned Beef');

      expect(ProductCharacteristics.typeTags(p1), contains('sardines'));
      expect(ProductCharacteristics.typeTags(p2), contains('tuna'));
      expect(ProductCharacteristics.typeTags(p3), contains('corned beef'));
    });

    test('extracts flavorTags and detects spice level', () {
      final mild = makeProduct('Mega Sardines in Tomato Sauce');
      final spicy = makeProduct('Mega Sardines Hot and Spicy');

      expect(ProductCharacteristics.flavorTags(mild), contains('tomato sauce'));
      expect(ProductCharacteristics.isSpicy(mild), isFalse);

      expect(ProductCharacteristics.flavorTags(spicy), contains('hot and spicy'));
      expect(ProductCharacteristics.isSpicy(spicy), isTrue);
    });

    test('genericNameTokens filters stopwords and brand words', () {
      final p = makeProduct(
        'Del Monte Premium Mixed Fruit Cocktail in Heavy Syrup',
        brand: 'Del Monte',
      );

      final tokens = ProductCharacteristics.genericNameTokens(p);
      expect(tokens, containsAll(['mixed', 'fruit', 'cocktail', 'syrup']));
      expect(tokens, isNot(contains('del')));
      expect(tokens, isNot(contains('monte')));
      expect(tokens, isNot(contains('premium')));
      expect(tokens, isNot(contains('in')));
    });

    test('displayLabel title-cases keywords', () {
      expect(ProductCharacteristics.displayLabel('corned beef'), 'Corned Beef');
      expect(ProductCharacteristics.displayLabel('tomato sauce'), 'Tomato Sauce');
      expect(ProductCharacteristics.displayLabel('tuna'), 'Tuna');
    });
  });
}
