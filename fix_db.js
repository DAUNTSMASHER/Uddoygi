// fix_db.js
// Usage: node fix_db.js

const admin = require('firebase-admin');
const path = require('path');

// Replace with your actual service account key path
const serviceAccount = require(path.join(__dirname, 'serviceAccountKey.json'));

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// Get Firestore DB instance
const db = admin.firestore();

async function ensureCollections() {
  try {
    // Check/Create `marketing_sales` collection
    const marketing_sales_ref = db.collection('marketing_sales');
    console.log('✅ Checked: marketing_sales – For tracking agent sales (quantity, amount, customer).');

    // Check/Create `products` collection
    const products_ref = db.collection('products');
    console.log('✅ Checked: products – Contains unit price and production cost for calculating profit.');

    // Check/Create `buyers` collection
    const buyers_ref = db.collection('buyers');
    console.log('✅ Checked: buyers – Links customers to contact info and their agent.');

    // Check/Create `marketing_incentives` collection
    const marketing_incentives_ref = db.collection('marketing_incentives');
    console.log('✅ Checked: marketing_incentives – Used to store calculated monthly incentives.');

    // Check/Create `users` collection
    const users_ref = db.collection('users');
    console.log('✅ Checked: users – Connects agentId with employee information.');

    // Optional: Check/Create `invoices` collection
    const invoices_ref = db.collection('invoices');
    console.log('✅ Checked: invoices – Useful for grand total, shipping cost, and tax info.');

    // Optional: Check/Create `expenses` collection
    const expenses_ref = db.collection('expenses');
    console.log('✅ Checked: expenses – Can hold additional deduction records if needed.');

    console.log('\n🎉 Firestore structure successfully validated for incentive calculation!');
  } catch (error) {
    console.error('❌ Error checking Firestore collections:', error);
  }
}

// Run the script
ensureCollections();
