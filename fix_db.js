// fix_db.js
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();

// The full schema & default values for every product document
const PRODUCT_FIELDS = {
  gender: '',
  model_name: '',
  size: '',
  density: '',
  curl: '',
  colour: '',
  unit_price: 0.0,
  notes: '',
  production_time: '',
  production_cost: 0.0,
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
  createdBy: ''
};

async function seedProductCollection() {
  console.log('🌱 Seeding products with IDs "1", "2", "3"...');

  for (let i = 1; i <= 3; i++) {
    const docId = i.toString();
    await db
      .collection('products')
      .doc(docId)
      .set(PRODUCT_FIELDS, { merge: true });
    console.log(` ✔️  products/${docId}`);
  }
}

async function fixExistingProducts() {
  console.log('🔧 Fixing any existing product docs...');
  const snapshot = await db.collection('products').get();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const updates = {};

    for (const [field, defaultValue] of Object.entries(PRODUCT_FIELDS)) {
      if (!data.hasOwnProperty(field)) {
        updates[field] = defaultValue;
      }
    }

    if (Object.keys(updates).length > 0) {
      await doc.ref.update(updates);
      console.log(` • ${doc.id} — added fields: ${Object.keys(updates).join(', ')}`);
    }
  }
}

async function main() {
  try {
    await seedProductCollection();
    await fixExistingProducts();
    console.log('✅ Done seeding & fixing products collection.');
  } catch (err) {
    console.error('❌ Error:', err);
  } finally {
    process.exit(0);
  }
}

main();
