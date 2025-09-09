// fix_db.js
// Backfill a shared `tracking_number` across invoices and their work orders,
// and into work_order_tracking docs (matched by workOrderNo).
//
// Usage:
//   node fix_db.js                         # DRY RUN (no writes)
//   CONFIRM=WRITE node fix_db.js           # actually writes changes
//
// Requires: serviceAccountKey.json with Firestore access in the same folder.

const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const db = admin.firestore();

// ───────────────────────── Config ─────────────────────────
const DRY_RUN = process.env.CONFIRM !== 'WRITE'; // default to dry-run
const PAGE_SIZE = 300;      // invoices scanned per page
const BATCH_MAX = 400;      // ops per batch (max 500; keep headroom)
const WORK_ORDER_COLL = 'work_orders';
const INVOICES_COLL = 'invoices';
const WORK_ORDER_TRACKING_COLL = 'work_order_tracking';

// ───────────────────────── Utils ─────────────────────────
function normalizeKey(v) {
  return String(v || '')
    .trim()
    .replace(/[^\w-]+/g, ''); // only word chars and dashes
}

function deriveTrackingFromInvoice(invoiceId, invoiceData, fallbackWO) {
  // Priority:
  // 1) existing invoice tracking_number
  // 2) existing invoice trackingNumber (camelCase)
  // 3) existing work order tracking number (first found)
  // 4) TRK-<invoiceNo or invoiceId>
  if (invoiceData.tracking_number) return String(invoiceData.tracking_number);
  if (invoiceData.trackingNumber) return String(invoiceData.trackingNumber);
  if (fallbackWO && (fallbackWO.tracking_number || fallbackWO.trackingNumber)) {
    return String(fallbackWO.tracking_number || fallbackWO.trackingNumber);
  }

  const base =
    invoiceData.invoiceNo ||
    invoiceData.invoice_number ||
    invoiceId;

  return `TRK-${normalizeKey(base)}`;
}

function needsSet(current, desired) {
  // consider equality with loose stringification
  if (current === undefined || current === null) return true;
  return String(current) !== String(desired);
}

async function forEachPaged(collectionRef, pageSize, handler) {
  let last = null;
  let processed = 0;
  while (true) {
    let q = collectionRef.orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      await handler(doc);
      processed++;
      last = doc.id;
    }
  }
  return processed;
}

function newBatch() {
  return { batch: db.batch(), count: 0 };
}

async function safeCommit(b) {
  if (b.count === 0) return;
  if (DRY_RUN) return; // skip actual commit
  await b.batch.commit();
}

async function addUpdateToBatch(bctl, ref, data) {
  bctl.batch.update(ref, data);
  bctl.count++;
  if (bctl.count >= BATCH_MAX) {
    await safeCommit(bctl);
    bctl.batch = db.batch();
    bctl.count = 0;
  }
}

// ───────────────────────── Main logic ─────────────────────────
(async () => {
  console.log(`\n=== Backfill shared tracking_number ===`);
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN (no writes)' : 'WRITE'}`);
  console.log(`Scanning collection: "${INVOICES_COLL}" ...`);

  let totals = {
    invoicesSeen: 0,
    invoicesUpdated: 0,
    workOrdersMatched: 0,
    workOrdersUpdated: 0,
    trackingDocsUpdated: 0,
  };

  let batchCtl = newBatch();

  await forEachPaged(db.collection(INVOICES_COLL), PAGE_SIZE, async (invoiceDoc) => {
    totals.invoicesSeen++;
    const invoiceId = invoiceDoc.id;
    const invData = invoiceDoc.data() || {};

    // Find linked work orders by invoiceId
    const woSnap = await db
      .collection(WORK_ORDER_COLL)
      .where('invoiceId', '==', invoiceId)
      .get();

    const firstWO = woSnap.docs[0] ? woSnap.docs[0].data() : null;
    const tracking = deriveTrackingFromInvoice(invoiceId, invData, firstWO);

    // 1) Update invoice to set tracking_number (and unify camelCase if needed)
    const invNeeds =
      needsSet(invData.tracking_number, tracking) ||
      (invData.trackingNumber && invData.tracking_number === undefined);

    if (invNeeds) {
      totals.invoicesUpdated++;
      const invUpdate = {
        tracking_number: tracking,
      };
      // Optional: keep a one-time back-compat mirror for UIs still reading camelCase
      if (invData.trackingNumber !== undefined && invData.trackingNumber !== tracking) {
        invUpdate.trackingNumber = tracking;
      }
      console.log(`→ Invoice ${invoiceId}: set tracking_number="${tracking}"`);
      await addUpdateToBatch(batchCtl, invoiceDoc.ref, invUpdate);
    }

    // 2) Update all matched work orders to have same tracking_number
    if (!woSnap.empty) {
      totals.workOrdersMatched += woSnap.size;

      for (const woDoc of woSnap.docs) {
        const woData = woDoc.data() || {};
        if (needsSet(woData.tracking_number, tracking) || (woData.trackingNumber && woData.tracking_number === undefined)) {
          totals.workOrdersUpdated++;
          const woUpdate = { tracking_number: tracking };
          if (woData.trackingNumber !== undefined && woData.trackingNumber !== tracking) {
            woUpdate.trackingNumber = tracking; // back-compat mirror if you used camelCase before
          }
          console.log(`   • WorkOrder ${woDoc.id}: set tracking_number="${tracking}"`);
          await addUpdateToBatch(batchCtl, woDoc.ref, woUpdate);
        }

        // 3) Also propagate tracking_number to any work_order_tracking docs with this workOrderNo
        const workOrderNo = woData.workOrderNo || woData.work_order_no;
        if (workOrderNo) {
          // There may be multiple tracking docs per WO; update all that match workOrderNo
          const trSnap = await db
            .collection(WORK_ORDER_TRACKING_COLL)
            .where('workOrderNo', '==', workOrderNo)
            .get();

          if (!trSnap.empty) {
            for (const trDoc of trSnap.docs) {
              const trData = trDoc.data() || {};
              if (needsSet(trData.tracking_number, tracking)) {
                totals.trackingDocsUpdated++;
                console.log(`      · Tracking ${trDoc.id}: set tracking_number="${tracking}" (workOrderNo=${workOrderNo})`);
                await addUpdateToBatch(batchCtl, trDoc.ref, { tracking_number: tracking });
              }
            }
          }
        }
      }
    }
  });

  // Final commit
  await safeCommit(batchCtl);

  console.log('\n=== Summary ===');
  console.log(`Invoices scanned:       ${totals.invoicesSeen}`);
  console.log(`Invoices updated:       ${totals.invoicesUpdated}`);
  console.log(`Work orders matched:    ${totals.workOrdersMatched}`);
  console.log(`Work orders updated:    ${totals.workOrdersUpdated}`);
  console.log(`Tracking docs updated:  ${totals.trackingDocsUpdated}`);
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN (no writes)' : 'WRITE'} complete.\n`);

  if (DRY_RUN) {
    console.log('No changes were written. Re-run with:');
    console.log('  CONFIRM=WRITE node fix_db.js\n');
  }

  process.exit(0);
})().catch((err) => {
  console.error('❌ Backfill failed:', err);
  process.exit(1);
});
