const admin = require('firebase-admin');
const fs = require('fs');

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function listCollectionsAndFields() {
  const collections = await db.listCollections();
  const result = {};

  for (const col of collections) {
    const colName = col.id;
    result[colName] = [];

    const snapshot = await col.limit(5).get(); // Sample max 5 docs
    snapshot.forEach(doc => {
      const data = doc.data();
      const fields = Object.keys(data);
      result[colName].push({
        docId: doc.id,
        fields
      });
    });
  }

  // Convert to readable YAML-like string
  let output = '';
  for (const [collection, docs] of Object.entries(result)) {
    output += `- ${collection}:\n`;
    docs.forEach(doc => {
      output += `  - ${doc.docId}:\n`;
      doc.fields.forEach(field => {
        output += `      - ${field}\n`;
      });
    });
  }

  fs.writeFileSync('firestore_structure.yaml', output);
  console.log('✅ Structure saved to firestore_structure.yaml');
}

listCollectionsAndFields();
