// tools/bulk-import/apply-merges.js
//
// Step 2 of 2. Reads merge-candidates.json (produced by find-matches.js,
// after you've hand-reviewed it and set "confirmed": true on the correct
// matches) and actually performs the merge:
//
//   1. Copies product_nutrition_data/{bulkDocId} -> product_nutrition_data/{legacyDocId}
//   2. Fills in any BLANK fields on fda_products/{legacyDocId} using the
//      bulk doc's values (never overwrites a legacy field that already has
//      a value -- e.g. your legacy doc's existing imageURL/cpr_number win)
//   3. Deletes fda_products/{bulkDocId} and product_nutrition_data/{bulkDocId}
//
// End result: one document per product, keyed by the ORIGINAL legacy doc
// ID (so anything already referencing it -- history, favorites -- keeps
// working), now with real nutrition data attached.
//
// Only rows with "confirmed": true are touched. Rows left false are
// skipped entirely, no exceptions.

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';
import admin from 'firebase-admin';

dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CANDIDATES_PATH = path.join(__dirname, 'merge-candidates.json');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error(
    'Missing GOOGLE_APPLICATION_CREDENTIALS in .env -- see .env.example',
  );
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(
    JSON.parse(fs.readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS, 'utf8')),
  ),
});
const db = admin.firestore();

function isBlank(v) {
  if (v === undefined || v === null) return true;
  if (typeof v === 'string') return v.trim() === '';
  if (Array.isArray(v)) return v.length === 0;
  return false;
}

async function main() {
  if (!fs.existsSync(CANDIDATES_PATH)) {
    console.error(
      'merge-candidates.json not found -- run "npm run find-matches" first.',
    );
    process.exit(1);
  }

  const candidates = JSON.parse(fs.readFileSync(CANDIDATES_PATH, 'utf8'));

  // Group by legacyDocId so we can catch the "more than one confirmed
  // match for the same legacy doc" mistake before touching anything.
  const byLegacyId = {};
  for (const row of candidates) {
    if (!row.matchedBulkDocId) continue; // "no candidates found" rows
    (byLegacyId[row.legacyDocId] ||= []).push(row);
  }

  const toApply = [];
  const problems = [];

  for (const [legacyDocId, rows] of Object.entries(byLegacyId)) {
    const confirmed = rows.filter((r) => r.confirmed === true);
    if (confirmed.length === 0) continue; // nothing confirmed, skip silently
    if (confirmed.length > 1) {
      problems.push(
        `${legacyDocId}: ${confirmed.length} rows marked confirmed -- expected exactly 1. Skipping this one, fix the file and re-run.`,
      );
      continue;
    }
    toApply.push({ legacyDocId, bulkDocId: confirmed[0].matchedBulkDocId });
  }

  if (problems.length > 0) {
    console.log('--- Problems found (these were skipped) ---');
    problems.forEach((p) => console.log(`  ${p}`));
    console.log('');
  }

  if (toApply.length === 0) {
    console.log('No confirmed merges to apply. Nothing to do.');
    return;
  }

  console.log(`Applying ${toApply.length} confirmed merge(s)...\n`);

  let done = 0;
  let failed = 0;

  for (const { legacyDocId, bulkDocId } of toApply) {
    try {
      const [legacyProductSnap, bulkProductSnap, bulkNutritionSnap] = await Promise.all([
        db.collection('fda_products').doc(legacyDocId).get(),
        db.collection('fda_products').doc(bulkDocId).get(),
        db.collection('product_nutrition_data').doc(bulkDocId).get(),
      ]);

      if (!legacyProductSnap.exists) {
        console.error(`FAIL  ${legacyDocId} -- legacy fda_products doc no longer exists, skipping.`);
        failed++;
        continue;
      }
      if (!bulkProductSnap.exists || !bulkNutritionSnap.exists) {
        console.error(`FAIL  ${bulkDocId} -- bulk-import doc(s) no longer exist, skipping.`);
        failed++;
        continue;
      }

      const legacyProduct = legacyProductSnap.data();
      const bulkProduct = bulkProductSnap.data();
      const bulkNutrition = bulkNutritionSnap.data();

      // 1. Copy nutrition data onto the legacy doc's ID.
      await db.collection('product_nutrition_data').doc(legacyDocId).set(bulkNutrition);

      // 2. Fill in blanks on the legacy fda_products doc from the bulk
      // doc -- never overwrite a legacy value that's already set.
      const fillableFields = [
        'product_name', 'brand', 'product_category', 'available_sizes', 'imageURL',
      ];
      const patch = {};
      for (const field of fillableFields) {
        if (isBlank(legacyProduct[field]) && !isBlank(bulkProduct[field])) {
          patch[field] = bulkProduct[field];
        }
      }
      patch.mergedFromBulkImportId = bulkDocId;
      patch.mergedAt = admin.firestore.FieldValue.serverTimestamp();
      await db.collection('fda_products').doc(legacyDocId).update(patch);

      // 3. Remove the now-redundant bulk-import documents.
      await db.collection('fda_products').doc(bulkDocId).delete();
      await db.collection('product_nutrition_data').doc(bulkDocId).delete();

      console.log(`OK    ${legacyDocId}  <-  merged from ${bulkDocId}`);
      done++;
    } catch (err) {
      console.error(`FAIL  ${legacyDocId} -- ${err.message}`);
      failed++;
    }
  }

  console.log(`\n--- Summary ---`);
  console.log(`Merged: ${done}`);
  console.log(`Failed: ${failed}`);
  console.log(
    '\nRe-run "npm run find-matches" afterward if you want to confirm no ' +
      'unmatched legacy docs remain, or to check remaining candidates.',
  );
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});