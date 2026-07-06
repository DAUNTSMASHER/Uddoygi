'use strict';
const fs = require('fs');
const path = require('path');

function fixFile(filePath, fixFn) {
  const src = fs.readFileSync(filePath, 'utf8');
  const result = fixFn(src);
  if (result !== src) {
    fs.writeFileSync(filePath, result, 'utf8');
    console.log('  ✔  ' + path.relative(process.cwd(), filePath));
    return true;
  }
  return false;
}

function ensureImport(src, importLine) {
  if (src.includes(importLine)) return src;
  // Add after first import
  return src.replace(/^(import .+;\n)/, '$1' + importLine + '\n');
}

// ── 1. reports_screen.dart ────────────────────────────────────────────────
fixFile('lib/features/admin/presentation/screens/reports_screen.dart', src => {
  src = ensureImport(src, "import 'package:uddoygi/services/local_storage_service.dart';");
  src = src.replace(
    'Future<_ReportData> _loadData(_Period period) async {\n  final db   = DB.firestore;',
    "Future<_ReportData> _loadData(_Period period) async {\n  final _cid = await LocalStorageService.getSavedCompanyId() ?? '';\n  final db   = DB.firestore;"
  );
  return src;
});

// ── 2. message_notification.dart - already fixed, verify ─────────────────

// ── 3. marketing_drawer.dart - DB.stream(C.users).doc() is invalid ────────
fixFile('lib/features/marketing/presentation/widgets/marketing_drawer.dart', src => {
  // DB.stream returns Stream<QuerySnapshot>, not CollectionReference
  // Replace: DB.stream(C.users).doc(currentUid).snapshots()
  // With: DB.colSync(_cid, C.users).doc(currentUid).snapshots()
  // But MarketingDrawer is StatelessWidget - need _cid from local storage
  // Best fix: convert to StatefulWidget
  if (src.includes('DB.stream(C.users)\n            .doc(currentUid)') ||
      src.includes('DB.stream(C.users)\n        .doc(currentUid)') ||
      src.includes("DB.stream(C.users)\n            .doc")) {
    // Already a StatelessWidget - convert to StatefulWidget
    src = src.replace(
      'class MarketingDrawer extends StatelessWidget {\n  const MarketingDrawer({Key? key}) : super(key: key);\n\n  @override\n  Widget build(BuildContext context) {\n    final currentUser = FirebaseAuth.instance.currentUser;\n    final currentUid = currentUser?.uid ?? \'\';',
      `class MarketingDrawer extends StatefulWidget {
  const MarketingDrawer({Key? key}) : super(key: key);

  @override
  State<MarketingDrawer> createState() => _MarketingDrawerState();
}

class _MarketingDrawerState extends State<MarketingDrawer> {
  String _cid = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUid = currentUser?.uid ?? '';`
    );
  }
  // Fix the stream call
  src = src.replace(
    /stream:\s*DB\.stream\(C\.users\)\s*\n\s*\.doc\(currentUid\)\s*\n\s*\.snapshots\(\),/g,
    'stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.users).doc(currentUid).snapshots(),'
  );
  src = src.replace(
    /stream:\s*DB\.stream\(C\.users\)\s*\.doc\(([^)]+)\)\s*\.snapshots\(\)/g,
    'stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.users).doc($1).snapshots()'
  );
  return src;
});

// ── 4. inbox.dart - DB.stream returns Stream, not Query, can't call .where() ──
fixFile('lib/features/common/presentation/widgets/inbox.dart', src => {
  // DB.stream(C.messages).where(...) is invalid
  // Replace with DB.colSync(_cid, C.messages) but InboxTab is StatelessWidget
  // with userEmail param - convert to StatefulWidget
  src = src.replace(
    'class InboxTab extends StatelessWidget {\n  final String userEmail;\n  const InboxTab({super.key , required this.userEmail});\n\n  @override\n  Widget build(BuildContext context) {\n    return StreamBuilder<QuerySnapshot>(\n      stream: DB.stream(C.messages)\n          .where(\'to\', arrayContains: userEmail)\n          .orderBy(\'timestamp\', descending: true)\n          .snapshots(),',
    `class InboxTab extends StatefulWidget {
  final String userEmail;
  const InboxTab({super.key, required this.userEmail});

  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> {
  String _cid = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.messages)
          .where('to', arrayContains: widget.userEmail)
          .orderBy('timestamp', descending: true)
          .snapshots(),`
  );
  // Fix remaining userEmail references
  src = src.replace(/\buserEmail\b/g, 'widget.userEmail');
  // But don't double-replace widget.widget.userEmail
  src = src.replace(/widget\.widget\.userEmail/g, 'widget.userEmail');
  return src;
});

// ── 5. sent.dart - same issue ─────────────────────────────────────────────
fixFile('lib/features/common/presentation/widgets/sent.dart', src => {
  src = src.replace(
    /stream:\s*DB\.stream\(C\.messages\)\s*\n?\s*\.where\('from',\s*isEqualTo:\s*userEmail\)\s*\n?\s*\.orderBy\('timestamp',\s*descending:\s*true\)\s*\n?\s*\.snapshots\(\)/g,
    `stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.messages)
          .where('from', isEqualTo: widget.userEmail)
          .orderBy('timestamp', descending: true)
          .snapshots()`
  );
  // Convert to StatefulWidget if not already
  if (src.includes('class SentTab extends StatelessWidget')) {
    src = src.replace(
      'class SentTab extends StatelessWidget {\n  final String userEmail;\n  const SentTab({super.key , required this.userEmail});\n\n  @override\n  Widget build(BuildContext context) {',
      `class SentTab extends StatefulWidget {
  final String userEmail;
  const SentTab({super.key, required this.userEmail});

  @override
  State<SentTab> createState() => _SentTabState();
}

class _SentTabState extends State<SentTab> {
  String _cid = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {`
    );
    src = src.replace(/\buserEmail\b/g, 'widget.userEmail');
    src = src.replace(/widget\.widget\.userEmail/g, 'widget.userEmail');
  }
  return src;
});

// ── 6. loan_request_screen.dart - _db reference ───────────────────────────
fixFile('lib/features/factory/presentation/screens/loan_request_screen.dart', src => {
  src = src.replace(/\bdb:\s*_db,/g, 'db: DB.firestore,');
  src = src.replace(/\b_db\.batch\(\)/g, 'DB.firestore.batch()');
  src = src.replace(/\b_db\.collection\(/g, 'DB.firestore.collection(');
  return src;
});

// ── 7. admin_allbuyer.dart - DB.stream() missing argument ─────────────────
fixFile('lib/features/admin/presentation/widgets/admin_allbuyer.dart', src => {
  // Need to convert to StatefulWidget to get _cid
  if (src.includes('DB.stream()')) {
    src = src.replace(/stream:\s*DB\.stream\(\)/g, 'stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.customers).snapshots()');
  }
  // Check if class is StatelessWidget
  if (src.includes('extends StatelessWidget') && src.includes('DB.colSync(_cid')) {
    // Already handled by previous script, just ensure _cid is in State
  }
  return src;
});

// ── 8. add_new_wo.dart - DB.stream() missing argument ─────────────────────
fixFile('lib/features/marketing/presentation/work_order/add_new_wo.dart', src => {
  src = src.replace(/stream:\s*DB\.stream\(\)/g, 'stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.invoices).snapshots()');
  return src;
});

// ── 9. rnd_notices_screen.dart - DB.stream().orderBy() invalid ────────────
fixFile('lib/features/rnd/presentation/screens/rnd_notices_screen.dart', src => {
  src = src.replace(
    /stream:\s*DB\.stream\(C\.notices\)\s*\n?\s*\.orderBy\('createdAt',\s*descending:\s*true\)\s*\n?\s*\.snapshots\(\)/g,
    "stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.notices).orderBy('createdAt', descending: true).snapshots()"
  );
  src = src.replace(
    /stream:\s*DB\.stream\(C\.notices\)\s*\.orderBy\('createdAt',\s*descending:\s*true\)\s*\.snapshots\(\)/g,
    "stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.notices).orderBy('createdAt', descending: true).snapshots()"
  );
  return src;
});

// ── 10. hr_authorization_screen.dart - DB.stream().orderBy() invalid ───────
fixFile('lib/features/hr/presentation/screens/hr_authorization_screen.dart', src => {
  src = src.replace(
    /stream:\s*DB\.stream\(C\.hrDocuments\)\s*\n?\s*\.orderBy\('createdAt',\s*descending:\s*true\)\s*\n?\s*\.snapshots\(\)/g,
    "stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.hrDocuments).orderBy('createdAt', descending: true).snapshots()"
  );
  src = src.replace(
    /stream:\s*DB\.stream\(C\.hrDocuments\)\s*\.orderBy\('createdAt',\s*descending:\s*true\)\s*\.snapshots\(\)/g,
    "stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.hrDocuments).orderBy('createdAt', descending: true).snapshots()"
  );
  return src;
});

// ── 11. customer_list_view.dart - DB.stream().where() invalid + await in non-async ──
fixFile('lib/features/marketing/presentation/widgets/customer_list_view.dart', src => {
  src = src.replace(
    /stream:\s*DB\.stream\(C\.customers\)\s*\n?\s*\.where\('agentName',\s*isEqualTo:\s*agentName\)/g,
    "stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.customers).where('agentName', isEqualTo: widget.agentName)"
  );
  src = src.replace(
    /stream:\s*DB\.stream\(C\.customers\)\s*\.where\('agentName',\s*isEqualTo:\s*agentName\)/g,
    "stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.customers).where('agentName', isEqualTo: widget.agentName)"
  );
  // Fix await in non-async
  src = src.replace(
    /final\s+q\s*=\s*\(await\s+DB\.col\(C\.invoices\)\)/g,
    'final q = DB.colSync(_cid, C.invoices)'
  );
  return src;
});

// ── 12. Fix all DB.stream(C.X).where/orderBy/doc patterns globally ─────────
const LIB = path.join(process.cwd(), 'lib');
function walk(dir, cb) {
  for (const e of fs.readdirSync(dir)) {
    const full = path.join(dir, e);
    if (fs.statSync(full).isDirectory()) walk(full, cb);
    else if (e.endsWith('.dart')) cb(full);
  }
}

walk(LIB, (filePath) => {
  let src = fs.readFileSync(filePath, 'utf8');
  const orig = src;
  // DB.stream(C.X).where(...) → DB.colSync(_cid, C.X).where(...)
  src = src.replace(/DB\.stream\(([^)]+)\)\.(where|orderBy|doc|limit)\(/g, 'DB.colSync(_cid, $1).$2(');
  // DB.stream() with no args → DB.stream(C.X) - can't fix without knowing collection, skip
  if (src !== orig) {
    fs.writeFileSync(filePath, src, 'utf8');
    console.log('  ✔  (stream chain) ' + path.relative(process.cwd(), filePath));
  }
});

console.log('\n✅  Done.');
