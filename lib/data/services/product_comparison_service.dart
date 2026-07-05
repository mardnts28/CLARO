// lib/data/services/product_comparison_service.dart
//
// Module 5.1/5.2 (Figure 3.19): implements the "Compare" button flow --
// fetch same-category products, add the originally scanned product to
// that list, then rank the whole set. FREE -- no Gemini call happens here;
// AI is only invoked later, per-product, via
// ProductRankingService.getProductDetail when the user taps into one.

import '../models/health_profile.dart';
import '../models/product.dart';
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
      scannedProduct.subCategory,
      excludeId: scannedProduct.id,
    );

    final cappedAlternatives = alternatives.take(_maxAlternatives).toList();
    final comparisonSet = [scannedProduct, ...cappedAlternatives];

    return _productRankingService.rankProducts(
      products: comparisonSet,
      user: user,
    );
  }
}