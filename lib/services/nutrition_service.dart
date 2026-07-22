import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

/// Fills in nutrition data (nutritionalFacts, allergens, ingredients) that
/// `fda_products` doesn't carry, by looking it up on Open Food Facts and
/// caching the result in Firestore -- so OFF only ever gets called once per
/// product, not on every scan/view.
///
/// This is called from FirestoreProductRepository, so every screen that
/// fetches a Product (detail, favorites, history, compare, ranking, scan)
/// gets nutrition-enriched products consistently, without each screen having
/// to remember to call this itself.
class NutritionService {
  static final NutritionService _instance = NutritionService._internal();
  factory NutritionService() => _instance;
  NutritionService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _cacheCollection = 'nutrition_cache';

  // Packaged-food nutrition facts don't change day to day, so a positive
  // cache hit (found: true) is treated as good indefinitely -- no TTL, no
  // repeat API calls for a product OFF already answered for. A "not found"
  // result gets a much shorter recheck window, since OFF's catalog grows
  // over time and a product missing today may exist there later.
  static const Duration _notFoundRecheckDuration = Duration.zero;

  // ─── Main entry point ──────────────────────────────────────────────────
  /// Returns [product] with nutritionalFacts/allergens/ingredients filled in
  /// from cache or Open Food Facts, merged onto the FDA-sourced fields
  /// already on [product] (id, imageUrl, fdaStatus, cprNumber, category,
  /// etc. are always preserved). If nothing is found, returns [product]
  /// unchanged -- nutrition fields simply stay at their zero/empty defaults.
  /// Never throws: enrichment failures shouldn't break a product fetch.
  Future<Product> enrichProduct(Product product) async {
    if (product.name.isEmpty) return product;

    final docRef = _db.collection(_cacheCollection).doc(product.id);

    try {
      final cached = await docRef.get();
      if (cached.exists) {
        final data = cached.data()!;
        if (data['found'] == true) {
          return _mergeCacheDoc(product, data);
        }
        // found == false: only skip the API call if the negative result is
        // still within its recheck window.
        final cachedAt = (data['cached_at'] as Timestamp?)?.toDate();
        final stillFresh = cachedAt != null &&
            DateTime.now().difference(cachedAt) < _notFoundRecheckDuration;
        if (stillFresh) return product;
      }
    } catch (_) {
      // Cache read failure -- fall through and try the API directly.
    }

    final fetched = await _fetchFromOpenFoodFacts(product.name, product.brand);

    if (fetched == null) {
      await _saveNotFound(docRef);
      return product;
    }

    await _saveToCache(docRef, fetched);
    return product.copyWith(
      nutritionalFacts: fetched.nutritionalFacts,
      allergens: fetched.allergens,
      ingredients: fetched.ingredients,
    );
  }

  // ─── Open Food Facts API ────────────────────────────────────────────────
  Future<_NutritionResult?> _fetchFromOpenFoodFacts(
    String productName,
    String brand,
  ) async {
    // Build search term list, avoiding redundant brand duplication (e.g. "Purefoods Purefoods Luncheon Meat")
    final termsToTry = <String>[];
    
    if (brand.isNotEmpty && productName.isNotEmpty) {
      if (productName.toLowerCase().contains(brand.toLowerCase())) {
        termsToTry.add(productName);
      } else {
        termsToTry.add('$brand $productName');
        termsToTry.add(productName);
      }
    } else if (productName.isNotEmpty) {
      termsToTry.add(productName);
    } else if (brand.isNotEmpty) {
      termsToTry.add(brand);
    }

    List? products;
    for (var searchTerm in termsToTry) {
      try {
        final encoded = Uri.encodeComponent(searchTerm);
        final url = Uri.parse(
          'https://world.openfoodfacts.org/cgi/search.pl'
          '?search_terms=$encoded'
          '&search_simple=1'
          '&action=process'
          '&json=1'
          '&fields=id,product_name,brands,serving_size,nutriments,allergens_tags,ingredients_text_en,ingredients_text'
          '&page_size=10',
        );

        final response = await http
            .get(url, headers: {'User-Agent': 'CLARO-App/1.0'})
            .timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) continue;

        final data = json.decode(response.body) as Map<String, dynamic>;
        final fetchedProducts = data['products'] as List?;
        if (fetchedProducts != null && fetchedProducts.isNotEmpty) {
          products = fetchedProducts;
          break;
        }
      } catch (_) {
        continue;
      }
    }

    if (products == null || products.isEmpty) return null;

    // Find the product in the returned list that has valid nutriments data
    Map<String, dynamic>? selectedProduct;
    final targetNorm = '$brand $productName'.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    for (var item in products) {
      final pMap = item as Map<String, dynamic>;
      final nutriments = pMap['nutriments'] as Map<String, dynamic>? ?? {};
      if (nutriments.isEmpty) continue;

      final pName = (pMap['product_name'] ?? '').toString();
      final pBrand = (pMap['brands'] ?? '').toString();
      final full = '$pBrand $pName'.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

      if (full.contains(targetNorm) || targetNorm.contains(pName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''))) {
        selectedProduct = pMap;
        break;
      }
    }

    selectedProduct ??= (products.first as Map<String, dynamic>);
    final p = selectedProduct;
    final nutriments = p['nutriments'] as Map<String, dynamic>? ?? {};

      // Whether ANY nutrient value was actually present in the OFF response
      // (as opposed to just defaulted to 0), so we don't report/cache a
      // product as having nutrition data when it doesn't.
      bool sawAnyValue = false;

      double? rawNum(String key) {
        final v = nutriments[key];
        if (v == null) return null;
        final parsed = v is num ? v.toDouble() : double.tryParse(v.toString());
        if (parsed != null) sawAnyValue = true;
        return parsed;
      }

      // OFF only populates "*_serving" keys when the product's serving size
      // was known at entry time -- a large share of products (especially
      // less-curated regional entries) only ever get the near-universal
      // "*_100g" keys filled in. Previously this code read *_serving only,
      // so those products silently came back as all-zero "found" data.
      //
      // Fix: fall back to the *_100g figure, scaled by the product's actual
      // serving size, so the value stored still means "per serving" like the
      // rest of the app (NutritionAvailability / nutrition_calculator.dart)
      // assumes. If no serving size is known at all, treat "100g" itself as
      // the serving (a common convention) instead of guessing.
      final servingSizeRaw = (p['serving_size'] ?? '') as String;
      final parsedServingGrams = _parseGrams(servingSizeRaw);
      final effectiveServingSize =
          servingSizeRaw.isNotEmpty ? servingSizeRaw : '100g';
      final scaleTo100g =
          (parsedServingGrams != null && parsedServingGrams > 0)
              ? parsedServingGrams / 100.0
              : 1.0;

      double valueFor(String key) {
        final perServing = rawNum('${key}_serving');
        if (perServing != null) return perServing;
        final per100g = rawNum('${key}_100g');
        if (per100g != null) return per100g * scaleTo100g;
        return 0.0;
      }

      // Parse allergens
      final allergenTagsRaw = p['allergens_tags'] as List? ?? [];
      final allergens = allergenTagsRaw
          .map((e) => e.toString().replaceAll('en:', '').replaceAll('-', ' '))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => e[0].toUpperCase() + e.substring(1))
          .toList();

      // Parse ingredients text
      final ingredientsText =
          (p['ingredients_text_en'] ?? p['ingredients_text'] ?? '') as String;
      final ingredientsList = ingredientsText.isNotEmpty
          ? ingredientsText
              .split(RegExp(r'[,;]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];

      final nutritionalFacts = NutritionalFacts(
        servingSize: effectiveServingSize,
        caloriesKcal: valueFor('energy-kcal'),
        proteinG: valueFor('proteins'),
        carbsG: valueFor('carbohydrates'),
        totalFatG: valueFor('fat'),
        saturatedFatG: valueFor('saturated-fat'),
        transFatG: valueFor('trans-fat'),
        sodiumMg: valueFor('sodium') * 1000, // OFF returns sodium in g
        potassiumMg: valueFor('potassium') * 1000,
        calciumMg: valueFor('calcium') * 1000,
        ironMg: valueFor('iron') * 1000,
        fiberG: valueFor('fiber'),
        sugarsG: valueFor('sugars'),
        addedSugarsG: valueFor('added-sugars'),
        // Only claim "real data" if we actually parsed at least one
        // nutrient value -- a name/brand match with an empty nutriments
        // object (OFF returns plenty of those) is NOT nutrition data, and
        // must not be cached as if it were (see NutritionAvailability).
        hasNutritionData: sawAnyValue,
      );

      if (!sawAnyValue) return null;

      return _NutritionResult(
        nutritionalFacts: nutritionalFacts,
        allergens: allergens,
        ingredients: ingredientsList,
      );
  }

  /// Extracts a gram quantity from an OFF serving_size string, e.g.
  /// "56g", "56 g (Approx. 1/3 cup)" -> 56.0. Mirrors the parsing already
  /// used by core/utils/nutrition_calculator.dart so both stay consistent.
  double? _parseGrams(String servingSize) {
    if (servingSize.isEmpty) return null;
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*[gG]').firstMatch(servingSize);
    if (match == null) return null;
    return double.tryParse(match.group(1) ?? '');
  }

  // ─── Firestore cache ─────────────────────────────────────────────────────
  Future<void> _saveToCache(
    DocumentReference<Map<String, dynamic>> docRef,
    _NutritionResult result,
  ) async {
    try {
      final nf = result.nutritionalFacts;
      await docRef.set({
        'found': true,
        'serving_size': nf.servingSize,
        'calories_kcal': nf.caloriesKcal,
        'protein_g': nf.proteinG,
        'carbs_g': nf.carbsG,
        'fat_total_g': nf.totalFatG,
        'fat_saturated_g': nf.saturatedFatG,
        'fat_trans_g': nf.transFatG,
        'sodium_mg': nf.sodiumMg,
        'potassium_mg': nf.potassiumMg,
        'calcium_mg': nf.calciumMg,
        'iron_mg': nf.ironMg,
        'fiber_g': nf.fiberG,
        'sugars_g': nf.sugarsG,
        'added_sugars_g': nf.addedSugarsG,
        'allergens': result.allergens,
        'ingredients': result.ingredients.join(', '),
        'source': 'open_food_facts',
        'cached_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Cache write failure is non-fatal -- the caller still gets the data
      // for this call, it'll just re-hit the API next time.
    }
  }

  Future<void> _saveNotFound(
    DocumentReference<Map<String, dynamic>> docRef,
  ) async {
    try {
      await docRef.set({
        'found': false,
        'cached_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Non-fatal.
    }
  }

  Product _mergeCacheDoc(Product product, Map<String, dynamic> doc) {
    double n(String key) => (doc[key] as num? ?? 0).toDouble();
    final allergens = List<String>.from(doc['allergens'] as List? ?? []);
    final ingText = (doc['ingredients'] as String?) ?? '';
    final ingList = ingText.isNotEmpty
        ? ingText.split(',').map((e) => e.trim()).toList()
        : <String>[];

    return product.copyWith(
      nutritionalFacts: NutritionalFacts(
        servingSize: (doc['serving_size'] as String?) ?? '',
        caloriesKcal: n('calories_kcal'),
        proteinG: n('protein_g'),
        carbsG: n('carbs_g'),
        totalFatG: n('fat_total_g'),
        saturatedFatG: n('fat_saturated_g'),
        transFatG: n('fat_trans_g'),
        sodiumMg: n('sodium_mg'),
        potassiumMg: n('potassium_mg'),
        calciumMg: n('calcium_mg'),
        ironMg: n('iron_mg'),
        fiberG: n('fiber_g'),
        sugarsG: n('sugars_g'),
        addedSugarsG: n('added_sugars_g'),
        hasNutritionData: true,
      ),
      allergens: allergens,
      ingredients: ingList,
    );
  }
}

class _NutritionResult {
  final NutritionalFacts nutritionalFacts;
  final List<String> allergens;
  final List<String> ingredients;

  _NutritionResult({
    required this.nutritionalFacts,
    required this.allergens,
    required this.ingredients,
  });
}