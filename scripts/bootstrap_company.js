/**
 * bootstrap_company.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Uddoygi — Post-Registration Company Bootstrapper (Firebase Admin SDK)
 *
 * PURPOSE
 *   After a company registers (via the Flutter app or manually), this script:
 *     1. Creates all required Firestore collections under data/{companyId}/
 *     2. Seeds each collection with an _init sentinel document
 *     3. Creates Firestore composite index definitions (firestore.indexes.json)
 *     4. Sets Firebase Auth custom claims on the admin user
 *     5. Writes the companies/{companyId} registry document
 *     6. Writes the admin user doc under data/{companyId}/users/{uid}
 *     7. Prints a full summary
 *
 * USAGE — bootstrap a NEW company:
 *   node bootstrap_company.js \
 *     --name   "Acme Textiles Ltd." \
 *     --email  "admin@acme.com" \
 *     --phone  "+8801711000000" \
 *     --pass   "SecurePass@123"
 *
 * USAGE — bootstrap an EXISTING company (already registered via Flutter app):
 *   node bootstrap_company.js --id 12345678
 *
 * USAGE — bootstrap ALL companies in the database:
 *   node bootstrap_company.js --all
 *
 * USAGE — dry run (see what would happen, write nothing):
 *   node bootstrap_company.js --id 12345678 --dry-run
 *
 * OPTIONAL FLAGS:
 *   --industry  "Textile"        (default: "Other")
 *   --address   "Dhaka, BD"
 *   --plan      "starter"
 *   --dry-run                    Print changes without writing
 *   --all                        Bootstrap every company in the database
 *
 * PREREQUISITES:
 *   npm install firebase-admin
 *   Place serviceAccountKey.json in this scripts/ directory.
 *   Download from: Firebase Console → Project Settings → Service Accounts
 *                  → Generate new private key
 * ─────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const admin = require('firebase-admin');
const path  = require('path');
const fs    = require('fs');

// ── ANSI colours ──────────────────────────────────────────────────────────────
const G   = (s) => `\x1b[32m${s}\x1b[0m`;
const R   = (s) => `\x1b[31m${s}\x1b[0m`;
const Y   = (s) => `\x1b[33m${s}\x1b[0m`;
const B   = (s) => `\x1b[36m${s}\x1b[0m`;
const W   = (s) => `\x1b[1m${s}\x1b[0m`;
const DIM = (s) => `\x1b[2m${s}\x1b[0m`;

// ── Parse CLI args ─────────────────────────────────────────────────────────────
const argv    = process.argv.slice(2);
const DRY_RUN = argv.includes('--dry-run');
const ALL     = argv.includes('--all');

function arg(name) {
  const i = argv.indexOf(`--${name}`);
  return i !== -1 ? argv[i + 1] : null;
}

// ── Firebase init ──────────────────────────────────────────────────────────────
function initFirebase() {
  if (admin.apps.length > 0) return;
  const keyPath = path.join(__dirname, 'serviceAccountKey.json');
  if (!fs.existsSync(keyPath)) {
    console.error(R('\n❌  serviceAccountKey.json not found in scripts/'));
    console.error(Y('   Download: Firebase Console → Project Settings → Service Accounts → Generate new private key'));
    console.error(Y('   Save as: scripts/serviceAccountKey.json\n'));
    process.exit(1);
  }
  admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
}

// ── Helpers ────────────────────────────────────────────────────────────────────
function generateId() {
  return String(Math.floor(10_000_000 + Math.random() * 90_000_000));
}

function generatePassword() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789@#!';
  return Array.from({ length: 12 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
}

let _fixed = 0, _skipped = 0, _errors = 0;

function ok(msg)   { console.log(`  ${G('✔')}  ${msg}`); }
function warn(msg) { console.log(`  ${Y('⚠')}  ${msg}`); }
function err(msg)  { console.log(`  ${R('✘')}  ${msg}`); _errors++; }
function info(msg) { console.log(`  ${B('ℹ')}  ${msg}`); }
function fix(msg)  {
  if (DRY_RUN) { console.log(`  ${Y('[DRY]')} ${msg}`); }
  else         { console.log(`  ${G('[FIX]')} ${msg}`); _fixed++; }
}
function section(title) {
  console.log(`\n${W('─'.repeat(65))}`);
  console.log(W(`  ${title}`));
  console.log(W('─'.repeat(65)));
}

// ── ALL collections that every company needs ───────────────────────────────────
// Mirrors the C class constants in lib/services/db.dart
const ALL_COLLECTIONS = [
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

  // Company profile (singleton)
  'company_profile',
];

// ── Index definitions ──────────────────────────────────────────────────────────
// Each entry describes a composite index needed by the Flutter app queries.
// These are written to firestore.indexes.json (deploy with: firebase deploy --only firestore:indexes)
//
// Format: { collection, fields: [{field, order}], queryScope }
// queryScope: 'COLLECTION' (default) or 'COLLECTION_GROUP'
//
// NOTE: Firestore does NOT support creating indexes via the Admin SDK.
//       This script generates the firestore.indexes.json file which you
//       deploy once with: firebase deploy --only firestore:indexes
//
const INDEX_DEFINITIONS = [
  // ── users ──────────────────────────────────────────────────────
  { col: 'users',            fields: [['companyId','ASC'], ['role','ASC'],       ['fullName','ASC']] },
  { col: 'users',            fields: [['companyId','ASC'], ['department','ASC'],  ['fullName','ASC']] },
  { col: 'users',            fields: [['companyId','ASC'], ['isActive','ASC'],    ['createdAt','DESC']] },

  // ── employees ──────────────────────────────────────────────────
  { col: 'employees',        fields: [['companyId','ASC'], ['department','ASC'],  ['fullName','ASC']] },
  { col: 'employees',        fields: [['companyId','ASC'], ['role','ASC'],        ['createdAt','DESC']] },

  // ── attendance ─────────────────────────────────────────────────
  { col: 'attendance',       fields: [['companyId','ASC'], ['userEmail','ASC'],   ['date','DESC']] },
  { col: 'attendance',       fields: [['companyId','ASC'], ['date','DESC'],       ['department','ASC']] },

  // ── payrolls ───────────────────────────────────────────────────
  { col: 'payrolls',         fields: [['companyId','ASC'], ['period','ASC'],      ['officeEmail','ASC']] },
  { col: 'payrolls',         fields: [['companyId','ASC'], ['officeEmail','ASC'], ['generatedAt','DESC']] },
  { col: 'payrolls',         fields: [['companyId','ASC'], ['department','ASC'],  ['period','ASC']] },

  // ── leaves / leave_requests ────────────────────────────────────
  { col: 'leaves',           fields: [['companyId','ASC'], ['userEmail','ASC'],   ['createdAt','DESC']] },
  { col: 'leaves',           fields: [['companyId','ASC'], ['status','ASC'],      ['createdAt','DESC']] },
  { col: 'leave_requests',   fields: [['companyId','ASC'], ['userEmail','ASC'],   ['createdAt','DESC']] },
  { col: 'leave_requests',   fields: [['companyId','ASC'], ['status','ASC'],      ['createdAt','DESC']] },

  // ── loans / loan_requests ──────────────────────────────────────
  { col: 'loans',            fields: [['companyId','ASC'], ['userEmail','ASC'],   ['createdAt','DESC']] },
  { col: 'loans',            fields: [['companyId','ASC'], ['status','ASC'],      ['createdAt','DESC']] },
  { col: 'loan_requests',    fields: [['companyId','ASC'], ['userEmail','ASC'],   ['createdAt','DESC']] },
  { col: 'loan_requests',    fields: [['companyId','ASC'], ['status','ASC'],      ['createdAt','DESC']] },

  // ── invoices ───────────────────────────────────────────────────
  { col: 'invoices',         fields: [['companyId','ASC'], ['agentEmail','ASC'],  ['createdAt','DESC']] },
  { col: 'invoices',         fields: [['companyId','ASC'], ['status','ASC'],      ['createdAt','DESC']] },
  { col: 'invoices',         fields: [['companyId','ASC'], ['customerEmail','ASC'],['createdAt','DESC']] },

  // ── payment_slips ──────────────────────────────────────────────
  { col: 'payment_slips',    fields: [['companyId','ASC'], ['status','ASC'],      ['createdAt','DESC']] },
  { col: 'payment_slips',    fields: [['companyId','ASC'], ['agentEmail','ASC'],  ['createdAt','DESC']] },

  // ── cash_flow ──────────────────────────────────────────────────
  { col: 'cash_flow',        fields: [['companyId','ASC'], ['type','ASC'],        ['date','DESC']] },
  { col: 'cash_flow',        fields: [['companyId','ASC'], ['date','DESC'],       ['amount','DESC']] },

  // ── expenses ───────────────────────────────────────────────────
  { col: 'expenses',         fields: [['companyId','ASC'], ['dueDate','ASC'],     ['category','ASC']] },
  { col: 'expenses',         fields: [['companyId','ASC'], ['category','ASC'],    ['dueDate','DESC']] },

  // ── customers ──────────────────────────────────────────────────
  { col: 'customers',        fields: [['companyId','ASC'], ['agentEmail','ASC'],  ['createdAt','DESC']] },
  { col: 'customers',        fields: [['companyId','ASC'], ['status','ASC'],      ['createdAt','DESC']] },

  // ── work_orders ────────────────────────────────────────────────
  { col: 'work_orders',      fields: [['companyId','ASC'], ['agentEmail','ASC'],  ['lastUpdated','DESC']] },
  { col: 'work_orders',      fields: [['companyId','ASC'], ['status','ASC'],      ['createdAt','DESC']] },
  { col: 'work_orders',      fields: [['companyId','ASC'], ['invoiceData.agentEmail','ASC'], ['timestamp','DESC']] },

  // ── work_order_tracking ────────────────────────────────────────
  { col: 'work_order_tracking', fields: [['companyId','ASC'], ['workOrderNo','ASC'], ['lastUpdated','DESC']] },
  { col: 'work_order_tracking', fields: [['companyId','ASC'], ['stage','ASC'],       ['lastUpdated','DESC']] },

  // ── daily_production ───────────────────────────────────────────
  { col: 'daily_production', fields: [['companyId','ASC'], ['date','DESC'],       ['department','ASC']] },

  // ── stocks ─────────────────────────────────────────────────────
  { col: 'stocks',           fields: [['companyId','ASC'], ['category','ASC'],    ['updatedAt','DESC']] },

  // ── purchase_orders ────────────────────────────────────────────
  { col: 'purchase_orders',  fields: [['companyId','ASC'], ['status','ASC'],      ['createdAt','DESC']] },

  // ── campaigns ──────────────────────────────────────────────────
  { col: 'campaigns',        fields: [['companyId','ASC'], ['status','ASC'],      ['createdAt','DESC']] },
  { col: 'campaigns',        fields: [['companyId','ASC'], ['agentEmail','ASC'],  ['createdAt','DESC']] },

  // ── tasks ──────────────────────────────────────────────────────
  { col: 'tasks',            fields: [['companyId','ASC'], ['assignedTo','ASC'],  ['dueDate','ASC']] },
  { col: 'tasks',            fields: [['companyId','ASC'], ['status','ASC'],      ['dueDate','ASC']] },

  // ── complaints ─────────────────────────────────────────────────
  { col: 'complaints',       fields: [['companyId','ASC'], ['submittedBy','ASC'], ['timestamp','DESC']] },
  { col: 'complaints',       fields: [['companyId','ASC'], ['againstEmail','ASC'],['timestamp','DESC']] },
  { col: 'complaints',       fields: [['companyId','ASC'], ['status','ASC'],      ['timestamp','DESC']] },

  // ── messages ───────────────────────────────────────────────────
  { col: 'messages',         fields: [['companyId','ASC'], ['to','ARRAY'],        ['timestamp','DESC']] },
  { col: 'messages',         fields: [['companyId','ASC'], ['from','ASC'],        ['timestamp','DESC']] },

  // ── notifications ──────────────────────────────────────────────
  { col: 'notifications',    fields: [['companyId','ASC'], ['toEmail','ASC'],     ['createdAt','DESC']] },
  { col: 'notifications',    fields: [['companyId','ASC'], ['toEmail','ASC'], ['isRead','ASC'], ['createdAt','DESC']] },

  // ── notices ────────────────────────────────────────────────────
  { col: 'notices',          fields: [['companyId','ASC'], ['department','ASC'],  ['createdAt','DESC']] },
  { col: 'notices',          fields: [['companyId','ASC'], ['createdAt','DESC'],  ['title','ASC']] },

  // ── marketing_incentives ───────────────────────────────────────
  { col: 'marketing_incentives', fields: [['companyId','ASC'], ['userEmail','ASC'],  ['timestamp','DESC']] },
  { col: 'marketing_incentives', fields: [['companyId','ASC'], ['agentEmail','ASC'], ['timestamp','DESC']] },

  // ── rnd_requests ───────────────────────────────────────────────
  { col: 'rnd_requests',     fields: [['companyId','ASC'], ['status','ASC'],      ['createdAt','DESC']] },
  { col: 'rnd_requests',     fields: [['companyId','ASC'], ['requestingDept','ASC'],['createdAt','DESC']] },

  // ── rnd_projects ───────────────────────────────────────────────
  { col: 'rnd_projects',     fields: [['companyId','ASC'], ['status','ASC'],      ['createdAt','DESC']] },
  { col: 'rnd_projects',     fields: [['companyId','ASC'], ['assignedTo','ASC'],  ['createdAt','DESC']] },

  // ── rnd_updates ────────────────────────────────────────────────
  { col: 'rnd_updates',      fields: [['companyId','ASC'], ['projectId','ASC'],   ['date','DESC']] },
  { col: 'rnd_updates',      fields: [['companyId','ASC'], ['submittedBy','ASC'], ['date','DESC']] },

  // ── rnd_milestones ─────────────────────────────────────────────
  { col: 'rnd_milestones',   fields: [['companyId','ASC'], ['projectId','ASC'],   ['createdAt','DESC']] },

  // ── hr_documents ───────────────────────────────────────────────
  { col: 'hr_documents',     fields: [['companyId','ASC'], ['type','ASC'],        ['createdAt','DESC']] },
  { col: 'hr_documents',     fields: [['companyId','ASC'], ['employeeEmail','ASC'],['createdAt','DESC']] },

  // ── welfare / welfare_requests ─────────────────────────────────
  { col: 'welfare_requests', fields: [['companyId','ASC'], ['userEmail','ASC'],   ['createdAt','DESC']] },
  { col: 'welfare_requests', fields: [['companyId','ASC'], ['status','ASC'],      ['createdAt','DESC']] },

  // ── qc_reports ─────────────────────────────────────────────────
  { col: 'qc_reports',       fields: [['companyId','ASC'], ['workOrderNo','ASC'], ['createdAt','DESC']] },

  // ── address_validations ────────────────────────────────────────
  { col: 'address_validations', fields: [['companyId','ASC'], ['status','ASC'],   ['createdAt','DESC']] },

  // ── budgets ────────────────────────────────────────────────────
  { col: 'budgets',          fields: [['companyId','ASC'], ['year','ASC'],        ['department','ASC']] },

  // ── accounts ───────────────────────────────────────────────────
  { col: 'accounts',         fields: [['companyId','ASC'], ['type','ASC'],        ['date','DESC']] },
];

// ── Build firestore.indexes.json content ──────────────────────────────────────
function buildIndexesJson() {
  const indexes = INDEX_DEFINITIONS.map(({ col, fields }) => {
    return {
      collectionGroup: col,
      queryScope: 'COLLECTION',
      fields: fields.map(([fieldPath, order]) => {
        if (order === 'ARRAY') {
          return { fieldPath, arrayConfig: 'CONTAINS' };
        }
        return { fieldPath, order };
      }),
    };
  });

  return JSON.stringify({ indexes, fieldOverrides: [] }, null, 2);
}

// ── Bootstrap a single company ─────────────────────────────────────────────────
async function bootstrapCompany(db, auth, companyId, companyData, adminUid) {
  const now  = admin.firestore.FieldValue.serverTimestamp();
  const root = db.collection('data').doc(companyId);

  section(`Bootstrapping company: ${B(companyId)} — ${W(companyData.companyName || '(unknown)')}`);

  // ── 1. Write companies/{companyId} registry doc ──────────────────────────
  if (!DRY_RUN) {
    await db.collection('companies').doc(companyId).set({
      companyId,
      companyName:  companyData.companyName  || '',
      legalName:    companyData.legalName    || companyData.companyName || '',
      brandName:    companyData.brandName    || companyData.companyName || '',
      email:        (companyData.email || '').toLowerCase(),
      phone:        companyData.phone        || '',
      address:      companyData.address      || '',
      industry:     companyData.industry     || 'Other',
      logoUrl:      companyData.logoUrl      || '',
      signatureUrl: companyData.signatureUrl || '',
      sealUrl:      companyData.sealUrl      || '',
      isVerified:   companyData.isVerified   ?? false,
      isActive:     companyData.isActive     ?? true,
      plan:         companyData.plan         || 'starter',
      adminUid:     adminUid                 || companyData.adminUid || '',
      adminEmail:   (companyData.adminEmail  || companyData.email || '').toLowerCase(),
      payment:      companyData.payment      || {
        method: 'free', reference: 'FREE_TESTING', amount: '0',
        status: 'complimentary', paidAt: now,
      },
      createdAt:    companyData.createdAt    || now,
      updatedAt:    now,
    }, { merge: true });
  }
  fix(`companies/${companyId} — registry document written`);

  // ── 2. Set custom claims on admin user ───────────────────────────────────
  const uid = adminUid || companyData.adminUid;
  if (uid) {
    try {
      if (!DRY_RUN) {
        await auth.setCustomUserClaims(uid, {
          companyId,
          role:       'admin',
          department: 'admin',
        });
      }
      fix(`Auth custom claims set for uid: ${DIM(uid)}`);
    } catch (e) {
      warn(`Could not set custom claims for uid ${uid}: ${e.message}`);
    }
  } else {
    warn(`No adminUid — skipping custom claims`);
  }

  // ── 3. Write admin user doc under data/{companyId}/users/{uid} ───────────
  if (uid && companyData.email) {
    const userRef = root.collection('users').doc(uid);
    if (!DRY_RUN) {
      await userRef.set({
        uid,
        fullName:    companyData.adminName  || companyData.companyName || '',
        email:       (companyData.adminEmail || companyData.email).toLowerCase(),
        officeEmail: (companyData.adminEmail || companyData.email).toLowerCase(),
        phone:       companyData.phone      || '',
        role:        'admin',
        department:  'admin',
        companyId,
        isAdmin:     true,
        isActive:    true,
        createdAt:   now,
        updatedAt:   now,
      }, { merge: true });
    }
    fix(`data/${companyId}/users/${uid} — admin user document written`);
  }

  // ── 4. Write company_profile/main singleton ──────────────────────────────
  const profileRef = root.collection('company_profile').doc('main');
  if (!DRY_RUN) {
    await profileRef.set({
      companyId,
      companyName:  companyData.companyName  || '',
      legalName:    companyData.legalName    || companyData.companyName || '',
      brandName:    companyData.brandName    || companyData.companyName || '',
      email:        (companyData.email || '').toLowerCase(),
      phone:        companyData.phone        || '',
      address:      companyData.address      || '',
      industry:     companyData.industry     || 'Other',
      logoUrl:      companyData.logoUrl      || '',
      signatureUrl: companyData.signatureUrl || '',
      sealUrl:      companyData.sealUrl      || '',
      isVerified:   companyData.isVerified   ?? false,
      isActive:     companyData.isActive     ?? true,
      cashIn:       0,
      cashOut:      0,
      totalEmployees: 0,
      createdAt:    companyData.createdAt    || now,
      updatedAt:    now,
    }, { merge: true });
  }
  fix(`data/${companyId}/company_profile/main — profile singleton written`);

  // ── 5. Seed all module collections with _init sentinel docs ─────────────
  //      Firestore collections only exist once they have at least one document.
  //      The _init doc is a placeholder so the collection appears in the DB.
  //      The Flutter app filters out docs where _sentinel == true.
  info(`Seeding ${ALL_COLLECTIONS.length} collections…`);

  // Firestore batch limit is 500 operations
  const chunks = [];
  for (let i = 0; i < ALL_COLLECTIONS.length; i += 490) {
    chunks.push(ALL_COLLECTIONS.slice(i, i + 490));
  }

  for (const chunk of chunks) {
    const batch = db.batch();
    for (const col of chunk) {
      const ref = root.collection(col).doc('_init');
      batch.set(ref, {
        companyId,
        _sentinel:  true,
        createdAt:  admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    if (!DRY_RUN) await batch.commit();
  }
  fix(`${ALL_COLLECTIONS.length} collections seeded under data/${companyId}/`);

  // ── 6. Write index key documents for fast lookups ───────────────────────
  //      These are small "index" documents stored in a dedicated collection
  //      so the app can quickly look up company-scoped data without
  //      full collection scans.
  const indexRef = root.collection('_index').doc('meta');
  if (!DRY_RUN) {
    await indexRef.set({
      companyId,
      collections:  ALL_COLLECTIONS,
      createdAt:    now,
      updatedAt:    now,
      version:      1,
    }, { merge: true });
  }
  fix(`data/${companyId}/_index/meta — collection index written`);

  ok(`\n  ${G('✔')}  Company ${B(companyId)} fully bootstrapped!`);
}

// ── Create a brand-new company from CLI args ───────────────────────────────────
async function createNewCompany(db, auth) {
  const name  = arg('name');
  const email = arg('email');
  const phone = arg('phone');
  const pass  = arg('pass');

  if (!name || !email || !phone || !pass) {
    console.error(R('\n❌  Missing required arguments for new company creation.'));
    console.error(Y('   Required: --name --email --phone --pass'));
    console.error(Y('   Example:'));
    console.error(Y('     node bootstrap_company.js --name "Acme Ltd" --email admin@acme.com --phone +8801711000000 --pass SecurePass@123'));
    process.exit(1);
  }

  const now = admin.firestore.FieldValue.serverTimestamp();

  // Generate unique company ID
  let companyId = arg('id') || generateId();
  while ((await db.collection('companies').doc(companyId).get()).exists) {
    console.log(`  ID ${companyId} already taken, regenerating…`);
    companyId = generateId();
  }
  console.log(`\n${G('✔')}  Generated Company ID: ${W(companyId)}`);

  // Create Firebase Auth user
  let uid;
  try {
    const userRecord = await auth.createUser({
      email,
      password:     pass,
      displayName:  name,
      phoneNumber:  phone.startsWith('+') ? phone : `+${phone}`,
      emailVerified: false,
    });
    uid = userRecord.uid;
    ok(`Firebase Auth user created: ${DIM(uid)}`);
  } catch (e) {
    if (e.code === 'auth/email-already-exists') {
      const existing = await auth.getUserByEmail(email);
      uid = existing.uid;
      warn(`Auth user already exists: ${DIM(uid)}`);
    } else {
      throw e;
    }
  }

  const companyData = {
    companyId,
    companyName:  name,
    legalName:    name,
    brandName:    name,
    email:        email.toLowerCase(),
    adminEmail:   email.toLowerCase(),
    adminName:    name,
    phone,
    address:      arg('address') || '',
    industry:     arg('industry') || 'Other',
    logoUrl:      '',
    signatureUrl: '',
    sealUrl:      '',
    isVerified:   false,
    isActive:     true,
    plan:         arg('plan') || 'starter',
    adminUid:     uid,
    payment: {
      method: 'free', reference: 'FREE_TESTING', amount: '0',
      status: 'complimentary', paidAt: now,
    },
    createdAt: now,
  };

  await bootstrapCompany(db, auth, companyId, companyData, uid);

  return { companyId, uid, pass };
}

// ── Bootstrap an existing company by ID ───────────────────────────────────────
async function bootstrapExistingById(db, auth, companyId) {
  const snap = await db.collection('companies').doc(companyId).get();
  if (!snap.exists) {
    err(`companies/${companyId} not found. Use --name --email --phone --pass to create a new one.`);
    return;
  }
  const data = snap.data();
  await bootstrapCompany(db, auth, companyId, data, data.adminUid);
}

// ── Bootstrap ALL companies ────────────────────────────────────────────────────
async function bootstrapAll(db, auth) {
  const snap = await db.collection('companies').get();
  const docs = snap.docs.filter(d => d.id !== '_init');

  if (docs.length === 0) {
    warn('No companies found in the database.');
    return;
  }

  info(`Found ${docs.length} company/companies to bootstrap.`);

  for (const doc of docs) {
    const data = doc.data();
    await bootstrapCompany(db, auth, doc.id, data, data.adminUid);
  }
}

// ── Generate firestore.indexes.json ───────────────────────────────────────────
function writeIndexesFile() {
  const projectRoot = path.join(__dirname, '..');
  const outPath     = path.join(projectRoot, 'firestore.indexes.json');
  const content     = buildIndexesJson();

  if (!DRY_RUN) {
    fs.writeFileSync(outPath, content, 'utf8');
    ok(`firestore.indexes.json written to: ${DIM(outPath)}`);
    ok(`Deploy indexes with: ${W('firebase deploy --only firestore:indexes')}`);
  } else {
    info(`[DRY] Would write firestore.indexes.json (${INDEX_DEFINITIONS.length} indexes)`);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────────────────────────────────
async function main() {
  initFirebase();
  const db   = admin.firestore();
  const auth = admin.auth();

  if (DRY_RUN) {
    console.log(Y('\n⚠️  DRY RUN MODE — nothing will be written to Firestore\n'));
  }

  console.log(W('\n══════════════════════════════════════════════════════════════════'));
  console.log(W('  Uddoygi — Company Bootstrapper'));
  console.log(W('══════════════════════════════════════════════════════════════════'));

  // ── Step A: Generate / update firestore.indexes.json ──────────────────────
  section('Step A · Generating Firestore index definitions');
  writeIndexesFile();

  // ── Step B: Bootstrap companies ───────────────────────────────────────────
  section('Step B · Bootstrapping company data');

  let result = null;

  if (ALL) {
    // Bootstrap every company in the database
    await bootstrapAll(db, auth);

  } else if (arg('id')) {
    // Bootstrap a specific existing company
    await bootstrapExistingById(db, auth, arg('id'));

  } else if (arg('name') && arg('email') && arg('phone') && arg('pass')) {
    // Create a brand-new company
    result = await createNewCompany(db, auth);

  } else {
    console.error(R('\n❌  No action specified. Use one of:'));
    console.error(Y('   Create new company:'));
    console.error(Y('     node bootstrap_company.js --name "Acme Ltd" --email admin@acme.com --phone +8801711000000 --pass SecurePass@123'));
    console.error(Y('   Bootstrap existing company by ID:'));
    console.error(Y('     node bootstrap_company.js --id 12345678'));
    console.error(Y('   Bootstrap ALL companies:'));
    console.error(Y('     node bootstrap_company.js --all'));
    console.error(Y('   Dry run (no writes):'));
    console.error(Y('     node bootstrap_company.js --id 12345678 --dry-run'));
    process.exit(1);
  }

  // ── Final report ──────────────────────────────────────────────────────────
  section('Summary');
  console.log(`
  ${G('Operations applied :')} ${_fixed}
  ${Y('Skipped            :')} ${_skipped}
  ${R('Errors             :')} ${_errors}
  ${DRY_RUN ? Y('Mode               : DRY RUN') : G('Mode               : LIVE')}
  `);

  if (result) {
    console.log(`
${W('╔══════════════════════════════════════════════════════════════╗')}
${W('║           COMPANY REGISTRATION COMPLETE                     ║')}
${W('╠══════════════════════════════════════════════════════════════╣')}
${W('║')}  Company ID    : ${B(result.companyId.padEnd(42))}${W('║')}
${W('║')}  Admin Email   : ${DIM((arg('email') || '').padEnd(42))}${W('║')}
${W('║')}  Admin Password: ${DIM(result.pass.padEnd(42))}${W('║')}
${W('║')}  Admin UID     : ${DIM(result.uid.padEnd(42))}${W('║')}
${W('╠══════════════════════════════════════════════════════════════╣')}
${W('║')}  ${Y('⚠  SAVE THE COMPANY ID — users need it to log in')}         ${W('║')}
${W('║')}  ${Y('⚠  SAVE THE PASSWORD   — send it to the admin')}            ${W('║')}
${W('╚══════════════════════════════════════════════════════════════╝')}
`);
  }

  console.log(`\n${B('Next steps:')}`);
  console.log(`  1. Deploy Firestore indexes:  ${W('firebase deploy --only firestore:indexes')}`);
  console.log(`  2. Deploy Firestore rules:    ${W('firebase deploy --only firestore:rules')}`);
  console.log(`  3. Run the Flutter app and log in with the Company ID above.\n`);
}

main().catch((e) => {
  console.error(R(`\n❌  Fatal: ${e.message}`));
  console.error(e.stack);
  process.exit(1);
});
