const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // Replace with your key file

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Update any collection with a consistent field like createdBy or agentId
async function tagCollectionWithUser(collectionName, fieldName, userId) {
  const snapshot = await db.collection(collectionName).get();
  for (const doc of snapshot.docs) {
    const data = doc.data();
    if (!data[fieldName]) {
      await doc.ref.update({ [fieldName]: userId });
      console.log(`✅ Updated ${collectionName}/${doc.id}`);
    }
  }
}

async function run() {
  const agentId = 'REPLACE_WITH_AGENT_UID'; // 🔁 Change this UID for each agent

  await tagCollectionWithUser('marketing_customers', 'createdBy', agentId);
  await tagCollectionWithUser('marketing_sales', 'agentId', agentId);
  await tagCollectionWithUser('marketing_orders', 'agentId', agentId);
  await tagCollectionWithUser('loan_requests', 'userId', agentId);
  await tagCollectionWithUser('marketing_incentives', 'agentId', agentId);
  await tagCollectionWithUser('address_validations', 'validatedBy', agentId);

  console.log('✅ All updates done.');
  process.exit();
}

run().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
