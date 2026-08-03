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

## Re-running

Safe to re-run any time. Each product folder becomes a stable document ID --
already-imported folders are skipped, not duplicated or overwritten. Add new
folders and re-run to backfill just those.

## Keeping this in sync with the app's extraction service

This script's prompt/JSON schema deliberately mirrors
`lib/data/services/product_extraction_service.dart` (can't reuse Dart code
in a Node script directly). If you change one, update the other -- see
`PROMPT_SCHEMA.md` for the shared contract both are expected to follow.
