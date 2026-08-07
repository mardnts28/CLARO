// src/constants/canonicalAllergens.js
//
// Fixed allergen vocabulary used by the admin review checklist. Must stay
// in sync with the OCR + Gemini extraction pipeline's allergen list --
// mirrors lib/core/constants/canonical_allergens.dart (Flutter app) and
// tools/bulk-import/import.js's CANONICAL_ALLERGENS constant. Extraction
// only ever returns values from this list, so the checklist here always
// has something to pre-check against -- see PROMPT_SCHEMA.md in
// bulk-import for the full shared-contract note.

export const CANONICAL_ALLERGENS = [
  "Milk",
  "Eggs",
  "Fish",
  "Shellfish",
  "Tree Nuts",
  "Peanuts",
  "Wheat",
  "Soy",
  "Sesame",
];
