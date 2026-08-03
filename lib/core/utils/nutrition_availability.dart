// lib/core/utils/nutrition_availability.dart
//
// Detection-only gate used by screens/orchestration code BEFORE calling into
// the health-advisory / ranking / comparison backend (WhoCalculator,
// GeminiAdvisoryService, ProductRankingService, ProductComparisonService).
//
// Those pipelines assume every nutrient field on a Product is real. A
// product whose nutritionalFacts haven't been extracted yet (no matching
// `product_nutrition_data` record) has all-zero values (see
// NutritionalFacts.hasNutritionData in
// models/product_model.dart) that would otherwise silently score as
// "Suitable" / rank as the healthiest option / compare as identical to
// products that actually have 0g of everything -- which is wrong, not just
// incomplete.
//
// This file only detects that condition. It does not wrap, modify, or
// change the output of WhoCalculator / GeminiAdvisoryService /
// ProductRankingService / ProductComparisonService in any way -- callers
// check this FIRST and simply don't invoke that backend at all when it
// returns false, showing a "data unavailable" message instead.

import '../../models/product_model.dart';

class NutritionAvailability {
  NutritionAvailability._();

  /// True only if [product] has real nutrition data (extracted via the OCR +
  /// Gemini pipeline and served from `product_nutrition_data`) -- i.e. it's
  /// safe to feed into WhoCalculator / GeminiAdvisoryService /
  /// ProductRankingService / ProductComparisonService.
  static bool isAvailable(Product product) =>
      product.nutritionalFacts.hasNutritionData;

  /// True only if EVERY product in [products] has real nutrition data.
  /// Ranking and comparison operate on the whole list at once (relative
  /// scoring, comparison matrices), so a single product with unavailable
  /// data would silently skew every other product's result too -- gate the
  /// whole list, not just the product missing data.
  static bool allAvailable(Iterable<Product> products) =>
      products.every(isAvailable);

  /// The subset of [products] that do NOT have nutrition data -- useful for
  /// building a message that names which product(s) are missing data.
  static List<Product> unavailableAmong(Iterable<Product> products) =>
      products.where((p) => !isAvailable(p)).toList();
}
