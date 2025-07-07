const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // 🔑 Make sure this file exists

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// 🔄 Add `createdBy` field to all documents in a collection
async function tagCollectionWithUserId(collectionName, userIdFieldName, fixedUserId) {
  const snapshot = await db.collection(collectionName).get();
  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (!data[userIdFieldName]) {
      await doc.ref.update({ [userIdFieldName]: fixedUserId });
      console.log(`✅ Updated ${collectionName}/${doc.id} with ${userIdFieldName}: ${fixedUserId}`);
    }
  }
}

async function run() {
  // 👇 Use actual agent UID (replace with real UID)
  const agentUid = 'YOUR_AGENT_UID_HERE';

  await tagCollectionWithUserId('marketing_customers', 'createdBy', agentUid);
  await tagCollectionWithUserId('marketing_sales', 'agentId', agentUid);
  await tagCollectionWithUserId('marketing_orders', 'agentId', agentUid);
  await tagCollectionWithUserId('loan_requests', 'userId', agentUid);
  await tagCollectionWithUserId('marketing_incentives', 'agentId', agentUid);
  await tagCollectionWithUserId('address_validations', 'validatedBy', agentUid);

  console.log('🎉 All missing agent fields have been updated!');
  process.exit();
}

run().catch(err => {
  console.error('❌ Error updating documents:', err);
  process.exit(1);
});
