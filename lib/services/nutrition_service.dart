import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import 'product_db_service.dart';

class NutritionService {
  static final NutritionService _instance = NutritionService._internal();
  factory NutritionService() => _instance;
  NutritionService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _cacheCollection = 'nutrition_cache';
  static const Duration _cacheDuration = Duration(hours: 24);

  // ─── Main entry point ──────────────────────────────────────────────────
  /// Returns a Product for the given product name.
  /// 1. Check Firestore cache (24hr)
  /// 2. Query Open Food Facts API
  /// 3. Fall back to local ProductDbService
  Future<Product?> getProductByName(String productName) async {
    final normalizedName = productName.trim().toLowerCase();

    // Step 1: Check Firestore cache
    final cached = await _getFromCache(normalizedName);
    if (cached != null) return cached;

    // Step 2: Try Open Food Facts
    final fromApi = await _fetchFromOpenFoodFacts(productName);
    if (fromApi != null) {
      await _saveToCache(normalizedName, fromApi);
      return fromApi;
    }

    // Step 3: Fallback to local Ever Plus / ProductDbService
    return _getFromLocalDb(productName);
  }

  // ─── Step 1: Firestore cache ────────────────────────────────────────────
  Future<Product?> _getFromCache(String normalizedName) async {
    try {
      final query = await _db
          .collection(_cacheCollection)
          .where('product_name', isEqualTo: normalizedName)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final doc = query.docs.first.data();
      final cachedAt = (doc['cached_at'] as Timestamp?)?.toDate();
      if (cachedAt == null ||
          DateTime.now().difference(cachedAt) > _cacheDuration) {
        // Cache expired — delete it
        await query.docs.first.reference.delete();
        return null;
      }

      return _productFromCacheDoc(doc);
    } catch (e) {
      // Cache read failure — continue to API
      return null;
    }
  }

  // ─── Step 2: Open Food Facts API ────────────────────────────────────────
  Future<Product?> _fetchFromOpenFoodFacts(String productName) async {
    try {
      final encoded = Uri.encodeComponent(productName);
      final url = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl'
        '?search_terms=$encoded'
        '&search_simple=1'
        '&action=process'
        '&json=1'
        '&page_size=1',
      );

      final response = await http
          .get(url, headers: {'User-Agent': 'CLARO-App/1.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final products = data['products'] as List?;
      if (products == null || products.isEmpty) return null;

      final p = products.first as Map<String, dynamic>;
      final nutriments = p['nutriments'] as Map<String, dynamic>? ?? {};

      double safeNum(String key) {
        final v = nutriments[key];
        if (v == null) return 0.0;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString()) ?? 0.0;
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

      final name = (p['product_name'] ?? productName) as String;
      final brand = (p['brands'] ?? '') as String;
      final servingSize = (p['serving_size'] ?? '') as String;

      return Product(
        id: (p['id'] ?? name.toLowerCase().replaceAll(' ', '_')) as String,
        name: name,
        brand: brand,
        nutritionalFacts: NutritionalFacts(
          servingSize: servingSize,
          caloriesKcal: safeNum('energy-kcal_serving'),
          proteinG: safeNum('proteins_serving'),
          carbsG: safeNum('carbohydrates_serving'),
          totalFatG: safeNum('fat_serving'),
          saturatedFatG: safeNum('saturated-fat_serving'),
          transFatG: safeNum('trans-fat_serving'),
          sodiumMg: safeNum('sodium_serving') * 1000, // OFF returns in g
          potassiumMg: safeNum('potassium_serving') * 1000,
          calciumMg: safeNum('calcium_serving') * 1000,
          ironMg: safeNum('iron_serving') * 1000,
          fiberG: safeNum('fiber_serving'),
          sugarsG: safeNum('sugars_serving'),
          addedSugarsG: safeNum('added-sugars_serving'),
        ),
        allergens: allergens,
        ingredients: ingredientsList,
      );
    } catch (e) {
      return null;
    }
  }

  // ─── Step 3: Local fallback ─────────────────────────────────────────────
  Product? _getFromLocalDb(String productName) {
    final lower = productName.toLowerCase();
    try {
      return ProductDbService().getAllProducts().firstWhere(
            (p) => p.name.toLowerCase().contains(lower) ||
                lower.contains(p.name.toLowerCase().split(' ').first.toLowerCase()),
          );
    } catch (_) {
      return null;
    }
  }

  // ─── Save to Firestore cache ─────────────────────────────────────────────
  Future<void> _saveToCache(String normalizedName, Product product) async {
    try {
      final nf = product.nutritionalFacts;
      await _db.collection(_cacheCollection).add({
        'product_name': normalizedName,
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
        'allergens': product.allergens,
        'ingredients': product.ingredients.join(', '),
        'source': 'open_food_facts',
        'cached_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Cache write failure is non-fatal
    }
  }

  // ─── Build Product from cache document ──────────────────────────────────
  Product _productFromCacheDoc(Map<String, dynamic> doc) {
    double n(String key) => (doc[key] as num? ?? 0).toDouble();
    final allergens = List<String>.from(doc['allergens'] as List? ?? []);
    final ingText = (doc['ingredients'] as String?) ?? '';
    final ingList = ingText.isNotEmpty
        ? ingText.split(',').map((e) => e.trim()).toList()
        : <String>[];

    return Product(
      id: doc['product_name'] as String,
      name: doc['product_name'] as String,
      brand: '',
      nutritionalFacts: NutritionalFacts(
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
      ),
      allergens: allergens,
      ingredients: ingList,
    );
  }
}
