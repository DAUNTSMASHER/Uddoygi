const admin = require('firebase-admin');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

// ✅ Initialize Firebase Admin with your downloaded key
const serviceAccount = require('./serviceAccountKey.json'); // path to your JSON key

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = getFirestore();

// ✅ Sample invoice data
const createSampleInvoice = async () => {
  const invoiceData = {
    agentEmail: 'agent01@example.com', // must match logged-in user's email
    customerName: 'Mr. Rahman',
    timestamp: Timestamp.now(),
    shippingCost: 100,
    tax: 200,
    grandTotal: 1800, // (auto calculated in app, optional here)
    items: [
      {
        model: 'BMW Regular',
        size: '8x10',
        color: '1B',
        quantity: 1,
        unitPrice: 500,
        totalPrice: 500, // qty * unitPrice
      },
      {
        model: 'Hollywood',
        size: '9x7',
        color: '1B-30',
        quantity: 1,
        unitPrice: 500,
        totalPrice: 500,
      }
    ],
    submitted: true
  };

  const ref = await db.collection('invoices').add(invoiceData);
  console.log(`✅ Invoice created with ID: ${ref.id}`);
};

// Run the function
createSampleInvoice().catch(console.error);
