// fix_db.js
// Script to backfill "agentEmail" field in all work_orders docs

const admin = require('firebase-admin');
const path  = require('path');

// Initialize Firebase Admin with your service account
admin.initializeApp({
  credential: admin.credential.cert(require(path.join(__dirname, 'serviceAccountKey.json'))),
});

const db = admin.firestore();

async function backfillAgentEmail() {
  const collectionRef = db.collection('work_orders');
  const snapshot = await collectionRef.get();

  if (snapshot.empty) {
    console.log('No work_orders documents found.');
    return;
  }

  let batch = db.batch();
  let count = 0;

  snapshot.docs.forEach(doc => {
    const docRef = collectionRef.doc(doc.id);
    batch.update(docRef, { agentEmail: 'herok@wigbd.com' });
    count += 1;

    // Firestore batch limit is 500; commit and reset if we hit it
    if (count % 500 === 0) {
      batch.commit();
      batch = db.batch();
    }
  });

  // commit any remaining updates
  await batch.commit();
  console.log(`✅ Updated agentEmail on ${count} work_orders documents.`);
}

backfillAgentEmail()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error during backfill:', err);
    process.exit(1);
  });
