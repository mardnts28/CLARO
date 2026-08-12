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
    // sauce") with the scanned product. "Canned Sardines in Tomato Sauce"
    // vs. "Canned Corn" share neither -> excluded, even though both are
    // "Canned Goods". vs. "Tuna in Tomato Sauce" share the flavor token
    // ("tomato sauce") even though the protein differs -> included. See
    // _isRelevantCandidate for the matching rule.
    final relevantAlternatives = deduped
        .where((p) => _isRelevantCandidate(scannedProduct, p))
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

  // ── Deterministic similarity gate (Option B) ────────────────────────
  //
  // Two products are "relevant" to each other if they share at least one
  // meaningful characteristic token -- drawn from either the curated
  // protein/type + flavor keyword lists below, or (for categories those
  // lists don't cover) generic overlap of the meaningful words left in
  // each product's name after stripping brand name and packaging/filler
  // words. A candidate needs to share ONLY ONE such token to be included
  // -- this deliberately is not an exact-match-of-every-phrase
  // requirement, so "Sardines in Tomato Sauce" and "Tuna in Tomato Sauce"
  // still match each other (shared flavor) even though their protein
  // differs.

  /// Curated PROTEIN/PRODUCT-TYPE keywords -- common, short/ambiguous
  /// words (like "tuna") that deserve an explicit list rather than
  /// relying on generic token overlap alone.
  static const List<String> _typeKeywords = [
    // Canned fish / meats
    'tuna', 'sardines', 'sardine', 'mackerel', 'bangus', 'milkfish',
    'corned beef', 'luncheon meat', 'meatloaf', 'vienna sausage', 'hotdog',
    // Common protein descriptors (noodles, snacks, etc.)
    'chicken', 'beef', 'pork', 'seafood', 'shrimp', 'squid',
  ];

  /// Curated FLAVOR/PREPARATION keywords -- checked against the product
  /// NAME (the only field that reliably carries this info -- see file
  /// header on Product.variant). Lets two products of a DIFFERENT protein
  /// type still count as relevant when they share a flavor/prep style,
  /// e.g. "Tuna in Tomato Sauce" vs. "Sardines in Tomato Sauce".
  static const List<String> _flavorKeywords = [
    'tomato sauce', 'chili sauce', 'hot and spicy', 'spicy', 'hot',
    'calamansi', 'vegetable oil', 'oil', 'garlic', 'onion', 'vinegar',
    'adobo', 'curry', 'barbecue', 'bbq', 'sweet and sour',
  ];

  /// Words that describe packaging/preparation filler rather than WHAT
  /// the product is -- stripped out before comparing product-name tokens
  /// so two products don't look "similar" just because they're both
  /// canned, or both use a generic descriptor like "original"/"premium".
  /// "sauce" is included here (rather than left as a generic token) since
  /// the SPECIFIC sauce types that actually matter are already captured
  /// as two-word phrases in [_flavorKeywords] (e.g. "tomato sauce") --
  /// letting the bare word "sauce" match on its own would treat any two
  /// differently-sauced products in a category as "relevant" to each
  /// other, which is too broad.
  static const List<String> _genericStopwords = [
    'canned', 'can', 'in', 'of', 'the', 'and', 'with', 'a', 'an',
    'original', 'classic', 'premium', 'select', 'choice', 'natural',
    'flavor', 'flavored', 'style', 'brand', 'new', 'net', 'wt', 'pack',
    'sauce',
  ];

  /// Every curated keyword (type OR flavor) found in [product]'s name,
  /// e.g. "Century Tuna Flakes in Tomato Sauce" -> {'tuna', 'tomato
  /// sauce'}.
  Set<String> _curatedCharacteristics(Product product) {
    final name = product.name.toLowerCase();
    return [..._typeKeywords, ..._flavorKeywords]
        .where((k) => name.contains(k))
        .toSet();
  }

  /// Fallback for categories the curated lists don't cover (fruits,
  /// vegetables, condiments, etc.): the set of meaningful words left in
  /// the product name after removing the brand name and packaging/filler
  /// words. "Del Monte Mixed Fruit Cocktail in Syrup" (brand "Del Monte")
  /// -> {'mixed', 'fruit', 'cocktail', 'syrup'}.
  Set<String> _genericNameTokens(Product product) {
    final brandWords = product.brand
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty)
        .toSet();

    return product.name
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length >= 3)
        .where((w) => !brandWords.contains(w))
        .where((w) => !_genericStopwords.contains(w))
        .toSet();
  }

  /// The full set of "what makes this product what it is" tokens for
  /// [product]: curated type/flavor keyword hits, plus generic name
  /// tokens as a catch-all. Combining both (rather than one OR the
  /// other) means a curated protein match ("sardines") AND a curated or
  /// generic flavor match ("tomato sauce") both count toward relevance.
  Set<String> _characteristicTokens(Product product) {
    return {
      ..._curatedCharacteristics(product),
      ..._genericNameTokens(product),
    };
  }

  /// True if [candidate] shares at least one meaningful characteristic
  /// (protein/type, flavor/prep, or -- for uncovered categories --
  /// generic name token) with [scanned]. This is the sole gate deciding
  /// whether [candidate] enters the comparison set; it does not affect
  /// where it ends up ranked once included.
  bool _isRelevantCandidate(Product scanned, Product candidate) {
    final scannedTokens = _characteristicTokens(scanned);
    final candidateTokens = _characteristicTokens(candidate);
    if (scannedTokens.isEmpty || candidateTokens.isEmpty) return false;
    return scannedTokens.intersection(candidateTokens).isNotEmpty;
  }
}