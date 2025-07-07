// fix_db.js
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function seedRecommendationCollection() {
  const template = {
    // Basic user info fields
    fullName: '',
    name: '',
    personalEmail: '',
    personalPhone: '',
    governmentIdUrl: '',
    profilePhotoUrl: '',
    // Certificate & document URLs
    cvUrl: '',
    ndaUrl: '',
    employmentContractUrl: '',
    workPermitUrl: '',
    taxFormUrl: '',
    certifications: [],      // array of strings
    trainingRecords: [],     // array of strings
    previousEmployers: [],   // array of strings
    probationReviews: [],    // array of strings

    // Recommendation-specific fields
    recommendation: '',
    createdAt: admin.firestore.Timestamp.now(),
    status: 'Pending',       // 'Pending', 'Approved', or 'Rejected'
    reasons: '',
    sentToCEO: false
  };

  const docRef = await db.collection('recommendation').add(template);
  console.log(`Created recommendation doc with ID: ${docRef.id}`);
}

async function fixExistingRecommendations() {
  const snapshot = await db.collection('recommendation').get();
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const updates = {};

    // Ensure basic user info fields exist
    ['fullName','name','personalEmail','personalPhone','governmentIdUrl','profilePhotoUrl'].forEach(fld => {
      if (!data.hasOwnProperty(fld)) updates[fld] = '';
    });

    // Ensure document/cert URL arrays exist
    ['cvUrl','ndaUrl','employmentContractUrl','workPermitUrl','taxFormUrl'].forEach(fld => {
      if (!data.hasOwnProperty(fld)) updates[fld] = '';
    });

    // Ensure array fields exist
    ['certifications','trainingRecords','previousEmployers','probationReviews'].forEach(fld => {
      if (!data.hasOwnProperty(fld)) updates[fld] = [];
    });

    // Recommendation fields
    if (!data.hasOwnProperty('recommendation'))    updates.recommendation = '';
    if (!data.hasOwnProperty('createdAt'))         updates.createdAt = admin.firestore.Timestamp.now();
    if (!data.hasOwnProperty('status'))            updates.status = 'Pending';
    if (!data.hasOwnProperty('reasons'))           updates.reasons = '';
    if (!data.hasOwnProperty('sentToCEO'))         updates.sentToCEO = false;

    if (Object.keys(updates).length > 0) {
      await doc.ref.update(updates);
      console.log(`Updated ${doc.id}: added fields ${Object.keys(updates).join(', ')}`);
    }
  }
}

async function main() {
  await seedRecommendationCollection();
  await fixExistingRecommendations();
  console.log('Recommendation collection seeded and existing docs fixed.');
  process.exit(0);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
