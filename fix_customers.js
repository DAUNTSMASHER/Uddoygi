const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function normalizeInvoices() {
  const invoices = await db.collection('invoices').get();

  for (const doc of invoices.docs) {
    const invoice = doc.data();
    const updates = {};

    // ✅ Ensure agentEmail
    if (!invoice.agentEmail && invoice.agentId) {
      const userDoc = await db.collection('users').doc(invoice.agentId).get();
      if (userDoc.exists) {
        updates.agentEmail = userDoc.data().email || '';
        updates.agentName = userDoc.data().fullName || '';
      }
    }

    // ✅ Ensure customerName
    if (!invoice.customerName && invoice.customerId) {
      const customerDoc = await db.collection('customers').doc(invoice.customerId).get();
      if (customerDoc.exists) {
        updates.customerName = customerDoc.data().name || '';
      }
    }

    // ✅ Normalize items[]
    if (Array.isArray(invoice.items)) {
      const normalizedItems = invoice.items.map(item => ({
        model: item.model || '',
        size: item.size || '',
        color: item.color || '',
        qty: Number(item.qty) || 0,
        price: Number(item.price) || 0,
        total: Number(item.total) || ((Number(item.qty) || 0) * (Number(item.price) || 0)),
      }));
      updates.items = normalizedItems;
    }

    if (Object.keys(updates).length > 0) {
      console.log(`Updating invoice ${doc.id}`);
      await doc.ref.update(updates);
    }
  }

  console.log('✅ Done updating invoices.');
}

normalizeInvoices().catch(console.error);
