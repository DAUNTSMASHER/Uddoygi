/**
 * fix_isolation.js  v2
 * Rewrites every Dart file to use DB.colSync(_cid, C.X) for company-scoped
 * Firestore access. Handles both single-line and multi-line patterns.
 *
 * Run from project root:
 *   node scripts/fix_isolation.js --dry-run
 *   node scripts/fix_isolation.js
 */
'use strict';

const fs   = require('fs');
const path = require('path');

const DRY_RUN = process.argv.includes('--dry-run');
const LIB_DIR = path.join(process.cwd(), 'lib');

const COMPANY_COLS = {
  'users':               'C.users',
  'notifications':       'C.notifications',
  'messages':            'C.messages',
  'notices':             'C.notices',
  'complaints':          'C.complaints',
  'alerts':              'C.alerts',
  'alert_dispatch':      'C.alertDispatch',
  'welfare':             'C.welfare',
  'welfare_requests':    'C.welfareRequests',
  'welfare_schemes':     'C.welfareSchemes',
  'employees':           'C.employees',
  'payrolls':            'C.payrolls',
  'salaries':            'C.salaries',
  'leaves':              'C.leaves',
  'leave_requests':      'C.leaveRequests',
  'shifts':              'C.shifts',
  'benefits':            'C.benefits',
  'attendance':          'C.attendance',
  'loans':               'C.loans',
  'loan_requests':       'C.loanRequests',
  'taxes':               'C.taxes',
  'procurements':        'C.procurements',
  'applicants':          'C.applicants',
  'promotions':          'C.promotions',
  'recommendation':      'C.recommendation',
  'hr_documents':        'C.hrDocuments',
  'marketing_incentives':'C.marketingIncentives',
  'punishments':         'C.punishments',
  'invoices':            'C.invoices',
  'payment_slips':       'C.paymentSlips',
  'cash_flow':           'C.cashFlow',
  'expenses':            'C.expenses',
  'ledger':              'C.ledger',
  'budgets':             'C.budgets',
  'budget':              'C.budget',
  'accounts':            'C.accounts',
  'targets':             'C.targets',
  'customers':           'C.customers',
  'products':            'C.products',
  'product_prices':      'C.productPrices',
  'campaigns':           'C.campaigns',
  'tasks':               'C.tasks',
  'qc_reports':          'C.qcReports',
  'address_validations': 'C.addressValidations',
  'work_orders':         'C.workOrders',
  'work_order_tracking': 'C.workOrderTracking',
  'tracking_index':      'C.trackingIndex',
  'daily_production':    'C.dailyProduction',
  'purchase_orders':     'C.purchaseOrders',
  'stocks':              'C.stocks',
  'rnd_requests':        'C.rndRequests',
  'rnd_projects':        'C.rndProjects',
  'rnd_updates':         'C.rndUpdates',
  'rnd_milestones':      'C.rndMilestones',
  'rnd_scores':          'C.rndScores',
  'company_profile':     'C.companyProfile',
};

let totalFiles = 0, changedFiles = 0;

function walkDir(dir, cb) {
  for (const e of fs.readdirSync(dir)) {
    const full = path.join(dir, e);
    if (fs.statSync(full).isDirectory()) walkDir(full, cb);
    else if (e.endsWith('.dart')) cb(full);
  }
}

function esc(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }

function transformFile(filePath) {
  const rel = path.relative(process.cwd(), filePath);

  if (filePath.endsWith(path.sep + 'db.dart')) return;
  if (filePath.includes('company_registration_screen') ||
      filePath.includes('login_screen') ||
      filePath.includes('forgot_company_id')) return;

  let src = fs.readFileSync(filePath, 'utf8');
  if (!src.includes('cloud_firestore')) return;

  totalFiles++;
  const original = src;

  // ── 1. Ensure imports ──────────────────────────────────────────────────────
  if (!src.includes("services/db.dart")) {
    src = src.replace(
      /import 'package:cloud_firestore\/cloud_firestore\.dart';/,
      `import 'package:cloud_firestore/cloud_firestore.dart';\nimport 'package:uddoygi/services/db.dart';`
    );
  }
  if (!src.includes("local_storage_service.dart")) {
    src = src.replace(
      /import 'package:uddoygi\/services\/db\.dart';/,
      `import 'package:uddoygi/services/db.dart';\nimport 'package:uddoygi/services/local_storage_service.dart';`
    );
  }

  // ── 2. Detect if this is a StatefulWidget file ─────────────────────────────
  const isStateful = /class\s+\w+\s+extends\s+State</.test(src);

  // ── 3. Inject _cid field + initState loading (StatefulWidget only) ─────────
  if (isStateful && !src.includes('_cid') && !src.includes('String _companyId')) {
    src = src.replace(
      /(class\s+\w+\s+extends\s+State<[^>]+>\s*(?:with\s+[^{]+)?\{)/,
      `$1\n  String _cid = '';`
    );
    if (src.includes('void initState()')) {
      src = src.replace(
        /(void initState\(\)\s*\{[^}]*super\.initState\(\);)/,
        `$1\n    LocalStorageService.getSavedCompanyId().then((id) {\n      if (mounted) setState(() => _cid = id ?? '');\n    });`
      );
    } else {
      src = src.replace(
        /(\s+@override\s+Widget build\()/,
        `\n  @override\n  void initState() {\n    super.initState();\n    LocalStorageService.getSavedCompanyId().then((id) {\n      if (mounted) setState(() => _cid = id ?? '');\n    });\n  }\n$1`
      );
    }
  }

  // ── 4. Build replacement patterns ─────────────────────────────────────────
  // Match: (prefix)(optional whitespace/newlines).collection('X')
  // The 's' flag makes . match newlines too.
  const fsPrefixes = [
    'FirebaseFirestore\\.instance',
    '_db',
    '_firestore',
    '(?<![a-zA-Z0-9_])db(?![a-zA-Z0-9_])',
    '(?<![a-zA-Z0-9_])fs(?![a-zA-Z0-9_])',
  ];
  const prefixPat = `(?:${fsPrefixes.join('|')})`;
  const ws = `[\\s]*`; // optional whitespace including newlines

  // company_profile/main
  src = src.replace(
    new RegExp(`${prefixPat}${ws}\\.collection\\('company'\\)${ws}\\.doc\\('main'\\)`, 'gs'),
    isStateful ? `DB.colSync(_cid, C.companyProfile).doc('main')` : `(await DB.doc(C.companyProfile, 'main'))`
  );

  // root-level: companies
  src = src.replace(
    new RegExp(`${prefixPat}${ws}\\.collection\\('companies'\\)`, 'gs'),
    'DB.companiesCol'
  );

  // root-level: smtp_config
  src = src.replace(
    new RegExp(`${prefixPat}${ws}\\.collection\\('smtp_config'\\)`, 'gs'),
    `DB.firestore.collection('smtp_config')`
  );

  // company-scoped collections
  for (const [col, cConst] of Object.entries(COMPANY_COLS)) {
    const colPat = new RegExp(`${prefixPat}${ws}\\.collection\\('${esc(col)}'\\)`, 'gs');
    const replacement = isStateful
      ? `DB.colSync(_cid, ${cConst})`
      : `(await DB.col(${cConst}))`;
    src = src.replace(colPat, replacement);
  }

  // ── 5. Replace remaining FirebaseFirestore.instance ───────────────────────
  src = src.replace(/FirebaseFirestore\.instance/g, 'DB.firestore');

  // ── 6. Remove now-unused _db / _firestore field declarations ──────────────
  src = src.replace(/\s*final\s+_db\s*=\s*DB\.firestore;\n?/g, '\n');
  src = src.replace(/\s*final\s+_firestore\s*=\s*DB\.firestore;\n?/g, '\n');
  src = src.replace(/\s*final\s+FirebaseFirestore\s+_db\s*=\s*DB\.firestore;\n?/g, '\n');

  if (src !== original) {
    changedFiles++;
    if (DRY_RUN) {
      console.log(`  [DRY] ${rel}`);
    } else {
      fs.writeFileSync(filePath, src, 'utf8');
      console.log(`  ✔  ${rel}`);
    }
  }
}

console.log(DRY_RUN ? '\n⚠️  DRY RUN\n' : '\n🔄  Fixing data isolation (v2)...\n');
walkDir(LIB_DIR, transformFile);
console.log(`\n✅  Done. Scanned: ${totalFiles}, Updated: ${changedFiles}`);
if (DRY_RUN) console.log('   Run without --dry-run to apply.');
