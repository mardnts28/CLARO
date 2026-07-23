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
    final rawAlternatives = await _productRepository.getSimilarProducts(
      scannedProduct.category,
      excludeId: scannedProduct.id,
    );

    // Catalog can contain literal duplicate entries (same product entered
    // twice under different Firestore doc ids) -- collapse those before
    // scoring so a duplicate can never occupy two of the comparison slots.
    final alternatives = _dedupeByIdentity(rawAlternatives);

    // Score every candidate, then only let candidates through that show an
    // ACTUAL similarity signal (matching type/flavor -- see _typeScore).
    // Two products merely sharing a category (e.g. "Canned Green Peas" and
    // "Canned Mixed Fruit" both being "Canned Goods") is not similarity on
    // its own; without this gate, a same-category-but-unrelated product
    // could still slip into the top 4 on brand/nutrient coincidence alone.
    final scoredAlternatives = alternatives
        .map((p) => (
              product: p,
              typeScore: _typeScore(scannedProduct, p),
              totalScore: _calculateSimilarityScore(scannedProduct, p),
            ))
        .where((s) => s.typeScore > 0)
        .toList();

    // Sort by overall similarity score (highest first)
    scoredAlternatives.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    // Take up to 4 most similar products -- fewer if fewer genuinely
    // similar alternatives exist. It's fine (and expected) for the final
    // comparison set to end up smaller than kMaxProductsPerRanking.
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

  /// Curated type keywords for KINDS of product that are common enough (and
  /// short/ambiguous enough as bare words) to deserve an explicit list --
  /// e.g. tuna vs. sardines within "Canned Fish", or chicken vs. beef
  /// within "Instant Noodles". Checked against the product NAME (not
  /// Product.variant): the Firestore-backed catalog
  /// (product_repository.dart's _productFromDoc) never populates `variant`
  /// for real products, so the name is the only field that actually
  /// carries this information today.
  ///
  /// This list intentionally does NOT try to cover every category in the
  /// catalog (fruits, vegetables, snacks, etc.) -- that doesn't scale and
  /// silently leaves new categories with zero type signal, which is
  /// exactly how an unrelated product (e.g. "Canned Green Peas" showing up
  /// as a match for "Canned Mixed Fruit") could previously tie with a
  /// genuinely similar one on nutrition/brand alone. _genericTypeTokens
  /// below is the fallback that covers everything else.
  static const List<String> _typeKeywords = [
    // Canned fish / meats
    'tuna', 'sardines', 'sardine', 'mackerel', 'bangus', 'milkfish',
    'corned beef', 'luncheon meat', 'meatloaf', 'vienna sausage', 'hotdog',
    // Common flavor/protein descriptors (noodles, snacks, etc.)
    'chicken', 'beef', 'pork', 'seafood', 'shrimp', 'squid',
  ];

  /// Words that describe packaging/preparation rather than WHAT the
  /// product is -- stripped out before comparing product-name tokens so
  /// two products don't look "similar" just because they're both canned,
  /// or both use a generic descriptor like "original"/"premium".
  static const List<String> _genericStopwords = [
    'canned', 'can', 'in', 'of', 'the', 'and', 'with', 'a', 'an',
    'original', 'classic', 'premium', 'select', 'choice', 'natural',
    'flavor', 'flavored', 'style', 'brand', 'new', 'net', 'wt', 'pack',
  ];

  /// Every curated type keyword found in [product]'s name, e.g. "Century
  /// Tuna Flakes in Oil" -> {'tuna'}. A product can match more than one
  /// keyword; any keyword shared between two products counts as a type
  /// match.
  Set<String> _productTypes(Product product) {
    final name = product.name.toLowerCase();
    return _typeKeywords.where((k) => name.contains(k)).toSet();
  }

  /// Generic fallback for "what kind of product is this" when no curated
  /// keyword applies (e.g. fruits, vegetables, condiments): the set of
  /// meaningful words left in the product name after removing the brand
  /// name and packaging/stopwords. "Del Monte Mixed Fruit Cocktail in
  /// Syrup" (brand "Del Monte") -> {'mixed', 'fruit', 'cocktail', 'syrup'}.
  Set<String> _genericTypeTokens(Product product) {
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

  /// How similar [a] and [b] are in terms of what KIND of product they are
  /// (category subtype/flavor), independent of brand or nutrition. This is
  /// the gate compareWithAlternatives uses to decide whether a candidate
  /// belongs in the comparison set at all -- 0 means "no real similarity
  /// found", regardless of any brand/nutrient coincidence.
  ///
  /// Prefers the curated keyword match (precise, handles short/ambiguous
  /// words like "tuna"); falls back to generic name-token overlap (Jaccard
  /// similarity) for every category the curated list doesn't cover, e.g.
  /// "Mixed Fruit" vs. "Fruit Cocktail" share 'fruit' -> partial match,
  /// while "Mixed Fruit" vs. "Green Peas" share nothing -> 0.
  double _typeScore(Product a, Product b) {
    final aTypes = _productTypes(a);
    final bTypes = _productTypes(b);
    if (aTypes.isNotEmpty && bTypes.isNotEmpty) {
      return aTypes.intersection(bTypes).isNotEmpty ? 100 : 0;
    }

    final aTokens = _genericTypeTokens(a);
    final bTokens = _genericTypeTokens(b);
    if (aTokens.isEmpty || bTokens.isEmpty) return 0;

    final overlap = aTokens.intersection(bTokens).length;
    if (overlap == 0) return 0;

    final union = aTokens.union(bTokens).length;
    return 100 * (overlap / union);
  }

  /// Calculates a similarity score between two products.
  /// Higher score = more similar.
  /// Scoring factors:
  /// - Matching TYPE/flavor (see _typeScore): up to 100 points -- dominant
  ///   factor. A same-brand product of a DIFFERENT type (e.g. brand's
  ///   corned beef vs. brand's tuna) should not outrank a different-brand
  ///   product of the SAME type (e.g. a competitor's tuna).
  /// - Same brand: +15 points -- a tie-breaker among same-type products,
  ///   not the deciding factor.
  /// - Similar sodium content (within 50mg): +20 points
  /// - Similar sugar content (within 2g): +15 points
  /// - Similar saturated fat (within 1g): +10 points
  /// - Same variant keywords: +5 points per matching keyword (rarely
  ///   fires today since Product.variant is usually empty -- see above)
  double _calculateSimilarityScore(Product a, Product b) {
    double score = _typeScore(a, b);

    // Brand match -- tie-breaker among products of the same type, not the
    // deciding factor.
    if (a.brand == b.brand) {
      score += 15;
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