// lib/core/utils/comparison_matrix_builder.dart
//
// Builds the full side-by-side NUTRIENT comparison (all 6 nutrients,
// always) -- distinct from WhoCalculator/ProductRankingService, which only
// evaluate sodium/sugar for SUITABILITY RANKING purposes. This file has no
// dependency on which conditions the user has saved for the nutrient rows
// themselves; conditions only affect the optional `level` field on the
// sodium/sugar rows specifically.

import '../../data/models/comparison_matrix.dart';
import '../../data/models/health_profile.dart';
import '../../data/models/product.dart';
import '../../data/models/product_evaluation.dart';
import '../constants/who_fda_thresholds.dart';
import 'who_calculator.dart';

class ComparisonMatrixBuilder {
  static ComparisonMatrix build({
    required List<ProductEvaluation> comparisonSet,
    required UserHealthProfile user,
  }) {
    if (comparisonSet.length < 2) {
      return const ComparisonMatrix(productIds: [], nutrientRows: [], allergenRows: []);
    }

    final productIds = comparisonSet.map((e) => e.product.id).toList();

    final nutrientRows = ComparisonNutrient.values
        .map((nutrient) => _buildRow(nutrient, comparisonSet, user))
        .toList();

    final allergenRows = <AllergenComparisonRow>[];
    for (final allergen in user.allergies) {
      final cells = comparisonSet.map((e) {
        final AllergenPresence presence;
        if (e.product.containsAllergens.contains(allergen)) {
          presence = AllergenPresence.contains;
        } else if (e.product.mayContainAllergens.contains(allergen)) {
          presence = AllergenPresence.mayContain;
        } else {
          presence = AllergenPresence.none;
        }
        return AllergenComparisonCell(productId: e.product.id, presence: presence);
      }).toList();

      allergenRows.add(AllergenComparisonRow(allergen: allergen, cells: cells));
    }

    return ComparisonMatrix(
      productIds: productIds,
      nutrientRows: nutrientRows,
      allergenRows: allergenRows,
    );
  }

  static NutrientComparisonRow _buildRow(
    ComparisonNutrient nutrient,
    List<ProductEvaluation> comparisonSet,
    UserHealthProfile user,
  ) {
    final values = comparisonSet.map((e) => _readValue(nutrient, e.product)).toList();

    final bestValue = nutrient.higherIsBetter
        ? values.reduce((a, b) => a > b ? a : b) // protein: highest is favorable
        : values.reduce((a, b) => a < b ? a : b); // everything else: lowest is favorable
    final worstValue = nutrient.higherIsBetter
        ? values.reduce((a, b) => a < b ? a : b)
        : values.reduce((a, b) => a > b ? a : b);

    final cells = <NutrientComparisonCell>[];
    for (var i = 0; i < comparisonSet.length; i++) {
      final value = values[i];
      final level = _resolveLevel(nutrient, value, user);

      // Ties: if every product has the same value for this nutrient,
      // nothing stands out -- neutral, not misleadingly green/red for all.
      final allTied = bestValue == worstValue;

      final ComparisonHighlight highlight;
      if (level != null) {
        // Absolute basis available (sodium+hypertension or sugar+diabetes):
        // color reflects actual WHO/FDA safety, NOT relative rank within
        // this specific comparison set. Fixes the case where three products
        // are 700mg/600mg/500mg sodium -- all three are Caution-level per
        // Table 3.14, so all three should read red, not "500mg = green"
        // just because it's the lowest of three still-unsafe values.
        switch (level) {
          case AdvisoryLevel.suitable:
            highlight = ComparisonHighlight.favorable;
            break;
          case AdvisoryLevel.moderate:
            highlight = ComparisonHighlight.neutral;
            break;
          case AdvisoryLevel.caution:
            highlight = ComparisonHighlight.unfavorable;
            break;
        }
      } else if (allTied) {
        highlight = ComparisonHighlight.neutral;
      } else if (value == bestValue) {
        highlight = ComparisonHighlight.favorable; // green
      } else if (value == worstValue) {
        highlight = ComparisonHighlight.unfavorable; // red
      } else {
        highlight = ComparisonHighlight.neutral; // middle-of-the-pack, 3+ products
      }

      cells.add(NutrientComparisonCell(
        productId: comparisonSet[i].product.id,
        value: value,
        highlight: highlight,
        level: level,
      ));
    }

    return NutrientComparisonRow(nutrient: nutrient, cells: cells);
  }

  static double _readValue(ComparisonNutrient nutrient, Product product) {
    final info = product.nutritionPer100g;
    switch (nutrient) {
      case ComparisonNutrient.calories:
        return info.caloriesKcal;
      case ComparisonNutrient.sodium:
        return info.sodiumMg;
      case ComparisonNutrient.sugars:
        return info.sugarsG;
      case ComparisonNutrient.protein:
        return info.proteinG;
      case ComparisonNutrient.totalFat:
        return info.totalFatG;
      case ComparisonNutrient.saturatedFat:
        return info.saturatedFatG;
    }
  }

  // Table 3.14 only defines thresholds for sodium (hypertension), sugars
  // (diabetes), and saturated fat (heart condition) -- and only meaningful
  // if the user actually has that condition saved. Every other
  // nutrient/condition combination has no defined band, so this returns
  // null rather than fabricating one.
  static AdvisoryLevel? _resolveLevel(
    ComparisonNutrient nutrient,
    double value,
    UserHealthProfile user,
  ) {
    if (nutrient == ComparisonNutrient.sodium && user.hasHypertension) {
      return WhoCalculator.classifyNutrient(HealthCondition.hypertension, 'sodiumMg', value);
    }
    if (nutrient == ComparisonNutrient.sugars && user.hasDiabetes) {
      return WhoCalculator.classifyNutrient(HealthCondition.diabetes, 'sugarsG', value);
    }
    if (nutrient == ComparisonNutrient.saturatedFat && user.hasHeartCondition) {
      return WhoCalculator.classifyNutrient(HealthCondition.heartCondition, 'saturatedFatG', value);
    }
    return null;
  }
}