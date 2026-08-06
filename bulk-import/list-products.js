// tools/bulk-import/list-products.js
//
// Temporary/utility script -- dumps every fda_products document into two
// local files so you can review your whole catalog at once instead of
// clicking through Firestore Console one document at a time. Read-only:
// never writes or deletes anything in Firestore.
//
// Usage: node list-products.js  (or add an npm script if you'll use this
// more than once -- see README)
//
// Writes:
//   products-list.json  -- full raw data, one object per product
//   products-list.txt   -- human-readable, sorted by name, one line each,
//                           flagging whether nutrition data exists yet

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';
import admin from 'firebase-admin';

dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const JSON_OUTPUT_PATH = path.join(__dirname, 'products-list.json');
const TXT_OUTPUT_PATH = path.join(__dirname, 'products-list.txt');

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

async function main() {
  console.log('Fetching all fda_products documents...');
  const productsSnapshot = await db.collection('fda_products').get();
  const products = productsSnapshot.docs.map((d) => ({ id: d.id, ...d.data() }));

  console.log(`Found ${products.length} products. Checking nutrition data for each...`);

  const withStatus = await Promise.all(
    products.map(async (p) => {
      const nutritionSnap = await db.collection('product_nutrition_data').doc(p.id).get();
      return { ...p, hasNutritionData: nutritionSnap.exists };
    }),
  );

  // Full raw JSON dump -- useful if you want to grep/search programmatically.
  fs.writeFileSync(JSON_OUTPUT_PATH, JSON.stringify(withStatus, null, 2));

  // Human-readable summary, sorted alphabetically by product name.
  const sorted = [...withStatus].sort((a, b) =>
    (a.product_name || '').localeCompare(b.product_name || ''),
  );

  const lines = sorted.map((p) => {
    const flag = p.hasNutritionData ? '[HAS DATA]   ' : '[NO DATA]    ';
    const name = (p.product_name || '(no name)').padEnd(45);
    const brand = (p.brand || '').padEnd(20);
    const source = p.source || 'legacy';
    return `${flag}${name} ${brand} id=${p.id}  source=${source}`;
  });

  const hasCount = withStatus.filter((p) => p.hasNutritionData).length;
  const noCount = withStatus.length - hasCount;

  const header = [
    `Total products: ${withStatus.length}`,
    `  With nutrition data: ${hasCount}`,
    `  Without nutrition data: ${noCount}`,
    '',
    '-'.repeat(100),
    '',
  ].join('\n');

  fs.writeFileSync(TXT_OUTPUT_PATH, header + lines.join('\n') + '\n');

  console.log(`\nWrote ${withStatus.length} products to:`);
  console.log(`  ${JSON_OUTPUT_PATH}`);
  console.log(`  ${TXT_OUTPUT_PATH}  <- start here, easiest to scan`);
  console.log(`\n${hasCount} have nutrition data, ${noCount} don't.`);
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});