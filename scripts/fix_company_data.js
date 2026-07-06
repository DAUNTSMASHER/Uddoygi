/**
 * fix_company_data.js
 * ─────────────────────────────────────────────────────────────
 * Uddoygi — Firebase Data Repair Script
 *
 * PROBLEMS THIS FIXES:
 *   1. Email already registered in Firebase Auth but NOT in `companies`
 *      collection → "forgot company ID" says no company found
 *   2. Users whose `companyId` field is missing or wrong
 *   3. `companies` docs missing `email` field (so email lookup fails)
 *   4. `company/main` singleton not linked to the correct companyId
 *   5. All existing Firestore data (invoices, payrolls, etc.) that has
 *      NO `companyId` field → stamps them with the correct company ID
 *      so data is properly isolated per company
 *
 * WHAT IT DOES (in order):
 *   Step 1  — List all Firebase Auth users
 *   Step 2  — List all `companies` documents
 *   Step 3  — List all `users` documents
 *   Step 4  — Cross-check: find Auth users whose email is NOT in any
 *             `companies` doc → create/repair the `companies` doc
 *   Step 5  — Cross-check: find `users` docs with missing/wrong companyId
 *             → patch them
 *   Step 6  — Ensure `companies` docs have all required lookup fields
 *             (email, phone, companyId) so "forgot company ID" works
 *   Step 7  — Stamp companyId onto ALL existing data documents in every
 *             module collection that are missing it
 *   Step 8  — Print a full audit report
 *
 * USAGE:
 *   cd scripts
 *   npm install
 *   node fix_company_data.js
 *
 *   Optional flags:
 *     --dry-run          Print what would change, but write nothing
 *     --company <id>     Only process one specific company ID
 *     --stamp-all        Also stamp companyId on all existing data docs
 *
 * PREREQUISITES:
 *   Place your Firebase service account key at:
 *     scripts/serviceAccountKey.json
 *   Download from: Firebase Console → Project Settings → Service Accounts
 *                  → Generate new private key
 * ─────────────────────────────────────────────────────────────
 */

'use strict';

const admin = require('firebase-admin');
const path  = require('path');
const fs    = require('fs');

// ── ANSI colours ─────────────────────────────────────────────
const G  = (s) => `\x1b[32m${s}\x1b[0m`;
const R  = (s) => `\x1b[31m${s}\x1b[0m`;
const Y  = (s) => `\x1b[33m${s}\x1b[0m`;
const B  = (s) => `\x1b[36m${s}\x1b[0m`;
const W  = (s) => `\x1b[1m${s}\x1b[0m`;
const DIM = (s) => `\x1b[2m${s}\x1b[0m`;

// ── All module collections that should carry companyId ────────
const MODULE_COLLECTIONS = [
  'notices', 'invoices', 'expenses', 'salaries', 'welfare',
  'welfare_requests', 'welfare_schemes',
  'complaints', 'messages', 'notifications',
  'rnd_projects', 'rnd_requests', 'rnd_updates', 'rnd_milestones',
  'work_orders', 'work_order_tracking', 'tracking_index',
  'campaigns', 'customers', 'products', 'product_prices',
  'attendance', 'loans', 'loan_requests', 'payrolls', 'cash_flow',
  'hr_documents', 'payment_slips', 'budgets', 'budget',
  'marketing_incentives', 'ledger', 'leaves', 'shifts', 'benefits',
  'applicants', 'qc_reports', 'daily_production', 'purchase_orders',
  'stocks', 'tasks', 'targets', 'accounts', 'employees',
  'promotions', 'recommendation', 'punishments', 'taxes',
  'procurements', 'alerts', 'alert_dispatch',
];

// ── Parse CLI flags ───────────────────────────────────────────
const argv     = process.argv.slice(2);
const DRY_RUN  = argv.includes('--dry-run');
const STAMP_ALL = argv.includes('--stamp-all');
const ONLY_ID  = (() => {
  const i = argv.indexOf('--company');
  return i !== -1 ? argv[i + 1] : null;
})();

// ── Counters ─────────────────────────────────────────────────
let fixed = 0;
let skipped = 0;
let errors  = 0;

function section(title) {
  console.log(`\n${W('═'.repeat(60))}`);
  console.log(W(` ${title}`));
  console.log(W('═'.repeat(60)));
}

function ok(msg)   { console.log(`  ${G('✔')}  ${msg}`); }
function warn(msg) { console.log(`  ${Y('⚠')}  ${msg}`); }
function err(msg)  { console.log(`  ${R('✘')}  ${msg}`); errors++; }
function info(msg) { console.log(`  ${B('ℹ')}  ${msg}`); }
function fix(msg)  {
  if (DRY_RUN) {
    console.log(`  ${Y('[DRY]')} ${msg}`);
  } else {
    console.log(`  ${G('[FIX]')} ${msg}`);
    fixed++;
  }
}

// ── Firebase init ─────────────────────────────────────────────
function initFirebase() {
  if (admin.apps.length > 0) return;
  const keyPath = path.join(__dirname, 'serviceAccountKey.json');
  if (!fs.existsSync(keyPath)) {
    console.error(R('\n❌  serviceAccountKey.json not found in scripts/'));
    console.error(Y('   Download from: Firebase Console → Project Settings'));
    console.error(Y('   → Service Accounts → Generate new private key'));
    console.error(Y('   → Save as scripts/serviceAccountKey.json\n'));
    process.exit(1);
  }
  admin.initializeApp({
    credential: admin.credential.cert(require(keyPath)),
  });
}

// ── Helpers ───────────────────────────────────────────────────
function generateId() {
  return String(Math.floor(10_000_000 + Math.random() * 90_000_000));
}

async function safeSet(ref, data, merge = true) {
  if (DRY_RUN) return;
  await ref.set(data, { merge });
}

async function safeUpdate(ref, data) {
  if (DRY_RUN) return;
  await ref.update(data);
}

// ── Fetch all Auth users (handles pagination) ─────────────────
async function getAllAuthUsers(auth) {
  const users = [];
  let pageToken;
  do {
    const result = await auth.listUsers(1000, pageToken);
    users.push(...result.users);
    pageToken = result.pageToken;
  } while (pageToken);
  return users;
}

// ─────────────────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────────────────
async function main() {
  initFirebase();
  const db   = admin.firestore();
  const auth = admin.auth();
  const now  = admin.firestore.FieldValue.serverTimestamp();

  if (DRY_RUN) {
    console.log(Y('\n⚠️  DRY RUN MODE — no data will be written\n'));
  }
  if (ONLY_ID) {
    console.log(B(`\nℹ️  Processing only company: ${ONLY_ID}\n`));
  }

  // ──────────────────────────────────────────────────────────
  // STEP 1 — Load all Firebase Auth users
  // ──────────────────────────────────────────────────────────
  section('Step 1 · Loading Firebase Auth users');
  const authUsers = await getAllAuthUsers(auth);
  info(`Found ${authUsers.length} Auth user(s)`);

  // Build lookup maps
  const authByEmail = {};
  const authByUid   = {};
  for (const u of authUsers) {
    if (u.email) authByEmail[u.email.toLowerCase()] = u;
    authByUid[u.uid] = u;
  }

  // ──────────────────────────────────────────────────────────
  // STEP 2 — Load all companies documents
  // ──────────────────────────────────────────────────────────
  section('Step 2 · Loading companies collection');
  const companiesSnap = await db.collection('companies').get();
  const companiesDocs = companiesSnap.docs.filter(d => d.id !== '_init');
  info(`Found ${companiesDocs.length} company document(s)`);

  // Build lookup maps for companies
  const companyByEmail = {};   // email → company doc data
  const companyById    = {};   // companyId → company doc data
  const companyByPhone = {};   // phone → company doc data

  for (const doc of companiesDocs) {
    const d = doc.data();
    const id = d.companyId || doc.id;
    companyById[id] = { ...d, _docId: doc.id };

    if (d.email) {
      companyByEmail[d.email.toLowerCase()] = { ...d, _docId: doc.id };
    }
    if (d.phone) {
      companyByPhone[d.phone.trim()] = { ...d, _docId: doc.id };
    }
  }

  // ──────────────────────────────────────────────────────────
  // STEP 3 — Load all users documents
  // ──────────────────────────────────────────────────────────
  section('Step 3 · Loading users collection');
  const usersSnap = await db.collection('users').get();
  const usersDocs = usersSnap.docs.filter(d => d.id !== '_init');
  info(`Found ${usersDocs.length} user document(s)`);

  const userByUid   = {};
  const userByEmail = {};
  for (const doc of usersDocs) {
    const d = doc.data();
    userByUid[doc.id]  = { ...d, _docId: doc.id };
    if (d.email) userByEmail[d.email.toLowerCase()] = { ...d, _docId: doc.id };
  }

  // ──────────────────────────────────────────────────────────
  // STEP 4 — Find Auth users not in companies collection
  //          (the core "email already registered" vs "not found" mismatch)
  // ──────────────────────────────────────────────────────────
  section('Step 4 · Cross-checking Auth users ↔ companies');

  for (const authUser of authUsers) {
    const email = (authUser.email || '').toLowerCase();
    if (!email) continue;

    // Skip if filtering by specific company
    const userDoc = userByUid[authUser.uid];
    if (ONLY_ID && userDoc?.companyId !== ONLY_ID) continue;

    const inCompanies = !!companyByEmail[email];
    const inUsers     = !!userByEmail[email];

    if (!inCompanies && !inUsers) {
      warn(`Auth user ${B(email)} (uid: ${authUser.uid}) has NO company or user doc`);
      // Nothing we can do automatically — no company data to work with
      skipped++;
      continue;
    }

    if (!inCompanies && inUsers) {
      // User doc exists but companies doc is missing the email
      const ud = userByEmail[email];
      const cid = ud.companyId;

      if (!cid) {
        err(`Auth user ${R(email)} — user doc has no companyId either. Manual fix needed.`);
        continue;
      }

      // Check if companies doc exists by ID
      const compDoc = companyById[cid];
      if (compDoc) {
        // companies doc exists but email field is missing or wrong
        warn(`companies/${cid} missing email field for ${B(email)}`);
        fix(`Patching companies/${cid} → email = "${email}"`);
        await safeUpdate(
          db.collection('companies').doc(cid),
          { email, updatedAt: now }
        );
        // Update local map
        companyByEmail[email] = { ...compDoc, email };
        companyById[cid] = { ...compDoc, email };
      } else {
        // companies doc doesn't exist at all — create it from user doc
        warn(`companies/${cid} does NOT exist for Auth user ${B(email)}`);
        fix(`Creating companies/${cid} from user doc data`);
        const newCompany = {
          companyId:   cid,
          companyName: ud.fullName || email,
          legalName:   ud.fullName || email,
          brandName:   ud.fullName || email,
          email:       email,
          phone:       ud.phone || '',
          address:     '',
          industry:    'Other',
          logoUrl:     '',
          signatureUrl: '',
          sealUrl:     '',
          isVerified:  false,
          isActive:    true,
          plan:        'starter',
          adminUid:    authUser.uid,
          adminEmail:  email,
          payment: {
            method:    'auto_repair',
            reference: 'SCRIPT_FIX',
            status:    'complimentary',
            paidAt:    now,
          },
          createdAt:   now,
          updatedAt:   now,
        };
        await safeSet(db.collection('companies').doc(cid), newCompany, false);
        companyByEmail[email] = { ...newCompany, _docId: cid };
        companyById[cid]      = { ...newCompany, _docId: cid };
      }
    }

    if (inCompanies && !inUsers) {
      // Company doc exists but no user doc
      const cd = companyByEmail[email];
      warn(`No users doc for Auth user ${B(email)} (company: ${cd.companyId})`);
      fix(`Creating users/${authUser.uid}`);
      await safeSet(db.collection('users').doc(authUser.uid), {
        uid:         authUser.uid,
        fullName:    authUser.displayName || email,
        email:       email,
        officeEmail: email,
        phone:       cd.phone || '',
        role:        'admin',
        department:  'admin',
        companyId:   cd.companyId,
        isAdmin:     true,
        isActive:    true,
        createdAt:   now,
        updatedAt:   now,
      }, false);
    }

    if (inCompanies && inUsers) {
      ok(`${B(email)} — Auth ✔  companies ✔  users ✔`);
    }
  }

  // ──────────────────────────────────────────────────────────
  // STEP 5 — Fix users docs with missing/wrong companyId
  // ──────────────────────────────────────────────────────────
  section('Step 5 · Checking users.companyId field');

  for (const doc of usersDocs) {
    const d   = doc.data();
    const uid = doc.id;
    if (uid === '_init') continue;

    const email = (d.email || '').toLowerCase();
    if (ONLY_ID && d.companyId !== ONLY_ID) continue;

    if (!d.companyId || d.companyId.trim() === '') {
      // Try to find company by email
      const cd = companyByEmail[email];
      if (cd) {
        warn(`users/${uid} missing companyId — found via email match: ${cd.companyId}`);
        fix(`Patching users/${uid} → companyId = "${cd.companyId}"`);
        await safeUpdate(db.collection('users').doc(uid), {
          companyId: cd.companyId,
          updatedAt: now,
        });
      } else {
        err(`users/${uid} (${email}) — no companyId and no matching company found`);
      }
    } else {
      // Verify companyId actually exists in companies
      if (!companyById[d.companyId]) {
        err(`users/${uid} has companyId="${d.companyId}" but that company doc doesn't exist`);
      } else {
        ok(`users/${uid} (${DIM(email)}) → companyId: ${B(d.companyId)} ✔`);
      }
    }
  }

  // ──────────────────────────────────────────────────────────
  // STEP 6 — Ensure companies docs have all required lookup fields
  // ──────────────────────────────────────────────────────────
  section('Step 6 · Validating companies lookup fields');

  for (const doc of companiesDocs) {
    const d  = doc.data();
    const id = doc.id;
    if (ONLY_ID && id !== ONLY_ID) continue;

    const patches = {};
    let needsPatch = false;

    // companyId field must match doc ID
    if (!d.companyId || d.companyId !== id) {
      warn(`companies/${id} — companyId field missing or mismatch`);
      patches.companyId = id;
      needsPatch = true;
    }

    // email must be lowercase and present
    if (!d.email) {
      // Try to find from users
      const adminUid = d.adminUid;
      const adminUser = adminUid ? userByUid[adminUid] : null;
      if (adminUser?.email) {
        warn(`companies/${id} — email missing, using admin user email`);
        patches.email = adminUser.email.toLowerCase();
        needsPatch = true;
      } else {
        err(`companies/${id} — email field missing and cannot be recovered`);
      }
    } else if (d.email !== d.email.toLowerCase()) {
      // Ensure lowercase for consistent lookup
      patches.email = d.email.toLowerCase();
      needsPatch = true;
    }

    // phone must be present (needed for OTP recovery)
    if (!d.phone || d.phone.trim() === '') {
      const adminUid  = d.adminUid;
      const adminUser = adminUid ? userByUid[adminUid] : null;
      if (adminUser?.phone) {
        warn(`companies/${id} — phone missing, using admin user phone`);
        patches.phone = adminUser.phone;
        needsPatch = true;
      } else {
        warn(`companies/${id} — phone field missing (OTP recovery won't work)`);
      }
    }

    if (needsPatch) {
      patches.updatedAt = now;
      fix(`Patching companies/${id}: ${JSON.stringify(patches)}`);
      await safeUpdate(db.collection('companies').doc(id), patches);
    } else {
      ok(`companies/${id} — all lookup fields present ✔`);
    }
  }

  // ──────────────────────────────────────────────────────────
  // STEP 7 — Stamp companyId on all existing data documents
  //          (only runs if --stamp-all flag is passed, or if
  //           there is exactly one company in the database)
  // ──────────────────────────────────────────────────────────
  const realCompanies = companiesDocs.filter(d => d.id !== '_init');

  if (STAMP_ALL || realCompanies.length === 1) {
    section('Step 7 · Stamping companyId on existing data documents');

    // Determine which companyId to use
    let targetCompanyId;
    if (ONLY_ID) {
      targetCompanyId = ONLY_ID;
    } else if (realCompanies.length === 1) {
      targetCompanyId = realCompanies[0].id;
      info(`Single company detected — stamping all data with: ${B(targetCompanyId)}`);
    } else {
      err('Multiple companies found — use --company <id> to specify which one to stamp');
      targetCompanyId = null;
    }

    if (targetCompanyId) {
      let totalStamped = 0;

      for (const colName of MODULE_COLLECTIONS) {
        try {
          const snap = await db.collection(colName).get();
          const toStamp = snap.docs.filter(d => {
            if (d.id === '_init') return false;
            const data = d.data();
            // Only stamp docs that are missing companyId
            return !data.companyId || data.companyId.trim() === '';
          });

          if (toStamp.length === 0) {
            info(`${colName}: all docs already have companyId`);
            continue;
          }

          info(`${colName}: ${toStamp.length} doc(s) need stamping`);

          // Batch write in groups of 500
          const chunks = [];
          for (let i = 0; i < toStamp.length; i += 499) {
            chunks.push(toStamp.slice(i, i + 499));
          }

          for (const chunk of chunks) {
            const batch = db.batch();
            for (const doc of chunk) {
              batch.update(doc.ref, {
                companyId: targetCompanyId,
                updatedAt: now,
              });
            }
            fix(`Stamping ${chunk.length} docs in ${colName}`);
            if (!DRY_RUN) await batch.commit();
            totalStamped += chunk.length;
          }
        } catch (e) {
          // Collection might not exist — skip silently
          if (!e.message?.includes('NOT_FOUND')) {
            warn(`Could not process ${colName}: ${e.message}`);
          }
        }
      }

      ok(`Total documents stamped with companyId: ${totalStamped}`);
    }
  } else {
    section('Step 7 · Stamping companyId on existing data documents');
    info(`Skipped — pass --stamp-all to stamp data docs`);
    info(`(Multiple companies found — use --company <id> --stamp-all)`);
  }

  // ──────────────────────────────────────────────────────────
  // STEP 8 — Sync company/main with correct companyId
  // ──────────────────────────────────────────────────────────
  section('Step 8 · Verifying company/main singleton');

  try {
    const mainDoc = await db.collection('company').doc('main').get();
    if (mainDoc.exists) {
      const md = mainDoc.data();
      const mainCid = md.companyId;

      if (!mainCid) {
        // Try to find the right company
        if (realCompanies.length === 1) {
          const cid = realCompanies[0].id;
          const cd  = realCompanies[0].data();
          warn(`company/main missing companyId — patching with ${cid}`);
          fix(`Patching company/main → companyId = "${cid}"`);
          await safeUpdate(db.collection('company').doc('main'), {
            companyId:   cid,
            companyName: cd.companyName || '',
            email:       cd.email || '',
            phone:       cd.phone || '',
            updatedAt:   now,
          });
        } else {
          err('company/main has no companyId and multiple companies exist — manual fix needed');
        }
      } else if (!companyById[mainCid]) {
        err(`company/main.companyId = "${mainCid}" but no companies/${mainCid} doc exists`);
      } else {
        ok(`company/main → companyId: ${B(mainCid)} ✔`);
      }
    } else {
      warn('company/main does not exist');
      if (realCompanies.length === 1) {
        const cid = realCompanies[0].id;
        const cd  = realCompanies[0].data();
        fix(`Creating company/main for company ${cid}`);
        await safeSet(db.collection('company').doc('main'), {
          companyId:   cid,
          companyName: cd.companyName || '',
          legalName:   cd.legalName  || '',
          brandName:   cd.brandName  || '',
          email:       cd.email      || '',
          phone:       cd.phone      || '',
          industry:    cd.industry   || '',
          logoUrl:     cd.logoUrl    || '',
          isVerified:  cd.isVerified || false,
          isActive:    cd.isActive   || true,
          cashIn:      0,
          cashOut:     0,
          createdAt:   now,
          updatedAt:   now,
        }, false);
      }
    }
  } catch (e) {
    err(`company/main check failed: ${e.message}`);
  }

  // ──────────────────────────────────────────────────────────
  // FINAL REPORT
  // ──────────────────────────────────────────────────────────
  section('Final Report');

  console.log(`
  ${G('Fixes applied  :')} ${fixed}
  ${Y('Skipped        :')} ${skipped}
  ${R('Errors         :')} ${errors}
  ${DRY_RUN ? Y('Mode           : DRY RUN (nothing written)') : G('Mode           : LIVE (changes written to Firestore)')}
  `);

  if (errors > 0) {
    console.log(R('  Some issues could not be auto-fixed. Review the errors above.'));
    console.log(Y('  You may need to manually update those records in Firebase Console.'));
  } else if (fixed === 0) {
    console.log(G('  Everything looks good! No fixes were needed.'));
  } else {
    console.log(G('  All fixable issues have been repaired.'));
    console.log(B('  Run the script again to verify — it should report 0 fixes needed.'));
  }

  // ── Print company summary ─────────────────────────────────
  if (realCompanies.length > 0) {
    console.log(`\n  ${W('Companies in database:')}`);
    for (const doc of realCompanies) {
      const d = doc.data();
      console.log(`
    ${W('Company ID  :')} ${B(doc.id)}
    ${W('Name        :')} ${d.companyName || '(none)'}
    ${W('Email       :')} ${d.email || R('MISSING')}
    ${W('Phone       :')} ${d.phone || Y('missing')}
    ${W('Admin UID   :')} ${d.adminUid || Y('missing')}
    ${W('Active      :')} ${d.isActive ? G('yes') : R('no')}
  `);
    }
  }
}

main().catch((e) => {
  console.error(R(`\n❌  Fatal: ${e.message}`));
  console.error(e.stack);
  process.exit(1);
});
