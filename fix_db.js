// fix_db.js
// Backfill userId & userEmail into loan repayment subcollections.
// Run: node fix_db.js

const admin = require('firebase-admin');

// serviceAccountKey.json = a service account with Firestore access
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

// ───────────────────────── Safety ─────────────────────────
if (process.env.CONFIRM !== 'DELETE') {
  console.error('Refusing to run without explicit confirmation.');
  console.error('Run again with: CONFIRM=DELETE node delete_loans_all.js');
  process.exit(1);
}

// ───────────────────── Helper functions ───────────────────
const ROOT_COLLECTION = 'loans';
const PAGE_SIZE = 200;     // page size for scanning docs
const CONCURRENCY = 10;    // how many docs to delete in parallel per page

async function deleteCollectionRecursively(collRef) {
  // We can’t batch-delete a collection in one call; we page through it.
  while (true) {
    const snap = await collRef.limit(PAGE_SIZE).get();
    if (snap.empty) break;

    // Process in limited parallelism to avoid overloading
    for (let i = 0; i < snap.docs.length; i += CONCURRENCY) {
      const chunk = snap.docs.slice(i, i + CONCURRENCY);
      await Promise.all(chunk.map(d => recursiveDeleteDoc(d.ref)));
    }
  }
}

async function recursiveDeleteDoc(docRef) {
  // Delete subcollections first
  const subcols = await docRef.listCollections();
  for (const sub of subcols) {
    await deleteCollectionRecursively(sub);
  }
  // Then delete the doc itself
  await docRef.delete();
}

(async () => {
  console.log(`Starting full recursive delete of "${ROOT_COLLECTION}"…`);
  const root = db.collection(ROOT_COLLECTION);

  // Optional: quick count (approximate) before delete
  const firstPage = await root.limit(1).get();
  if (firstPage.empty) {
    console.log('Collection is already empty.');
    process.exit(0);
  }

  await deleteCollectionRecursively(root);

  console.log('✅ Completed recursive delete of "loans". All data removed.');
  process.exit(0);
})().catch(err => {
  console.error('❌ Delete failed:', err);
  process.exit(1);
});