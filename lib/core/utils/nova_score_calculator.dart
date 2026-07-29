// lib/core/utils/nova_score_calculator.dart
//
// Local implementation of the NOVA food classification system.
// Classifies products into 4 NOVA groups based on ingredients and processing level:
// 1. Unprocessed or minimally processed foods
// 2. Processed culinary ingredients
// 3. Processed foods
// 4. Ultra-processed food products

import '../../models/product_model.dart';

enum NovaGroup { group1, group2, group3, group4 }

class NovaScoreResult {
  final NovaGroup group;
  final int groupNumber;

  const NovaScoreResult({
    required this.group,
    required this.groupNumber,
  });

  String get groupString => '$groupNumber';

  /// Hex color code matching NOVA group standard colors
  int get colorHex {
    switch (group) {
      case NovaGroup.group1:
        return 0xFF008B4C; // Green
      case NovaGroup.group2:
        return 0xFF80BC42; // Light Green
      case NovaGroup.group3:
        return 0xFFF58220; // Orange
      case NovaGroup.group4:
        return 0xFFEF3E23; // Red
    }
  }

  String description(String languageCode) {
    if (languageCode == 'tl') {
      switch (group) {
        case NovaGroup.group1:
          return 'Hindi o bahagyang naprosesong natural na pagkain.';
        case NovaGroup.group2:
          return 'Naprosesong sangkap sa pagluluto at pagtimpla.';
        case NovaGroup.group3:
          return 'Naprosesong pagkain na may medyo simpleng sangkap.';
        case NovaGroup.group4:
          return 'Ultra-processed na pagkain na may mga sangkap mula sa industriya.';
      }
    } else {
      switch (group) {
        case NovaGroup.group1:
          return 'Unprocessed or minimally processed natural foods.';
        case NovaGroup.group2:
          return 'Processed culinary ingredient used for seasoning and cooking.';
        case NovaGroup.group3:
          return 'Processed food with relatively simple ingredients.';
        case NovaGroup.group4:
          return 'Ultra-processed food product with industrial additives.';
      }
    }
  }
}

class NovaScoreCalculator {
  /// Keywords indicative of NOVA Group 4 (Ultra-processed industrial additives/processes)
  static const List<String> ultraProcessedKeywords = [
    // Flavor enhancers / Glutamates
    'monosodium glutamate', 'msg', 'e621', 'disodium inosinate', 'disodium guanylate',
    'flavor enhancer', 'pampalasa', 'hydrolyzed', 'yeast extract',
    
    // Emulsifiers / Stabilizers / Thickeners
    'emulsifier', 'lecithin', 'mono- and diglycerides', 'polysorbate',
    'carrageenan', 'xanthan gum', 'guar gum', 'modified starch',
    'modified food starch', 'maltodextrin',
    
    // Syrups & Artificial Sweeteners
    'high fructose', 'corn syrup', 'glucose syrup', 'invert sugar',
    'aspartame', 'sucralose', 'acesulfame', 'saccharin',
    
    // Artificial Colors & Flavorings
    'artificial flavor', 'artificial color', 'caramel color', 'yellow 5',
    'yellow 6', 'red 40', 'blue 1', 'tartrazine',
    
    // Preservatives & Industrial Fats
    'hydrogenated', 'partially hydrogenated', 'interesterified',
    'sodium nitrite', 'sodium nitrate', 'sodium benzoate', 'potassium sorbate',
    'bht', 'bha', 'tbhq',
    
    // Category / Product type indicators for Group 4
    'instant noodle', 'pancit canton', 'ramen', 'soft drink', 'soda',
    'snack', 'chips', 'hotdog', 'sausage', 'nuggets'
  ];

  /// Keywords indicative of NOVA Group 2 (Culinary ingredients)
  static const List<String> culinaryIngredientKeywords = [
    'salt', 'asin', 'sugar', 'asukal', 'cooking oil', 'vegetable oil',
    'palm oil', 'butter', 'mantekilya', 'vinegar', 'suka', 'lard'
  ];

  static NovaScoreResult computeFromProduct(Product product) {
    final lowerName = '${product.name} ${product.variant} ${product.category}'.toLowerCase();
    final ingredientsText = product.ingredients.join(' ').toLowerCase();
    final combinedText = '$lowerName $ingredientsText';

    // Check for Group 4 (Ultra-processed)
    for (final kw in ultraProcessedKeywords) {
      if (combinedText.contains(kw)) {
        return const NovaScoreResult(
          group: NovaGroup.group4,
          groupNumber: 4,
        );
      }
    }

    // Canned meats / fishes with sauces often fall in Group 3 or 4.
    // Instant noodles are always Group 4.
    if (lowerName.contains('instant') || lowerName.contains('noodle') || lowerName.contains('pancit canton')) {
      return const NovaScoreResult(
        group: NovaGroup.group4,
        groupNumber: 4,
      );
    }

    // Check for Group 2 (Culinary Ingredients) if product category/name is purely an ingredient
    if (product.ingredients.length <= 2) {
      for (final kw in culinaryIngredientKeywords) {
        if (lowerName.contains(kw)) {
          return const NovaScoreResult(
            group: NovaGroup.group2,
            groupNumber: 2,
          );
        }
      }
    }

    // If ingredients are empty or 1 single raw item (e.g., fresh fruit, plain water, fresh milk, oats)
    if (product.ingredients.isEmpty || (product.ingredients.length == 1 && !combinedText.contains('preservative'))) {
      if (lowerName.contains('water') || lowerName.contains('fresh') || lowerName.contains('oats') || lowerName.contains('rice')) {
        return const NovaScoreResult(
          group: NovaGroup.group1,
          groupNumber: 1,
        );
      }
    }

    // Canned goods (tuna, sardines, corned beef, processed canned items) with simple ingredients -> Group 3
    return const NovaScoreResult(
      group: NovaGroup.group3,
      groupNumber: 3,
    );
  }
}
