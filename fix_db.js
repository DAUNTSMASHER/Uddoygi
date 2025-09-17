/* fix_db.js
 * Normalize budgets → one doc per month at id "yyyy-MM"
 * Usage:
 *   node fix_db.js            # dry-run (no writes)
 *   COMMIT=1 node fix_db.js   # write changes
 */

const admin = require('firebase-admin');
const path = require('path');

const SERVICE_ACCOUNT = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(SERVICE_ACCOUNT),
});
const db = admin.firestore();

const COMMIT = !!process.env.COMMIT;
const LOCK_DAYS = Number(process.env.LOCK_DAYS || 7);

/* -------------------------- helpers -------------------------- */
const MONTHS = {
  january: 1, february: 2, march: 3, april: 4, may: 5, june: 6,
  july: 7, august: 8, september: 9, october: 10, november: 11, december: 12,
};

function pad2(n) { return String(n).padStart(2, '0'); }

function keyFromDate(d) {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}`; // yyyy-MM
}

function parsePeriodKey(periodStr, fallbackDate) {
  if (typeof periodStr === 'string' && periodStr.trim()) {
    const parts = periodStr.trim().split(/\s+/); // "September 2025"
    if (parts.length >= 2) {
      const m = MONTHS[(parts[0] || '').toLowerCase()];
      const y = Number(parts[1]);
      if (m && y) return `${y}-${pad2(m)}`;
    }
  }
  // fallback to createdAt/update time if parsing fails
  return keyFromDate(fallbackDate || new Date());
}

function displayFromKey(key) {
  const [y, m] = key.split('-').map(Number);
  const date = new Date(y, (m || 1) - 1, 1);
  return date.toLocaleDateString('en', { month: 'long', year: 'numeric' }); // "September 2025"
}

function numify(v) {
  if (v == null) return 0;
  if (typeof v === 'number') return v;
  if (typeof v === 'string') return Number(v.replace(/,/g, '')) || 0;
  return 0;
}

function tsToDate(v) {
  if (!v) return null;
  if (v.toDate) return v.toDate();
  const n = Number(v);
  return Number.isFinite(n) ? new Date(n) : null;
}

function addDays(d, days) {
  const x = new Date(d.getTime());
  x.setDate(x.getDate() + days);
  return x;
}

function normalizeItems(items) {
  if (!Array.isArray(items)) return [];
  return items.map((r, idx) => {
    const sl = Number(r?.sl ?? idx + 1);
    return {
      sl,
      name: String(r?.name ?? '').trim(),
      amountNeed: Number(numify(r?.amountNeed)),
      minAmount: Number(numify(r?.minAmount)),
      notes: (r?.notes == null || String(r.notes).trim() === '') ? null : String(r.notes).trim(),
    };
  });
}

function normalizeTargets(targets) {
  if (!Array.isArray(targets)) return [];
  return targets.map(t => ({
    name: String(t?.name ?? '').trim(),
    maxTarget: Number(numify(t?.maxTarget)),
    finalTarget: Number(numify(t?.finalTarget)),
  })).filter(t => t.name);
}

function computeTotals(items) {
  const totalNeed = items.reduce((p, e) => p + numify(e.amountNeed), 0);
  const totalMin  = items.reduce((p, e) => p + numify(e.minAmount), 0);
  return { totalNeed, totalMin };
}

/* -------------------------- main -------------------------- */
async function run() {
  console.log(`[fix_db] starting. COMMIT=${COMMIT ? 'YES' : 'NO (dry-run)'}  LOCK_DAYS=${LOCK_DAYS}`);

  const snap = await db.collection('budgets')
    .orderBy('createdAt', 'desc')
    .get();

  console.log(`[fix_db] scanned ${snap.size} docs`);

  // Group by periodKey
  const groups = new Map(); // key -> array of {id, data, createdAtDate}
  snap.docs.forEach(d => {
    const data = d.data() || {};
    const createdAtDate =
      tsToDate(data.createdAt) ||
      tsToDate(data.editableUntil) ||
      new Date();

    let periodKey = data.periodKey;
    if (!periodKey) {
      periodKey = parsePeriodKey(data.period, createdAtDate);
    }

    if (!groups.has(periodKey)) groups.set(periodKey, []);
    groups.get(periodKey).push({ id: d.id, data, createdAtDate });
  });

  let writes = 0;
  let deletes = 0;
  let batches = 0;
  let batch = db.batch();

  const commitBatch = async () => {
    if (!COMMIT) return; // dry-run
    if (writes + deletes === 0) return;
    await batch.commit();
    batches++;
    batch = db.batch();
  };

  for (const [periodKey, arr] of groups.entries()) {
    // pick newest by createdAt
    arr.sort((a, b) => b.createdAtDate - a.createdAtDate);
    const primary = arr[0];
    const discard = arr.slice(1);

    const companyName =
      (primary.data.companyName && String(primary.data.companyName).trim()) ||
      'Wig Bangladesh';

    // Normalize items/targets
    const items = normalizeItems(primary.data.items);
    const salesTargets = normalizeTargets(primary.data.salesTargets);
    const { totalNeed, totalMin } = computeTotals(items);

    // Timestamps
    const createdAt = tsToDate(primary.data.createdAt) || primary.createdAtDate || new Date();
    const editableUntil = tsToDate(primary.data.editableUntil) || addDays(createdAt, LOCK_DAYS);

    const period = displayFromKey(periodKey);

    const canonicalDoc = {
      periodKey,                 // "yyyy-MM"
      period,                    // "MMMM yyyy"
      companyName,               // String
      createdAt: admin.firestore.Timestamp.fromDate(createdAt),
      editableUntil: admin.firestore.Timestamp.fromDate(editableUntil),
      items,
      salesTargets,
      totalNeed,
      totalMin,
    };

    const targetRef = db.collection('budgets').doc(periodKey);

    // Decide whether we need to write/overwrite
    let needsWrite = true;
    if (primary.id === periodKey) {
      // Already at the right ID—still write to normalize fields
      needsWrite = true;
    }

    console.log(`\n[fix_db] → month ${periodKey} (${period})`);
    console.log(`  keep:   ${primary.id}${primary.id === periodKey ? ' (already canonical id)' : ''}`);
    if (discard.length) console.log(`  delete: ${discard.map(x => x.id).join(', ')}`);
    console.log(`  totals: need=${totalNeed}  min=${totalMin}`);
    console.log(`  createdAt=${createdAt.toISOString()}  editableUntil=${editableUntil.toISOString()}`);

    if (needsWrite) {
      if (COMMIT) batch.set(targetRef, canonicalDoc, { merge: false });
      writes++;
    }

    for (const d of discard) {
      if (d.id === periodKey) continue; // safety
      if (COMMIT) batch.delete(db.collection('budgets').doc(d.id));
      deletes++;
    }

    // Commit in chunks of ~400 ops to be safe (limit is 500)
    if ((writes + deletes) % 400 === 0) {
      await commitBatch();
    }
  }

  await commitBatch();

  console.log(`\n[fix_db] done. batches=${batches} writes=${writes} deletes=${deletes} (COMMIT=${COMMIT})`);
}

run().catch(err => {
  console.error('[fix_db] fatal:', err);
  process.exit(1);
});
