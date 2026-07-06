'use strict';
const fs = require('fs');
const path = require('path');

function fix(filePath, fn) {
  const src = fs.readFileSync(filePath, 'utf8');
  const result = fn(src);
  if (result !== src) {
    fs.writeFileSync(filePath, result, 'utf8');
    console.log('  ✔  ' + path.relative(process.cwd(), filePath));
  }
}

// ─── inbox.dart ──────────────────────────────────────────────────────────────
// The script mangled it - rewrite properly
fs.writeFileSync('lib/features/common/presentation/widgets/inbox.dart', `import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InboxTab extends StatefulWidget {
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
      stream: _cid.isEmpty
          ? const Stream.empty()
          : DB.colSync(_cid, C.messages)
              .where('to', arrayContains: widget.userEmail)
              .orderBy('timestamp', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.indigo));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: \${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: const Text('No new messages',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                  subtitle: const Text('Your inbox is empty.',
                      style: TextStyle(color: Colors.black54)),
                  trailing: const Icon(Icons.inbox, color: Colors.indigo),
                ),
              ),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, idx) {
            final data = docs[idx].data() as Map<String, dynamic>;
            final fromField = data['from']?.toString() ?? '';
            final subject = data['subject']?.toString() ?? '(No Subject)';
            final body = data['body']?.toString() ?? '';
            final ts = data['timestamp'];
            String time = '';
            if (ts is Timestamp) {
              time = DateFormat('MMM d, h:mm a').format(ts.toDate());
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(subject,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                  subtitle: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (fromField.isNotEmpty)
                        Text('From: \$fromField',
                            style: const TextStyle(color: Colors.black54, fontSize: 13)),
                      Text(body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black87, fontSize: 14)),
                      if (time.isNotEmpty)
                        Text(time, style: const TextStyle(fontSize: 12, color: Colors.indigo)),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.indigo),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
`, 'utf8');
console.log('  ✔  lib/features/common/presentation/widgets/inbox.dart (rewritten)');

// ─── messages_screen.dart ────────────────────────────────────────────────────
fix('lib/features/common/presentation/screens/messages_screen.dart', src => {
  // Fix InboxTab(widget: ..., userEmail: ...) → InboxTab(userEmail: ...)
  src = src.replace(/InboxTab\(\s*widget:\s*[^,]+,\s*userEmail:\s*([^)]+)\)/g, 'InboxTab(userEmail: $1)');
  src = src.replace(/InboxTab\(\s*widget:\s*[^)]+\)/g, 'InboxTab(userEmail: \'\')');
  return src;
});

// ─── complaint_against_me.dart ───────────────────────────────────────────────
fix('lib/features/common/complaints/complaint_against_me.dart', src => {
  // DB.stream(C.X).where(...).orderBy(...) → DB.colSync(_cid, C.X).where(...).orderBy(...)
  src = src.replace(/DB\.stream\(([^)]+)\)\.(where|orderBy|doc|limit)\(/g, 'DB.colSync(_cid, $1).$2(');
  return src;
});

// ─── complaint_from_me.dart ──────────────────────────────────────────────────
fix('lib/features/common/complaints/complaint_from_me.dart', src => {
  src = src.replace(/DB\.stream\(([^)]+)\)\.(where|orderBy|doc|limit)\(/g, 'DB.colSync(_cid, $1).$2(');
  return src;
});

// ─── incoming_products.dart ──────────────────────────────────────────────────
fix('lib/features/marketing/presentation/work_order/incoming_products.dart', src => {
  src = src.replace(/DB\.stream\(([^)]+)\)\.(where|orderBy|doc|limit)\(/g, 'DB.colSync(_cid, $1).$2(');
  return src;
});

// ─── notification.dart ───────────────────────────────────────────────────────
// Methods on widget class, State can't find them
fix('lib/features/common/notification.dart', src => {
  // Find the widget class with _stream, _markAllRead, _when methods
  // and move them to the State class
  // Check if there's a StatefulWidget with these methods
  const widgetMatch = src.match(/class\s+(\w+)\s+extends\s+StatefulWidget[^{]*\{/);
  if (!widgetMatch) return src;
  
  // Find _stream, _markAllRead, _when in widget class body
  // Strategy: if _cid is used in widget class, convert properly
  src = src.replace(/DB\.stream\(([^)]+)\)\.(where|orderBy|doc|limit)\(/g, 'DB.colSync(_cid, $1).$2(');
  return src;
});

// ─── stockhistory.dart ───────────────────────────────────────────────────────
fix('lib/features/common/stock/stockhistory.dart', src => {
  // _DashboardTab is a StatelessWidget using _cid - convert to StatefulWidget
  if (src.includes('class _DashboardTab extends StatelessWidget')) {
    src = src.replace(
      'class _DashboardTab extends StatelessWidget {',
      `class _DashboardTab extends StatefulWidget {
  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  String _cid = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }`
    );
    // Remove duplicate @override Widget build if any
  }
  return src;
});

// ─── leave_data_source.dart ──────────────────────────────────────────────────
fix('lib/features/hr/data/datasources/leave_data_source.dart', src => {
  // Add _getCid helper if not present
  if (!src.includes('_getCid')) {
    src = src.replace(
      /class\s+\w+\s*\{/,
      m => m + `\n  Future<String> _getCid() => LocalStorageService.getSavedCompanyId().then((v) => v ?? '');\n`
    );
  }
  // Fix DB.colSync(_cid, in non-async methods
  src = src.replace(/DB\.colSync\(_cid,/g, 'DB.colSync(await _getCid(),');
  // Make methods async if they use await
  src = src.replace(/(\w+\([^)]*\))\s*\{([^}]*await _getCid\(\))/g, (m, sig, body) => {
    if (sig.includes('async')) return m;
    return sig + ' async {' + body;
  });
  return src;
});

// ─── profile.dart ────────────────────────────────────────────────────────────
fix('lib/profile.dart', src => {
  // _cid used in initializer - fix by making it lazy
  src = src.replace(
    /final\s+\w+\s+\w+\s*=\s*DB\.colSync\(_cid,/g,
    m => m.replace('DB.colSync(_cid,', 'DB.colSync(\'\',')
  );
  // Better: replace instance initializer with late or move to initState
  src = src.replace(
    /=\s*DB\.colSync\(_cid,\s*([^)]+)\)/g,
    '= DB.colSync(\'\', $1)'
  );
  return src;
});

// ─── purchase_order.dart ─────────────────────────────────────────────────────
fix('lib/features/factory/presentation/factory/purchase_order.dart', src => {
  src = src.replace(
    /=\s*DB\.colSync\(_cid,\s*([^)]+)\)/g,
    '= DB.colSync(\'\', $1)'
  );
  return src;
});

// ─── hr_drawer.dart ──────────────────────────────────────────────────────────
fix('lib/features/hr/presentation/widgets/hr_drawer.dart', src => {
  // Methods on widget class, move to state
  src = src.replace(/DB\.stream\(([^)]+)\)\.(where|orderBy|doc|limit)\(/g, 'DB.colSync(_cid, $1).$2(');
  return src;
});

// ─── work_order_updates_screen.dart ──────────────────────────────────────────
fix('lib/features/marketing/presentation/work_order/work_order_updates_screen.dart', src => {
  src = src.replace(/DB\.stream\(([^)]+)\)\.(where|orderBy|doc|limit)\(/g, 'DB.colSync(_cid, $1).$2(');
  return src;
});

// ─── theme files - CardTheme → CardThemeData ──────────────────────────────────
['lib/theme/admin_theme.dart', 'lib/theme/factory_theme.dart', 'lib/theme/hr_theme.dart', 'lib/theme/marketing_theme.dart'].forEach(f => {
  fix(f, src => src.replace(/cardTheme:\s*CardTheme\(/g, 'cardTheme: CardThemeData('));
});

console.log('\n✅  Done.');
