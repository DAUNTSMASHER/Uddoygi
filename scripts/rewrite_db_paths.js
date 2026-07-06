/**
 * rewrite_db_paths.js
 * ─────────────────────────────────────────────────────────────
 * Rewrites all Dart files in lib/ to use the new DB helper
 * (lib/services/db.dart) instead of hardcoded Firestore paths.
 *
 * NEW STRUCTURE:
 *   OLD: FirebaseFirestore.instance.collection('invoices')
 *   NEW: await DB.col(C.invoices)
 *
 *   OLD: FirebaseFirestore.instance.collection('users').doc(uid)
 *   NEW: (await DB.col(C.users)).doc(uid)
 *
 * Run from project root:
 *   node scripts/rewrite_db_paths.js
 *   node scripts/rewrite_db_paths.js --dry-run   (preview only)
 * ─────────────────────────────────────────────────────────────
 */

'use strict';

const fs   = require('fs');
const path = require('path');

const DRY_RUN = process.argv.includes('--dry-run');
const LIB_DIR = path.join(process.cwd(), 'lib');

// ── Collections that are company-scoped (live under data/{cid}/) ──
const COMPANY_SCOPED = new Set([
  'users', 'notifications', 'messages', 'notices', 'complaints',
  'alerts', 'alert_dispatch', 'welfare', 'welfare_requests',
  'welfare_schemes', 'employees', 'payrolls', 'salaries', 'leaves',
  'leave_requests', 'shifts', 'benefits', 'attendance', 'loans',
  'loan_requests', 'taxes', 'procurements', 'applicants', 'promotions',
  'recommendation', 'hr_documents', 'marketing_incentives', 'punishments',
  'invoices', 'payment_slips', 'cash_flow', 'expenses', 'ledger',
  'budgets', 'budget', 'accounts', 'targets', 'customers', 'products',
  'product_prices', 'campaigns', 'tasks', 'qc_reports',
  'address_validations', 'work_orders', 'work_order_tracking',
  'tracking_index', 'daily_production', 'purchase_orders', 'stocks',
  'rnd_requests', 'rnd_projects', 'rnd_updates', 'rnd_milestones',
  'rnd_scores', 'orders', 'clients', 'company_profile',
]);

// Map from old string name → C.constant name
const C_MAP = {
  users:               'C.users',
  notifications:       'C.notifications',
  messages:            'C.messages',
  notices:             'C.notices',
  complaints:          'C.complaints',
  alerts:              'C.alerts',
  alert_dispatch:      'C.alertDispatch',
  welfare:             'C.welfare',
  welfare_requests:    'C.welfareRequests',
  welfare_schemes:     'C.welfareSchemes',
  employees:           'C.employees',
  payrolls:            'C.payrolls',
  salaries:            'C.salaries',
  leaves:              'C.leaves',
  leave_requests:      'C.leaveRequests',
  shifts:              'C.shifts',
  benefits:            'C.benefits',
  attendance:          'C.attendance',
  loans:               'C.loans',
  loan_requests:       'C.loanRequests',
  taxes:               'C.taxes',
  procurements:        'C.procurements',
  applicants:          'C.applicants',
  promotions:          'C.promotions',
  recommendation:      'C.recommendation',
  hr_documents:        'C.hrDocuments',
  marketing_incentives:'C.marketingIncentives',
  punishments:         'C.punishments',
  invoices:            'C.invoices',
  payment_slips:       'C.paymentSlips',
  cash_flow:           'C.cashFlow',
  expenses:            'C.expenses',
  ledger:              'C.ledger',
  budgets:             'C.budgets',
  budget:              'C.budget',
  accounts:            'C.accounts',
  targets:             'C.targets',
  customers:           'C.customers',
  products:            'C.products',
  product_prices:      'C.productPrices',
  campaigns:           'C.campaigns',
  tasks:               'C.tasks',
  qc_reports:          'C.qcReports',
  address_validations: 'C.addressValidations',
  work_orders:         'C.workOrders',
  work_order_tracking: 'C.workOrderTracking',
  tracking_index:      'C.trackingIndex',
  daily_production:    'C.dailyProduction',
  purchase_orders:     'C.purchaseOrders',
  stocks:              'C.stocks',
  rnd_requests:        'C.rndRequests',
  rnd_projects:        'C.rndProjects',
  rnd_updates:         'C.rndUpdates',
  rnd_milestones:      'C.rndMilestones',
  rnd_scores:          'C.rndScores',
  company_profile:     'C.companyProfile',
  orders:              "'orders'",
  clients:             "'clients'",
};

// Prefixes that mean "get Firestore instance"
const FS_PREFIXES = [
  'FirebaseFirestore\\.instance',
  '_db',
  '_firestore',
  'firestore(?!\\w)',
  'fs(?!\\w)',
  'db(?!\\w)',
];

let totalFiles = 0;
let changedFiles = 0;

// ── Walk lib/ recursively ─────────────────────────────────────
function walkDir(dir, callback) {
  for (const entry of fs.readdirSync(dir)) {
    const full = path.join(dir, entry);
    const stat = fs.statSync(full);
    if (stat.isDirectory()) {
      walkDir(full, callback);
    } else if (entry.endsWith('.dart')) {
      callback(full);
    }
  }
}

// ── Transform a single Dart file ─────────────────────────────
function transformFile(filePath) {
  // Skip the DB helper itself
  if (filePath.endsWith(path.join('services', 'db.dart'))) return;

  let src = fs.readFileSync(filePath, 'utf8');
  const original = src;

  // Only process files that use cloud_firestore
  if (!src.includes('cloud_firestore')) return;

  totalFiles++;

  // ── Add import for db.dart if not already present ──────────
  if (!src.includes("services/db.dart")) {
    src = src.replace(
      /import 'package:cloud_firestore\/cloud_firestore\.dart';/,
      `import 'package:cloud_firestore/cloud_firestore.dart';\nimport 'package:uddoygi/services/db.dart';`
    );
  }

  // ── Replace .collection('company').doc('main') → company_profile ──
  // Must do this BEFORE the general collection replacements
  const fsPrefixPattern = FS_PREFIXES.join('|');
  src = src.replace(
    new RegExp(`(?:${fsPrefixPattern})\\.collection\\('company'\\)\\.doc\\('main'\\)`, 'g'),
    `(await DB.doc(C.companyProfile, 'main'))`
  );
  src = src.replace(
    /\.collection\('company'\)\.doc\('main'\)/g,
    `(await DB.doc(C.companyProfile, 'main'))`
  );

  // ── Replace .collection('companies') → DB.companiesCol ─────
  for (const prefix of FS_PREFIXES) {
    src = src.replace(
      new RegExp(`(?:${prefix})\\.collection\\('companies'\\)`, 'g'),
      'DB.companiesCol'
    );
  }
  // bare .collection('companies') at start of chain
  src = src.replace(/(?<!\w)\.collection\('companies'\)/g, 'DB.companiesCol');

  // ── Replace .collection('smtp_config') → stays root-level ──
  for (const prefix of FS_PREFIXES) {
    src = src.replace(
      new RegExp(`(?:${prefix})\\.collection\\('smtp_config'\\)`, 'g'),
      `DB.firestore.collection('smtp_config')`
    );
  }

  // ── Replace company-scoped collections ─────────────────────
  for (const [colName, cConst] of Object.entries(C_MAP)) {
    if (!COMPANY_SCOPED.has(colName)) continue;

    // Pattern: (prefix).collection('colName')
    for (const prefix of FS_PREFIXES) {
      src = src.replace(
        new RegExp(`(?:${prefix})\\.collection\\('${colName}'\\)`, 'g'),
        `(await DB.col(${cConst}))`
      );
    }

    // Pattern: bare .collection('colName') (chained from something)
    // Only replace when it's clearly a top-level call
    src = src.replace(
      new RegExp(`(?<![a-zA-Z0-9_])\\.collection\\('${colName}'\\)`, 'g'),
      `(await DB.col(${cConst}))`
    );
  }

  // ── Replace DB.firestore with DB.firestore (no-op, already correct) ──
  // Replace remaining FirebaseFirestore.instance with DB.firestore
  src = src.replace(/FirebaseFirestore\.instance(?!\s*\.collection)/g, 'DB.firestore');

  // ── Fix users/{uid}/fcmTokens → DB.fcmTokensCol(uid) ───────
  src = src.replace(
    /\(await DB\.col\(C\.users\)\)\.doc\(([^)]+)\)\.collection\('fcmTokens'\)/g,
    'DB.fcmTokensCol($1)'
  );

  // ── Fix users/{uid}/devices → DB.devicesCol(uid) ───────────
  src = src.replace(
    /\(await DB\.col\(C\.users\)\)\.doc\(([^)]+)\)\.collection\('devices'\)/g,
    'DB.devicesCol($1)'
  );

  if (src !== original) {
    changedFiles++;
    const rel = path.relative(process.cwd(), filePath);
    if (DRY_RUN) {
      console.log(`  [DRY] Would update: ${rel}`);
    } else {
      fs.writeFileSync(filePath, src, 'utf8');
      console.log(`  ✔  Updated: ${rel}`);
    }
  }
}

// ── Main ──────────────────────────────────────────────────────
console.log(DRY_RUN ? '\n⚠️  DRY RUN — no files will be written\n' : '\n🔄  Rewriting Dart files...\n');

walkDir(LIB_DIR, transformFile);

console.log(`\n✅  Done.`);
console.log(`   Files scanned (with cloud_firestore): ${totalFiles}`);
console.log(`   Files ${DRY_RUN ? 'that would be' : ''} updated: ${changedFiles}`);
console.log(DRY_RUN ? '\n   Run without --dry-run to apply changes.' : '');
