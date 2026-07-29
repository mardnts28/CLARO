// lib/core/utils/nutri_score_calculator.dart
//
// Pure local implementation of the updated (2023) Nutri-Score algorithm
// for canned goods and instant noodle products sold in the Philippines.
// Operates independently of Open Food Facts.
//
// Reference: Santé publique France / AECOSAN, "NUTRI-SCORE Questions & Answers,"
// approved 21 Dec 2023.

import '../../models/product_model.dart';

enum NutriScoreGrade { A, B, C, D, E }

enum NutriScoreCategory { general, red_meat }

class NutriScoreResult {
  final int score;
  final NutriScoreGrade grade;
  final NutriScoreCategory category;
  final int negativePoints; // N
  final int positivePoints; // P
  final int energyPoints;
  final int satFatPoints;
  final int sugarsPoints;
  final int saltPoints;
  final int proteinPoints;
  final int fibrePoints;
  final int fruitVegPoints;
  final bool isFruitVegEstimated;
  final bool isRedMeat;
  final String sourceNotice;

  const NutriScoreResult({
    required this.score,
    required this.grade,
    required this.category,
    required this.negativePoints,
    required this.positivePoints,
    required this.energyPoints,
    required this.satFatPoints,
    required this.sugarsPoints,
    required this.saltPoints,
    required this.proteinPoints,
    required this.fibrePoints,
    required this.fruitVegPoints,
    required this.isFruitVegEstimated,
    required this.isRedMeat,
    this.sourceNotice =
        'Calculated using official 2023 Nutri-Score algorithm (Independent of Open Food Facts)',
  });

  String get gradeLetter => grade.name;

  /// Hex color code matching official Nutri-Score badge colors
  int get gradeColorHex {
    switch (grade) {
      case NutriScoreGrade.A:
        return 0xFF008B4C; // Dark Green
      case NutriScoreGrade.B:
        return 0xFF80BC42; // Light Green
      case NutriScoreGrade.C:
        return 0xFFFCCA1D; // Yellow
      case NutriScoreGrade.D:
        return 0xFFF58220; // Orange
      case NutriScoreGrade.E:
        return 0xFFEF3E23; // Red
    }
  }

  String description(String languageCode) {
    if (languageCode == 'tl') {
      switch (grade) {
        case NutriScoreGrade.A:
          return 'Napakataas na kalidad ng nutrisyon na may mababang negatibong sustansya.';
        case NutriScoreGrade.B:
          return 'Magandang kalidad ng nutrisyon na may balanseng sustansya.';
        case NutriScoreGrade.C:
          return 'Katamtamang kalidad ng nutrisyon; kainin nang may kontrol.';
        case NutriScoreGrade.D:
          return 'Mababang kalidad ng nutrisyon; mas mataas sa asukal, asin, o taba.';
        case NutriScoreGrade.E:
          return 'Mahinang kalidad ng nutrisyon; limitahan ang pagkonsumo nito.';
      }
    } else {
      switch (grade) {
        case NutriScoreGrade.A:
          return 'Very high nutritional quality with low negative nutrients.';
        case NutriScoreGrade.B:
          return 'Good nutritional quality with favorable nutrient balance.';
        case NutriScoreGrade.C:
          return 'Average nutritional quality; consume in moderate amounts.';
        case NutriScoreGrade.D:
          return 'Low nutritional quality; higher in sugar, salt, or saturated fat.';
        case NutriScoreGrade.E:
          return 'Poor nutritional quality; limit consumption of this item.';
      }
    }
  }
}

class NutriScoreCalculator {
  // ============================================================================
  // Named Point Tables (Auditable against 2023 Nutri-Score PDF)
  // ============================================================================

  /// Energy (kJ / 100g) points mapping: 0..10
  static const List<MapEntry<double, int>> ENERGY_POINTS_TABLE = [
    MapEntry(335.0, 0),
    MapEntry(670.0, 1),
    MapEntry(1005.0, 2),
    MapEntry(1340.0, 3),
    MapEntry(1675.0, 4),
    MapEntry(2010.0, 5),
    MapEntry(2345.0, 6),
    MapEntry(2680.0, 7),
    MapEntry(3015.0, 8),
    MapEntry(3350.0, 9),
  ];

  /// Saturated Fat (g / 100g) points mapping: 0..10
  static const List<MapEntry<double, int>> SAT_FAT_POINTS_TABLE = [
    MapEntry(1.0, 0),
    MapEntry(2.0, 1),
    MapEntry(3.0, 2),
    MapEntry(4.0, 3),
    MapEntry(5.0, 4),
    MapEntry(6.0, 5),
    MapEntry(7.0, 6),
    MapEntry(8.0, 7),
    MapEntry(9.0, 8),
    MapEntry(10.0, 9),
  ];

  /// Sugars (g / 100g) points mapping: 0..15 (Nutri-Score 2023 update)
  static const List<MapEntry<double, int>> SUGARS_POINTS_TABLE = [
    MapEntry(3.4, 0),
    MapEntry(6.8, 1),
    MapEntry(10.0, 2),
    MapEntry(14.0, 3),
    MapEntry(17.0, 4),
    MapEntry(20.0, 5),
    MapEntry(24.0, 6),
    MapEntry(27.0, 7),
    MapEntry(31.0, 8),
    MapEntry(34.0, 9),
    MapEntry(37.0, 10),
    MapEntry(41.0, 11),
    MapEntry(44.0, 12),
    MapEntry(48.0, 13),
    MapEntry(51.0, 14),
  ];

  /// Salt (g / 100g) points mapping: 0..20 (Nutri-Score 2023 update)
  static const List<MapEntry<double, int>> SALT_POINTS_TABLE = [
    MapEntry(0.2, 0),
    MapEntry(0.4, 1),
    MapEntry(0.6, 2),
    MapEntry(0.8, 3),
    MapEntry(1.0, 4),
    MapEntry(1.2, 5),
    MapEntry(1.4, 6),
    MapEntry(1.6, 7),
    MapEntry(1.8, 8),
    MapEntry(2.0, 9),
    MapEntry(2.2, 10),
    MapEntry(2.4, 11),
    MapEntry(2.6, 12),
    MapEntry(2.8, 13),
    MapEntry(3.0, 14),
    MapEntry(3.2, 15),
    MapEntry(3.4, 16),
    MapEntry(3.6, 17),
    MapEntry(3.8, 18),
    MapEntry(4.0, 19),
  ];

  /// Protein (g / 100g) points mapping: 0..7 (Nutri-Score 2023 update)
  static const List<MapEntry<double, int>> PROTEIN_POINTS_TABLE = [
    MapEntry(2.4, 0),
    MapEntry(4.8, 1),
    MapEntry(7.2, 2),
    MapEntry(9.6, 3),
    MapEntry(12.0, 4),
    MapEntry(14.0, 5),
    MapEntry(17.0, 6),
  ];

  /// Fibre (g / 100g) points mapping: 0..5
  static const List<MapEntry<double, int>> FIBRE_POINTS_TABLE = [
    MapEntry(3.0, 0),
    MapEntry(4.1, 1),
    MapEntry(5.2, 2),
    MapEntry(6.3, 3),
    MapEntry(7.4, 4),
  ];

  // ============================================================================
  // Conversion & Normalization Helpers (PH Product Specific)
  // ============================================================================

  /// Converts energy in kcal to kJ (1 kcal = 4.184 kJ)
  static double kcalToKj(double energyKcal) => energyKcal * 4.184;

  /// Converts sodium in mg to salt in grams: salt (g) = (sodium (mg) / 1000) * 2.5
  static double sodiumMgToSaltG(double sodiumMg) => (sodiumMg / 1000.0) * 2.5;

  /// Normalizes a per-serving nutrient value to per-100g
  static double normalizeToPer100g(double perServingValue, double servingSizeG) {
    if (servingSizeG <= 0) return perServingValue;
    return (perServingValue / servingSizeG) * 100.0;
  }

  // ============================================================================
  // Point Lookup Helper Logic
  // ============================================================================

  static int _lookupPoints(double val, List<MapEntry<double, int>> table, int maxPts) {
    for (final entry in table) {
      if (val <= entry.key) return entry.value;
    }
    return maxPts;
  }

  /// Fruit / Veg / Legumes / Nuts % points mapping (0, 1, 2, 5)
  static int _getFruitVegPoints(double fruitVegPct) {
    if (fruitVegPct < 40.0) return 0;
    if (fruitVegPct <= 60.0) return 1;
    if (fruitVegPct <= 80.0) return 2;
    return 5;
  }

  // ============================================================================
  // Red Meat & Fruit/Veg Detection & Estimation Helpers
  // ============================================================================

  /// Red meat detection rule:
  /// Applies if the product's lead/first ingredient is beef, pork, corned beef,
  /// carne norte, luncheon meat, etc., or contains >=20% red meat.
  static bool isRedMeatProduct(Product product) {
    final lowerName = '${product.name} ${product.variant} ${product.category}'.toLowerCase();
    
    // Check name / variant keywords
    final redMeatKeywords = [
      'corned beef', 'carne norte', 'beef', 'pork', 'luncheon meat',
      'meatloaf', 'spam', 'bacon', 'ham', 'sausage', 'longganisa',
      'tocino', 'chicharron', 'pork & beans', 'pork and beans', 'giniling'
    ];

    for (final kw in redMeatKeywords) {
      if (lowerName.contains(kw)) {
        // Exclude chicken or fish/tuna variants that mention corned style (e.g. corned tuna, chicken luncheon meat)
        if (lowerName.contains('tuna') || lowerName.contains('chicken') || lowerName.contains('isda')) {
          if (!lowerName.contains('beef') && !lowerName.contains('pork')) {
            return false;
          }
        }
        return true;
      }
    }

    // Check ingredients list for red meat as 1st or 2nd ingredient
    if (product.ingredients.isNotEmpty) {
      final firstTwo = product.ingredients.take(2).join(' ').toLowerCase();
      if (firstTwo.contains('beef') || firstTwo.contains('pork') || firstTwo.contains('baka') || firstTwo.contains('baboy')) {
        return true;
      }
    }

    return false;
  }

  /// Fruit, Vegetable, Legume % Estimation Helper
  /// Parses declared percentage or estimates based on product ingredients/category.
  /// Returns a record: (estimatedPercentage, isEstimated)
  static (double, bool) estimateFruitVegPercentage(Product product) {
    final lowerText = '${product.name} ${product.category} ${product.ingredients.join(" ")}'.toLowerCase();

    // 1. Check for explicit percentage in ingredients string (e.g., "green peas (60%)")
    final pctRegex = RegExp(r'(peas|vegetables|fruit|tomato|beans|corn)\s*\(\s*(\d+(?:\.\d+)?)\s*%\s*\)');
    final match = pctRegex.firstMatch(lowerText);
    if (match != null) {
      final parsedPct = double.tryParse(match.group(2) ?? '');
      if (parsedPct != null) return (parsedPct, false); // Declared!
    }

    // 2. Category / Ingredient Estimation
    if (lowerText.contains('green peas') || lowerText.contains('guisantes') || lowerText.contains('mushrooms') || lowerText.contains('fruit cocktail') || lowerText.contains('pineapple tidbits')) {
      return (85.0, true); // High fruit/veg/legume product
    }

    if (lowerText.contains('sardines in tomato sauce') || lowerText.contains('sardines in tomato') || lowerText.contains('squid in soy sauce') || lowerText.contains('tomato sauce')) {
      return (35.0, true); // Canned fish with tomato sauce base (~35%)
    }

    if (lowerText.contains('pancit canton') || lowerText.contains('instant noodle') || lowerText.contains('ramen') || lowerText.contains('beef na beef')) {
      // Dehydrated veg in noodle cups is generally < 5%
      return (2.0, true);
    }

    return (0.0, false);
  }

  // ============================================================================
  // Main Pure Scoring Function
  // ============================================================================

  /// Calculates Nutri-Score 2023 from per-100g nutrient values.
  static NutriScoreResult compute({
    required double energyKj,
    required double satFatG,
    required double sugarsG,
    required double saltG,
    required double proteinG,
    required double fibreG,
    required double fruitVegPct,
    required bool isRedMeat,
    bool isFruitVegEstimated = false,
  }) {
    // Step 1: Negative Points (N)
    final energyPts = _lookupPoints(energyKj, ENERGY_POINTS_TABLE, 10);
    final satFatPts = _lookupPoints(satFatG, SAT_FAT_POINTS_TABLE, 10);
    final sugarsPts = _lookupPoints(sugarsG, SUGARS_POINTS_TABLE, 15);
    final saltPts = _lookupPoints(saltG, SALT_POINTS_TABLE, 20);

    final nPoints = energyPts + satFatPts + sugarsPts + saltPts;

    // Step 2: Positive Points (P)
    int rawProteinPts = _lookupPoints(proteinG, PROTEIN_POINTS_TABLE, 7);
    
    // Red Meat Exception: protein points capped at max 2!
    if (isRedMeat && rawProteinPts > 2) {
      rawProteinPts = 2;
    }
    final proteinPts = rawProteinPts;

    final fibrePts = _lookupPoints(fibreG, FIBRE_POINTS_TABLE, 5);
    final fruitVegPts = _getFruitVegPoints(fruitVegPct);

    final pPoints = proteinPts + fibrePts + fruitVegPts;

    // Step 3: Combine N and P
    // Official Nutri-Score 2023 Rule:
    // If N < 11 OR fruitVegPct >= 80%: score = N - P
    // Else (N >= 11 AND fruitVegPct < 80%): score = N - (fibrePts + fruitVegPts) (protein excluded)
    final int finalScore;
    if (nPoints < 11 || fruitVegPct >= 80.0) {
      finalScore = nPoints - pPoints;
    } else {
      finalScore = nPoints - (fibrePts + fruitVegPts);
    }

    // Step 4: Map score to Grade (General Food & Red Meat 2023 cutoff table)
    final NutriScoreGrade grade;
    if (finalScore <= -1) {
      grade = NutriScoreGrade.A;
    } else if (finalScore <= 2) {
      grade = NutriScoreGrade.B;
    } else if (finalScore <= 10) {
      grade = NutriScoreGrade.C;
    } else if (finalScore <= 18) {
      grade = NutriScoreGrade.D;
    } else {
      grade = NutriScoreGrade.E;
    }

    return NutriScoreResult(
      score: finalScore,
      grade: grade,
      category: isRedMeat ? NutriScoreCategory.red_meat : NutriScoreCategory.general,
      negativePoints: nPoints,
      positivePoints: pPoints,
      energyPoints: energyPts,
      satFatPoints: satFatPts,
      sugarsPoints: sugarsPts,
      saltPoints: saltPts,
      proteinPoints: proteinPts,
      fibrePoints: fibrePts,
      fruitVegPoints: fruitVegPts,
      isFruitVegEstimated: isFruitVegEstimated,
      isRedMeat: isRedMeat,
    );
  }

  // ============================================================================
  // Convenient Wrapper for Product Model
  // ============================================================================

  /// Calculates Nutri-Score directly from a [Product] object.
  /// Converts per-serving values to per-100g if needed and handles custom size scaling.
  static NutriScoreResult computeFromProduct(
    Product product, {
    double? customServingSizeG,
    bool? isRedMeatOverride,
  }) {
    final nf = product.nutritionalFacts;
    
    // Determine serving size in grams
    double servingG = customServingSizeG ?? 0.0;
    if (servingG <= 0) {
      servingG = product.servingSizeG > 0 ? product.servingSizeG : 100.0;
    }

    // Per-100g conversions
    final energyKcal100g = normalizeToPer100g(nf.caloriesKcal, servingG);
    final energyKj100g = kcalToKj(energyKcal100g);

    final satFat100g = normalizeToPer100g(nf.saturatedFatG, servingG);
    final sugars100g = normalizeToPer100g(nf.sugarsG, servingG);
    
    final sodiumMg100g = normalizeToPer100g(nf.sodiumMg, servingG);
    final saltG100g = sodiumMgToSaltG(sodiumMg100g);

    final protein100g = normalizeToPer100g(nf.proteinG, servingG);
    final fibre100g = normalizeToPer100g(nf.fiberG, servingG);

    final redMeat = isRedMeatOverride ?? isRedMeatProduct(product);
    final (fruitVegPct, isEstimated) = estimateFruitVegPercentage(product);

    return compute(
      energyKj: energyKj100g,
      satFatG: satFat100g,
      sugarsG: sugars100g,
      saltG: saltG100g,
      proteinG: protein100g,
      fibreG: fibre100g,
      fruitVegPct: fruitVegPct,
      isRedMeat: redMeat,
      isFruitVegEstimated: isEstimated,
    );
  }
}
