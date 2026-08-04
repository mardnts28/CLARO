import 'dart:ui';
import '../data/models/health_profile.dart';
import '../core/utils/nutrition_calculator.dart';

/// One entry of a product's `available_sizes` array, pairing a package
/// size (in grams) with the Cloudinary photo of THAT specific package,
/// when one has been uploaded. [imageUrl] is null for sizes that don't
/// have their own photo yet -- callers should fall back to
/// [Product.imageUrl] (the product's default/primary image) in that case.
class ProductSizeOption {
  final double sizeGrams;
  final String? imageUrl;

  const ProductSizeOption({required this.sizeGrams, this.imageUrl});
}

class Product {
  final String id;
  final String name;
  final String brand;
  final String variant;
  final String category;
  final String imageUrl;
  final String fdaStatus;            // 'ACTIVE', 'EXPIRED', 'UNVERIFIED'
  final String fdaRegistrationNumber;
  final String fdaValidityDate;      // NEW: e.g. "2027-12-31"
  final String fdaManufacturer;      // NEW
  final String cprNumber;            // NEW: Certificate of Product Registration
  final List<String> allergens;
  final List<String> ingredients;
  final String servingInstructions;
  final List<double> availableSizes;
  // Size -> image pairing parsed from the same `available_sizes` Firestore
  // field as [availableSizes] (see product_repository.dart's
  // _productFromDoc). Kept as a separate list rather than folded into
  // [availableSizes] so every existing caller of the plain-number list
  // (nutrition scaling, etc.) keeps working unchanged.
  final List<ProductSizeOption> sizeOptions;
  final NutritionalFacts nutritionalFacts;

  Product({
    required this.id,
    required this.name,
    required this.brand,
    this.variant = '',
    this.category = '',
    this.imageUrl = '',
    this.fdaStatus = 'UNVERIFIED',
    this.fdaRegistrationNumber = '',
    this.fdaValidityDate = '',
    this.fdaManufacturer = '',
    this.cprNumber = '',
    this.allergens = const [],
    this.ingredients = const [],
    this.servingInstructions = '',
    this.availableSizes = const [],
    this.sizeOptions = const [],
    required this.nutritionalFacts,
  });

  /// Image to show for [sizeGrams], falling back to [imageUrl] (the
  /// product's default photo) when that size has no photo of its own yet.
  String imageUrlForSize(double sizeGrams) {
    for (final option in sizeOptions) {
      if (option.sizeGrams == sizeGrams && (option.imageUrl?.isNotEmpty ?? false)) {
        return option.imageUrl!;
      }
    }
    return imageUrl;
  }

  /// Returns a copy with the given fields replaced. Used to merge data from
  /// a secondary source (e.g. Open Food Facts nutrition enrichment) onto a
  /// product that already carries FDA-sourced fields (id, imageUrl,
  /// fdaStatus, cprNumber, etc.) without discarding those fields.
  Product copyWith({
    String? id,
    String? name,
    String? brand,
    String? variant,
    String? category,
    String? imageUrl,
    String? fdaStatus,
    String? fdaRegistrationNumber,
    String? fdaValidityDate,
    String? fdaManufacturer,
    String? cprNumber,
    List<String>? allergens,
    List<String>? ingredients,
    String? servingInstructions,
    List<double>? availableSizes,
    List<ProductSizeOption>? sizeOptions,
    NutritionalFacts? nutritionalFacts,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      variant: variant ?? this.variant,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      fdaStatus: fdaStatus ?? this.fdaStatus,
      fdaRegistrationNumber: fdaRegistrationNumber ?? this.fdaRegistrationNumber,
      fdaValidityDate: fdaValidityDate ?? this.fdaValidityDate,
      fdaManufacturer: fdaManufacturer ?? this.fdaManufacturer,
      cprNumber: cprNumber ?? this.cprNumber,
      allergens: allergens ?? this.allergens,
      ingredients: ingredients ?? this.ingredients,
      servingInstructions: servingInstructions ?? this.servingInstructions,
      availableSizes: availableSizes ?? this.availableSizes,
      sizeOptions: sizeOptions ?? this.sizeOptions,
      nutritionalFacts: nutritionalFacts ?? this.nutritionalFacts,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class NutritionalFacts {
  final String servingSize;
  final String servingsPerContainer;
  final double caloriesKcal;
  final double proteinG;
  final double carbsG;
  final double totalFatG;
  final double saturatedFatG;
  final double transFatG;
  final double cholesterolMg;
  final double sodiumMg;
  final double potassiumMg;
  final double calciumMg;
  final double ironMg;
  final double fiberG;
  final double sugarsG;
  final double addedSugarsG;

  /// True once real nutrition data has been found for this product (from
  /// Open Food Facts, live or cached). False means the numeric fields above
  /// are just unset defaults (0), not a confirmed "this product has 0g of
  /// everything" -- the UI should show an "unavailable" state rather than
  /// the zero values in that case.
  final bool hasNutritionData;

  // Computed getters for UI rendering (retains compatibility with old fields)
  String get calories => '${caloriesKcal.toStringAsFixed(0)} kcal';
  String get totalFat => '${totalFatG.toStringAsFixed(1)}g';
  String get saturatedFat => '${saturatedFatG.toStringAsFixed(1)}g';
  String get transFat => '${transFatG.toStringAsFixed(1)}g';
  String get cholesterol => '${cholesterolMg.toStringAsFixed(0)}mg';
  String get sodium => '${sodiumMg.toStringAsFixed(0)}mg';
  String get totalCarbohydrate => '${carbsG.toStringAsFixed(1)}g';
  String get dietaryFiber => '${fiberG.toStringAsFixed(1)}g';
  String get sugars => '${sugarsG.toStringAsFixed(1)}g';
  String get protein => '${proteinG.toStringAsFixed(1)}g';

  NutritionalFacts({
    this.servingSize = '',
    this.servingsPerContainer = '',
    double? caloriesKcal,
    double? proteinG,
    double? carbsG,
    double? totalFatG,
    double? saturatedFatG,
    double? transFatG,
    double? cholesterolMg,
    double? sodiumMg,
    double? potassiumMg,
    double? calciumMg,
    double? ironMg,
    double? fiberG,
    double? sugarsG,
    double? addedSugarsG,

    // Legacy parameters to support existing database without editing 1500 lines:
    String? calories,
    String? totalFat,
    String? saturatedFat,
    String? transFat,
    String? cholesterol,
    String? sodium,
    String? totalCarbohydrate,
    String? dietaryFiber,
    String? sugars,
    String? protein,
    this.hasNutritionData = false,
  })  : caloriesKcal = caloriesKcal ?? (calories != null ? double.tryParse(calories.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0 : 0.0),
        proteinG = proteinG ?? (protein != null ? double.tryParse(protein.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0 : 0.0),
        carbsG = carbsG ?? (totalCarbohydrate != null ? double.tryParse(totalCarbohydrate.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0 : 0.0),
        totalFatG = totalFatG ?? (totalFat != null ? double.tryParse(totalFat.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0 : 0.0),
        saturatedFatG = saturatedFatG ?? (saturatedFat != null ? double.tryParse(saturatedFat.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0 : 0.0),
        transFatG = transFatG ?? (transFat != null ? double.tryParse(transFat.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0 : 0.0),
        cholesterolMg = cholesterolMg ?? (cholesterol != null ? double.tryParse(cholesterol.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0 : 0.0),
        sodiumMg = sodiumMg ?? (sodium != null ? double.tryParse(sodium.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0 : 0.0),
        potassiumMg = potassiumMg ?? 0.0,
        calciumMg = calciumMg ?? 0.0,
        ironMg = ironMg ?? 0.0,
        fiberG = fiberG ?? (dietaryFiber != null ? double.tryParse(dietaryFiber.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0 : 0.0),
        sugarsG = sugarsG ?? (sugars != null ? double.tryParse(sugars.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0 : 0.0),
        addedSugarsG = addedSugarsG ?? 0.0;
}

class DetectionResult {
  final String label;
  final double confidence;
  final Rect boundingBox;

  DetectionResult({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });
}

// ============================================================================
// Backend Compatibility Extensions
// ============================================================================
// These extensions provide the fields and structure expected by the backend
// logic (lib/core and lib/data) while keeping product_model.dart as the
// single source of truth for product data.

/// NutritionInfo class expected by backend logic (per-100g values)
class NutritionInfo {
  final double caloriesKcal;
  final double sodiumMg;
  final double sugarsG;
  final double saturatedFatG;
  final double totalCarbohydratesG;
  final double dietaryFiberG;
  final double potassiumMg;
  final double totalFatG;
  final double proteinG;

  const NutritionInfo({
    required this.caloriesKcal,
    required this.sodiumMg,
    required this.sugarsG,
    required this.saturatedFatG,
    required this.totalCarbohydratesG,
    required this.dietaryFiberG,
    required this.potassiumMg,
    required this.totalFatG,
    required this.proteinG,
  });
}

/// Extension on Product to provide backend-compatible fields
extension ProductBackendAdapter on Product {
  /// Parses serving size string to extract grams (e.g., "56g" -> 56.0)
  double get servingSizeG {
    final regex = RegExp(r'(\d+(?:\.\d+)?)\s*[gG]');
    final match = regex.firstMatch(nutritionalFacts.servingSize);
    if (match == null) return 0.0;
    return double.tryParse(match.group(1) ?? '') ?? 0.0;
  }

  /// Calculates per-100g nutrition values from per-serving values
  NutritionInfo get nutritionPer100g {
    final per100g = nutritionalFacts.per100gValues;
    if (per100g == null) {
      // Fallback: return per-serving values if calculation fails
      return NutritionInfo(
        caloriesKcal: nutritionalFacts.caloriesKcal,
        sodiumMg: nutritionalFacts.sodiumMg,
        sugarsG: nutritionalFacts.sugarsG,
        saturatedFatG: nutritionalFacts.saturatedFatG,
        totalCarbohydratesG: nutritionalFacts.carbsG,
        dietaryFiberG: nutritionalFacts.fiberG,
        potassiumMg: nutritionalFacts.potassiumMg,
        totalFatG: nutritionalFacts.totalFatG,
        proteinG: nutritionalFacts.proteinG,
      );
    }
    return NutritionInfo(
      caloriesKcal: per100g['caloriesKcal'] ?? nutritionalFacts.caloriesKcal,
      sodiumMg: per100g['sodiumMg'] ?? nutritionalFacts.sodiumMg,
      sugarsG: per100g['sugarsG'] ?? nutritionalFacts.sugarsG,
      saturatedFatG: per100g['saturatedFatG'] ?? nutritionalFacts.saturatedFatG,
      totalCarbohydratesG: per100g['carbsG'] ?? nutritionalFacts.carbsG,
      dietaryFiberG: per100g['fiberG'] ?? nutritionalFacts.fiberG,
      potassiumMg: per100g['potassiumMg'] ?? nutritionalFacts.potassiumMg,
      totalFatG: per100g['totalFatG'] ?? nutritionalFacts.totalFatG,
      proteinG: per100g['proteinG'] ?? nutritionalFacts.proteinG,
    );
  }

  /// Converts string allergens to AllergenType enums
  List<AllergenType> get containsAllergens {
    return allergens.map((allergenStr) {
      final normalized = allergenStr.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      switch (normalized) {
        case 'fish':
        case 'isda':
          return AllergenType.fish;
        case 'milk':
        case 'gatas':
          return AllergenType.dairy;
        case 'egg':
        case 'itlog':
          return AllergenType.eggs;
        case 'soy':
        case 'soya':
        case 'soybean':
          return AllergenType.soy;
        case 'wheat':
        case 'trigo':
          return AllergenType.wheatGluten;
        case 'shellfish':
        case 'lamangdagat':
        case 'lamang-dagat':
          return AllergenType.shellfish;
        case 'peanut':
        case 'mani':
          return AllergenType.peanuts;
        default:
          return AllergenType.msg; // Fallback for unrecognized allergens
      }
    }).toList();
  }

  /// Use variant as subCategory for backend compatibility
  String get subCategory => variant;

  /// Convert string FDA status to enum-like behavior
  String get fdaStatusBackend => fdaStatus;
}