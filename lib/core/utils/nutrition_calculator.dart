// lib/core/utils/nutrition_calculator.dart
//
// Utility functions for calculating per-100g nutrient values from per-serving values.
// Used internally for product ranking and comparison while keeping per-serving values for display.

import '../../models/product_model.dart';

/// Parses a serving size string to extract the numeric value in grams.
/// Examples: "56g", "56g (Approx. 1/3 cup)", "100g", "250g" -> returns 56.0, 100.0, 250.0
/// Returns null if parsing fails or if the unit is not in grams.
double? _parseServingSizeGrams(String servingSize) {
  if (servingSize.isEmpty) return null;
  
  // Extract the first number followed by 'g' (case-insensitive)
  final regex = RegExp(r'(\d+(?:\.\d+)?)\s*[gG]');
  final match = regex.firstMatch(servingSize);
  
  if (match == null) return null;
  
  return double.tryParse(match.group(1) ?? '');
}

/// Calculates per-100g nutrient values from per-serving values.
/// Returns a map of nutrient keys to their per-100g values.
/// Returns null if serving size cannot be parsed or is zero.
Map<String, double>? calculatePer100gValues(NutritionalFacts facts) {
  final servingSizeGrams = _parseServingSizeGrams(facts.servingSize);
  
  if (servingSizeGrams == null || servingSizeGrams <= 0) {
    return null;
  }
  
  final multiplier = 100.0 / servingSizeGrams;
  
  return {
    'caloriesKcal': facts.caloriesKcal * multiplier,
    'proteinG': facts.proteinG * multiplier,
    'carbsG': facts.carbsG * multiplier,
    'totalFatG': facts.totalFatG * multiplier,
    'saturatedFatG': facts.saturatedFatG * multiplier,
    'transFatG': facts.transFatG * multiplier,
    'cholesterolMg': facts.cholesterolMg * multiplier,
    'sodiumMg': facts.sodiumMg * multiplier,
    'potassiumMg': facts.potassiumMg * multiplier,
    'calciumMg': facts.calciumMg * multiplier,
    'ironMg': facts.ironMg * multiplier,
    'fiberG': facts.fiberG * multiplier,
    'sugarsG': facts.sugarsG * multiplier,
    'addedSugarsG': facts.addedSugarsG * multiplier,
  };
}

/// Extension on NutritionalFacts to provide convenient per-100g access.
extension NutritionalFactsPer100g on NutritionalFacts {
  /// Gets per-100g values as a map, or null if serving size cannot be parsed.
  Map<String, double>? get per100gValues => calculatePer100gValues(this);
  
  /// Gets a specific nutrient value per 100g, or null if serving size cannot be parsed.
  double? getPer100g(String nutrientKey) {
    final values = per100gValues;
    if (values == null) return null;
    return values[nutrientKey];
  }
}
