// lib/core/constants/canonical_allergens.dart
//
// Fixed allergen vocabulary used across the OCR + Gemini extraction pipeline
// (core/utils, data/services/product_extraction_service.dart) and mirrored
// in the admin dashboard's review checklist. Extraction is instructed to
// match detected allergen statements against this list rather than
// returning free-text, so "Milk" / "milk" / "contains milk" / "dairy" all
// collapse to one consistent value instead of admin (and the app) having to
// deal with N different spellings of the same allergen.
//
// Keep this list and the admin dashboard's copy of it in sync -- see
// admin-claro/src/constants/canonicalAllergens.js.
class CanonicalAllergens {
  CanonicalAllergens._();

  static const List<String> values = [
    'Milk',
    'Eggs',
    'Fish',
    'Shellfish',
    'Tree Nuts',
    'Peanuts',
    'Wheat',
    'Soy',
    'Sesame',
  ];
}
