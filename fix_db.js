// fix_db.js
// Usage: node fix_db.js

const admin = require('firebase-admin');
const path  = require('path');

// Replace with the path to your service account key
const serviceAccount = require(path.join(__dirname, 'serviceAccountKey.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function seedTracking() {
  // You can change this to any identifier you like,
  // or omit .doc() to let Firestore generate one.
  const docRef = db.collection('tracking').doc('orderTrackingTemplate');

  const trackingData = {
    invoiceCreated:           false,
    paymentTaken:             false,
    submittedToFactory:       false,
    factoryUpdate1BaseDone:   false,
    hairIsReady:              false,
    knottingGoingOn:          false,
    putting:                  false,
    molding:                  false,
    submittedToHeadOffice:    false,
    addressValidation:        false,
    shippedToFedEx:           false,
    finalTrackingCode:        false
  };

  await docRef.set(trackingData);
  console.log(`✔️  Seeded tracking document with ID "${docRef.id}"`);
}

seedTracking()
  .then(() => {
    console.log('🎉 Done creating tracking collection.');
    process.exit(0);
  })
  .catch(err => {
    console.error('❌ Error seeding tracking data:', err);
    process.exit(1);
  });