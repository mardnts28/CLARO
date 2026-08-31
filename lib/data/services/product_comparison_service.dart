// lib/data/services/product_comparison_service.dart
//
// Module 5.1/5.2 (Figure 3.19): implements the "Compare" button flow --
// find products that are SEMANTICALLY SIMILAR to the scanned product
// (not just same-category), add the scanned product to that list, then
// rank the whole set. FREE -- no Gemini call happens here; AI is only
// invoked later, per-product, via ProductRankingService.getProductDetail
// when the user taps into one.
//
// Candidate SELECTION vs. RANKING are deliberately two separate steps:
//   1. Selection (this file, _isRelevantCandidate below): a deterministic,
//      keyword/phrase-based relevance gate over Product.name -- decides
//      WHICH same-category products are similar enough to include at all.
//      The keyword lists live in ProductCharacteristics (core/utils),
//      shared with CompareProductsScreen's on-screen Product Type/Flavor
//      filter chips, so there's one vocabulary to maintain, not two.
//   2. Ranking (ProductRankingService.rankProducts, i.e. WhoCalculator):
//      decides the DISPLAY ORDER of whichever candidates made it through
//      step 1, purely on nutritional suitability. Selection never
//      influences order -- a product either belongs in the comparison set
//      or it doesn't; once in, only WhoCalculator decides its position.
//
// Why deterministic (no Gemini) here: no product in the catalog carries a
// stored "type"/"flavor" tag (Product.variant is always empty for real
// products -- see _productFromDoc in product_repository.dart), so the only
// signal available either way is the free-text product name. Matching
// that name against a keyword list is instant and has zero failure mode,
// so it keeps this screen's current "loads immediately, no network/API
// dependency" behavior intact rather than adding Gemini latency/cost/
// timeout risk to every "Compare" tap.
//
// Scenario B (this file) intentionally has no result-count ceiling beyond
// relevance: the comparison set can be smaller than, equal to, or larger
// than kMaxProductsPerRanking. Unlike Scenario A (a multi-product scan,
// capped upstream to 5 detections and ranked via
// ProductRankingService.rankProducts with its default cap enforced), the
// "Compare" button's job is to show every RELEVANT same-category
// alternative -- CompareProductsScreen paginates that ranked list behind
// "See More" rather than this service truncating it.

import '../models/health_profile.dart';
import '../../core/utils/nutrition_availability.dart';
import '../../core/utils/product_characteristics.dart';
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
    // filtering/ranking so a duplicate can never occupy two slots in the
    // comparison list.
    final deduped = _dedupeByIdentity(rawAlternatives);

    // SELECTION: same category is necessary but not sufficient -- only
    // keep alternatives that share an actual product characteristic
    // (protein/type, e.g. "sardines", OR flavor/preparation, e.g. "tomato
    // sauce") with the scanned product and have nutrition facts available.
    final relevantAlternatives = deduped
        .where((p) =>
            _isRelevantCandidate(scannedProduct, p) &&
            NutritionAvailability.isAvailable(p))
        .toList();

    final comparisonSet = [scannedProduct, ...relevantAlternatives];

    // RANKING: unchanged -- WhoCalculator's suitability ranking via
    // ProductRankingService, with no count cap (see file header).
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

  /// True if [candidate] shares at least one meaningful characteristic
  /// token (see ProductCharacteristics) with [scanned]. This is the sole
  /// gate deciding whether [candidate] enters the comparison set; it does
  /// not affect where it ends up ranked once included. Not an
  /// exact-match-of-every-phrase requirement -- "Sardines in Tomato
  /// Sauce" and "Tuna in Tomato Sauce" still match each other (shared
  /// flavor) even though their protein differs.
  bool _isRelevantCandidate(Product scanned, Product candidate) {
    final scannedTokens = ProductCharacteristics.characteristicTokens(scanned);
    final candidateTokens =
        ProductCharacteristics.characteristicTokens(candidate);
    if (scannedTokens.isEmpty || candidateTokens.isEmpty) return false;
    return scannedTokens.intersection(candidateTokens).isNotEmpty;
  }
}