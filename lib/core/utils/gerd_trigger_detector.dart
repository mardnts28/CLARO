// lib/core/utils/gerd_trigger_detector.dart
//
// Pure-Dart, awareness-only detector for common GERD (acid reflux) dietary
// triggers. This is NOT part of the Suitable/Moderate/Caution scoring
// pipeline (WhoCalculator/ConditionThresholds) -- GERD is an
// awareness-only condition (see HealthConditionKind.isAwarenessOnly in
// data/models/health_profile.dart). This file only detects potential
// triggers from a Product's ingredients/nutrition; it never assigns a
// Suitable/Moderate/Caution verdict and never claims a product is
// "safe"/"unsafe".
//
// Matching approach mirrors WhoCalculator.assessAllergens: case-insensitive,
// whole-word/phrase matching so e.g. "tea" does not match inside "steak",
// and "lemon" does not match inside "lemongrass".

import '../../models/product_model.dart';
import 'nutrition_availability.dart';

enum GerdTriggerType {
  tomatoAcidic,
  spicy,
  caffeine,
  chocolate,
  highFat,
}

/// One detected trigger. [matchedIngredient] is set for the
/// ingredient-keyword triggers (tomatoAcidic/spicy/caffeine/chocolate);
/// [matchedValue] is set for highFat (grams of total fat per serving).
class GerdTriggerMatch {
  final GerdTriggerType type;
  final String? matchedIngredient;
  final double? matchedValue;

  const GerdTriggerMatch({
    required this.type,
    this.matchedIngredient,
    this.matchedValue,
  });
}

/// Result of running the detector against a product. Callers (the GERD
/// warning card) use [hasIngredientData]/[hasNutritionData] to tell apart
/// "checked and found nothing" from "couldn't check, data missing" --
/// see GerdWarningCard's three display states.
class GerdDetectionResult {
  final List<GerdTriggerMatch> triggers;
  final bool hasIngredientData;
  final bool hasNutritionData;

  const GerdDetectionResult({
    required this.triggers,
    required this.hasIngredientData,
    required this.hasNutritionData,
  });

  bool get hasAnyData => hasIngredientData || hasNutritionData;
  bool get hasTriggers => triggers.isNotEmpty;
}

class GerdTriggerDetector {
  GerdTriggerDetector._();

  // High-fat meals are commonly reported as a GERD trigger (fat slows
  // gastric emptying and is associated with lower esophageal sphincter
  // relaxation). There's no single clinical per-serving gram cutoff, so
  // this uses the same reference point already established elsewhere in
  // this codebase: the FDA "high" nutrient-content-claim convention of
  // >=20% of the Daily Value (21 CFR 101.54), applied to the FDA Daily
  // Value for total fat used on Philippine/US nutrition labels (78g,
  // based on a 2,000-kcal reference diet -- 21 CFR 101.9). 20% of 78g =
  // 15.6g. This mirrors the >20% "high" boundary WhoCalculator already
  // uses for WHO-limit nutrients (see classifyByWhoPercentage), just
  // applied to total fat instead of sodium/sugars/saturated fat.
  static const double highFatPerServingThresholdG = 15.6;

  static const List<String> _tomatoAcidicKeywords = [
    'tomato',
    'ketchup',
    'citric acid',
    'vinegar',
    'lemon',
    'calamansi',
    'citrus',
    'orange',
    'pineapple',
    'tamarind',
  ];

  static const List<String> _spicyKeywords = [
    'chili',
    'cayenne',
    'paprika',
    'hot sauce',
    'curry',
    'spicy',
    'labuyo',
    'hot',
  ];

  static const List<String> _caffeineKeywords = [
    'coffee',
    'caffeine',
    'tea',
    'guarana',
    'cola',
    'matcha',
  ];

  static const List<String> _chocolateKeywords = [
    'chocolate',
    'cocoa',
    'cacao',
  ];

  /// Detects GERD triggers for [product]. Null-safe: a product with no
  /// ingredients and/or no nutrition data simply skips the checks that
  /// need that data -- see [GerdDetectionResult.hasIngredientData] /
  /// [hasNutritionData] for what was actually checked.
  static GerdDetectionResult detect(Product product) {
    final ingredients = product.ingredients;
    final hasIngredientData = ingredients.isNotEmpty;
    final hasNutritionData = NutritionAvailability.isAvailable(product);

    final triggers = <GerdTriggerMatch>[];

    if (hasIngredientData) {
      triggers.addAll(_detectIngredientTriggers(ingredients));
    }

    // Also check product name for spicy-related keywords (for type/flavor info)
    final productNameTriggers = _detectSpicyInProductName(product.name);
    if (productNameTriggers != null) {
      // Avoid duplicate spicy trigger if ingredients already flagged spicy
      final alreadyHasSpicy = triggers.any((t) => t.type == GerdTriggerType.spicy);
      if (!alreadyHasSpicy) {
        triggers.add(productNameTriggers);
      }
    }

    if (hasNutritionData) {
      final fatPerServing = product.nutritionalFacts.totalFatG;
      if (fatPerServing >= highFatPerServingThresholdG) {
        triggers.add(GerdTriggerMatch(
          type: GerdTriggerType.highFat,
          matchedValue: fatPerServing,
        ));
      }
    }

    return GerdDetectionResult(
      triggers: triggers,
      hasIngredientData: hasIngredientData,
      hasNutritionData: hasNutritionData,
    );
  }

  static List<GerdTriggerMatch> _detectIngredientTriggers(
    List<String> ingredients,
  ) {
    final matches = <GerdTriggerMatch>[];
    final categories = <GerdTriggerType, List<String>>{
      GerdTriggerType.tomatoAcidic: _tomatoAcidicKeywords,
      GerdTriggerType.spicy: _spicyKeywords,
      GerdTriggerType.caffeine: _caffeineKeywords,
      GerdTriggerType.chocolate: _chocolateKeywords,
    };

    for (final entry in categories.entries) {
      final matched = _findFirstMatchingIngredient(
        ingredients,
        entry.value,
        triggerType: entry.key,
      );
      if (matched != null) {
        matches.add(GerdTriggerMatch(type: entry.key, matchedIngredient: matched));
      }
    }
    return matches;
  }

  /// Returns the first ingredient string (in label order) whose text
  /// contains any of [keywords] as a whole word/phrase -- e.g. "tea"
  /// matches "Iced Tea Powder" but NOT "Steak Seasoning" or
  /// "Vegetable Oil (Palm Oil with Green Tea Extract)"; "lemon" matches
  /// "Lemon Juice" but NOT "Lemongrass". Case-insensitive.
  static String? _findFirstMatchingIngredient(
    List<String> ingredients,
    List<String> keywords, {
    GerdTriggerType? triggerType,
  }) {
    for (final ingredient in ingredients) {
      final lower = ingredient.toLowerCase();
      for (final keyword in keywords) {
        final pattern = RegExp(
          r'(?<![a-z])' + RegExp.escape(keyword.toLowerCase()) + r'(?![a-z])',
        );
        if (pattern.hasMatch(lower)) {
          if (!_isExcludedMatch(lower, keyword.toLowerCase(), triggerType)) {
            return ingredient;
          }
        }
      }
    }
    return null;
  }

  /// Excludes known false positives for specific trigger types.
  static bool _isExcludedMatch(
    String ingredientLower,
    String keywordLower,
    GerdTriggerType? triggerType,
  ) {
    if (triggerType == GerdTriggerType.caffeine) {
      // "tea" keyword: green tea extract / tea extract in ingredients (such as
      // "Vegetable Oil (Palm Oil with Green Tea Extract)") is used as a food
      // antioxidant additive, not a caffeinated tea beverage/ingredient.
      if (keywordLower == 'tea') {
        if (ingredientLower.contains('green tea extract') ||
            ingredientLower.contains('tea extract')) {
          if (!ingredientLower.contains('caffeine')) {
            return true;
          }
        }
      }
      // "tea" or "coffee" keyword: decaffeinated / decaf items
      if (keywordLower == 'tea' || keywordLower == 'coffee') {
        if (ingredientLower.contains('decaf') ||
            ingredientLower.contains('decaffeinated')) {
          if (!ingredientLower.contains('caffeine')) {
            return true;
          }
        }
      }
    } else if (triggerType == GerdTriggerType.spicy) {
      if (keywordLower == 'hot') {
        if (ingredientLower.contains('hot water') ||
            ingredientLower.contains('hot break') ||
            ingredientLower.contains('hot pack') ||
            ingredientLower.contains('hot process')) {
          return true;
        }
      }
    }
    return false;
  }

  /// Detects spicy-related keywords in the product name (for type/flavor info).
  /// Returns a GerdTriggerMatch if found, null otherwise.
  static GerdTriggerMatch? _detectSpicyInProductName(String productName) {
    final lower = productName.toLowerCase();
    for (final keyword in _spicyKeywords) {
      final pattern = RegExp(
        r'(?<![a-z])' + RegExp.escape(keyword.toLowerCase()) + r'(?![a-z])',
      );
      if (pattern.hasMatch(lower)) {
        if (!_isExcludedMatch(lower, keyword.toLowerCase(), GerdTriggerType.spicy)) {
          return GerdTriggerMatch(
            type: GerdTriggerType.spicy,
            matchedIngredient: keyword,
          );
        }
      }
    }
    return null;
  }
}

