/**
 * migrate_to_new_structure.js
 * ─────────────────────────────────────────────────────────────
 * Migrates all existing Firestore data from the OLD flat structure
 * to the NEW company-scoped structure.
 *
 * OLD:  invoices/{docId}
 * NEW:  data/{companyId}/invoices/{docId}
 *
 * OLD:  users/{uid}
 * NEW:  data/{companyId}/users/{uid}
 *       (root users/{uid} kept for FCM/presence only)
 *
 * OLD:  company/main
 * NEW:  data/{companyId}/company_profile/main
 *
 * USAGE:
 *   cd scripts
 *   npm install
 *   node migrate_to_new_structure.js --dry-run    ← preview
 *   node migrate_to_new_structure.js              ← live migration
 *   node migrate_to_new_structure.js --company 12345678  ← specific company
 *
 * PREREQUISITES:
 *   scripts/serviceAccountKey.json  (Firebase service account key)
 * ─────────────────────────────────────────────────────────────
 */

'use strict';

const admin = require('firebase-admin');
const path  = require('path');
const fs    = require('fs');

// ── ANSI ──────────────────────────────────────────────────────
const G  = s => `\x1b[32m${s}\x1b[0m`;
const R  = s => `\x1b[31m${s}\x1b[0m`;
const Y  = s => `\x1b[33m${s}\x1b[0m`;
const B  = s => `\x1b[36m${s}\x1b[0m`;
const W  = s => `\x1b[1m${s}\x1b[0m`;

// ── All collections to migrate ────────────────────────────────
const COLLECTIONS = [
  // Core
  'users', 'notifications', 'messages', 'notices', 'complaints',
  'alerts', 'alert_dispatch', 'welfare', 'welfare_requests', 'welfare_schemes',
  // HR
  'employees', 'payrolls', 'salaries', 'leaves', 'leave_requests',
  'shifts', 'benefits', 'attendance', 'loans', 'loan_requests',
  'taxes', 'procurements', 'applicants', 'promotions', 'recommendation',
  'hr_documents', 'marketing_incentives', 'punishments',
  // Finance
  'invoices', 'payment_slips', 'cash_flow', 'expenses', 'ledger',
  'budgets', 'budget', 'accounts', 'targets',
  // Marketing
  'customers', 'products', 'product_prices', 'campaigns', 'tasks',
  'qc_reports', 'address_validations',
  // Factory
  'work_orders', 'work_order_tracking', 'tracking_index',
  'daily_production', 'purchase_orders', 'stocks',
  // R&D
  'rnd_requests', 'rnd_projects', 'rnd_updates', 'rnd_milestones', 'rnd_scores',
  // Other
  'orders', 'clients',
];

// Subcollections that need to be migrated along with their parent
const SUBCOLLECTIONS = {
  notices:    ['comments'],
  loans:      ['repayments'],
  messages:   ['replies'],
  campaigns:  ['metrics'],
  stocks:     ['logs'],
  tasks:      ['replies'],
  attendance: ['records'],
};

// ── CLI args ──────────────────────────────────────────────────
const argv     = process.argv.slice(2);
const DRY_RUN  = argv.includes('--dry-run');
const ONLY_CID = (() => { const i = argv.indexOf('--company'); return i !== -1 ? argv[i+1] : null; })();

let copied = 0;
let errors  = 0;

function section(t) {
  console.log(`\n${W('═'.repeat(60))}\n${W(' '+t)}\n${W('═'.repeat(60))}`);
}

// ── Firebase init ─────────────────────────────────────────────
function initFirebase() {
  if (admin.apps.length) return;
  const keyPath = path.join(__dirname, 'serviceAccountKey.json');
  if (!fs.existsSync(keyPath)) {
    console.error(R('\n❌  serviceAccountKey.json not found in scripts/'));
    process.exit(1);
  }
  admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
}

// ── Copy a single document ────────────────────────────────────
async function copyDoc(srcRef, dstRef, label) {
  try {
    const snap = await srcRef.get();
    if (!snap.exists) return;
    const data = snap.data();
    if (data._sentinel) return; // skip sentinel init docs

    if (!DRY_RUN) {
      await dstRef.set(data, { merge: true });
    }
    console.log(`  ${DRY_RUN ? Y('[DRY]') : G('[OK]')}  ${label}`);
    copied++;
  } catch (e) {
    console.log(`  ${R('[ERR]')} ${label}: ${e.message}`);
    errors++;
  }
}

// ── Copy a collection + its subcollections ────────────────────
async function copyCollection(db, srcColPath, dstColPath, colName) {
  const srcSnap = await db.collection(srcColPath).get();
  if (srcSnap.empty) return;

  const subs = SUBCOLLECTIONS[colName] || [];
  let count = 0;

  // Batch in groups of 499
  const docs = srcSnap.docs.filter(d => !d.data()._sentinel);
  const chunks = [];
  for (let i = 0; i < docs.length; i += 499) chunks.push(docs.slice(i, i+499));

  for (const chunk of chunks) {
    if (!DRY_RUN) {
      const batch = db.batch();
      for (const doc of chunk) {
        batch.set(db.doc(`${dstColPath}/${doc.id}`), doc.data(), { merge: true });
      }
      await batch.commit();
    }
    count += chunk.length;
  }

  if (count > 0) {
    console.log(`  ${DRY_RUN ? Y('[DRY]') : G('[OK]')}  ${srcColPath} → ${dstColPath}  (${count} docs)`);
    copied += count;
  }

  // Copy subcollections
  for (const sub of subs) {
    for (const doc of docs) {
      const srcSub = `${srcColPath}/${doc.id}/${sub}`;
      const dstSub = `${dstColPath}/${doc.id}/${sub}`;
      const subSnap = await db.collection(srcSub).get();
      if (subSnap.empty) continue;

      const subDocs = subSnap.docs.filter(d => !d.data()._sentinel);
      if (subDocs.length === 0) continue;

      if (!DRY_RUN) {
        const batch = db.batch();
        for (const sd of subDocs) {
          batch.set(db.doc(`${dstSub}/${sd.id}`), sd.data(), { merge: true });
        }
        await batch.commit();
      }
      console.log(`    ${DRY_RUN ? Y('[DRY]') : G('[OK]')}  subcol: ${srcSub} → ${dstSub}  (${subDocs.length} docs)`);
      copied += subDocs.length;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────────────────
async function main() {
  initFirebase();
  const db = admin.firestore();

  if (DRY_RUN) console.log(Y('\n⚠️  DRY RUN — nothing will be written\n'));

  // ── Step 1: Find all companies ──────────────────────────────
  section('Step 1 · Finding companies');
  const companiesSnap = await db.collection('companies').get();
  const companies = companiesSnap.docs
    .filter(d => d.id !== '_init')
    .filter(d => !ONLY_CID || d.id === ONLY_CID);

  if (companies.length === 0) {
    console.log(R('  No companies found. Run fix_company_data.js first.'));
    process.exit(1);
  }

  for (const c of companies) {
    const cid  = c.id;
    const data = c.data();
    console.log(`  ${B('Company:')} ${data.companyName || cid}  (ID: ${cid})`);
  }

  // ── Step 2: Migrate each company ───────────────────────────
  for (const companyDoc of companies) {
    const cid  = companyDoc.id;
    const data = companyDoc.data();
    const name = data.companyName || cid;

    section(`Step 2 · Migrating: ${name} (${cid})`);

    const dataRoot = `data/${cid}`;

    // 2a. company/main → data/{cid}/company_profile/main
    console.log(`\n  ${W('company/main → company_profile/main')}`);
    await copyDoc(
      db.collection('company').doc('main'),
      db.doc(`${dataRoot}/company_profile/main`),
      `company/main → ${dataRoot}/company_profile/main`
    );

    // 2b. All module collections
    console.log(`\n  ${W('Module collections:')}`);
    for (const col of COLLECTIONS) {
      await copyCollection(db, col, `${dataRoot}/${col}`, col);
    }

    // 2c. Write a marker so we know migration is done
    if (!DRY_RUN) {
      await db.doc(`${dataRoot}/_meta/migration`).set({
        migratedAt:  admin.firestore.FieldValue.serverTimestamp(),
        fromVersion: 'flat',
        toVersion:   'company_scoped',
        companyId:   cid,
        companyName: name,
      }, { merge: true });
    }

    console.log(`\n  ${G('✔')}  Migration complete for ${name}`);
  }

  // ── Step 3: Summary ─────────────────────────────────────────
  section('Summary');
  console.log(`
  ${G('Documents copied :')} ${copied}
  ${R('Errors           :')} ${errors}
  ${DRY_RUN ? Y('Mode             : DRY RUN (nothing written)') : G('Mode             : LIVE')}
  `);

  if (!DRY_RUN && errors === 0) {
    console.log(G('  ✅  Migration successful!'));
    console.log(B('  Old flat collections are still in place (not deleted).'));
    console.log(B('  Test the app thoroughly before deleting old collections.'));
    console.log(Y('\n  To delete old data after verification:'));
    console.log(Y('    node migrate_to_new_structure.js --cleanup'));
  }
}

// ── Optional cleanup: delete old flat collections ─────────────
async function cleanup() {
  initFirebase();
  const db = admin.firestore();

  console.log(R('\n⚠️  CLEANUP MODE — deleting old flat collections\n'));
  console.log(Y('  This will permanently delete all old top-level collections.'));
  console.log(Y('  Make sure the app is working with the new structure first!\n'));

  // Safety: require explicit confirmation
  if (!process.argv.includes('--confirm')) {
    console.log(R('  Add --confirm flag to actually delete. Exiting.'));
    process.exit(0);
  }

  for (const col of [...COLLECTIONS, 'company']) {
    try {
      const snap = await db.collection(col).get();
      if (snap.empty) continue;
      const batch = db.batch();
      for (const doc of snap.docs) batch.delete(doc.ref);
      await batch.commit();
      console.log(`  ${G('[DELETED]')} ${col} (${snap.docs.length} docs)`);
    } catch (e) {
      console.log(`  ${R('[ERR]')} ${col}: ${e.message}`);
    }
  }
}

// ── Entry point ───────────────────────────────────────────────
if (process.argv.includes('--cleanup')) {
  cleanup().catch(e => { console.error(R(e.message)); process.exit(1); });
} else {
  main().catch(e => { console.error(R(`\n❌  Fatal: ${e.message}`)); process.exit(1); });
}
