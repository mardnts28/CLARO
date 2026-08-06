# CLARO bulk import (dev tool)

Standalone script for bulk-populating the initial product catalog from local
photos, using the same Gemini extraction approach as the app's runtime
report flow. **Not part of the Flutter app or the admin dashboard** -- runs
locally, writes directly to Firestore, no admin approval step (per the
decision to skip review for dev-phase population).

Safe to delete once you're done with initial population -- nothing else in
the system imports or depends on this folder. If you delete it, also revoke
the service account key it used (Firebase Console > Project Settings >
Service Accounts). If you'd rather keep it around for future backfills, just
make sure `.env` and `serviceAccountKey.json` stay out of version control
(already covered by `.gitignore` here).

## Setup

1. `npm install`
2. `cp .env.example .env` and fill in:
   - `GEMINI_API_KEY` -- same key as the Flutter app's `.env`
   - `GOOGLE_APPLICATION_CREDENTIALS` -- path to a Firebase service account
     JSON key (Firebase Console > Project Settings > Service Accounts >
     Generate new private key)
   - `DELAY_BETWEEN_REQUESTS_MS` -- optional, defaults to 4000 (4s) between
     Gemini calls to stay under free-tier rate limits. Raise it if you're
     still getting rate-limited; lower it if you're on a paid tier.
3. Add product photos -- see `photos/_example_product/README.md`
4. `npm run import`

## What it writes

For each product folder, creates two Firestore documents sharing the same
(slugified-folder-name) document ID:
- `fda_products` -- brand, name, category, size
- `product_nutrition_data` -- nutrition facts, ingredients, allergens

Both are marked `source: "bulk_import"` so you can distinguish them from
admin-approved user reports later if needed.

`imageURL` is left blank -- this script doesn't upload to Cloudinary. Either
backfill that field manually/via the admin dashboard, or extend this script
to upload the front photo automatically.

## Photos with nutrition facts and ingredients in different spots

Some packages print the nutrition table and ingredients list in different
places rather than one combined back panel. A product folder can have
either:
- one `back.jpg` (single combined back photo), or
- multiple `back_*.jpg` files, e.g. `back_nutrition.jpg` +
  `back_ingredients.jpg` -- any number, any names starting with `back_`

Either way, it's still **one Gemini request per product** -- extra back
photos add a bit more image data to that single call, they don't add extra
API calls, so this doesn't multiply your rate-limit usage. Don't stitch
multiple back photos into one image yourself; sending them separately
avoids any risk of blurring small print at a stitch seam, and Gemini reads
multiple images in one call natively.

## Re-running / resuming after a rate limit

Safe to re-run any time, including after being interrupted mid-batch (e.g.
hitting a free-tier quota). A product is only considered done once **both**
its `fda_products` and `product_nutrition_data` documents exist -- if a
previous run got cut off between writing the two, the next run finishes
that product instead of skipping it as "already done". If the script hits
a rate limit, it stops the batch immediately (rather than burning through
remaining folders on failed requests) and tells you to re-run later --
everything already imported stays put, and the run picks up wherever it
left off.

## Keeping this in sync with the app's extraction service

This script's prompt/JSON schema deliberately mirrors
`lib/data/services/product_extraction_service.dart` (can't reuse Dart code
in a Node script directly). If you change one, update the other -- see
`PROMPT_SCHEMA.md` for the shared contract both are expected to follow.
