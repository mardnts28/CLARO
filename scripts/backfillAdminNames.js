// Backfill adminName field on activity_logs using Firebase Admin SDK.
// Usage:
// 1. Place a service account JSON at the path in SERVICE_ACCOUNT (or set
//    the SERVICE_ACCOUNT env var to its path).
// 2. Run: node scripts/backfillAdminNames.js

import fs from 'fs';
import admin from 'firebase-admin';

const SERVICE_ACCOUNT = process.env.SERVICE_ACCOUNT || './serviceAccountKey.json';

if (!fs.existsSync(SERVICE_ACCOUNT)) {
  console.error('Service account JSON not found at', SERVICE_ACCOUNT);
  process.exit(1);
}

const serviceAccount = JSON.parse(fs.readFileSync(SERVICE_ACCOUNT, 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function backfill(batchSize = 500) {
  console.log('Starting backfill...');
  const snapshot = await db.collection('activity_logs').get();
  console.log(`Found ${snapshot.size} activity log documents`);

  let updates = [];
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const adminUid = data.adminUid;
    const hasName = data.adminName && data.adminName !== data.adminUid && data.adminName !== data.adminEmail;
    if (!adminUid || hasName) continue;

    try {
      const adminDoc = await db.collection('admins').doc(adminUid).get();
      if (adminDoc.exists) {
        const adminData = adminDoc.data();
        const name = adminData?.name || null;
        if (name) {
          updates.push({ id: doc.id, name });
        }
      }
    } catch (e) {
      console.error('Error reading admin doc for', adminUid, e.message || e);
    }
  }

  console.log(`Will update ${updates.length} documents`);
  while (updates.length) {
    const batch = db.batch();
    const chunk = updates.splice(0, batchSize);
    for (const u of chunk) {
      const ref = db.collection('activity_logs').doc(u.id);
      batch.update(ref, { adminName: u.name });
    }
    await batch.commit();
    console.log(`Committed ${chunk.length} updates`);
  }

  console.log('Backfill complete.');
}

backfill().catch((err) => {
  console.error('Backfill failed:', err);
  process.exitCode = 1;
});
