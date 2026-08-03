import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

/// Fills in nutrition data (nutritionalFacts, allergens, ingredients) that
/// `fda_products` doesn't carry, by reading it from `product_nutrition_data`
/// -- Firestore, populated by the OCR + Gemini extraction pipeline (either
/// the initial dev-phase catalog population, or an admin-approved user
/// report), not by any external API.
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
  static const String _dataCollection = 'product_nutrition_data';

  // ─── Main entry point ──────────────────────────────────────────────────
  /// Returns [product] with nutritionalFacts/allergens/ingredients filled in
  /// from `product_nutrition_data`, merged onto the FDA-sourced fields
  /// already on [product] (id, imageUrl, fdaStatus, cprNumber, category,
  /// etc. are always preserved). If no record exists yet for this product,
  /// returns [product] unchanged -- nutrition fields simply stay at their
  /// zero/empty defaults (see NutritionalFacts.hasNutritionData /
  /// core/utils/nutrition_availability.dart). Never throws: enrichment
  /// failures shouldn't break a product fetch.
  Future<Product> enrichProduct(Product product) async {
    if (product.name.isEmpty) return product;

    try {
      final doc = await _db.collection(_dataCollection).doc(product.id).get();
      if (!doc.exists) return product;
      return _mergeDataDoc(product, doc.data()!);
    } catch (_) {
      // Read failure -- fail safe, return the product unenriched rather
      // than throwing and breaking the whole product fetch.
      return product;
    }
  }

  Product _mergeDataDoc(Product product, Map<String, dynamic> doc) {
    double n(String key) => (doc[key] as num? ?? 0).toDouble();
    final allergens = List<String>.from(doc['allergens'] as List? ?? []);
    final ingredients = List<String>.from(doc['ingredients'] as List? ?? []);

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
      ingredients: ingredients,
    );
  }
}
