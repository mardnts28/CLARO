import 'package:flutter_test/flutter_test.dart';
import 'package:claro/models/product_model.dart';
import 'package:claro/data/models/comparison_matrix.dart';
import 'package:claro/data/models/health_profile.dart';
import 'package:claro/core/utils/comparison_matrix_builder.dart';
import 'package:claro/core/utils/who_calculator.dart';

void main() {
  group('ComparisonMatrixBuilder Tests', () {
    final user = UserHealthProfile(
      userId: 'test_user',
      displayName: 'Test User',
      conditions: const [HealthCondition.hypertension],
      allergies: const [AllergenType.fish],
    );

    Product makeProduct(String id, double sodium, double protein, {List<String> allergens = const []}) {
      return Product(
        id: id,
        name: 'Product $id',
        brand: 'Brand $id',
        ingredients: const ['Water'],
        allergens: allergens,
        nutritionalFacts: NutritionalFacts(
          servingSize: '100g',
          caloriesKcal: 100,
          proteinG: protein,
          sodiumMg: sodium,
          hasNutritionData: true,
        ),
      );
    }

    test('returns empty matrix if comparison set has fewer than 2 items', () {
      final p1 = makeProduct('p1', 100, 10);
      final eval1 = WhoCalculator.evaluateProduct(p1, user);

      final matrix = ComparisonMatrixBuilder.build(
        comparisonSet: [eval1],
        user: user,
      );

      expect(matrix.productIds, isEmpty);
      expect(matrix.nutrientRows, isEmpty);
      expect(matrix.allergenRows, isEmpty);
    });

    test('builds rows across all comparison nutrients and detects favorable values', () {
      final p1 = makeProduct('p1', 100, 20); // 100mg sodium = Suitable (favorable), 20g protein = highest (favorable)
      final p2 = makeProduct('p2', 300, 5, allergens: ['Fish']); // 300mg sodium = Moderate (neutral), 5g protein = lowest (unfavorable)

      final eval1 = WhoCalculator.evaluateProduct(p1, user);
      final eval2 = WhoCalculator.evaluateProduct(p2, user);

      final matrix = ComparisonMatrixBuilder.build(
        comparisonSet: [eval1, eval2],
        user: user,
      );

      expect(matrix.productIds, equals(['p1', 'p2']));
      expect(matrix.nutrientRows.length, ComparisonNutrient.values.length);

      // Sodium row: 100mg is Suitable (favorable), 300mg is Moderate (neutral)
      final sodiumRow = matrix.nutrientRows.firstWhere((r) => r.nutrient == ComparisonNutrient.sodium);
      final p1SodiumCell = sodiumRow.cells.firstWhere((c) => c.productId == 'p1');
      final p2SodiumCell = sodiumRow.cells.firstWhere((c) => c.productId == 'p2');
      expect(p1SodiumCell.highlight, ComparisonHighlight.favorable);
      expect(p2SodiumCell.highlight, ComparisonHighlight.neutral);

      // Protein row: higher is favorable (no health condition filter -> relative comparison)
      final proteinRow = matrix.nutrientRows.firstWhere((r) => r.nutrient == ComparisonNutrient.protein);
      final p1ProteinCell = proteinRow.cells.firstWhere((c) => c.productId == 'p1');
      final p2ProteinCell = proteinRow.cells.firstWhere((c) => c.productId == 'p2');
      expect(p1ProteinCell.highlight, ComparisonHighlight.favorable);
      expect(p2ProteinCell.highlight, ComparisonHighlight.unfavorable);

      // Allergen row: fish
      expect(matrix.allergenRows.length, 1);
      final fishRow = matrix.allergenRows.first;
      expect(fishRow.allergen, AllergenType.fish);
      final p1Fish = fishRow.cells.firstWhere((c) => c.productId == 'p1');
      final p2Fish = fishRow.cells.firstWhere((c) => c.productId == 'p2');
      expect(p1Fish.presence, AllergenPresence.none);
      expect(p2Fish.presence, AllergenPresence.contains);
    });
  });
}
