// fix_db.js
// Normalize & backfill `shipping` object on invoices.
// Usage:
//   node fix_db.js                         # DRY RUN (no writes)
//   CONFIRM=WRITE node fix_db.js           # actually writes changes
//
// Requires: serviceAccountKey.json with Firestore access in the same folder.

const admin = require('firebase-admin');

const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// ───────────────────────── Config ─────────────────────────
const DRY_RUN = process.env.CONFIRM !== 'WRITE';
const PAGE_SIZE = 300;
const BATCH_MAX = 400;
const INVOICES_COLL = 'invoices';
const CUSTOMERS_COLL = 'customers';

// ───────────────────────── Utils ─────────────────────────
function println(...a) { console.log(...a); }
function trim(v) { return (v == null) ? '' : String(v).trim(); }
function nonEmpty(v) { return trim(v).length > 0; }

function newBatch() { return { batch: db.batch(), count: 0 }; }
async function safeCommit(b) { if (b.count > 0 && !DRY_RUN) await b.batch.commit(); }
async function addUpdateToBatch(bctl, ref, data) {
  bctl.batch.set(ref, data, { merge: true });
  bctl.count++;
  if (bctl.count >= BATCH_MAX) {
    await safeCommit(bctl);
    bctl.batch = db.batch();
    bctl.count = 0;
  }
}

function normalizeCountry(country, code) {
  const name = trim(country);
  const cObj = {};
  if (nonEmpty(name)) cObj.name = name;
  if (nonEmpty(code)) cObj.code = code.toUpperCase();
  return Object.keys(cObj).length ? cObj : null;
}

function normalizePhone(phone, phoneCode) {
  let national = trim(phone);
  let dial = trim(phoneCode);
  if (!nonEmpty(dial) && national.startsWith('+')) {
    // If the number is already in +E.164 style, split a guess:
    // crude parse: +<code><rest>
    const m = national.match(/^\+(\d{1,4})(.*)$/);
    if (m) {
      dial = `+${m[1]}`;
      national = trim(m[2]);
    }
  }
  const e164 = (nonEmpty(dial) && nonEmpty(national)) ? `${dial}${national}`.replace(/\s+/g, '') : '';
  const obj = {};
  if (nonEmpty(dial)) obj.countryDialCode = dial;  // e.g. +880
  if (nonEmpty(national)) obj.national = national; // e.g. 1736...
  if (nonEmpty(e164)) obj.e164 = e164;
  // isoCode is hard to infer without a lib; leave blank (Flutter writes it later)
  return Object.keys(obj).length ? obj : null;
}

function isShippingComplete(s) {
  if (!s) return false;
  const a1 = trim(s.address1);
  const city = trim(s.city);
  const zip = trim(s.postalCode || s.zip);
  const country = s.country && (trim(s.country.name) || trim(s.country) || trim(s.country.code));
  return !!(a1 && city && zip && country);
}

async function forEachPaged(collRef, pageSize, handler) {
  let last = null;
  let processed = 0;
  while (true) {
    let q = collRef.orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
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

// ───────────────────────── Main ─────────────────────────
(async () => {
  println(`\n=== Backfill normalized 'shipping' on invoices ===`);
  println(`Mode: ${DRY_RUN ? 'DRY RUN (no writes)' : 'WRITE'}`);
  println(`Scanning: "${INVOICES_COLL}" ...`);

  const totals = {
    invoicesSeen: 0,
    invoicesUpdated: 0,
    hadCustomerLookup: 0,
    customerHits: 0,
  };

  let batchCtl = newBatch();

  await forEachPaged(db.collection(INVOICES_COLL), PAGE_SIZE, async (invDoc) => {
    totals.invoicesSeen++;
    const invId = invDoc.id;
    const inv   = invDoc.data() || {};

    // Skip if shipping already looks complete
    let shipping = (inv.shipping || null);
    if (isShippingComplete(shipping)) return;

    // Build candidate from invoice itself
    const cand = {
      address1  : trim(inv.address1 || (shipping && shipping.address1)),
      address2  : trim(inv.address2 || (shipping && shipping.address2)),
      city      : trim(inv.city     || (shipping && shipping.city)),
      state     : trim(inv.state    || (shipping && shipping.state || shipping && shipping.region)),
      postalCode: trim(inv.postalCode || inv.zip || (shipping && (shipping.postalCode || shipping.zip))),
      country   : normalizeCountry(inv.country || (shipping && (shipping.country?.name || shipping.country)), (shipping && shipping.country && shipping.country.code)),
      phone     : (shipping && shipping.phone) || null,
    };

    // If not enough info, try to pull from customers/{customerId}
    const customerId = trim(inv.customerId);
    if (customerId) {
      totals.hadCustomerLookup++;
      const custRef = db.collection(CUSTOMERS_COLL).doc(customerId);
      const custSnap = await custRef.get();
      if (custSnap.exists) {
        totals.customerHits++;
        const c = custSnap.data() || {};
        // map common customer fields
        cand.address1   = cand.address1   || trim(c.address1 || c.address || c.addr1);
        cand.address2   = cand.address2   || trim(c.address2 || c.addr2);
        cand.city       = cand.city       || trim(c.city);
        cand.state      = cand.state      || trim(c.state || c.region || c.province);
        cand.postalCode = cand.postalCode || trim(c.postalCode || c.zip);
        const ctryName  = (cand.country && cand.country.name) || trim(c.country);
        const ctryCode  = (cand.country && cand.country.code) || trim(c.countryCode || c.countryISO || c.isoCode);
        cand.country = normalizeCountry(ctryName, ctryCode) || cand.country;

        // phone
        if (!cand.phone) {
          const phone = trim(c.phone || c.mobile || c.whatsapp);
          const phoneCode = trim(c.phoneCode || c.countryDialCode || c.dialCode);
          const p = normalizePhone(phone, phoneCode);
          if (p) cand.phone = p;
        }
      }
    }

    // If still missing basics, skip
    if (!nonEmpty(cand.address1) && !nonEmpty(cand.city) && !cand.country && !nonEmpty(cand.postalCode)) {
      // Not enough to create; leave untouched
      return;
    }

    // Final normalized object
    const shippingOut = {
      ...(nonEmpty(cand.address1) ? { address1: cand.address1 } : {}),
      ...(nonEmpty(cand.address2) ? { address2: cand.address2 } : {}),
      ...(nonEmpty(cand.city)     ? { city: cand.city } : {}),
      ...(nonEmpty(cand.state)    ? { state: cand.state } : {}),
      ...(nonEmpty(cand.postalCode) ? { postalCode: cand.postalCode } : {}),
      ...(cand.country ? { country: cand.country } : {}),
      ...(cand.phone   ? { phone: cand.phone } : {}),
    };

    // Merge write (preserve existing shipping fields)
    const update = { shipping: shippingOut, updatedAt: admin.firestore.FieldValue.serverTimestamp() };

    println(`→ Invoice ${invId}: write shipping =`, JSON.stringify(shippingOut));
    await addUpdateToBatch(batchCtl, invDoc.ref, update);
    totals.invoicesUpdated++;
  });

  await safeCommit(batchCtl);

  println('\n=== Summary ===');
  println(`Invoices scanned:        ${totals.invoicesSeen}`);
  println(`Invoices updated:        ${totals.invoicesUpdated}`);
  println(`Invoices with custId:    ${totals.hadCustomerLookup}`);
  println(`Customer lookups hit:    ${totals.customerHits}`);
  println(`Mode: ${DRY_RUN ? 'DRY RUN (no writes)' : 'WRITE'} complete.\n`);

  if (DRY_RUN) {
    println('No changes were written. Re-run with:');
    println('  CONFIRM=WRITE node fix_db.js\n');
  }
  process.exit(0);
})().catch((err) => {
  console.error('❌ Backfill failed:', err);
  process.exit(1);
});
