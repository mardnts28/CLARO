// tools/bulk-import/import.js
//
// Dev-only, standalone script. NOT part of the Flutter app or the admin
// dashboard -- run locally by developers to bulk-populate the initial
// catalog from local product photos, bypassing the runtime report/admin-
// approval flow entirely (writes straight to the live collections), per
// the "skip review during dev phase" decision.
//
// Re-implements the same extraction prompt/JSON schema as
// lib/data/services/product_extraction_service.dart (the Flutter app's
// Gemini extraction service used for runtime user reports). This is a
// deliberate duplication, not an oversight -- Dart's cloud_firestore plugin
// doesn't run outside a Flutter app, so a standalone dev tool needs a
// separate Node implementation. If you change the extraction prompt/schema
// in one place, mirror the change in the other -- see PROMPT_SCHEMA.md in
// this folder for the shared contract both implementations follow.
//
// Usage:
//   1. cp .env.example .env, fill in GEMINI_API_KEY and
//      GOOGLE_APPLICATION_CREDENTIALS (path to a Firebase service account
//      JSON key -- Project Settings > Service Accounts > Generate new
//      private key in the Firebase console). Never commit this key file.
//   2. Drop photos into photos/<product-folder-name>/front.jpg and back.jpg
//      (see photos/_example_product/README.md).
//   3. npm install
//   4. npm run import
//
// Safe to re-run: each product folder name becomes a stable Firestore
// document ID, so re-running after adding new folders only imports the new
// ones -- existing products are skipped, not duplicated or overwritten.

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';
import admin from 'firebase-admin';
import { GoogleGenerativeAI } from '@google/generative-ai';

dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PHOTOS_DIR = path.join(__dirname, 'photos');

// ─── Setup ──────────────────────────────────────────────────────────────

if (!process.env.GEMINI_API_KEY) {
  console.error('Missing GEMINI_API_KEY in .env -- see .env.example');
  process.exit(1);
}
if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error(
    'Missing GOOGLE_APPLICATION_CREDENTIALS in .env (path to your Firebase ' +
      'service account JSON key) -- see .env.example',
  );
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(
    JSON.parse(fs.readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS, 'utf8')),
  ),
});
const db = admin.firestore();

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const model = genAI.getGenerativeModel({
  model: 'gemini-2.5-flash',
  generationConfig: {
    responseMimeType: 'application/json',
    temperature: 0.1,
    maxOutputTokens: 2048,
  },
});

// Mirrors lib/core/constants/canonical_allergens.dart -- keep both lists
// identical.
const CANONICAL_ALLERGENS = [
  'Milk', 'Eggs', 'Fish', 'Shellfish', 'Tree Nuts', 'Peanuts', 'Wheat',
  'Soy', 'Sesame',
];

// ─── Prompt (mirrors ProductExtractionService._buildPrompt) ───────────────

function buildPrompt() {
  return `
You are reading two photos of a packaged food product sold in the
Philippines: the FRONT of the package (first image) and the BACK/nutrition
label (second image). Extract the following as strict JSON -- no markdown
fences, no commentary, just the JSON object.

Return exactly this shape:
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

Rules:
- "category": a short product category label, e.g. "Canned Fish",
  "Instant Noodles", "Canned Meat", "Condiments" -- used to group similar
  products for comparison elsewhere in the app.
- "ingredients": split into individual items, in the order printed. Keep as
  printed (don't translate).
- "nutrition_per_100g": read values as printed. Convert per-serving values
  to per-100g using the stated serving size. Use null if a field genuinely
  isn't visible/printed -- do NOT guess or estimate.
- "allergens": only choose from this fixed list, based on the label's
  allergen statement: [${CANONICAL_ALLERGENS.join(', ')}]. Note anything
  allergen-relevant that doesn't fit this list in "confidence_notes" instead
  of inventing a new category.
- "confidence_notes": briefly flag anything unclear/blurry/ambiguous a human
  should double-check against the actual package. Empty if nothing stood out.
- If the back label is missing/unreadable, still fill in brand/product_name/
  size/category from the front photo, leave nutrition/ingredients/allergens
  empty, and say so in "confidence_notes".
`;
}

// ─── Helpers ────────────────────────────────────────────────────────────

function fileToPart(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const mimeType = ext === '.png' ? 'image/png' : 'image/jpeg';
  return {
    inlineData: {
      data: fs.readFileSync(filePath).toString('base64'),
      mimeType,
    },
  };
}

function findImage(folder, baseName) {
  for (const ext of ['.jpg', '.jpeg', '.png']) {
    const candidate = path.join(folder, `${baseName}${ext}`);
    if (fs.existsSync(candidate)) return candidate;
  }
  return null;
}

// "century_tuna_flakes_original" -> safe, stable Firestore doc ID. Also
// used as the idempotency key -- re-running the script won't duplicate a
// product whose folder was already imported.
function slugToDocId(folderName) {
  return folderName.trim().toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
}

function num(v) {
  return typeof v === 'number' ? v : 0;
}

async function extractProduct(frontPath, backPath) {
  const result = await model.generateContent([
    buildPrompt(),
    fileToPart(frontPath),
    fileToPart(backPath),
  ]);
  const text = result.response.text();
  return JSON.parse(text);
}

// ─── Main ───────────────────────────────────────────────────────────────

async function main() {
  if (!fs.existsSync(PHOTOS_DIR)) {
    console.error(`Photos folder not found: ${PHOTOS_DIR}`);
    process.exit(1);
  }

  const folders = fs
    .readdirSync(PHOTOS_DIR, { withFileTypes: true })
    .filter((d) => d.isDirectory() && !d.name.startsWith('_'))
    .map((d) => d.name);

  if (folders.length === 0) {
    console.log('No product folders found in photos/ -- nothing to import.');
    console.log('See photos/_example_product/README.md for the expected layout.');
    return;
  }

  console.log(`Found ${folders.length} product folder(s). Starting import...\n`);

  const summary = { imported: [], skipped: [], failed: [] };

  for (const folder of folders) {
    const folderPath = path.join(PHOTOS_DIR, folder);
    const docId = slugToDocId(folder);

    const frontPath = findImage(folderPath, 'front');
    const backPath = findImage(folderPath, 'back');

    if (!frontPath || !backPath) {
      console.log(`SKIP  ${folder} -- missing front and/or back image.`);
      summary.skipped.push(folder);
      continue;
    }

    const existing = await db.collection('fda_products').doc(docId).get();
    if (existing.exists) {
      console.log(`SKIP  ${folder} -- already imported (doc id: ${docId}).`);
      summary.skipped.push(folder);
      continue;
    }

    try {
      console.log(`Extracting ${folder}...`);
      const data = await extractProduct(frontPath, backPath);
      const n = data.nutrition_per_100g || {};

      // fda_products doc -- field names match FirestoreProductRepository's
      // _productFromDoc expectations.
      await db.collection('fda_products').doc(docId).set({
        product_name: data.product_name || '',
        brand: data.brand || '',
        product_category: (data.category || '').toLowerCase().replace(/\s+/g, '_'),
        registration_status: false, // not FDA-verified via this tool -- set separately if applicable
        cpr_number: '',
        available_sizes: data.size ? [data.size] : [],
        imageURL: '', // upload front photo to Cloudinary separately and backfill, if desired
        source: 'bulk_import',
        imported_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      // product_nutrition_data doc -- same doc id, field names match
      // NutritionService._mergeDataDoc expectations.
      await db.collection('product_nutrition_data').doc(docId).set({
        serving_size: data.serving_size || '',
        calories_kcal: num(n.energy_kcal),
        protein_g: num(n.protein_g),
        carbs_g: num(n.carbs_g),
        fat_total_g: num(n.fat_total_g),
        fat_saturated_g: num(n.fat_saturated_g),
        fat_trans_g: num(n.fat_trans_g),
        sodium_mg: num(n.sodium_mg),
        potassium_mg: num(n.potassium_mg),
        calcium_mg: num(n.calcium_mg),
        iron_mg: num(n.iron_mg),
        fiber_g: num(n.fiber_g),
        sugars_g: num(n.sugars_g),
        added_sugars_g: num(n.added_sugars_g),
        allergens: data.allergens || [],
        ingredients: data.ingredients || [],
        source: 'bulk_import',
        imported_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      const notes = data.confidence_notes ? ` (note: ${data.confidence_notes})` : '';
      console.log(`OK    ${folder} -> ${docId}${notes}`);
      summary.imported.push(folder);
    } catch (err) {
      console.error(`FAIL  ${folder} -- ${err.message}`);
      summary.failed.push({ folder, error: err.message });
    }
  }

  console.log('\n--- Summary ---');
  console.log(`Imported: ${summary.imported.length}`);
  console.log(`Skipped:  ${summary.skipped.length}`);
  console.log(`Failed:   ${summary.failed.length}`);
  if (summary.failed.length > 0) {
    console.log('\nFailed products (re-run the script to retry these):');
    summary.failed.forEach((f) => console.log(`  - ${f.folder}: ${f.error}`));
  }
  console.log(
    '\nNote: imageURL was left blank for every imported product -- upload ' +
      'the front photos to Cloudinary and backfill that field separately, ' +
      'or extend this script to do so automatically.',
  );
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
