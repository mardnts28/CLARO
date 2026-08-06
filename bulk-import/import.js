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
//   2. Drop photos into photos/<product-folder-name>/ -- see
//      photos/_example_product/README.md for the exact filename rules
//      (front.jpg is required; the back label can be one back.jpg OR
//      several back_*.jpg files if nutrition/ingredients are printed in
//      separate places on the package).
//   3. npm install
//   4. npm run import
//
// Safe to re-run, including after a partial/interrupted run (e.g. hitting
// a free-tier rate limit mid-batch): each product folder name becomes a
// stable Firestore document ID, and a product is only ever considered
// "done" once BOTH its fda_products and product_nutrition_data documents
// exist -- re-running only (re)processes folders that are missing either
// one, so an interrupted run never leaves a half-imported product stuck
// looking "done". Already-complete products are skipped without calling
// Gemini again.

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';
import admin from 'firebase-admin';
import { GoogleGenerativeAI } from '@google/generative-ai';

dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PHOTOS_DIR = path.join(__dirname, 'photos');

// Free-tier pacing: gap between consecutive Gemini calls, to stay under
// per-minute rate limits rather than firing 62 requests back-to-back.
// Override in .env if your tier/limits differ.
const DELAY_BETWEEN_REQUESTS_MS =
  Number(process.env.DELAY_BETWEEN_REQUESTS_MS) || 4000;

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
    // 2048 was too tight -- products with long ingredient lists (e.g.
    // multi-flavor instant noodles with many seasoning/additive
    // components) could get cut off mid-response, producing invalid JSON
    // ("Unterminated string..." from JSON.parse) rather than a usable
    // result. 4096 gives real headroom without meaningfully raising cost
    // (Gemini bills on tokens actually used, not the ceiling).
    maxOutputTokens: 4096,
  },
});

// Mirrors lib/core/constants/canonical_allergens.dart -- keep both lists
// identical.
const CANONICAL_ALLERGENS = [
  'Milk', 'Eggs', 'Fish', 'Shellfish', 'Tree Nuts', 'Peanuts', 'Wheat',
  'Soy', 'Sesame',
];

// ─── Prompt (mirrors ProductExtractionService._buildPrompt) ───────────────
// [numBackImages] varies per product -- some packages print nutrition
// facts and the ingredients list in different spots, so a folder may
// contribute 1 back photo or several. Gemini reads all of them in the same
// call regardless (this is a single request either way -- what matters for
// rate limits is requests, not images per request), so the prompt just
// needs to say "one or more" rather than assuming exactly one.

function buildPrompt(numBackImages, allowParaphrase = false) {
  const backDescription =
    numBackImages === 1
      ? 'the BACK of the package (second image), showing the nutrition label and/or ingredients list'
      : `${numBackImages} additional photos covering the BACK of the package -- nutrition facts and ingredients may be split across these photos rather than in one shot`;

  // Default wording asks for exact transcription, which occasionally
  // triggers Gemini's RECITATION safety filter if this product's label
  // text happens to closely match something published online that the
  // model recognizes from training. The paraphrase-permitting variant is
  // only used as an automatic retry after a RECITATION block -- normal
  // runs always use the strict version, since exact wording matters (this
  // is nutrition/allergen data).
  const ingredientsRule = allowParaphrase
    ? `- "ingredients": list each item you can identify from the label, in the
  order printed. Prioritize accuracy over exact wording -- if reproducing
  the exact printed phrasing is problematic, use a clear equivalent
  description instead (e.g. "wheat flour" rather than a distinctive
  marketing phrase around it), but never omit or invent an ingredient.`
    : `- "ingredients": split into individual items, in the order printed. Keep as
  printed (don't translate).`;

  return `
You are reading photos of a packaged food product sold in the Philippines:
the FRONT of the package (first image), and ${backDescription}. Extract the
following as strict JSON -- no markdown fences, no commentary, just the
JSON object.

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
${ingredientsRule}
  If the ingredients list appears in one of the back photos and nutrition
  facts in another, combine what you find across all provided photos into
  this single field.
- "nutrition_per_100g": read values as printed, from whichever back photo
  shows the nutrition table. Convert per-serving values to per-100g using
  the stated serving size. Use null if a field genuinely isn't visible/
  printed -- do NOT guess or estimate.
- "allergens": only choose from this fixed list, based on the label's
  allergen statement: [${CANONICAL_ALLERGENS.join(', ')}]. Note anything
  allergen-relevant that doesn't fit this list in "confidence_notes" instead
  of inventing a new category.
- "confidence_notes": briefly flag anything unclear/blurry/ambiguous a human
  should double-check against the actual package. Empty if nothing stood out.
- If none of the back photos are readable, still fill in brand/product_name/
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

const IMAGE_EXTS = ['.jpg', '.jpeg', '.png'];

function findImage(folder, baseName) {
  for (const ext of IMAGE_EXTS) {
    const candidate = path.join(folder, `${baseName}${ext}`);
    if (fs.existsSync(candidate)) return candidate;
  }
  return null;
}

// Supports two layouts per product folder:
//   - a single back.jpg/back.jpeg/back.png, OR
//   - any number of back_*.jpg files (e.g. back_nutrition.jpg,
//     back_ingredients.jpg) when the label's info is split across photos.
// Returns [] if neither pattern matches -- caller treats that as "missing".
function findBackImages(folder) {
  const single = findImage(folder, 'back');
  if (single) return [single];

  return fs
    .readdirSync(folder)
    .filter((f) => /^back_.+/i.test(f) && IMAGE_EXTS.includes(path.extname(f).toLowerCase()))
    .sort() // deterministic order across runs
    .map((f) => path.join(folder, f));
}

// "century_tuna_flakes_original" -> safe, stable Firestore doc ID. Also
// used as the idempotency key -- re-running the script won't duplicate a
// product whose folder was already imported.
function slugToDocId(folderName) {
  return folderName.trim().toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
}

// Backfilling a specific legacy product (see find-matches.js /
// apply-merges.js): drop an optional target_id.txt file inside the
// product's folder containing the EXACT existing fda_products document ID
// you want this photo set written to, instead of a fresh slugified-folder-
// name ID. Lets you re-photograph a legacy product that never got a
// bulk-import match and write straight into its existing document rather
// than creating yet another duplicate. Falls back to the normal slug
// behavior if the file isn't present.
function resolveDocId(folderPath, folderName) {
  const overridePath = path.join(folderPath, 'target_id.txt');
  if (fs.existsSync(overridePath)) {
    const targetId = fs.readFileSync(overridePath, 'utf8').trim();
    if (targetId) return targetId;
  }
  return slugToDocId(folderName);
}

function num(v) {
  return typeof v === 'number' ? v : 0;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Gemini/Google API client errors carry a numeric `status` (HTTP-style) or
// a `.status` string like "RESOURCE_EXHAUSTED" depending on SDK version --
// check both rather than relying on message text alone.
function isRateLimitError(err) {
  const status = err?.status ?? err?.code;
  const msg = (err?.message || '').toLowerCase();
  return (
    status === 429 ||
    status === 'RESOURCE_EXHAUSTED' ||
    msg.includes('quota') ||
    msg.includes('rate limit')
  );
}

// RECITATION is a separate safety mechanism from rate limiting -- it fires
// when Gemini judges its own output too close to text it recognizes from
// training data. Can genuinely false-positive on an ordinary product label
// if that product's ingredients/nutrition facts are already published
// somewhere online (retailer page, manufacturer site, review blog) and the
// model treats "read this photo verbatim" as reproducing that memorized
// text. Not something a longer maxOutputTokens or a pacing delay fixes --
// needs a different prompt framing instead (see buildPrompt's
// `allowParaphrase` param below).
function isRecitationError(err) {
  return (err?.message || '').includes('RECITATION');
}

async function extractProduct(frontPath, backPaths, allowParaphrase = false) {
  const result = await model.generateContent([
    buildPrompt(backPaths.length, allowParaphrase),
    fileToPart(frontPath),
    ...backPaths.map(fileToPart),
  ]);
  const text = result.response.text();
  try {
    return JSON.parse(text);
  } catch (parseErr) {
    // Re-throw with the raw response attached so the caller can log it --
    // a bare "Unterminated string..." message alone doesn't tell you
    // whether the response was truncated (hit maxOutputTokens mid-string)
    // or genuinely malformed. Seeing the tail of the raw text usually
    // makes that obvious at a glance.
    const snippet = text.length > 300 ? `...${text.slice(-300)}` : text;
    parseErr.rawResponseSnippet = snippet;
    throw parseErr;
  }
}

// A product only counts as already done if BOTH documents exist -- if a
// previous run got interrupted (e.g. rate-limited) between writing
// fda_products and product_nutrition_data, this makes sure the incomplete
// one gets finished on the next run instead of being skipped forever.
async function isAlreadyImported(docId) {
  const [productSnap, nutritionSnap] = await Promise.all([
    db.collection('fda_products').doc(docId).get(),
    db.collection('product_nutrition_data').doc(docId).get(),
  ]);
  return productSnap.exists && nutritionSnap.exists;
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
  let stoppedForQuota = false;

  for (const folder of folders) {
    const folderPath = path.join(PHOTOS_DIR, folder);
    const docId = resolveDocId(folderPath, folder);

    const frontPath = findImage(folderPath, 'front');
    const backPaths = findBackImages(folderPath);

    if (!frontPath || backPaths.length === 0) {
      console.log(`SKIP  ${folder} -- missing front and/or back image(s).`);
      summary.skipped.push(folder);
      continue;
    }

    if (await isAlreadyImported(docId)) {
      console.log(`SKIP  ${folder} -- already fully imported (doc id: ${docId}).`);
      summary.skipped.push(folder);
      continue;
    }

    try {
      const backLabel = backPaths.length > 1 ? `${backPaths.length} back photos` : 'back photo';
      console.log(`Extracting ${folder} (front + ${backLabel})...`);
      let data;
      try {
        data = await extractProduct(frontPath, backPaths);
      } catch (err) {
        if (!isRecitationError(err)) throw err;
        // RECITATION false-positives are usually specific to the exact
        // "transcribe verbatim" framing, not the image itself -- retry
        // once immediately with a softened prompt before giving up on
        // this product for the run.
        console.log(`      RECITATION block on ${folder} -- retrying with a softened prompt...`);
        data = await extractProduct(frontPath, backPaths, /* allowParaphrase */ true);
      }
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
      if (isRateLimitError(err)) {
        console.error(
          `\nRATE LIMIT / QUOTA hit while processing "${folder}": ${err.message}\n` +
            'Stopping here rather than burning through the rest of the batch on ' +
            'failed requests. Everything imported so far is saved. Just re-run ' +
            '"npm run import" later (e.g. after your quota resets) -- already-' +
            'imported products will be skipped automatically and this run will ' +
            'pick up where it left off.\n',
        );
        stoppedForQuota = true;
        break;
      }
      if (isRecitationError(err)) {
        console.error(
          `FAIL  ${folder} -- blocked by RECITATION even after the softened-prompt ` +
            'retry. This product\'s label text likely matches something Gemini ' +
            'recognizes from training data. Consider entering this one product\'s ' +
            'data manually in Firestore Console rather than continuing to retry.',
        );
        summary.failed.push({ folder, error: err.message });
        await sleep(DELAY_BETWEEN_REQUESTS_MS);
        continue;
      }
      console.error(`FAIL  ${folder} -- ${err.message}`);
      if (err.rawResponseSnippet) {
        console.error(`      Raw response tail: ${err.rawResponseSnippet}`);
      }
      summary.failed.push({ folder, error: err.message });
    }

    // Pace requests to stay under free-tier per-minute limits. Only needed
    // after an actual Gemini call, not after a skip (no call was made).
    await sleep(DELAY_BETWEEN_REQUESTS_MS);
  }

  console.log('\n--- Summary ---');
  console.log(`Imported: ${summary.imported.length}`);
  console.log(`Skipped:  ${summary.skipped.length}`);
  console.log(`Failed:   ${summary.failed.length}`);
  if (summary.failed.length > 0) {
    console.log('\nFailed products (re-run the script to retry these):');
    summary.failed.forEach((f) => console.log(`  - ${f.folder}: ${f.error}`));
  }
  if (stoppedForQuota) {
    const remaining = folders.length - summary.imported.length - summary.skipped.length - summary.failed.length;
    console.log(`\nStopped early due to rate limiting -- ${remaining} folder(s) not yet attempted.`);
    console.log('Re-run "npm run import" once your quota resets to continue.');
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