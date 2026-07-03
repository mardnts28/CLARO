import 'dart:ui';

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
    required this.nutritionalFacts,
  });
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
