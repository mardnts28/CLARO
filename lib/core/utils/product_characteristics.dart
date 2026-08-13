// lib/core/utils/product_characteristics.dart
//
// Single source of truth for the curated PRODUCT-TYPE and FLAVOR keyword
// lists used to describe "what a product fundamentally is" from its name.
// Deliberately pure/static (no async, no dependencies) so it's cheap to
// call from anywhere.
//
// Two consumers today:
//   - ProductComparisonService: uses characteristicTokens() as the
//     Scenario B ("Compare" button) candidate-relevance gate -- deciding
//     WHICH same-category products are similar enough to include.
//   - CompareProductsScreen: uses typeTags()/flavorTags() to populate and
//     evaluate the on-screen "Product Type" / "Flavor" filter chips --
//     deciding which of the ALREADY-INCLUDED products are currently
//     visible. Same vocabulary, two different jobs -- keeping them here
//     once means a new keyword only ever needs to be added in one place.
//
// Scoped to CLARO's actual supported categories: Canned Fish, Canned
// Seafood, Canned Meat, Canned Vegetables/Fruits, Instant Noodles.
// Extend the lists below as more product types are added to the catalog.

import '../../models/product_model.dart';

class ProductCharacteristics {
  ProductCharacteristics._();

  /// What the product fundamentally IS.
  static const List<String> typeKeywords = [
    // Canned Fish
    'tuna', 'sardines',
    // Canned Seafood
    'squid', 'seafood',
    // Canned Meat
    'corned beef', 'luncheon meat', 'meatloaf', 'vienna sausage',
    'chicken', 'pork', 'beef',
    // Canned Vegetables / Fruits
    'pineapple', 'fruit cocktail', 'mixed fruit', 'green peas',
    // Instant Noodles
    'pancit canton',
  ];

  /// The flavor/packing-medium a product comes in. "spicy" and "hot"
  /// deliberately sit in one shared list rather than being duplicated per
  /// category -- both the candidate-selection gate and the filter chips
  /// scope matching to same-category products already, so one entry
  /// covers canned fish, canned meat, and instant noodles alike.
  static const List<String> flavorKeywords = [
    // Fish / seafood / meat packing styles
    'tomato sauce', 'chili sauce', 'hot and spicy', 'spicy', 'hot',
    'chili', 'chilli',
    'oil', 'vegetable oil', 'brine', 'spring water', 'garlic',
    // Fruit / vegetable packing mediums
    'light syrup', 'heavy syrup', 'syrup', 'juice',
    // Instant noodle preparation style
    'dry', 'soup',
  ];

  /// The subset of [flavorKeywords] that represent "spicy" -- used to
  /// power the Spicy / Non-Spicy toggle in the filter sheet, which is a
  /// presence/absence split rather than a plain keyword-membership chip.
  static const List<String> spicyKeywords = ['spicy', 'hot and spicy', 'hot', 'chili', 'chilli'];

  /// Packaging/preparation filler stripped out before comparing
  /// product-name tokens, so two products don't look "similar" just
  /// because they're both canned, or both use a generic descriptor like
  /// "original"/"premium". "sauce" is included here rather than left as a
  /// generic token since the SPECIFIC sauce types that matter are already
  /// captured as two-word phrases in [flavorKeywords] (e.g. "tomato
  /// sauce") -- letting the bare word "sauce" match on its own would be
  /// too broad.
  static const List<String> genericStopwords = [
    'canned', 'can', 'in', 'of', 'the', 'and', 'with', 'a', 'an',
    'original', 'classic', 'premium', 'select', 'choice', 'natural',
    'flavor', 'flavored', 'style', 'brand', 'new', 'net', 'wt', 'pack',
    'sauce',
  ];

  /// Every curated TYPE keyword found in [product]'s name.
  static Set<String> typeTags(Product product) {
    final name = product.name.toLowerCase();
    return typeKeywords.where((k) => name.contains(k)).toSet();
  }

  /// Every curated FLAVOR keyword found in [product]'s name.
  static Set<String> flavorTags(Product product) {
    final name = product.name.toLowerCase();
    return flavorKeywords.where((k) => name.contains(k)).toSet();
  }

  /// True if [product]'s name contains any spicy-indicating keyword.
  static bool isSpicy(Product product) =>
      flavorTags(product).any(spicyKeywords.contains);

  /// Fallback for categories the curated lists don't cover: the set of
  /// meaningful words left in the product name after removing the brand
  /// name and packaging/filler words. "Del Monte Mixed Fruit Cocktail in
  /// Syrup" (brand "Del Monte") -> {'mixed', 'fruit', 'cocktail',
  /// 'syrup'}.
  static Set<String> genericNameTokens(Product product) {
    final brandWords = product.brand
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty)
        .toSet();

    return product.name
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length >= 3)
        .where((w) => !brandWords.contains(w))
        .where((w) => !genericStopwords.contains(w))
        .toSet();
  }

  /// The full set of "what makes this product what it is" tokens: curated
  /// type/flavor keyword hits, plus generic name tokens as a catch-all.
  /// Used by ProductComparisonService as the candidate-relevance gate.
  static Set<String> characteristicTokens(Product product) {
    return {
      ...typeTags(product),
      ...flavorTags(product),
      ...genericNameTokens(product),
    };
  }

  /// Turns a raw keyword ("corned beef") into a display label ("Corned
  /// Beef") for filter chips. Not localized -- see CompareProductsScreen
  /// for why (the keyword list is English/catalog-driven and can grow
  /// often, unlike the small fixed HealthCondition set).
  static String displayLabel(String keyword) {
    return keyword
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}