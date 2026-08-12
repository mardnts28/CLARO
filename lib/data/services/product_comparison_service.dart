// lib/data/services/product_comparison_service.dart
//
// Module 5.1/5.2 (Figure 3.19): implements the "Compare" button flow --
// fetch EVERY same-category product, add the originally scanned product to
// that list, then rank the whole set. FREE -- no Gemini call happens here;
// AI is only invoked later, per-product, via
// ProductRankingService.getProductDetail when the user taps into one.
//
// Scenario B (this file) intentionally has no result-count ceiling: the
// comparison set can be smaller than, equal to, or larger than
// kMaxProductsPerRanking. Unlike Scenario A (a multi-product scan, capped
// upstream to 5 detections and ranked via ProductRankingService.rankProducts
// with its default cap enforced), the "Compare" button's job is to show
// every same-category alternative -- CompareProductsScreen paginates that
// full ranked list behind "See More" rather than this service truncating it.

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

  Future<List<RankedProductResult>> compareWithAlternatives({
    required Product scannedProduct,
    required UserHealthProfile user,
  }) async {
    final rawAlternatives = await _productRepository.getSimilarProducts(
      scannedProduct.category,
      excludeId: scannedProduct.id,
    );

    // Catalog can contain literal duplicate entries (same product entered
    // twice under different Firestore doc ids) -- collapse those before
    // ranking so a duplicate can never occupy two slots in the comparison
    // list.
    final alternatives = _dedupeByIdentity(rawAlternatives);

    // Every same-category alternative goes into the ranked list -- no
    // similarity gate, no cap. Final display order comes entirely from
    // ProductRankingService.rankProducts (WhoCalculator's suitability
    // ranking) below, not from any pre-filtering here.
    final comparisonSet = [scannedProduct, ...alternatives];

    return _productRankingService.rankProducts(
      products: comparisonSet,
      user: user,
      enforceMaxCap: false,
    );
  }

  /// Collapses products that are the same real-world item (same name +
  /// brand + variant, case/whitespace-insensitive) down to one entry,
  /// keeping the first occurrence. Guards against duplicate catalog rows
  /// showing up twice in the same comparison list.
  List<Product> _dedupeByIdentity(List<Product> products) {
    final seen = <String>{};
    final result = <Product>[];
    for (final p in products) {
      final key = [
        p.name.trim().toLowerCase(),
        p.brand.trim().toLowerCase(),
        p.variant.trim().toLowerCase(),
      ].join('|');
      if (seen.add(key)) {
        result.add(p);
      }
    }
    return result;
  }
}