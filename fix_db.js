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

async function seedAdminPayrolls() {
  // we’ll use the email as the “userId” field here:
  const userId = 'admin@ud.com';

  // two example payroll entries
  const payrolls = [
    {
      userId,
      month:       '2025-07',
      baseSalary:  8000,
      bonus:       1200,
      deductions:  300,
      netSalary:   8900,
      status:      'processed',
      processedAt: admin.firestore.Timestamp.now(),
    },
    {
      userId,
      month:       '2025-06',
      baseSalary:  8000,
      bonus:        500,
      deductions:  200,
      netSalary:   8300,
      status:      'processed',
      processedAt: admin.firestore.Timestamp.now(),
    },
  ];

  for (const p of payrolls) {
    const docRef = await db.collection('payrolls').add(p);
    console.log(`✔️  Seeded payroll (${p.month}) as doc ${docRef.id}`);
  }
}

seedAdminPayrolls()
  .then(() => {
    console.log('🎉 Done seeding admin@ud.com payroll records.');
    process.exit(0);
  })
  .catch(err => {
    console.error('❌ Error seeding payrolls:', err);
    process.exit(1);
  });
