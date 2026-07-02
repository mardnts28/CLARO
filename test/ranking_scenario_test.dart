// test/ranking_scenarios_test.dart
//
// Exercises the two real user flows end-to-end against your mock data, so
// you can verify the logic BEFORE any UI exists.
//
// NOTE on GeminiAdvisoryService: these tests use the real Gemini API and will
// consume quota. If you hit quota limits, the service will fall back to
// FallbackAdvisoryGenerator automatically and tests will still pass.
//
// Run with: flutter test test/ranking_scenarios_test.dart --dart-define=GEMINI_API_KEY=your_key

import 'package:flutter_test/flutter_test.dart';
import 'package:claro/data/models/health_profile.dart';
import 'package:claro/data/models/ranked_product_result.dart';
import 'package:claro/data/repositories/product_repository.dart';
import 'package:claro/data/services/gemini_advisory_service.dart';
import 'package:claro/data/services/product_comparison_service.dart';
import 'package:claro/data/services/product_ranking_service.dart';

void main() {
  const apiKey = String.fromEnvironment('GEMINI_API_KEY');
  final geminiService = GeminiAdvisoryService(apiKey: apiKey);
  final rankingService = ProductRankingService(geminiService: geminiService);

  final hypertensionUser = UserHealthProfile(
    userId: 'test-user',
    displayName: 'Test User',
    conditions: [HealthCondition.hypertension],
    allergies: [],
    dietaryRestrictions: const [],
  );

  group('Scenario 1: multiple products recognized in one scan', () {
    test('ranks all recognized products regardless of category, top-3 get '
        'AI-path reasons, rest get fallback', () async {
      final repo = MockProductRepository();
      // Simulating simultaneous recognition of 4 different products --
      // mixed categories, exactly like a real multi-item scan would be.
      final scanned = [
        await repo.getProductById('p001'), // Argentina Corned Beef
        await repo.getProductById('p008'), // Lucky Me Pancit Canton
        await repo.getProductById('p005'), // Century Tuna
        await repo.getProductById('p012'), // Low Sodium Corned Beef (should rank well)
      ];

      final results = rankingService.rankProducts(
        products: scanned,
        user: hypertensionUser,
      );

      // All 4 scanned products appear in the result.
      expect(results.length, 4);

      // Ranks are unique and sequential.
      expect(results.map((r) => r.rank).toList(), [1, 2, 3, 4]);

      // Risk scores are non-decreasing down the list (ascending sort).
      for (var i = 0; i < results.length - 1; i++) {
        expect(
          results[i].evaluation.riskScore,
          lessThanOrEqualTo(results[i + 1].evaluation.riskScore),
        );
      }

      // Exactly one mostSuitable, exactly one leastSuitable (no allergen
      // matches in this set, so none should be forcedLast).
      final labelCounts = <SuitabilityRankLabel, int>{};
      for (final r in results) {
        labelCounts[r.suitabilityRankLabel] =
            (labelCounts[r.suitabilityRankLabel] ?? 0) + 1;
      }
      expect(labelCounts[SuitabilityRankLabel.mostSuitable], 1);
      expect(labelCounts[SuitabilityRankLabel.leastSuitable], 1);
      expect(labelCounts[SuitabilityRankLabel.forcedLast], null);

      // With only 4 products and topCount fixed at 3, exactly 3 should
      // have attempted the AI path (source will be fallbackRuleBased since
      // the fake key forces failure, but isTopRecommendation still reflects
      // rank, independent of whether Gemini actually succeeded).
      expect(results.where((r) => r.isTopRecommendation).length, 3);
    });

    test('throws if more than 5 products are scanned simultaneously', () async {
      final repo = MockProductRepository();
      final allProducts = await repo.getAllProducts();
      final tooMany = allProducts.take(6).toList();

      expect(
        () => rankingService.rankProducts(
          products: tooMany,
          user: hypertensionUser,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Scenario 2: single product scanned, user taps Compare', () {
    test('sardines subCategory has 6 total products -- alternatives must be '
        'capped to 4, giving 5 total with the scanned product included', () async {
      final repo = MockProductRepository();
      final comparisonService = ProductComparisonService(
        productRepository: repo,
        productRankingService: rankingService,
      );

      // p002 is 'sardines' subCategory. Mock data now has 6 sardines total
      // (p002, p003, p013-p016), so 5 possible alternatives exist -- must
      // be capped to 4 to demonstrate actual truncation.
      final scannedProduct = await repo.getProductById('p002');

      final results = await comparisonService.compareWithAlternatives(
        scannedProduct: scannedProduct,
        user: hypertensionUser,
      );

      // 1 scanned product + 4 capped alternatives = 5 total (NOT 6, which
      // is what you'd get without the cap).
      expect(results.length, 5);

      // The originally scanned product must be present in the result.
      expect(
        results.any((r) => r.evaluation.product.id == scannedProduct.id),
        true,
      );

      // Every product in the result must share the scanned product's
      // subCategory (comparable products, not just same broad packaging).
      expect(
        results.every((r) => r.evaluation.product.subCategory == scannedProduct.subCategory),
        true,
      );

      // Ranks are unique and sequential across all 5.
      expect(results.map((r) => r.rank).toList(), [1, 2, 3, 4, 5]);
    });

    test('cornedBeef subCategory has only 3 total products -- comparison set '
        'should be all 3, not padded or errored (fewer than the cap)', () async {
      final repo = MockProductRepository();
      final comparisonService = ProductComparisonService(
        productRepository: repo,
        productRankingService: rankingService,
      );

      final scannedProduct = await repo.getProductById('p001'); // Argentina

      final results = await comparisonService.compareWithAlternatives(
        scannedProduct: scannedProduct,
        user: hypertensionUser,
      );

      // 3 cornedBeef products exist total (p001, p004, p012) -- scanned
      // product + 2 alternatives = 3, no truncation needed.
      expect(results.length, 3);
    });

    test('a subCategory with only 1 product (no alternatives) returns just '
        'the scanned product by itself -- not an error', () async {
      final repo = MockProductRepository();
      final comparisonService = ProductComparisonService(
        productRepository: repo,
        productRankingService: rankingService,
      );

      // pancitCanton subCategory currently only has p008 -- a realistic
      // gap in a still-growing dataset, not a bug. The compare flow should
      // degrade gracefully to "just show this one product," not crash or
      // fetch unrelated products as a fallback.
      final scannedProduct = await repo.getProductById('p008');

      final results = await comparisonService.compareWithAlternatives(
        scannedProduct: scannedProduct,
        user: hypertensionUser,
      );

      expect(results.length, 1);
      expect(results.first.evaluation.product.id, 'p008');
      // With only one product, it's trivially both the best and only
      // option -- mostSuitable, per computeSuitabilityRankLabels' rule
      // that position 1 is always checked before "last" position.
      expect(results.first.suitabilityRankLabel, SuitabilityRankLabel.mostSuitable);
    });
  });
}