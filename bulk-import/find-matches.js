// tools/bulk-import/find-matches.js
//
// Step 1 of 2 for merging legacy fda_products documents (your original
// catalog, no matching product_nutrition_data) with bulk-imported ones
// (created by import.js, DOES have matching nutrition data) that represent
// the SAME real product under two different document IDs.
//
// This script only PROPOSES candidate matches -- it writes
// merge-candidates.json for you to review and confirm by hand. It never
// touches Firestore data. Deliberately not fully automated: matching by
// name similarity can produce false positives (two different products
// with similar names) or false negatives (same product, very different
// extracted name), and a wrong merge would silently corrupt nutrition/
// allergen data for real products -- that's not something to risk on an
// unreviewed string-similarity guess.
//
// Usage: npm run find-matches
// Then:  open merge-candidates.json, for each entry set "confirmed": true
//        on the correct match (or leave/set false to skip), save.
// Then:  npm run apply-merges

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';
import admin from 'firebase-admin';

dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUTPUT_PATH = path.join(__dirname, 'merge-candidates.json');

// A legacy doc's proposed match needs at least this much token overlap
// with a bulk-import doc's name/brand to be worth showing a human at all.
// Low bar on purpose -- this is a "don't hide possible matches" threshold,
// not a "trust this automatically" threshold. Every candidate still
// requires a manual "confirmed": true before apply-merges.js touches it.
const MIN_SCORE_TO_SHOW = 0.2;
const MAX_CANDIDATES_PER_LEGACY_DOC = 3;

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

function tokenize(str) {
  return new Set(
    (str || '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, ' ')
      .split(' ')
      .filter((t) => t.length > 1), // drop single-char noise tokens
  );
}

function jaccard(setA, setB) {
  if (setA.size === 0 || setB.size === 0) return 0;
  let intersection = 0;
  for (const t of setA) if (setB.has(t)) intersection++;
  const union = setA.size + setB.size - intersection;
  return union === 0 ? 0 : intersection / union;
}

function nameKey(doc) {
  return `${doc.brand || ''} ${doc.product_name || ''}`.trim();
}

async function main() {
  console.log('Fetching all fda_products documents...\n');
  const snapshot = await db.collection('fda_products').get();
  const allDocs = snapshot.docs.map((d) => ({ id: d.id, ...d.data() }));

  const bulkDocs = allDocs.filter((d) => d.source === 'bulk_import');
  const legacyDocs = allDocs.filter((d) => d.source !== 'bulk_import');

  console.log(`Total fda_products: ${allDocs.length}`);
  console.log(`  Bulk-imported (source: "bulk_import"): ${bulkDocs.length}`);
  console.log(`  Legacy (everything else):              ${legacyDocs.length}\n`);

  if (bulkDocs.length === 0) {
    console.log('No bulk-imported documents found -- nothing to match against.');
    return;
  }
  if (legacyDocs.length === 0) {
    console.log('No legacy documents found -- nothing needs merging.');
    return;
  }

  // Only legacy docs actually missing nutrition data need a match --
  // check product_nutrition_data existence, not just "is legacy", in case
  // some legacy docs already got backfilled some other way.
  console.log('Checking which legacy docs already have nutrition data...');
  const legacyNeedingMatch = [];
  for (const doc of legacyDocs) {
    const nutritionSnap = await db.collection('product_nutrition_data').doc(doc.id).get();
    if (!nutritionSnap.exists) legacyNeedingMatch.push(doc);
  }
  console.log(
    `${legacyNeedingMatch.length} of ${legacyDocs.length} legacy docs are missing nutrition data.\n`,
  );

  const candidates = [];
  for (const legacy of legacyNeedingMatch) {
    const legacyTokens = tokenize(nameKey(legacy));
    const scored = bulkDocs
      .map((bulk) => ({
        bulk,
        score: jaccard(legacyTokens, tokenize(nameKey(bulk))),
      }))
      .filter((s) => s.score >= MIN_SCORE_TO_SHOW)
      .sort((a, b) => b.score - a.score)
      .slice(0, MAX_CANDIDATES_PER_LEGACY_DOC);

    if (scored.length === 0) {
      candidates.push({
        legacyDocId: legacy.id,
        legacyName: nameKey(legacy) || '(no name)',
        confirmed: false,
        matchedBulkDocId: null,
        note: 'NO CANDIDATES FOUND -- this product likely needs a fresh bulk-import run targeting this exact doc ID (see README: "Backfilling a specific legacy product").',
      });
      continue;
    }

    for (const { bulk, score } of scored) {
      candidates.push({
        legacyDocId: legacy.id,
        legacyName: nameKey(legacy) || '(no name)',
        matchedBulkDocId: bulk.id,
        matchedBulkName: nameKey(bulk) || '(no name)',
        similarityScore: Math.round(score * 100) / 100,
        confirmed: false, // ← set this to true for the correct match, per legacy doc
      });
    }
  }

  fs.writeFileSync(OUTPUT_PATH, JSON.stringify(candidates, null, 2));

  const withCandidates = candidates.filter((c) => c.matchedBulkDocId).length;
  const withoutCandidates = candidates.filter((c) => !c.matchedBulkDocId).length;

  console.log(`Wrote ${candidates.length} candidate row(s) to merge-candidates.json`);
  console.log(`  ${withCandidates} rows have a possible bulk-import match to review`);
  console.log(`  ${withoutCandidates} legacy doc(s) had no candidate at all\n`);
  console.log('Next steps:');
  console.log('  1. Open merge-candidates.json');
  console.log('  2. For each legacyDocId, look at its candidate row(s) and set');
  console.log('     "confirmed": true on the ONE correct match (if any) -- leave the');
  console.log('     rest as false. Only one match per legacyDocId will be applied.');
  console.log('  3. Run: npm run apply-merges');
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});