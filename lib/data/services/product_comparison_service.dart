// lib/data/services/product_comparison_service.dart
//
// Module 5.1/5.2 (Figure 3.19): implements the "Compare" button flow --
// fetch same-category products, add the originally scanned product to
// that list, then rank the whole set. FREE -- no Gemini call happens here;
// AI is only invoked later, per-product, via
// ProductRankingService.getProductDetail when the user taps into one.

import '../models/health_profile.dart';
import '../../models/product_model.dart';
import '../models/ranked_product_result.dart';
import '../repositories/product_repository.dart';
import 'product_ranking_service.dart';

class ProductComparisonService {
  ProductComparisonService({
    required ProductRepository productRepository,
    required ProductRankingService productRankingService,
  })  : _productRepository = productRepository,
        _productRankingService = productRankingService;

  final ProductRepository _productRepository;
  final ProductRankingService _productRankingService;

  // The scanned product always takes one of the kMaxProductsPerRanking (5)
  // slots, per Figure 3.19's "Add scanned Product to the List" step -- so
  // only 4 alternatives get fetched, not 5.
  static const int _maxAlternatives = kMaxProductsPerRanking - 1;

  Future<List<RankedProductResult>> compareWithAlternatives({
    required Product scannedProduct,
    required UserHealthProfile user,
  }) async {
    final alternatives = await _productRepository.getSimilarProducts(
      scannedProduct.category,
      excludeId: scannedProduct.id,
    );

    // Intelligent selection: score alternatives by similarity
    final scoredAlternatives = alternatives.map((p) {
      final score = _calculateSimilarityScore(scannedProduct, p);
      return (product: p, score: score);
    }).toList();

    // Sort by similarity score (highest first)
    scoredAlternatives.sort((a, b) => b.score.compareTo(a.score));

    // Take top 4 most similar products
    final cappedAlternatives = scoredAlternatives
        .take(_maxAlternatives)
        .map((s) => s.product)
        .toList();

    final comparisonSet = [scannedProduct, ...cappedAlternatives];

    return _productRankingService.rankProducts(
      products: comparisonSet,
      user: user,
    );
  }

  /// Calculates a similarity score between two products.
  /// Higher score = more similar.
  /// Scoring factors:
  /// - Same brand: +50 points
  /// - Similar sodium content (within 50mg): +20 points
  /// - Similar sugar content (within 2g): +15 points
  /// - Similar saturated fat (within 1g): +10 points
  /// - Same variant keywords: +5 points per matching keyword
  double _calculateSimilarityScore(Product a, Product b) {
    double score = 0;

    // Brand match (highest priority)
    if (a.brand == b.brand) {
      score += 50;
    }

    // Nutritional similarity
    final sodiumDiff = (_parseSodium(a.nutritionalFacts.sodium) - _parseSodium(b.nutritionalFacts.sodium)).abs();
    if (sodiumDiff <= 50) score += 20;

    final sugarDiff = (_parseSugar(a.nutritionalFacts.sugars) - _parseSugar(b.nutritionalFacts.sugars)).abs();
    if (sugarDiff <= 2) score += 15;

    final satFatDiff = (_parseFat(a.nutritionalFacts.saturatedFat) - _parseFat(b.nutritionalFacts.saturatedFat)).abs();
    if (satFatDiff <= 1) score += 10;

    // Variant keyword similarity
    final aVariant = a.variant.toLowerCase();
    final bVariant = b.variant.toLowerCase();
    final keywords = ['flakes', 'hot', 'spicy', 'calamansi', 'tomato', 'oil', 'natural', 'garlic', 'onion'];
    for (final keyword in keywords) {
      if (aVariant.contains(keyword) && bVariant.contains(keyword)) {
        score += 5;
      }
    }

    return score;
  }

  double _parseSodium(String sodiumStr) {
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*mg').firstMatch(sodiumStr);
    return match != null ? double.parse(match.group(1)!) : 0.0;
  }

  double _parseSugar(String sugarStr) {
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*g').firstMatch(sugarStr);
    return match != null ? double.parse(match.group(1)!) : 0.0;
  }

  double _parseFat(String fatStr) {
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*g').firstMatch(fatStr);
    return match != null ? double.parse(match.group(1)!) : 0.0;
  }
}