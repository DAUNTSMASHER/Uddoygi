// seedFirestore.js
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function seedFirestore() {
  try {
    // 🔹 Buyers
    const buyerRef = await db.collection('buyers').add({ name: 'Buyer One', email: 'buyer1@example.com' });

    // 🔹 Suppliers
    await db.collection('suppliers').add({ name: 'Supplier One', contact: '1234567890' });

    // 🔹 Sales
    await db.collection('sales').add({
      amount: 1000,
      buyerId: buyerRef.id,
      date: new Date().toISOString()
    });

    // 🔹 Expenses
    await db.collection('expenses').add({
      amount: 500,
      description: 'Packaging Cost',
      date: new Date().toISOString()
    });

    // 🔹 Budget
    await db.collection('budget').add({
      amount: 5000,
      year: 2025
    });

    // 🔹 Users (Workers)
    const userRef = await db.collection('users').add({
      name: 'John Worker',
      role: 'worker'
    });

    const today = new Date().toISOString().split('T')[0];

    // 🔹 Attendance
    await db.collection('attendance').add({
      userId: userRef.id,
      date: today,
      status: 'present'
    });

    // 🔹 Performance
    await db.collection('performance').add({
      userId: userRef.id,
      score: 85
    });

    // 🔹 R&D
    await db.collection('rnd_updates').add({
      title: 'New Fiber Research',
      status: 'ongoing',
      date: new Date().toISOString()
    });

    console.log('✅ Firestore data seeded successfully!');
    process.exit();
  } catch (error) {
    console.error('❌ Error seeding Firestore:', error);
    process.exit(1);
  }
}

seedFirestore();
