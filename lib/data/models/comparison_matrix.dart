// lib/data/models/comparison_matrix.dart
//
// UI-ready side-by-side comparison data. Two distinct comparison concepts
// live here, not one:
//
// 1. NutrientComparisonRow -- ALWAYS the same 6 nutrients (calories, sodium,
//    sugars, protein, total fat, saturated fat), regardless of the user's
//    saved health conditions. This is a general nutritional comparison, not
//    a suitability-ranking comparison.
// 2. `level` (Suitable/Moderate/Caution) is populated ONLY for sodium and
//    sugars, and ONLY when the user has the matching condition saved
//    (hypertension -> sodium, diabetes -> sugars) -- these are the only two
//    nutrients Table 3.14 actually defines thresholds for. Calories,
//    protein, total fat, and saturated fat have no Table 3.14 basis, so
//    `level` stays null for those rows; only the relative best/worst
//    highlight applies.

import '../../core/constants/who_fda_thresholds.dart';
import 'health_profile.dart';

// The fixed nutrient set for general comparison -- independent of ranking,
// independent of which conditions the user has saved. Every comparison
// screen shows all 6, always, per your Phase 4 spec.
enum ComparisonNutrient { calories, sodium, sugars, protein, totalFat, saturatedFat }

extension ComparisonNutrientInfo on ComparisonNutrient {
  // Maps to the field-reading key already used elsewhere in the app
  // (WhoCalculator.readNutrientValue only knows 'sodiumMg'/'sugarsG' --
  // the other 4 are read directly off NutritionInfo in the builder instead).
  String get displayLabel {
    switch (this) {
      case ComparisonNutrient.calories:
        return 'Calories';
      case ComparisonNutrient.sodium:
        return 'Sodium';
      case ComparisonNutrient.sugars:
        return 'Sugars';
      case ComparisonNutrient.protein:
        return 'Protein';
      case ComparisonNutrient.totalFat:
        return 'Total Fat';
      case ComparisonNutrient.saturatedFat:
        return 'Saturated Fat';
    }
  }

  String get unit => this == ComparisonNutrient.calories ? 'kcal' : 'g';

  // Protein is the ONE nutrient where MORE is favorable. Every other
  // nutrient here is favorable when LOWER (per your stated rule).
  bool get higherIsBetter => this == ComparisonNutrient.protein;
}

// Which direction a cell's highlight should point, already resolved so the
// UI never has to re-derive "is this good or bad" per nutrient itself.
enum ComparisonHighlight { favorable, unfavorable, neutral }

class NutrientComparisonCell {
  final String productId;
  final double value;
  final ComparisonHighlight highlight; // green (favorable) / red (unfavorable) / neutral
  final AdvisoryLevel? level; // Table 3.14 classification -- ONLY set for sodium/sugars, only if the user has the matching condition. Null otherwise.

  const NutrientComparisonCell({
    required this.productId,
    required this.value,
    required this.highlight,
    this.level,
  });
}

class NutrientComparisonRow {
  final ComparisonNutrient nutrient;
  final List<NutrientComparisonCell> cells; // same order as ComparisonMatrix.productIds

  const NutrientComparisonRow({
    required this.nutrient,
    required this.cells,
  });
}

enum AllergenPresence { none, contains }

class AllergenComparisonCell {
  final String productId;
  final AllergenPresence presence;

  const AllergenComparisonCell({
    required this.productId,
    required this.presence,
  });
}

class AllergenComparisonRow {
  final AllergenType allergen;
  final List<AllergenComparisonCell> cells;

  const AllergenComparisonRow({
    required this.allergen,
    required this.cells,
  });
}

class ComparisonMatrix {
  final List<String> productIds;
  final List<NutrientComparisonRow> nutrientRows;
  final List<AllergenComparisonRow> allergenRows;

  const ComparisonMatrix({
    required this.productIds,
    required this.nutrientRows,
    required this.allergenRows,
  });

  bool get isEmpty => productIds.length < 2;
}