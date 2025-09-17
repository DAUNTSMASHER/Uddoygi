import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'budget_table.dart';

const _green = Color(0xFF065F46);
final _money = NumberFormat.currency(locale: 'en', symbol: '৳', decimalDigits: 0);

/// Helpers: display period "MMMM yyyy" and stable key "yyyy-MM"
final _fmtDisplay = DateFormat('MMMM yyyy'); // e.g. September 2025
final _fmtKey = DateFormat('yyyy-MM');       // e.g. 2025-09

String _keyFromDate(DateTime d) => _fmtKey.format(DateTime(d.year, d.month));
String _displayFromDate(DateTime d) => _fmtDisplay.format(DateTime(d.year, d.month));
String _keyFromDisplay(String period) {
  try {
    final d = _fmtDisplay.parse(period);
    return _keyFromDate(d);
  } catch (_) {
    return period; // fallback, keeps old data visible
  }
}

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});
  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final DateTime _now = DateTime.now();
  late final String _periodNowDisplay = _displayFromDate(_now);
  late final String _periodNowKey = _keyFromDate(_now);

  /// Open-or-create a budget document at a STABLE id (yyyy-MM) so
  /// Firestore physically cannot have more than one doc for that month.
  Future<DocumentReference<Map<String, dynamic>>> _openOrCreateMonth(String periodKey, String periodDisplay) async {
    final ref = FirebaseFirestore.instance.collection('budgets').doc(periodKey);
    final snap = await ref.get();
    if (snap.exists) return ref;

    // Create minimal shell (merge-friendly), you can enrich from your table page as needed
    await ref.set({
      'periodKey': periodKey,                // yyyy-MM (unique id)
      'period': periodDisplay,               // "MMMM yyyy" for UI
      'createdAt': FieldValue.serverTimestamp(),
      // Optional: allow edits 7 days
      'editableUntil': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
      // Optional totals defaults
      'totalNeed': 0,
    }, SetOptions(merge: true));

    return ref;
  }

  /// Legacy-friendly finder (for safety with old data that may not use the stable id yet)
  Future<DocumentSnapshot<Map<String, dynamic>>?> _findLegacyByDisplay(String periodDisplay) async {
    final q = await FirebaseFirestore.instance
        .collection('budgets')
        .where('period', isEqualTo: periodDisplay)
        .limit(1)
        .get();
    return q.docs.isEmpty ? null : q.docs.first;
  }

  ({String prevLabel, String prevPeriodKey}) _prev() {
    final prev = DateTime(_now.year, _now.month - 1, 1);
    return (prevLabel: _displayFromDate(prev), prevPeriodKey: _keyFromDate(prev));
  }

  num _numify(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.replaceAll(',', '')) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final budgetsStream = FirebaseFirestore.instance
        .collection('budgets')
    // order by most recent month if available, else createdAt
        .orderBy('periodKey', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(100) // generous to let us dedupe legacy docs
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _green,
        title: const Text('Budget Overview', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.addchart, color: Colors.white),
            tooltip: 'Create / Edit This Month',
            onPressed: () async {
              // prefer stable id; if old legacy doc exists, migrate/open that id instead
              final legacy = await _findLegacyByDisplay(_periodNowDisplay);
              final ref = legacy?.reference ?? await _openOrCreateMonth(_periodNowKey, _periodNowDisplay);
              if (!mounted) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => BudgetTablePage(budgetDoc: ref)));
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: budgetsStream,
        builder: (ctx, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Failed to load budgets'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snap.data!.docs;

          // De-duplicate by month key (handles any legacy duplicates that slipped in)
          final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> unique = {};
          for (final d in all) {
            final data = d.data();
            final key = (data['periodKey'] as String?) ?? _keyFromDisplay((data['period'] ?? '') as String? ?? '');
            if (key.isEmpty) continue;
            // Keep the latest by createdAt if duplicates exist
            final existing = unique[key];
            if (existing == null) {
              unique[key] = d;
            } else {
              final t1 = (d.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
              final t2 = (existing.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
              if (t1.isAfter(t2)) unique[key] = d;
            }
          }

          // Sort by month desc
          final docs = unique.values.toList()
            ..sort((a, b) {
              final ak = (a.data()['periodKey'] as String?) ?? _keyFromDisplay(a.data()['period'] ?? '');
              final bk = (b.data()['periodKey'] as String?) ?? _keyFromDisplay(b.data()['period'] ?? '');
              return bk.compareTo(ak); // desc
            });

          // Compute “now” & “prev” totals
          QueryDocumentSnapshot<Map<String, dynamic>>? _byKey(String key) {
            for (final d in docs) {
              final dk = (d.data()['periodKey'] as String?) ?? _keyFromDisplay(d.data()['period'] ?? '');
              if (dk == key) return d;
            }
            return null;
          }

          final prevInfo = _prev();
          final nowDoc = _byKey(_periodNowKey);
          final prevDoc = _byKey(prevInfo.prevPeriodKey);

          final nowTotal = nowDoc == null ? 0 : _numify(nowDoc.data()['totalNeed']);
          final prevTotal = prevDoc == null ? 0 : _numify(prevDoc.data()['totalNeed']);
          final diff = nowTotal - prevTotal;
          final diffStr = (diff >= 0 ? '▲ ' : '▼ ') + _money.format(diff.abs());

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // OVERVIEW (no overflow)
              LayoutBuilder(
                builder: (context, c) {
                  final cardW = (c.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: cardW,
                        child: _OverviewCard(
                          label: 'This Month (${_periodNowDisplay})',
                          value: _money.format(nowTotal),
                          color: _green,
                        ),
                      ),
                      SizedBox(
                        width: cardW,
                        child: _OverviewCard(
                          label: 'Δ vs ${prevInfo.prevLabel}',
                          value: diffStr,
                          color: diff >= 0 ? Colors.orange : Colors.teal,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              // OPEN/CREATE button uses stable id
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _green),
                  icon: const Icon(Icons.grid_on, color: Colors.white),
                  label: const Text('Open Budget Table', style: TextStyle(color: Colors.white)),
                  onPressed: () async {
                    final ref = await _openOrCreateMonth(_periodNowKey, _periodNowDisplay);
                    if (!mounted) return;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => BudgetTablePage(budgetDoc: ref)));
                  },
                ),
              ),

              const SizedBox(height: 16),

              const Text('History (one per month)', style: TextStyle(fontWeight: FontWeight.w800, color: _green)),
              const SizedBox(height: 8),

              if (docs.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('No budgets yet. Tap “Open Budget Table” to create this month.'),
                  ),
                )
              else
                ...docs.map((d) {
                  final m = d.data();
                  final total = _money.format(_numify(m['totalNeed']));
                  final created = (m['createdAt'] as Timestamp?)?.toDate();
                  final editableUntil = (m['editableUntil'] as Timestamp?)?.toDate();
                  final locked = editableUntil == null ? true : DateTime.now().isAfter(editableUntil);

                  final createdStr = created == null ? '—' : DateFormat('yMMMd').format(created);
                  final editableStr = editableUntil == null
                      ? ''
                      : (locked ? ' • Locked' : ' • Editable until ${DateFormat('yMMMd').format(editableUntil)}');

                  return Card(
                    child: ListTile(
                      title: Text('${m['period'] ?? m['periodKey']} • $total'),
                      subtitle: Text('Created: $createdStr$editableStr'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => BudgetTablePage(budgetDoc: d.reference)),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _OverviewCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        border: Border.all(color: color.withOpacity(.18)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
