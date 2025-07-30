const admin = require("firebase-admin");
const fs = require("fs");

// 🔐 Replace with your service account key file path
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function patchMissingRowsInSalesReports() {
  const colRef = db.collection("marketing_incentives");
  const snapshot = await colRef.get();

  const defaultRows = [
    {
      productName: "All Skin",
      quantity: 10,
      sellingPrice: 200,
      purchaseCost: 100,
    },
    {
      productName: "Mono Regular",
      quantity: 5,
      sellingPrice: 220,
      purchaseCost: 140,
    },
  ];

  const batch = db.batch();

  snapshot.forEach((doc) => {
    const docId = doc.id;

    // 🔍 Only apply to documents ending with "_sales"
    if (!docId.endsWith("_sales")) return;

    const data = doc.data();
    const hasRows = Array.isArray(data.rows) && data.rows.length > 0;

    if (!hasRows) {
      const ref = colRef.doc(docId);
      batch.update(ref, { rows: defaultRows });
      console.log(`✅ Patched: ${docId}`);
    } else {
      console.log(`✔️ Already has rows: ${docId}`);
    }
  });

  if (batch._ops.length === 0) {
    console.log("🎉 All sales reports are already patched.");
  } else {
    await batch.commit();
    console.log("✅ Missing rows added to unpatched sales reports.");
  }
}

patchMissingRowsInSalesReports().catch(console.error);
