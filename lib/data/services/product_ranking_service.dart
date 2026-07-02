// lib/data/services/product_ranking_service.dart
//
// rankProducts(): FREE. Pure Dart, zero Gemini calls -- powers the
// "multiple product compared interface" list (names + rank only).
//
// getProductDetail(): the ONLY method here that touches Gemini, and only
// for ONE product, only when the user actually taps into it. Powers the
// "solo product interface" screen, with or without comparison context.

import 'gemini_advisory_service.dart';
import '../models/health_advisory.dart';
import '../models/health_profile.dart';
import '../models/product.dart';
import '../models/ranked_product_result.dart';
import '../../core/utils/who_calculator.dart';
import '../../core/utils/comparison_calculator.dart';

// Module says "up to 3-5 products" per scan/comparison event.
const int kMaxProductsPerRanking = 5;

class ProductRankingService {
  ProductRankingService({required GeminiAdvisoryService geminiService})
      : _geminiService = geminiService;

  final GeminiAdvisoryService _geminiService;

  /// Ranks [products] against [user]'s profile. Pure Dart -- no API calls,
  /// safe to call as often as needed (rebuilds, re-sorts, etc.) at zero cost.
  List<RankedProductResult> rankProducts({
    required List<Product> products,
    required UserHealthProfile user,
  }) {
    if (products.length > kMaxProductsPerRanking) {
      throw ArgumentError(
        'CLARO supports ranking up to $kMaxProductsPerRanking products per '
        'scan event, got ${products.length}.',
      );
    }
    if (products.isEmpty) return [];

    final ranked = WhoCalculator.rankProducts(products, user);
    final labels = computeSuitabilityRankLabels(ranked);

    return List.generate(
      ranked.length,
      (i) => RankedProductResult(
        rank: i + 1,
        evaluation: ranked[i],
        suitabilityRankLabel: labels[i],
      ),
    );
  }

  /// Called when the user taps a specific product to view its detail
  /// screen. ONE Gemini call. If [comparisonSet] has more than one entry,
  /// the same call also returns a comparisonExplanation -- no second call.
  /// If [comparisonSet] is null or has just [target] (solo scan, Scenario
  /// A before Compare is tapped), this behaves exactly like the original
  /// Phase 2 flow -- health advisory only, no comparison text.
  Future<HealthAdvisory> getProductDetail({
    required RankedProductResult target,
    List<RankedProductResult>? comparisonSet,
    required UserHealthProfile user,
    required String scanEventId,
    String languageCode = 'en',
  }) async {
    ComparisonFact? primaryFact;

    if (comparisonSet != null && comparisonSet.length > 1) {
      final facts = ComparisonCalculator.computeFacts(
        target: target.evaluation,
        comparisonSet: comparisonSet.map((r) => r.evaluation).toList(),
        user: user,
      );
      primaryFact = ComparisonCalculator.primaryFact(facts);
    }

    return _geminiService.generateAdvisory(
      scanEventId: scanEventId,
      evaluation: target.evaluation,
      user: user,
      comparisonFact: primaryFact,
      rankLabel: primaryFact != null ? target.suitabilityRankLabel : null,
      languageCode: languageCode,
    );
  }
}