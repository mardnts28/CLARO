// test/comparison_and_favorites_test.dart
//
// Run with: flutter test test/comparison_and_favorites_test.dart
// No API key needed -- both pieces here are pure Dart / in-memory, no Gemini.

import 'package:flutter_test/flutter_test.dart';
import 'package:claro/core/constants/who_fda_thresholds.dart';
import 'package:claro/core/utils/comparison_matrix_builder.dart';
import 'package:claro/core/utils/who_calculator.dart';
import 'package:claro/data/models/comparison_matrix.dart';
import 'package:claro/data/models/health_profile.dart';
import 'package:claro/data/repositories/favorites_repository.dart';
import 'package:claro/data/repositories/product_repository.dart';

void main() {
  group('ComparisonMatrixBuilder', () {
    test('fewer than 2 products returns an empty matrix', () {
      final user = UserHealthProfile(
        userId: 'u1',
        displayName: 'Test',
        conditions: [HealthCondition.hypertension],
        allergies: [],
      );

      final matrix = ComparisonMatrixBuilder.build(comparisonSet: [], user: user);

      expect(matrix.isEmpty, true);
      expect(matrix.nutrientRows, isEmpty);
    });

    test('always includes all 6 nutrient rows, regardless of user conditions', () async {
      final repo = MockProductRepository();
      // Deliberately NO conditions saved -- confirms the fixed 6-nutrient
      // set no longer depends on user.conditions like the old ranking-tied
      // version did.
      final user = UserHealthProfile(
        userId: 'u1',
        displayName: 'Test',
        conditions: [],
        allergies: [],
      );

      final productA = await repo.getProductById('p001');
      final productB = await repo.getProductById('p012');

      final evalA = WhoCalculator.evaluateProduct(productA, user);
      final evalB = WhoCalculator.evaluateProduct(productB, user);

      final matrix = ComparisonMatrixBuilder.build(
        comparisonSet: [evalA, evalB],
        user: user,
      );

      expect(matrix.nutrientRows.length, 6);
      expect(
        matrix.nutrientRows.map((r) => r.nutrient).toSet(),
        ComparisonNutrient.values.toSet(),
      );
    });

    test('correctly flags favorable/unfavorable sodium between two corned beef products', () async {
      final repo = MockProductRepository();
      final user = UserHealthProfile(
        userId: 'u1',
        displayName: 'Test',
        conditions: [HealthCondition.hypertension],
        allergies: [],
      );

      // p001 Argentina: sodiumMg 780. p012 Low Sodium: sodiumMg 320.
      final productA = await repo.getProductById('p001');
      final productB = await repo.getProductById('p012');

      final evalA = WhoCalculator.evaluateProduct(productA, user);
      final evalB = WhoCalculator.evaluateProduct(productB, user);

      final matrix = ComparisonMatrixBuilder.build(
        comparisonSet: [evalA, evalB],
        user: user,
      );

      expect(matrix.isEmpty, false);
      expect(matrix.productIds, ['p001', 'p012']);

      final sodiumRow =
          matrix.nutrientRows.firstWhere((r) => r.nutrient == ComparisonNutrient.sodium);
      final cellA = sodiumRow.cells.firstWhere((c) => c.productId == 'p001');
      final cellB = sodiumRow.cells.firstWhere((c) => c.productId == 'p012');

      // Highlight color follows the ABSOLUTE WHO/FDA level (Table 3.14),
      // not just "which product is lower" -- see comparison_matrix_builder's
      // top-of-file comment. p001 is Caution-level sodium for a hypertension
      // user -> unfavorable (red). p012 is lower but still only
      // Moderate-level (not actually in the safe range) -> neutral, NOT
      // favorable. Favorable is reserved for AdvisoryLevel.suitable, i.e.
      // genuinely safe for this user's condition.
      expect(cellA.highlight, ComparisonHighlight.unfavorable);
      expect(cellB.highlight, ComparisonHighlight.neutral);

      // Absolute levels still follow Table 3.14, only because the user has
      // hypertension saved -- independent of the relative highlight above.
      expect(cellA.level, AdvisoryLevel.caution); // 780mg >= 400mg
      expect(cellB.level, AdvisoryLevel.moderate); // 320mg is 101-399 range
    });

    test('level is null for nutrients with no Table 3.14 threshold, even when '
        'that nutrient clearly differs between products', () async {
      final repo = MockProductRepository();
      final user = UserHealthProfile(
        userId: 'u1',
        displayName: 'Test',
        conditions: [HealthCondition.hypertension],
        allergies: [],
      );

      final productA = await repo.getProductById('p001'); // saturatedFatG 6.5
      final productB = await repo.getProductById('p012'); // saturatedFatG 4.5

      final evalA = WhoCalculator.evaluateProduct(productA, user);
      final evalB = WhoCalculator.evaluateProduct(productB, user);

      final matrix = ComparisonMatrixBuilder.build(
        comparisonSet: [evalA, evalB],
        user: user,
      );

      final satFatRow = matrix.nutrientRows
          .firstWhere((r) => r.nutrient == ComparisonNutrient.saturatedFat);
      final cellA = satFatRow.cells.firstWhere((c) => c.productId == 'p001');
      final cellB = satFatRow.cells.firstWhere((c) => c.productId == 'p012');

      // Relative highlight still works (no threshold needed for this).
      expect(cellA.highlight, ComparisonHighlight.unfavorable); // 6.5g, higher
      expect(cellB.highlight, ComparisonHighlight.favorable); // 4.5g, lower

      // But absolute level stays null -- Table 3.14 has no saturated fat band.
      expect(cellA.level, null);
      expect(cellB.level, null);
    });

    test('level stays null for sodium when the user does NOT have hypertension saved, '
        'even though the highlight still works', () async {
      final repo = MockProductRepository();
      final user = UserHealthProfile(
        userId: 'u1',
        displayName: 'Test',
        conditions: [HealthCondition.diabetes], // NOT hypertension
        allergies: [],
      );

      final productA = await repo.getProductById('p001');
      final productB = await repo.getProductById('p012');

      final evalA = WhoCalculator.evaluateProduct(productA, user);
      final evalB = WhoCalculator.evaluateProduct(productB, user);

      final matrix = ComparisonMatrixBuilder.build(
        comparisonSet: [evalA, evalB],
        user: user,
      );

      final sodiumRow =
          matrix.nutrientRows.firstWhere((r) => r.nutrient == ComparisonNutrient.sodium);
      final cellA = sodiumRow.cells.firstWhere((c) => c.productId == 'p001');

      expect(cellA.highlight, ComparisonHighlight.unfavorable); // still works
      expect(cellA.level, null); // no hypertension saved -> no Table 3.14 level
    });

test('protein direction is flipped: higher protein is favorable (green), '
        'lower is unfavorable (red)', () async {
      final repo = MockProductRepository();
      final user = UserHealthProfile(
        userId: 'u1',
        displayName: 'Test',
        conditions: [],
        allergies: [],
      );

      final productA = await repo.getProductById('p001'); // proteinG 18.0
      final productB = await repo.getProductById('p011'); // proteinG 3.0 -- clearly lower

      final evalA = WhoCalculator.evaluateProduct(productA, user);
      final evalB = WhoCalculator.evaluateProduct(productB, user);

      final matrix = ComparisonMatrixBuilder.build(
        comparisonSet: [evalA, evalB],
        user: user,
      );

      final proteinRow =
          matrix.nutrientRows.firstWhere((r) => r.nutrient == ComparisonNutrient.protein);
      final cellA = proteinRow.cells.firstWhere((c) => c.productId == 'p001');
      final cellB = proteinRow.cells.firstWhere((c) => c.productId == 'p011');

      // p001 has HIGHER protein (18.0g) -> should be favorable (green).
      // p011 has LOWER protein (3.0g) -> should be unfavorable (red).
      // This is the opposite direction from sodium/sugar/fat, confirming
      // ComparisonNutrient.protein.higherIsBetter is actually being honored.
      expect(cellA.highlight, ComparisonHighlight.favorable);
      expect(cellB.highlight, ComparisonHighlight.unfavorable);
    });

    test('tied values produce neutral highlight for all products, not a '
        'false favorable/unfavorable split', () async {
      final repo = MockProductRepository();
      final user = UserHealthProfile(
        userId: 'u1',
        displayName: 'Test',
        conditions: [],
        allergies: [],
      );

      // p001 and p012 both have proteinG 18.0 -- a genuine tie.
      final productA = await repo.getProductById('p001');
      final productB = await repo.getProductById('p012');

      final evalA = WhoCalculator.evaluateProduct(productA, user);
      final evalB = WhoCalculator.evaluateProduct(productB, user);

      final matrix = ComparisonMatrixBuilder.build(
        comparisonSet: [evalA, evalB],
        user: user,
      );

      final proteinRow =
          matrix.nutrientRows.firstWhere((r) => r.nutrient == ComparisonNutrient.protein);
      final cellA = proteinRow.cells.firstWhere((c) => c.productId == 'p001');
      final cellB = proteinRow.cells.firstWhere((c) => c.productId == 'p012');

      expect(cellA.value, cellB.value); // confirms this genuinely is a tie
      expect(cellA.highlight, ComparisonHighlight.neutral);
      expect(cellB.highlight, ComparisonHighlight.neutral);
    });

    test('allergen rows only include allergens on the user\'s profile, and '
        'correctly flag which products contain them', () async {
      final repo = MockProductRepository();
      final user = UserHealthProfile(
        userId: 'u1',
        displayName: 'Test',
        conditions: [],
        allergies: [AllergenType.fish],
      );

      final sardine = await repo.getProductById('p002'); // contains fish
      final cornedBeef = await repo.getProductById('p001'); // no fish

      final evalSardine = WhoCalculator.evaluateProduct(sardine, user);
      final evalCornedBeef = WhoCalculator.evaluateProduct(cornedBeef, user);

      final matrix = ComparisonMatrixBuilder.build(
        comparisonSet: [evalSardine, evalCornedBeef],
        user: user,
      );

      expect(matrix.allergenRows.length, 1);
      final fishRow = matrix.allergenRows.first;
      expect(fishRow.allergen, AllergenType.fish);

      final sardineCell = fishRow.cells.firstWhere((c) => c.productId == 'p002');
      final cornedBeefCell = fishRow.cells.firstWhere((c) => c.productId == 'p001');

      expect(sardineCell.presence, AllergenPresence.contains);
      expect(cornedBeefCell.presence, AllergenPresence.none);
    });
  });

  group('MockFavoritesRepository', () {
    test('toggleFavorite adds then removes, returning the new state each time', () async {
      final favorites = MockFavoritesRepository();

      final afterFirstToggle = await favorites.toggleFavorite(
        userId: 'u1',
        productId: 'p001',
      );
      expect(afterFirstToggle, true);
      expect(await favorites.isFavorite(userId: 'u1', productId: 'p001'), true);

      final afterSecondToggle = await favorites.toggleFavorite(
        userId: 'u1',
        productId: 'p001',
      );
      expect(afterSecondToggle, false);
      expect(await favorites.isFavorite(userId: 'u1', productId: 'p001'), false);
    });

    test('favorites are isolated per user', () async {
      final favorites = MockFavoritesRepository();

      await favorites.addFavorite(userId: 'u1', productId: 'p001');
      await favorites.addFavorite(userId: 'u2', productId: 'p002');

      expect(await favorites.getFavoriteProductIds('u1'), ['p001']);
      expect(await favorites.getFavoriteProductIds('u2'), ['p002']);
      expect(await favorites.isFavorite(userId: 'u1', productId: 'p002'), false);
    });

    test('removeFavorite on a product that was never added is a safe no-op', () async {
      final favorites = MockFavoritesRepository();

      await favorites.removeFavorite(userId: 'u1', productId: 'p999');

      expect(await favorites.getFavoriteProductIds('u1'), isEmpty);
    });
  });
}