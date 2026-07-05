// lib/data/models/product.dart
//
// Represents a scanned product, eventually assembled from:
//   - teammate's image recognition model (identifies WHICH product)
//   - Open Food Facts API or product DB (nutrition + allergen data)
//   - Firestore (cached FDA approval status)

import 'health_profile.dart';

enum ProductCategory {
  cannedFood,
  instantNoodles,
}

enum FdaApprovalStatus {
  verified,
  pending,
  notFound,
}

// All nutrient values are normalized PER 100g so products with different
// serving sizes can be fairly compared (per Table 3.14 basis).
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

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      caloriesKcal: (json['caloriesKcal'] as num).toDouble(),
      sodiumMg: (json['sodiumMg'] as num).toDouble(),
      sugarsG: (json['sugarsG'] as num).toDouble(),
      saturatedFatG: (json['saturatedFatG'] as num).toDouble(),
      totalCarbohydratesG: (json['totalCarbohydratesG'] as num).toDouble(),
      dietaryFiberG: (json['dietaryFiberG'] as num).toDouble(),
      potassiumMg: (json['potassiumMg'] as num).toDouble(),
      totalFatG: (json['totalFatG'] as num).toDouble(),
      proteinG: (json['proteinG'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'caloriesKcal': caloriesKcal,
        'sodiumMg': sodiumMg,
        'sugarsG': sugarsG,
        'saturatedFatG': saturatedFatG,
        'totalCarbohydratesG': totalCarbohydratesG,
        'dietaryFiberG': dietaryFiberG,
        'potassiumMg': potassiumMg,
        'totalFatG': totalFatG,
        'proteinG': proteinG,
      };
}

class Product {
  final String id;
  final String name;
  final String brand;
  final ProductCategory category;
  final String subCategory; // e.g. 'sardines', 'cornedBeef', 'tunaFlakes' --
  // finer-grained than `category`, used for meaningful "compare" alternatives
  // (comparing sardines to sardines, not sardines to spaghetti sauce).
  final double servingSizeG;
  final NutritionInfo nutritionPer100g;
  final List<AllergenType> containsAllergens;
  final List<AllergenType> mayContainAllergens; // cross-contamination warning
  final FdaApprovalStatus fdaStatus;
  final String? imageUrl;
  final String? barcode;

  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.subCategory,
    required this.servingSizeG,
    required this.nutritionPer100g,
    required this.containsAllergens,
    required this.mayContainAllergens,
    required this.fdaStatus,
    this.imageUrl,
    this.barcode,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String,
      category: ProductCategory.values.firstWhere((e) => e.name == json['category']),
      subCategory: json['subCategory'] as String,
      servingSizeG: (json['servingSizeG'] as num).toDouble(),
      nutritionPer100g: NutritionInfo.fromJson(json['nutritionPer100g'] as Map<String, dynamic>),
      containsAllergens: (json['containsAllergens'] as List<dynamic>)
          .map((a) => AllergenType.values.firstWhere((e) => e.name == a))
          .toList(),
      mayContainAllergens: (json['mayContainAllergens'] as List<dynamic>)
          .map((a) => AllergenType.values.firstWhere((e) => e.name == a))
          .toList(),
      fdaStatus: FdaApprovalStatus.values.firstWhere((e) => e.name == json['fdaStatus']),
      imageUrl: json['imageUrl'] as String?,
      barcode: json['barcode'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brand': brand,
        'category': category.name,
        'subCategory': subCategory,
        'servingSizeG': servingSizeG,
        'nutritionPer100g': nutritionPer100g.toJson(),
        'containsAllergens': containsAllergens.map((a) => a.name).toList(),
        'mayContainAllergens': mayContainAllergens.map((a) => a.name).toList(),
        'fdaStatus': fdaStatus.name,
        'imageUrl': imageUrl,
        'barcode': barcode,
      };
}