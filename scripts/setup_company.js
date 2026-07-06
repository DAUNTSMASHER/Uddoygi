/**
 * setup_company.js
 * ─────────────────────────────────────────────────────────────
 * Firebase Admin SDK — Multi-Tenant Company Bootstrapper
 *
 * Usage:
 *   node setup_company.js \
 *     --name   "Acme Textiles Ltd." \
 *     --email  "admin@acmetextiles.com" \
 *     --phone  "+8801711000000" \
 *     --pass   "SecurePass@123"
 *
 * Optional flags:
 *   --industry  "Textile"        (default: "Other")
 *   --address   "Dhaka, BD"
 *   --plan      "starter"        (default: "starter")
 *   --id        "12345678"       (provide a specific ID; auto-generated if omitted)
 *
 * What this script does:
 *   1. Generates a unique 8-digit Company ID (or uses --id)
 *   2. Creates a Firebase Auth user for the admin
 *   3. Sets custom claims: { companyId, role: "admin", department: "admin" }
 *   4. Writes companies/{companyId} document
 *   5. Writes users/{uid} document
 *   6. Bootstraps all module collections with sentinel init documents
 *   7. Writes company/main document (mirrors the Flutter app's schema)
 *   8. Prints a summary with the Company ID and admin credentials
 *
 * Prerequisites:
 *   npm install firebase-admin
 *   Set GOOGLE_APPLICATION_CREDENTIALS env var to your service account JSON
 *   OR place serviceAccountKey.json in this directory.
 * ─────────────────────────────────────────────────────────────
 */

'use strict';

const admin = require('firebase-admin');
const path  = require('path');
const fs    = require('fs');

// ── Initialise Firebase Admin ─────────────────────────────────
function initFirebase() {
  if (admin.apps.length > 0) return; // already initialised

  const keyPath = path.join(__dirname, 'serviceAccountKey.json');
  if (fs.existsSync(keyPath)) {
    const serviceAccount = require(keyPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  } else {
    // Fall back to Application Default Credentials
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  }
}

// ── Parse CLI args ────────────────────────────────────────────
function parseArgs() {
  const args = process.argv.slice(2);
  const map  = {};
  for (let i = 0; i < args.length; i += 2) {
    const key = args[i].replace(/^--/, '');
    map[key]  = args[i + 1] ?? '';
  }
  return map;
}

// ── Generate unique 8-digit ID ────────────────────────────────
function generateId() {
  return String(Math.floor(10_000_000 + Math.random() * 90_000_000));
}

async function isIdTaken(db, id) {
  const snap = await db.collection('companies').doc(id).get();
  return snap.exists;
}

// ── Core collections to bootstrap ────────────────────────────
const MODULE_COLLECTIONS = [
  'notices', 'invoices', 'expenses', 'salaries', 'welfare',
  'complaints', 'messages', 'notifications',
  'rnd_projects', 'rnd_requests', 'rnd_updates', 'rnd_milestones', 'rnd_scores',
  'orders', 'work_orders', 'campaigns', 'clients', 'products',
  'attendance', 'loans', 'payrolls', 'cash_flow',
  'hr_documents', 'payment_slips', 'budgets', 'marketing_incentives',
];

// ─────────────────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────────────────
async function main() {
  initFirebase();

  const args = parseArgs();

  // Validate required args
  const required = ['name', 'email', 'phone', 'pass'];
  for (const r of required) {
    if (!args[r]) {
      console.error(`❌  Missing required argument: --${r}`);
      process.exit(1);
    }
  }

  const db   = admin.firestore();
  const auth = admin.auth();
  const now  = admin.firestore.FieldValue.serverTimestamp();

  // ── 1. Generate / validate Company ID ──────────────────────
  let companyId = args.id ?? generateId();
  while (await isIdTaken(db, companyId)) {
    console.log(`  ID ${companyId} already taken, regenerating…`);
    companyId = generateId();
  }
  console.log(`\n✅  Company ID: ${companyId}`);

  // ── 2. Create Firebase Auth user ───────────────────────────
  let uid;
  try {
    const userRecord = await auth.createUser({
      email:        args.email,
      password:     args.pass,
      displayName:  args.name,
      phoneNumber:  args.phone.startsWith('+') ? args.phone : `+${args.phone}`,
      emailVerified: false,
    });
    uid = userRecord.uid;
    console.log(`✅  Auth user created: ${uid}`);
  } catch (err) {
    if (err.code === 'auth/email-already-exists') {
      // Fetch existing user
      const existing = await auth.getUserByEmail(args.email);
      uid = existing.uid;
      console.log(`ℹ️   Auth user already exists: ${uid}`);
    } else {
      throw err;
    }
  }

  // ── 3. Set custom claims ────────────────────────────────────
  await auth.setCustomUserClaims(uid, {
    companyId,
    role:       'admin',
    department: 'admin',
  });
  console.log(`✅  Custom claims set`);

  // ── 4. Write companies/{companyId} ──────────────────────────
  await db.collection('companies').doc(companyId).set({
    companyId,
    companyName:   args.name,
    legalName:     args.name,
    brandName:     args.name,
    email:         args.email,
    phone:         args.phone,
    address:       args.address ?? '',
    industry:      args.industry ?? 'Other',
    logoUrl:       '',
    signatureUrl:  '',
    sealUrl:       '',
    isVerified:    false,
    isActive:      true,
    plan:          args.plan ?? 'starter',
    adminUid:      uid,
    adminEmail:    args.email,
    payment: {
      method:    'setup_script',
      reference: 'ADMIN_SETUP',
      status:    'complimentary',
      paidAt:    now,
    },
    createdAt:     now,
    updatedAt:     now,
  });
  console.log(`✅  companies/${companyId} written`);

  // ── 5. Write users/{uid} ────────────────────────────────────
  await db.collection('users').doc(uid).set({
    uid,
    fullName:     args.name,
    email:        args.email,
    officeEmail:  args.email,
    phone:        args.phone,
    role:         'admin',
    department:   'admin',
    companyId,
    isAdmin:      true,
    isActive:     true,
    createdAt:    now,
    updatedAt:    now,
  });
  console.log(`✅  users/${uid} written`);

  // ── 6. Write company/main (Flutter app schema) ──────────────
  await db.collection('company').doc('main').set({
    companyId,
    companyName:   args.name,
    legalName:     args.name,
    brandName:     args.name,
    email:         args.email,
    phone:         args.phone,
    industry:      args.industry ?? 'Other',
    logoUrl:       '',
    isVerified:    false,
    isActive:      true,
    cashIn:        0,
    cashOut:       0,
    createdAt:     now,
    updatedAt:     now,
  }, { merge: true });
  console.log(`✅  company/main written`);

  // ── 7. Bootstrap module collections ─────────────────────────
  const batch = db.batch();
  for (const col of MODULE_COLLECTIONS) {
    const ref = db.collection(col).doc('_init');
    batch.set(ref, {
      companyId,
      createdAt: now,
      _sentinel: true,
    }, { merge: true });
  }
  await batch.commit();
  console.log(`✅  ${MODULE_COLLECTIONS.length} module collections bootstrapped`);

  // ── 8. Print summary ─────────────────────────────────────────
  console.log(`
╔══════════════════════════════════════════════════════╗
║          COMPANY REGISTRATION COMPLETE               ║
╠══════════════════════════════════════════════════════╣
║  Company Name  : ${args.name.padEnd(35)}║
║  Company ID    : ${companyId.padEnd(35)}║
║  Admin Email   : ${args.email.padEnd(35)}║
║  Admin UID     : ${uid.padEnd(35)}║
╠══════════════════════════════════════════════════════╣
║  ⚠️  SAVE THE COMPANY ID — users need it to log in   ║
║  Share it with the company owner via SMS / email.    ║
╚══════════════════════════════════════════════════════╝
`);
}

main().catch((err) => {
  console.error('❌  Fatal error:', err);
  process.exit(1);
});
