// lib/data/models/product_extraction_result.dart
//
// Structured output of ProductExtractionService -- the OCR + Gemini
// extraction pipeline's result for one front+back photo pair. This is a
// plain data holder: it doesn't know about Firestore or the report/approval
// flow. Callers (the submission screen in Phase 3, the admin approval step
// in Phase 4/6, or tools/bulk-import in Phase 2b) decide what to do with it.
//
// Field names deliberately mirror NutritionService's `product_nutrition_data`
// document shape (calories_kcal, fat_total_g, etc.) so mapping this result
// into that collection later is a direct field-for-field copy, not a
// translation step.
class ProductExtractionResult {
  final String brand;
  final String productName;
  final String size;
  final String servingSize;
  final List<String> ingredients;
  final List<String> allergens;
  final ExtractedNutrition nutrition;

  /// True only if Gemini actually found and read a nutrition table --
  /// mirrors NutritionalFacts.hasNutritionData's "don't trust zeros" rule
  /// from the OFF-era code. A product photographed with an unreadable/
  /// missing nutrition panel should NOT silently look like "0 calories,
  /// 0g everything".
  final bool hasNutritionData;

  /// Free-text notes from Gemini about anything it wasn't confident about
  /// (blurry field, ambiguous serving size, etc.) -- surfaced in the admin
  /// review UI so a human knows what to double-check against the photo
  /// rather than trusting every field equally.
  final String confidenceNotes;

  const ProductExtractionResult({
    required this.brand,
    required this.productName,
    required this.size,
    required this.servingSize,
    required this.ingredients,
    required this.allergens,
    required this.nutrition,
    required this.hasNutritionData,
    required this.confidenceNotes,
  });

  factory ProductExtractionResult.empty({String reason = ''}) {
    return ProductExtractionResult(
      brand: '',
      productName: '',
      size: '',
      servingSize: '',
      ingredients: const [],
      allergens: const [],
      nutrition: const ExtractedNutrition(),
      hasNutritionData: false,
      confidenceNotes: reason,
    );
  }

  /// Firestore-doc-shaped map matching `product_nutrition_data`'s existing
  /// field names (see NutritionService._mergeDataDoc) -- callers writing
  /// this result to that collection can spread this directly rather than
  /// re-mapping field names by hand.
  Map<String, dynamic> toNutritionDataMap() => {
        'serving_size': servingSize,
        'calories_kcal': nutrition.caloriesKcal,
        'protein_g': nutrition.proteinG,
        'carbs_g': nutrition.carbsG,
        'fat_total_g': nutrition.totalFatG,
        'fat_saturated_g': nutrition.saturatedFatG,
        'fat_trans_g': nutrition.transFatG,
        'sodium_mg': nutrition.sodiumMg,
        'potassium_mg': nutrition.potassiumMg,
        'calcium_mg': nutrition.calciumMg,
        'iron_mg': nutrition.ironMg,
        'fiber_g': nutrition.fiberG,
        'sugars_g': nutrition.sugarsG,
        'added_sugars_g': nutrition.addedSugarsG,
        'allergens': allergens,
        'ingredients': ingredients,
      };

  /// Nested-map shape used to embed this result under a report document's
  /// `extractedData` field (see ReportModel) -- this is what the admin
  /// dashboard's review UI (Phase 4) reads and lets a reviewer correct
  /// before approval.
  Map<String, dynamic> toReportExtractedDataMap() => {
        'brand': brand,
        'productName': productName,
        'size': size,
        'servingSize': servingSize,
        'ingredients': ingredients,
        'allergens': allergens,
        'nutrition': {
          'calories_kcal': nutrition.caloriesKcal,
          'protein_g': nutrition.proteinG,
          'carbs_g': nutrition.carbsG,
          'fat_total_g': nutrition.totalFatG,
          'fat_saturated_g': nutrition.saturatedFatG,
          'fat_trans_g': nutrition.transFatG,
          'sodium_mg': nutrition.sodiumMg,
          'potassium_mg': nutrition.potassiumMg,
          'calcium_mg': nutrition.calciumMg,
          'iron_mg': nutrition.ironMg,
          'fiber_g': nutrition.fiberG,
          'sugars_g': nutrition.sugarsG,
          'added_sugars_g': nutrition.addedSugarsG,
        },
        'hasNutritionData': hasNutritionData,
        'confidenceNotes': confidenceNotes,
      };
}

class ExtractedNutrition {
  final double caloriesKcal;
  final double proteinG;
  final double carbsG;
  final double totalFatG;
  final double saturatedFatG;
  final double transFatG;
  final double sodiumMg;
  final double potassiumMg;
  final double calciumMg;
  final double ironMg;
  final double fiberG;
  final double sugarsG;
  final double addedSugarsG;

  const ExtractedNutrition({
    this.caloriesKcal = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.totalFatG = 0,
    this.saturatedFatG = 0,
    this.transFatG = 0,
    this.sodiumMg = 0,
    this.potassiumMg = 0,
    this.calciumMg = 0,
    this.ironMg = 0,
    this.fiberG = 0,
    this.sugarsG = 0,
    this.addedSugarsG = 0,
  });
}