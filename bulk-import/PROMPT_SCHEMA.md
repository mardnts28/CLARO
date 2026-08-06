# Shared extraction contract

Both extraction implementations below must stay in sync -- they're
independent code (Dart vs. Node), not shared code, so a change to one needs
a matching change to the other:

- `lib/data/services/product_extraction_service.dart` (Flutter app,
  used for runtime user reports of unrecognized products)
- `tools/bulk-import/import.js` (this tool, used for offline batch
  population)

## Output JSON shape

```json
{
  "brand": "",
  "product_name": "",
  "category": "",
  "size": "",
  "serving_size": "",
  "ingredients": [],
  "nutrition_per_100g": {
    "energy_kcal": null, "protein_g": null, "carbs_g": null,
    "fat_total_g": null, "fat_saturated_g": null, "fat_trans_g": null,
    "sodium_mg": null, "potassium_mg": null, "calcium_mg": null,
    "iron_mg": null, "fiber_g": null, "sugars_g": null, "added_sugars_g": null
  },
  "allergens": [],
  "confidence_notes": ""
}
```

Note: the Dart service's schema (used for runtime reports) omits
`"category"` since the mobile submission screen collects the product's
category from other context. The bulk-import tool needs it because it's
populating `fda_products.product_category` directly with no other source
for that field. Keep this one intentional difference in mind if you diff
the two prompts.

## Back-photo count (another intentional difference)

`tools/bulk-import/import.js` accepts a variable number of back photos per
product (one combined `back.jpg`, or several `back_*.jpg` files when
nutrition facts and ingredients are printed in different spots on the
package) -- see `photos/_example_product/README.md`. The prompt adapts its
wording based on how many back images were found.

`lib/data/services/product_extraction_service.dart` (the runtime mobile
report flow) currently only accepts exactly one back photo
(`backImageBytes`), because the submission screen's UI only captures one.
If split-panel labels turn out to be common enough that this becomes a
real problem for user-submitted reports too, extending the mobile
submission screen to capture multiple back photos (and updating this
service's `extract()` signature to accept a list) would be the fix -- not
done here since it wasn't needed yet for the runtime flow.

## Output token limit (keep in sync too)

Both implementations use `maxOutputTokens: 4096` (raised from an initial
2048, which could truncate mid-response on products with long ingredient
lists -- e.g. multi-flavor instant noodles -- producing invalid JSON
instead of a parseable result). If you see "Unterminated string..." parse
errors again even at 4096, that's the same failure mode recurring -- raise
it further in both places, don't just patch one.

## Allergen vocabulary

Both must offer Gemini the exact same fixed list, so allergen values are
consistent regardless of which pipeline a product went through:

`Milk, Eggs, Fish, Shellfish, Tree Nuts, Peanuts, Wheat, Soy, Sesame`

Defined in:
- `lib/core/constants/canonical_allergens.dart` (Dart)
- `CANONICAL_ALLERGENS` constant in `tools/bulk-import/import.js` (Node)
- Should also match the admin dashboard's review checklist once Phase 4
  builds that (see main phased plan).