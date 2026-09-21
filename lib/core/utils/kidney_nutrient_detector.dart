// lib/core/utils/kidney_nutrient_detector.dart
//
// Pure-Dart, awareness-only detector for nutrients relevant to kidney health.
// This is NOT part of the Suitable/Moderate/Caution scoring pipeline
// (WhoCalculator/ConditionThresholds) -- Kidney Disease is an
// awareness-only condition (see HealthConditionKind.isAwarenessOnly in
// data/models/health_profile.dart). This file only extracts relevant
// nutrients from a Product's nutrition facts and phosphate additives from
// its ingredient list; it never assigns a Suitable/Moderate/Caution verdict
// and never claims a product is "safe"/"unsafe".

import '../../models/product_model.dart';
import 'nutrition_availability.dart';

enum KidneyNutrientType {
  sodium,
  potassium,
  protein,
  phosphorus,
  potassiumChloride,
}

/// One detected nutrient.
///
/// * sodium / potassium / protein: [valuePerServing] holds the per-serving
///   amount from the nutrition facts and [matchedIngredient] is null.
/// * phosphorus: detected from phosphate additives in the ingredient list,
///   so [matchedIngredient] holds the matched ingredient text (e.g.
///   "Sodium Phosphate, Phosphoric Acid") and [valuePerServing] is 0
///   (the amount is not declared on the label).
class KidneyNutrientMatch {
  final KidneyNutrientType type;
  final double valuePerServing;
  final String? matchedIngredient;

  const KidneyNutrientMatch({
    required this.type,
    this.valuePerServing = 0,
    this.matchedIngredient,
  });
}

/// Result of running the detector against a product. Callers (the Kidney
/// Disease warning card) use [hasNutritionData] / [hasIngredientData] to tell
/// apart "checked and found nothing" from "couldn't check, data missing".
class KidneyNutrientResult {
  final List<KidneyNutrientMatch> nutrients;
  final bool hasNutritionData;
  final bool hasIngredientData;

  const KidneyNutrientResult({
    required this.nutrients,
    required this.hasNutritionData,
    this.hasIngredientData = false,
  });

  bool get hasAnyNutrients => nutrients.isNotEmpty;

  /// True if there was anything at all (nutrition facts or ingredients) to
  /// check. When false, the card should show "not enough information".
  bool get hasAnyData => hasNutritionData || hasIngredientData;
}

class KidneyNutrientDetector {
  KidneyNutrientDetector._();

  /// Substrings that identify an inorganic phosphate additive. Matched as a
  /// plain substring so compound names are caught: "monocalcium phosphate",
  /// "sodium polyphosphate", "sodium acid pyrophosphate",
  /// "sodium hexametaphosphate", "phosphoric acid", etc.
  ///
  /// Deliberately NOT "phosphat" / "phospho": that would also match
  /// phosphatidylcholine / phospholipids / "ammonium phosphatides" (E442),
  /// which are lecithin-type emulsifiers, not phosphate additives.
  static const List<String> _phosphateKeywords = [
    'phosphate', // covers phosphates, polyphosphate, pyrophosphate, ...
    'phosphoric', // phosphoric acid (E338)
    'fosfato', // Spanish/Filipino-label spelling
  ];

  /// E-number / INS codes for phosphate additives:
  /// E338 phosphoric acid, E339-E341 sodium/potassium/calcium phosphates,
  /// E343 magnesium phosphates, E450 diphosphates, E451 triphosphates,
  /// E452 polyphosphates, E540 dicalcium diphosphate, E541 sodium aluminium
  /// phosphate, E542 bone phosphate, E544 calcium polyphosphates.
  /// Accepts "E450", "E-450", "E 450(i)", "INS 452", "E451i" etc.
  static final RegExp _phosphateECode = RegExp(
    r'(?<![a-z0-9])(?:e|ins)[\s\-]?'
    r'(?:338|339|340|341|343|450|451|452|540|541|542|544)'
    r'(?![0-9])(?!\s?(?:mg|mcg|g|iu)\b)', // skip "Vitamin E 340mg"-style amounts
  );

  /// Maximum number of matched ingredients shown in the card detail.
  static const int _maxMatchedIngredients = 3;

  /// Detects kidney-relevant nutrients for [product]. Null-safe: a product
  /// with no nutrition data and no ingredients simply returns an empty
  /// result -- see [KidneyNutrientResult.hasNutritionData] /
  /// [KidneyNutrientResult.hasIngredientData] for what was actually checked.
  static KidneyNutrientResult detect(Product product) {
    final hasNutritionData = NutritionAvailability.isAvailable(product);
    final ingredients = product.ingredients;
    final hasIngredientData = ingredients.isNotEmpty;
    final nutrients = <KidneyNutrientMatch>[];

    if (hasNutritionData) {
      final facts = product.nutritionalFacts;

      // Sodium
      if (facts.sodiumMg > 0) {
        nutrients.add(
          KidneyNutrientMatch(
            type: KidneyNutrientType.sodium,
            valuePerServing: facts.sodiumMg,
          ),
        );
      }

      // Potassium
      if (facts.potassiumMg > 0) {
        nutrients.add(
          KidneyNutrientMatch(
            type: KidneyNutrientType.potassium,
            valuePerServing: facts.potassiumMg,
          ),
        );
      }

      // Protein
      if (facts.proteinG > 0) {
        nutrients.add(
          KidneyNutrientMatch(
            type: KidneyNutrientType.protein,
            valuePerServing: facts.proteinG,
          ),
        );
      }
    }

    // Phosphorus (phosphate additives) -- scanned from ingredients, so it
    // runs even when the product has no nutrition facts.
    if (hasIngredientData) {
      final matched = _findPhosphateIngredients(ingredients);
      if (matched.isNotEmpty) {
        nutrients.add(
          KidneyNutrientMatch(
            type: KidneyNutrientType.phosphorus,
            matchedIngredient: matched.take(_maxMatchedIngredients).join('; '),
          ),
        );
      }
      final potassiumChloride = _findFirstIngredient(
        ingredients,
        'potassium chloride',
      );
      if (potassiumChloride != null) {
        nutrients.add(
          KidneyNutrientMatch(
            type: KidneyNutrientType.potassiumChloride,
            matchedIngredient: potassiumChloride,
          ),
        );
      }
    }

    return KidneyNutrientResult(
      nutrients: nutrients,
      hasNutritionData: hasNutritionData,
      hasIngredientData: hasIngredientData,
    );
  }

  /// True if a single ingredient string (e.g. "Sodium Phosphate",
  /// "Acidity Regulator (E450(i))") contains a phosphate additive name or
  /// E-number. Public so other screens (e.g. the ingredient list on the
  /// More Details screen) can highlight the same items the Kidney Disease
  /// card reports, using one shared definition.
  static bool isPhosphateIngredient(String ingredient) {
    final lower = ingredient.toLowerCase();
    return _phosphateKeywords.any((k) => lower.contains(k)) ||
        _phosphateECode.hasMatch(lower);
  }

  /// Returns the ingredient items (label order, de-duplicated, trimmed) that
  /// contain a phosphate additive. The raw list is first re-split on
  /// top-level commas (commas inside parentheses/brackets are kept, so
  /// "Emulsifier (Sodium Phosphate, Lecithin)" stays one item) so a list
  /// stored as one long string still yields short, readable matches.
  static List<String> _findPhosphateIngredients(List<String> ingredients) {
    final matches = <String>[];
    final seen = <String>{};
    for (final item in _splitTopLevel(ingredients.join(', '))) {
      if (isPhosphateIngredient(item) && seen.add(item.toLowerCase())) {
        matches.add(item);
      }
    }
    return matches;
  }

  static String? _findFirstIngredient(
    List<String> ingredients,
    String keyword,
  ) {
    final pattern = RegExp(
      r'(?<![a-z])' + RegExp.escape(keyword) + r'(?![a-z])',
      caseSensitive: false,
    );
    for (final ingredient in ingredients) {
      if (pattern.hasMatch(ingredient)) return ingredient;
    }
    return null;
  }

  /// Splits [text] on commas that are not inside (...) or [...].
  static List<String> _splitTopLevel(String text) {
    final items = <String>[];
    final current = StringBuffer();
    var depth = 0;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '(' || ch == '[') {
        depth++;
        current.write(ch);
      } else if (ch == ')' || ch == ']') {
        if (depth > 0) depth--;
        current.write(ch);
      } else if (ch == ',' && depth == 0) {
        final part = current.toString().trim();
        if (part.isNotEmpty) items.add(part);
        current.clear();
      } else {
        current.write(ch);
      }
    }
    final last = current.toString().trim();
    if (last.isNotEmpty) items.add(last);
    return items;
  }
}
