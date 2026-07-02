import 'dart:ui';

class Product {
  final String id;
  final String name;
  final String brand;
  final String variant;
  final String category;
  final String imageUrl;
  final String fdaStatus; // 'Registered', 'Pending', 'Unregistered'
  final String fdaRegistrationNumber;
  final List<String> allergens;
  final List<String> ingredients;
  final String servingInstructions;
  final NutritionalFacts nutritionalFacts;

  Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.variant,
    required this.category,
    required this.imageUrl,
    required this.fdaStatus,
    required this.fdaRegistrationNumber,
    required this.allergens,
    required this.ingredients,
    required this.servingInstructions,
    required this.nutritionalFacts,
  });
}

class NutritionalFacts {
  final String servingSize;
  final String servingsPerContainer;
  final String calories;
  final String totalFat;
  final String saturatedFat;
  final String transFat;
  final String cholesterol;
  final String sodium;
  final String totalCarbohydrate;
  final String dietaryFiber;
  final String sugars;
  final String protein;

  NutritionalFacts({
    required this.servingSize,
    required this.servingsPerContainer,
    required this.calories,
    required this.totalFat,
    required this.saturatedFat,
    required this.transFat,
    required this.cholesterol,
    required this.sodium,
    required this.totalCarbohydrate,
    required this.dietaryFiber,
    required this.sugars,
    required this.protein,
  });
}

class DetectionResult {
  final String label;
  final double confidence;
  final Rect boundingBox; // relative coordinate values [0.0, 1.0]

  DetectionResult({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });
}
