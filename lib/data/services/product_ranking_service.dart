// lib/data/services/product_ranking_service.dart
//
// Phase 3 (Module 4.3): orchestrates Phase 1's scoring/ranking across
// multiple products and attaches a Phase 2 reason to each. Cost-conscious
// by design -- only the top 3 (what's actually shown prominently) get a
// real Gemini call; everything ranked below that gets the free, deterministic
// fallback template instead, since a user rarely needs AI-quality prose for
// "least suitable, ranked #5."

import 'gemini_advisory_service.dart';
import '../models/health_advisory.dart';
import '../models/health_profile.dart';
import '../models/product.dart';
import '../models/ranked_product_result.dart';
import '../../core/utils/who_calculator.dart';
import '../../core/utils/fallback_advisory_generator.dart';

// Module says "up to 3-5 products" per scan/comparison event.
const int kMaxProductsPerRanking = 5;

class ProductRankingService {
  ProductRankingService({required GeminiAdvisoryService geminiService})
      : _geminiService = geminiService;

  final GeminiAdvisoryService _geminiService;

  /// Ranks [products] against [user]'s health profile (Phase 1), then
  /// attaches a display-ready reason to each. Only the top
  /// [kTopRecommendationCount] products get a real AI-generated explanation;
  /// the rest get a deterministic template explanation at zero token cost.
  ///
  /// Throws [ArgumentError] if [products] exceeds [kMaxProductsPerRanking],
  /// per Module 4.3's "up to 3-5 products" constraint.
  Future<List<RankedProductResult>> rankProducts({
    required List<Product> products,
    required UserHealthProfile user,
    required String scanEventId,
    String languageCode = 'en',
  }) async {
    if (products.length > kMaxProductsPerRanking) {
      throw ArgumentError(
        'CLARO supports ranking up to $kMaxProductsPerRanking products per '
        'scan event, got ${products.length}.',
      );
    }
    if (products.isEmpty) return [];

    // Phase 1: pure logic, no cost, no network -- sorted ascending risk,
    // tie-break applied, allergen override forces last place.
    final ranked = WhoCalculator.rankProducts(products, user);

    // Position-based labels computed once over the whole list, so exactly
    // one product is mostSuitable and exactly one is leastSuitable.
    final labels = computeSuitabilityRankLabels(ranked);

    final results = <RankedProductResult>[];

    for (var i = 0; i < ranked.length; i++) {
      final evaluation = ranked[i];
      final rank = i + 1;

      HealthAdvisory reason;
      if (rank <= kTopRecommendationCount) {
        // Reuses Phase 2 in full -- same cache-by-scanEventId+productId,
        // same timeout/fallback handling.
        reason = await _geminiService.generateAdvisory(
          scanEventId: scanEventId,
          evaluation: evaluation,
          user: user,
          languageCode: languageCode,
        );
      } else {
        // Below the top N: template-only, no API call. These products are
        // shown lower in the list (if at all) -- not worth spending tokens
        // on prose quality for "least suitable, ranked last."
        reason = FallbackAdvisoryGenerator.generate(
          evaluation,
          reason: FallbackReason.notNeeded,
        );
      }

      results.add(RankedProductResult(
        rank: rank,
        evaluation: evaluation,
        reason: reason,
        suitabilityRankLabel: labels[i],
      ));
    }

    return results;
  }

  /// Convenience for UI code that only wants the top N, matching
  /// WhoCalculator.topRecommendations but returning the display-ready shape.
  List<RankedProductResult> topRecommendations(
    List<RankedProductResult> ranked, {
    int count = kTopRecommendationCount,
  }) {
    return ranked.take(count).toList();
  }
}