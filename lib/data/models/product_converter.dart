// lib/data/models/product_converter.dart
//
// Helper functions to convert between old Product model (lib/models/product_model.dart)
// and new Product model (lib/data/models/product.dart).
// This is needed during the migration phase where some services still use the old model.

import 'product.dart';
import 'health_profile.dart';
import '../repositories/product_repository.dart';
import '../../models/product_model.dart' as old_model;

final ProductRepository _productRepository = MockProductRepository();

/// Converts new Product model to old Product model for services that haven't migrated yet.
old_model.Product newToOldProduct(Product newProduct) {
  return old_model.Product(
    id: newProduct.id,
    name: newProduct.name,
    brand: newProduct.brand,
    variant: newProduct.subCategory,
    category: _mapCategoryToString(newProduct.category),
    imageUrl: newProduct.imageUrl ?? '',
    fdaStatus: 'UNVERIFIED',
    fdaRegistrationNumber: '',
    fdaValidityDate: '',
    fdaManufacturer: '',
    cprNumber: '',
    allergens: mapAllergensToStrings(newProduct.containsAllergens),
    ingredients: [],
    servingInstructions: '',
    nutritionalFacts: old_model.NutritionalFacts(
      servingSize: '${newProduct.servingSizeG}g',
      servingsPerContainer: '',
      caloriesKcal: newProduct.nutritionPer100g.caloriesKcal,
      proteinG: newProduct.nutritionPer100g.proteinG,
      carbsG: newProduct.nutritionPer100g.totalCarbohydratesG,
      totalFatG: newProduct.nutritionPer100g.totalFatG,
      saturatedFatG: newProduct.nutritionPer100g.saturatedFatG,
      transFatG: 0.0,
      cholesterolMg: 0.0,
      sodiumMg: newProduct.nutritionPer100g.sodiumMg,
      potassiumMg: newProduct.nutritionPer100g.potassiumMg,
      calciumMg: 0.0,
      ironMg: 0.0,
      fiberG: newProduct.nutritionPer100g.dietaryFiberG,
      sugarsG: newProduct.nutritionPer100g.sugarsG,
      addedSugarsG: 0.0,
    ),
  );
}

/// Converts old Product model to new Product model.
///
/// IMPORTANT: prefers looking up the VERIFIED new-model product by ID
/// (correct per-100g nutrition, correct subCategory) rather than
/// reconstructing values from the old model, since the old model stores
/// per-serving nutrition and naive field copying produces WRONG values
/// for WhoCalculator (e.g. sodium 250mg/serving misread as 250mg/100g).
Future<Product> oldToNewProduct(old_model.Product oldProduct) async {
  try {
    final match = await _productRepository.getProductById(oldProduct.id);
    if (match != null) return match;
  } catch (_) {
    // Not found in the new repository -- fall through to reconstruction
    // below. This should only happen for products not yet migrated into
    // mock_product_data.dart.
  }

  final servingSizeG = _parseServingSize(oldProduct.nutritionalFacts.servingSize);
  final scale = servingSizeG > 0 ? 100 / servingSizeG : 1.0;

  return Product(
    id: oldProduct.id,
    name: oldProduct.name,
    brand: oldProduct.brand,
    category: _mapStringToCategory(oldProduct.category),
    subCategory: 'general', // unknown outside the verified dataset
    servingSizeG: servingSizeG,
    nutritionPer100g: NutritionInfo(
      caloriesKcal: oldProduct.nutritionalFacts.caloriesKcal * scale,
      sodiumMg: oldProduct.nutritionalFacts.sodiumMg * scale,
      sugarsG: oldProduct.nutritionalFacts.sugarsG * scale,
      saturatedFatG: oldProduct.nutritionalFacts.saturatedFatG * scale,
      totalCarbohydratesG: oldProduct.nutritionalFacts.carbsG * scale,
      dietaryFiberG: oldProduct.nutritionalFacts.fiberG * scale,
      potassiumMg: oldProduct.nutritionalFacts.potassiumMg * scale,
      totalFatG: oldProduct.nutritionalFacts.totalFatG * scale,
      proteinG: oldProduct.nutritionalFacts.proteinG * scale,
    ),
    containsAllergens: mapStringAllergens(oldProduct.allergens),
    mayContainAllergens: [],
    otherIngredientNotices: [],
    fdaStatus: FdaApprovalStatus.pending,
    imageUrl: oldProduct.imageUrl.isNotEmpty ? oldProduct.imageUrl : null,
    barcode: null,
  );
}

String _mapCategoryToString(ProductCategory category) {
  switch (category) {
    case ProductCategory.cannedFish:
      return 'Canned Fish';
    case ProductCategory.cannedMeat:
      return 'Canned Meat';
    case ProductCategory.instantNoodles:
      return 'Instant Noodles';
  }
}

ProductCategory _mapStringToCategory(String category) {
  switch (category) {
    case 'Canned Fish':
      return ProductCategory.cannedFish;
    case 'Canned Meat':
      return ProductCategory.cannedMeat;
    case 'Instant Noodles':
      return ProductCategory.instantNoodles;
    default:
      return ProductCategory.cannedFish;
  }
}

/// Public (no underscore) so screens can reuse this for display purposes.
List<String> mapAllergensToStrings(List<AllergenType> allergens) {
  return allergens.map((a) {
    switch (a) {
      case AllergenType.shellfish:
        return 'Crustaceans (Shrimp)';
      case AllergenType.fish:
        return 'Fish';
      case AllergenType.peanuts:
        return 'Peanuts';
      case AllergenType.treeNuts:
        return 'Tree Nuts';
      case AllergenType.soy:
        return 'Soy';
      case AllergenType.dairy:
        return 'Milk';
      case AllergenType.eggs:
        return 'Egg';
      case AllergenType.wheatGluten:
        return 'Wheat';
      case AllergenType.msg:
        return 'MSG';
    }
  }).toList();
}

List<AllergenType> mapStringAllergens(List<String> allergens) {
  final mapped = <AllergenType>[];
  for (final a in allergens) {
    final lower = a.toLowerCase();
    if (lower.contains('shrimp') || lower.contains('crustacean')) {
      mapped.add(AllergenType.shellfish);
    } else if (lower.contains('fish')) {
      mapped.add(AllergenType.fish);
    } else if (lower.contains('peanut')) {
      mapped.add(AllergenType.peanuts);
    } else if (lower.contains('tree nut')) {
      mapped.add(AllergenType.treeNuts);
    } else if (lower.contains('soy')) {
      mapped.add(AllergenType.soy);
    } else if (lower.contains('milk') || lower.contains('dairy')) {
      mapped.add(AllergenType.dairy);
    } else if (lower.contains('egg')) {
      mapped.add(AllergenType.eggs);
    } else if (lower.contains('wheat') || lower.contains('gluten')) {
      mapped.add(AllergenType.wheatGluten);
    } else if (lower.contains('msg')) {
      mapped.add(AllergenType.msg);
    }
  }
  return mapped;
}

double _parseServingSize(String servingSize) {
  final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(servingSize);
  if (match != null) {
    return double.tryParse(match.group(1)!) ?? 100.0;
  }
  return 100.0;
}