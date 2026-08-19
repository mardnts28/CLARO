// lib/core/utils/who_calculator.dart
//
// Phase 1: full scoring engine. Implements Table 3.14 (per-nutrient
// advisory bands) and Table 3.15 (risk scoring, tie-breaking, allergen
// override for ranking).

import '../constants/who_fda_thresholds.dart';
import '../../data/models/health_profile.dart';
import '../../data/models/product_evaluation.dart';
import '../../models/product_model.dart';

class WhoCalculator {
  // Classify nutrient based on WHO daily limit percentage per serving
  // Suitable: ≤10%, Moderate: >10-20%, Caution: >20%
  static AdvisoryLevel classifyByWhoPercentage(double whoPercentage) {
    if (whoPercentage <= 5) return AdvisoryLevel.suitable;
    if (whoPercentage > 20) return AdvisoryLevel.caution;
    return AdvisoryLevel.moderate;
  }

  // Per-100g band classification. Powers both the comparison matrix
  // (red/green/neutral cells) AND riskScore in evaluateProduct() below --
  // i.e. the actual ranking order -- so a product's rank and its matrix
  // cells are always derived from the same numbers. Deliberately
  // independent of any one product's serving size, so products with
  // different serving sizes are compared on equal nutrient-density
  // footing rather than favoring whichever has the smaller label serving.
  static AdvisoryLevel classifyNutrient(
    HealthCondition condition,
    String nutrientKey,
    double value,
  ) {
    final band = ConditionThresholds.thresholds[condition]?[nutrientKey];
    if (band == null) {
      throw ArgumentError('No threshold defined for $condition / $nutrientKey');
    }
    if (value <= band.suitableMaxInclusive) return AdvisoryLevel.suitable;
    if (value >= band.cautionMinInclusive) return AdvisoryLevel.caution;
    return AdvisoryLevel.moderate;
  }

  // Public (no underscore) so ComparisonCalculator can reuse it without
  // duplicating this switch statement.
  static double readNutrientValue(NutritionInfo info, String nutrientKey) {
    switch (nutrientKey) {
      case 'sodiumMg':
        return info.sodiumMg;
      case 'sugarsG':
        return info.sugarsG;
      case 'saturatedFatG':
        return info.saturatedFatG;
      default:
        throw ArgumentError('Unknown nutrientKey: $nutrientKey');
    }
  }

  static AllergenAssessment assessAllergens(Product product, UserHealthProfile user) {
    final matchedAllergens = <AllergenType>[];
    final matchedIngredientStrings = <String>[];
    final ingredientSources = <AllergenIngredientMatch>[];

    for (final allergy in user.allergies) {
      // Direct: the ingredient text IS the allergen (or an unambiguous
      // species/synonym of it) -- checked first, since a direct match is
      // always at least as reliable as a derived one.
      final directIngredient = _findFirstMatchingIngredient(
        product.ingredients,
        _getDirectAllergenKeywords(allergy),
      );

      // Derived: only checked when no direct match was found. These
      // keywords are deliberately a short, curated list of well-known
      // allergen *derivatives* (e.g. "whey" for dairy, "surimi" for
      // fish) -- never generic/ambiguous terms like "flavors" or
      // "spices", which stay unmatched on purpose (see class 3 in the
      // module doc: ambiguous ingredients must not be auto-attributed).
      final derivedIngredient = directIngredient == null
          ? _findFirstMatchingIngredient(
              product.ingredients,
              _getDerivedAllergenKeywords(allergy),
            )
          : null;

      final hasIngredientEvidence = directIngredient != null || derivedIngredient != null;

      // Only flag allergens when there's explicit ingredient evidence.
      // Label declarations alone are not sufficient for a caution warning.
      if (!hasIngredientEvidence) continue;

      matchedAllergens.add(allergy);

      if (directIngredient != null) {
        ingredientSources.add(AllergenIngredientMatch(
          allergen: allergy,
          ingredient: directIngredient,
          matchType: AllergenMatchType.direct,
        ));
        matchedIngredientStrings.add(directIngredient);
      } else if (derivedIngredient != null) {
        ingredientSources.add(AllergenIngredientMatch(
          allergen: allergy,
          ingredient: derivedIngredient,
          matchType: AllergenMatchType.derived,
        ));
        matchedIngredientStrings.add(derivedIngredient);
      }
    }

    final allMatches = {...matchedAllergens}.toList();

    return AllergenAssessment(
      matchedContains: allMatches,
      hasDirectAllergen: allMatches.isNotEmpty,
      matchedIngredients: matchedIngredientStrings,
      ingredientSources: ingredientSources,
    );
  }

  /// Returns the first ingredient string (in label order) whose text
  /// contains any of [keywords] as a whole word/phrase -- e.g. "fish"
  /// matches "Fish Sauce" but NOT "Selfish Snacks Co." or "Catfish" being
  /// treated as a match for an unrelated "cat" keyword. Word-boundary
  /// matching (rather than plain `.contains`) also prevents false
  /// positives like "nut" matching inside "coconut" or "nutmeg".
  /// Also handles plural forms: e.g., "sardine" matches "sardines" and vice versa.
  static String? _findFirstMatchingIngredient(
    List<String> ingredients,
    List<String> keywords,
  ) {
    for (final ingredient in ingredients) {
      final lower = ingredient.toLowerCase();
      for (final keyword in keywords) {
        // Try exact word boundary match first
        final pattern = RegExp(
          r'(?<![a-z])' + RegExp.escape(keyword.toLowerCase()) + r'(?![a-z])',
        );
        if (pattern.hasMatch(lower)) return ingredient;
        
        // Try plural/singular variations
        // If keyword ends with 's', try without 's'
        if (keyword.toLowerCase().endsWith('s')) {
          final singular = keyword.toLowerCase().substring(0, keyword.length - 1);
          final singularPattern = RegExp(
            r'(?<![a-z])' + RegExp.escape(singular) + r'(?![a-z])',
          );
          if (singularPattern.hasMatch(lower)) return ingredient;
        }
        
        // If keyword doesn't end with 's', try with 's' added
        if (!keyword.toLowerCase().endsWith('s')) {
          final plural = keyword.toLowerCase() + 's';
          final pluralPattern = RegExp(
            r'(?<![a-z])' + RegExp.escape(plural) + r'(?![a-z])',
          );
          if (pluralPattern.hasMatch(lower)) return ingredient;
        }
      }
    }
    return null;
  }

  /// Keywords where the ingredient name itself directly names the
  /// allergen (or an unambiguous species/synonym of it) -- e.g. "Tuna" IS
  /// fish, "Milk" IS dairy. Matching one of these means the ingredient
  /// directly contains the allergen, not merely derives from it.
  static List<String> _getDirectAllergenKeywords(AllergenType allergen) {
    switch (allergen) {
      case AllergenType.shellfish:
        return ['shellfish', 'shrimp', 'prawn', 'crab', 'lobster', 'squid', 'clams', 'mussels', 'oysters', 'scallops', 'octopus', 'abalone', 'snail', 'crustacean', 'lamang dagat', 'lamang-dagat'];
      case AllergenType.fish:
        return ['fish', 'isda', 'anchovy', 'anchovies', 'mackerel', 'mackarel', 'tuna', 'salmon', 'cod', 'trout', 'sardine', 'sardines', 'bangus', 'tilapia'];
      case AllergenType.peanuts:
        return ['peanut', 'peanuts', 'mani', 'groundnut', 'arachis', 'mandelonas'];
      case AllergenType.treeNuts:
        return ['tree nut', 'tree nuts', 'almond', 'walnut', 'cashew', 'pecan', 'hazelnut', 'pistachio', 'macadamia', 'brazil nut', 'pine nut'];
      case AllergenType.soy:
        return ['soy', 'soya', 'soybean', 'tofu', 'tempeh', 'tamari', 'shoyu', 'edamame', 'miso', 'natto', 'okara'];
      case AllergenType.dairy:
        return ['milk', 'dairy', 'cream', 'cheese', 'yogurt', 'butter', 'gatas'];
      case AllergenType.eggs:
        return ['egg', 'eggs', 'itlog'];
      case AllergenType.wheatGluten:
        return ['wheat', 'trigo', 'barley', 'rye'];
      case AllergenType.msg:
        return ['msg', 'monosodium glutamate'];
    }
  }

  /// Keywords for well-known *derivatives* of an allergen -- the
  /// ingredient name does not contain the allergen's name, but the food
  /// data reliably confirms what it's made from (e.g. "Whey" and "Casein"
  /// are always milk-derived; "Surimi" is always fish-derived). This list
  /// deliberately excludes anything ambiguous (e.g. bare "flour", which
  /// could be rice/corn/wheat flour, or bare "flavors", which could be
  /// derived from anything) -- those must fall through to "undetermined"
  /// rather than being guessed here.
  static List<String> _getDerivedAllergenKeywords(AllergenType allergen) {
    switch (allergen) {
      case AllergenType.shellfish:
        return [];
      case AllergenType.fish:
        return ['surimi', 'bonito', 'katsuobushi', 'worcestershire', 'fish sauce', 'patis', 'fish oil'];
      // Peanut-derived ingredients (e.g. "Peanut Oil") already contain the
      // word "peanut" and are caught by the DIRECT keyword list above, per
      // the module spec: an ingredient name that explicitly contains the
      // allergen's name is a direct match, not a derived one.
      case AllergenType.peanuts:
        return [];
      case AllergenType.treeNuts:
        return ['marzipan', 'praline'];
      case AllergenType.soy:
        return ['hydrolyzed vegetable protein', 'soy lecithin', 'soy protein'];
      case AllergenType.dairy:
        return ['lactose', 'casein', 'caseinate', 'whey', 'buttermilk', 'ghee'];
      case AllergenType.eggs:
        return ['albumin', 'ovalbumin', 'mayonnaise', 'meringue'];
      case AllergenType.wheatGluten:
        return ['gluten', 'wheat flour', 'malt', 'semolina', 'durum', 'farina', 'seitan'];
      case AllergenType.msg:
        return ['yeast extract', 'autolyzed yeast', 'hydrolyzed vegetable protein'];
    }
  }

  static ProductEvaluation evaluateProduct(Product product, UserHealthProfile user) {
    final nutrientEvals = <NutrientEvaluation>[];

    // Ranking basis: per-100g. Kept separate from nutrientEvals/level above
    // so two products with different serving sizes (e.g. an 85g vs a 155g
    // can) are compared on equal nutrient-density footing rather than one
    // looking artificially "better" just because its label serving happens
    // to be smaller. This uses classifyNutrient() -- the same per-100g
    // band classification already powering the comparison matrix -- so a
    // product's rank and its red/green/neutral comparison cells are
    // always derived from the same numbers.
    int riskScore = 0;

    for (final condition in user.conditions) {
      final nutrientKeys = ConditionThresholds.thresholds[condition]?.keys ?? const <String>[];
      for (final key in nutrientKeys) {
        final valuePer100g = readNutrientValue(product.nutritionPer100g, key);
        
        // Calculate per-serving value
        final valuePerServing = (valuePer100g / 100) * product.servingSizeG;
        
        // Get WHO daily limit for this nutrient
        final whoDailyLimit = getWhoDailyLimit(key);
        
        // Calculate percentage of WHO daily limit per serving
        final whoPercentage = (valuePerServing / whoDailyLimit) * 100;
        
        // Classify based on WHO percentage, per serving -- this is the
        // health advisory basis: what a person actually eats in one
        // sitting is what should drive the advisory text/warning level
        // for a single product.
        final level = classifyByWhoPercentage(whoPercentage);
        
        nutrientEvals.add(NutrientEvaluation(
          condition: condition,
          nutrientKey: key,
          valuePer100g: valuePer100g,
          valuePerServing: valuePerServing,
          whoDailyLimitPercentage: whoPercentage,
          level: level,
        ));

        // Ranking basis: per-100g band classification, independent of
        // this product's own serving size.
        final rankingLevel = classifyNutrient(condition, key, valuePer100g);
        riskScore += RiskScoring.points[rankingLevel] ?? 0;
      }
    }

    final allergenAssessment = assessAllergens(product, user);

    // Table 3.14: food allergy is a THIRD condition row in the same table
    // as hypertension/diabetes, with its own Suitable/Caution classification
    // (no Moderate -- N/A). An allergen match (confirmed by explicit ingredient
    // evidence) forces the overall advisory level to Caution, even if every
    // evaluated nutrient came back Suitable. This does NOT touch riskScore --
    // Table 3.15 explicitly marks the Allergen Detected row as N/A for score,
    // using it only to force last place in ranking (handled separately via
    // allergenOverride below).
    final overallLevel = allergenAssessment.hasDirectAllergen
        ? AdvisoryLevel.caution
        : _worstLevel(nutrientEvals);

    return ProductEvaluation(
      product: product,
      nutrientEvaluations: nutrientEvals,
      allergenAssessment: allergenAssessment,
      riskScore: riskScore,
      overallLevel: overallLevel,
      allergenOverride: allergenAssessment.hasDirectAllergen,
    );
  }

  // Public (no underscore) so UI code (e.g. re-deriving the advisory badge
  // for a user-selected pack size instead of the product's label serving)
  // can reuse the exact same limits instead of duplicating them.
  static double getWhoDailyLimit(String nutrientKey) {
    switch (nutrientKey) {
      case 'sodiumMg':
        return WhoDailyLimits.sodiumMgPerDay;
      case 'sugarsG':
        return WhoDailyLimits.sugarsGPerDay;
      case 'saturatedFatG':
        return WhoDailyLimits.saturatedFatGPerDay;
      default:
        throw ArgumentError('No WHO daily limit defined for $nutrientKey');
    }
  }

  static AdvisoryLevel _worstLevel(List<NutrientEvaluation> evals) {
    if (evals.isEmpty) return AdvisoryLevel.suitable;
    if (evals.any((e) => e.level == AdvisoryLevel.caution)) return AdvisoryLevel.caution;
    if (evals.any((e) => e.level == AdvisoryLevel.moderate)) return AdvisoryLevel.moderate;
    return AdvisoryLevel.suitable;
  }

  static List<ProductEvaluation> rankProducts(
    List<Product> products,
    UserHealthProfile user,
  ) {
    final evaluations = products.map((p) => evaluateProduct(p, user)).toList();

    // Tie-break signal: sum of raw per-100g values across evaluated
    // nutrients. Table 3.15 says "higher nutrient value per 100g" without
    // specifying which nutrient when multiple are evaluated -- summing all
    // evaluated nutrients is my interpretation; confirm with your adviser
    // if a single specific nutrient should be used instead.
    double tieBreakValue(ProductEvaluation e) =>
        e.nutrientEvaluations.fold<double>(0, (sum, ev) => sum + ev.valuePer100g);

    evaluations.sort((a, b) {
      if (a.allergenOverride != b.allergenOverride) {
        return a.allergenOverride ? 1 : -1;
      }
      final scoreCompare = a.riskScore.compareTo(b.riskScore);
      if (scoreCompare != 0) return scoreCompare;
      return tieBreakValue(a).compareTo(tieBreakValue(b));
    });

    return evaluations;
  }

  static List<ProductEvaluation> topRecommendations(
    List<ProductEvaluation> ranked, {
    int count = 3,
  }) {
    return ranked.take(count).toList();
  }
}