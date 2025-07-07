const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function setupMarketingData() {
  // 🧾 Sample customer (lead/confirmed)
  await db.collection('marketing_customers').add({
    name: 'John Doe',
    status: 'lead', // or 'confirmed'
    address: '123 Street, City',
    email: 'john@example.com',
    phone: '018xxxxxxxx',
    createdBy: 'AGENT_UID'
  });

  // 🧾 Sales invoice
  await db.collection('marketing_sales').add({
    customerId: 'CUSTOMER_ID',
    agentId: 'AGENT_UID',
    amount: 3000,
    date: new Date().toISOString(),
    status: 'pending',
    paymentProofUrl: '',
    approvedByHR: false
  });

  // 🧾 Agent goal
  await db.collection('marketing_goals').add({
    agentId: 'AGENT_UID',
    month: '2025-07',
    targetAmount: 10000,
    achievedAmount: 3000,
    incentiveEligible: false
  });

  // 🧾 Incentive
  await db.collection('marketing_incentives').add({
    agentId: 'AGENT_UID',
    month: '2025-07',
    amount: 1500,
    approved: true
  });

  // 🧾 Work order
  await db.collection('marketing_orders').add({
    agentId: 'AGENT_UID',
    clientName: 'Jane',
    description: 'Custom wig system',
    status: 'order_placed', // use enum logic in frontend
    updatedByFactory: false
  });

  // 🧾 Task assignment
  await db.collection('marketing_tasks').add({
    assignedBy: 'SENIOR_UID',
    assignedTo: 'JUNIOR_UID',
    description: 'Follow-up client',
    proofUrl: '',
    status: 'pending'
  });

  // 🧾 Campaign proposal (only head)
  await db.collection('marketing_campaigns').add({
    title: 'New Summer Sale',
    submittedBy: 'HEAD_UID',
    status: 'pending', // or 'approved_by_ceo', 'rejected'
    toHR: false
  });

  // 🧾 Address validation record
  await db.collection('address_validations').add({
    clientEmail: 'jane@example.com',
    status: 'awaiting_reply', // or 'confirmed'
    trackingNumber: '',
    validatedBy: 'AGENT_UID'
  });

  // 🔄 Update users with joining date & goal field (example)
  const userRef = db.collection('users').doc('AGENT_UID');
  await userRef.set({
    joiningDate: new Date('2024-06-01').toISOString(),
    goalAmount: 10000,
    fullName: 'Agent One'
  }, { merge: true });

  console.log('✅ Marketing module collections & fields created!');
  process.exit();
}

setupMarketingData();
