/**
 * fix_db.js
 * Creates:
 *   - `ledger` collection with example journal entries
 *   - `expenses` collection with example company expenses
 */

const admin = require("firebase-admin");

// 🔐 Replace with your Firebase service account JSON path
const serviceAccount = require("./serviceAccountKey.json");

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}
const db = admin.firestore();

/* -------------------- Seed Ledger -------------------- */
async function seedLedger() {
  const examples = [
    {
      account: "Cash",
      description: "Opening balance",
      date: admin.firestore.Timestamp.fromDate(new Date("2025-08-01")),
      debit: 100000,
      credit: 0,
      journalId: "JRN-OPEN-001",
    },
    {
      account: "Owner’s Equity",
      description: "Opening balance",
      date: admin.firestore.Timestamp.fromDate(new Date("2025-08-01")),
      debit: 0,
      credit: 100000,
      journalId: "JRN-OPEN-001",
    },
  ];

  for (const line of examples) {
    const ref = db.collection("ledger").doc();
    await ref.set({
      account: line.account,
      description: line.description,
      date: line.date,
      debit: line.debit,
      credit: line.credit,
      journalId: line.journalId,
      // optional metadata
      costCenter: null,
      project: null,
      counterparty: null,
      currency: "BDT",
      createdAt: admin.firestore.Timestamp.now(),
      createdBy: "system",
    });
    console.log(`✅ Added ledger line: ${line.account}`);
  }
  console.log("🎉 Ledger collection seeded.");
}

/* -------------------- Seed Expenses -------------------- */
async function seedExpenses() {
  const examples = [
    {
      vendor: "City Power & Light",
      category: "Utilities",
      amount: 18000,
      paidAmount: 0,
      balance: 18000,
      dueDate: admin.firestore.Timestamp.fromDate(new Date("2025-08-20")),
      status: "unpaid", // unpaid | partial | paid
      notes: "August electricity bill",
      costCenter: "Factory",
    },
    {
      vendor: "Evergreen Supplies",
      category: "Office Supplies",
      amount: 8500,
      paidAmount: 2000,
      balance: 6500,
      dueDate: admin.firestore.Timestamp.fromDate(new Date("2025-08-25")),
      status: "partial",
      notes: "Printer cartridges",
      costCenter: "HR",
    },
    {
      vendor: "Blue Sky Marketing",
      category: "Marketing",
      amount: 32000,
      paidAmount: 32000,
      balance: 0,
      dueDate: admin.firestore.Timestamp.fromDate(new Date("2025-08-10")),
      status: "paid",
      notes: "Social media campaign",
      costCenter: "Marketing",
    },
  ];

  for (const exp of examples) {
    const ref = db.collection("expenses").doc();
    await ref.set({
      vendor: exp.vendor,
      category: exp.category,
      amount: exp.amount,
      paidAmount: exp.paidAmount,
      balance: exp.balance,
      dueDate: exp.dueDate,
      status: exp.status,
      notes: exp.notes,
      costCenter: exp.costCenter,
      currency: "BDT",
      attachments: [], // e.g., invoice PDF links
      createdAt: admin.firestore.Timestamp.now(),
      createdBy: "system",
    });
    console.log(`✅ Added expense: ${exp.vendor}`);
  }
  console.log("🎉 Expenses collection seeded.");
}

/* -------------------- Main -------------------- */
async function main() {
  try {
    await seedLedger();
    await seedExpenses();
    console.log("✅ Done seeding ledger & expenses.");
    process.exit(0);
  } catch (err) {
    console.error("❌ Error:", err);
    process.exit(1);
  }
}

main();
