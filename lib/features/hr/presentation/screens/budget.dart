// lib/features/hr/presentation/screens/budget.dart
//
// Budget Overview — lists all monthly budgets, lets HR open/create any month.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'budget_table.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _brand    = Color(0xFF065F46);
const Color _brandMid = Color(0xFF059669);
const Color _surface  = Color(0xFFF0FDF4);

final _money      = NumberFormat('#,##0', 'en');
final _fmtDisplay = DateFormat('MMMM yyyy');
final _fmtKey     = DateFormat('yyyy-MM');

String _keyFromDate(DateTime d)    => _fmtKey.format(DateTime(d.year, d.month));
String _displayFromDate(DateTime d) => _fmtDisplay.format(DateTime(d.year, d.month));

String _keyFromDisplay(String period) {
  try {
    return _keyFromDate(_fmtDisplay.parse(period));
  } catch (_) {
    return period;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});
  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  String _cid = '';
  bool   _cidLoaded = false;
  final DateTime _now = DateTime.now();
  late final String _periodNowDisplay = _displayFromDate(_now);
  late final String _periodNowKey     = _keyFromDate(_now);

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() { _cid = id ?? ''; _cidLoaded = true; });
    });
  }

  num _numify(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.replaceAll(',', '')) ?? 0;
    return 0;
  }

  /// Open or create the budget doc for a given month key.
  Future<DocumentReference<Map<String, dynamic>>> _openOrCreate(
      String key, String display) async {
    final ref = DB.colSync(_cid, C.budgets).doc(key);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'periodKey': key,
        'period':    display,
        'totalNeed': 0,
        'totalMin':  0,
        'createdAt': FieldValue.serverTimestamp(),
        'editableUntil': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30))),
      }, SetOptions(merge: true));
    }
    return ref;
  }

  @override
  Widget build(BuildContext context) {
    if (!_cidLoaded) {
      return const Scaffold(
        backgroundColor: _surface,
        body: Center(child: CircularProgressIndicator(color: _brand)),
      );
    }

    final stream = DB.colSync(_cid, C.budgets)
        .orderBy('periodKey', descending: true)
        .limit(24)
        .snapshots();

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_brand, _brandMid],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        title: const Text('Budget Planner',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_chart_rounded),
            tooltip: 'Create / Edit This Month',
            onPressed: () async {
              final nav = Navigator.of(context);
              final ref = await _openOrCreate(_periodNowKey, _periodNowDisplay);
              if (!mounted) return;
              nav.push(MaterialPageRoute(
                  builder: (_) => BudgetTablePage(
                      cid: _cid, budgetDoc: ref)));
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(color: Colors.red)),
            );
          }
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: _brand));
          }

          // De-duplicate by periodKey
          final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> unique = {};
          for (final d in snap.data!.docs) {
            final data = d.data();
            final key  = (data['periodKey'] as String?)
                ?? _keyFromDisplay((data['period'] ?? '') as String);
            if (key.isEmpty) continue;
            final existing = unique[key];
            if (existing == null) {
              unique[key] = d;
            } else {
              final t1 = (d.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final t2 = (existing.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              if (t1 > t2) unique[key] = d;
            }
          }

          final docs = unique.values.toList()
            ..sort((a, b) {
              final ak = (a.data()['periodKey'] as String?) ?? '';
              final bk = (b.data()['periodKey'] as String?) ?? '';
              return bk.compareTo(ak);
            });

          // Current & previous month totals
          QueryDocumentSnapshot<Map<String, dynamic>>? byKey(String k) {
            for (final d in docs) {
              if (((d.data()['periodKey'] as String?) ?? '') == k) return d;
            }
            return null;
          }

          final prevDate  = DateTime(_now.year, _now.month - 1, 1);
          final prevKey   = _keyFromDate(prevDate);
          final prevLabel = _displayFromDate(prevDate);

          final nowDoc   = byKey(_periodNowKey);
          final prevDoc  = byKey(prevKey);
          final nowTotal = nowDoc == null ? 0 : _numify(nowDoc.data()['totalNeed']);
          final prevTotal = prevDoc == null ? 0 : _numify(prevDoc.data()['totalNeed']);
          final diff     = nowTotal - prevTotal;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ── Hero summary ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_brand, _brandMid],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: _brand.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_periodNowDisplay,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      nowDoc == null
                          ? 'No budget yet'
                          : '৳ ${_money.format(nowTotal)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Text('Total budget need this month',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11)),
                    const SizedBox(height: 16),
                    Row(children: [
                      _HeroStat(
                        label: 'vs $prevLabel',
                        value: prevTotal == 0
                            ? '—'
                            : '${diff >= 0 ? '▲' : '▼'} ৳ ${_money.format(diff.abs())}',
                        color: diff >= 0
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFF86EFAC),
                      ),
                      const SizedBox(width: 12),
                      _HeroStat(
                        label: 'Months on record',
                        value: '${docs.length}',
                        color: const Color(0xFF86EFAC),
                      ),
                    ]),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Open this month button ────────────────────────────────────
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _brand,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.grid_on_rounded),
                  label: Text(
                    nowDoc == null
                        ? 'Create Budget for $_periodNowDisplay'
                        : 'Open Budget Table — $_periodNowDisplay',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final ref = await _openOrCreate(
                        _periodNowKey, _periodNowDisplay);
                    if (!mounted) return;
                    nav.push(MaterialPageRoute(
                        builder: (_) => BudgetTablePage(
                            cid: _cid, budgetDoc: ref)));
                  },
                ),
              ),

              const SizedBox(height: 24),

              // ── History list ─────────────────────────────────────────────
              Row(children: [
                const Icon(Icons.history_rounded, color: _brand, size: 18),
                const SizedBox(width: 8),
                const Text('Budget History',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: _brand)),
                const Spacer(),
                Text('${docs.length} months',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black38)),
              ]),
              const SizedBox(height: 10),

              if (docs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.grid_off_rounded,
                          size: 48, color: Colors.black12),
                      SizedBox(height: 12),
                      Text('No budgets yet',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black38)),
                      SizedBox(height: 4),
                      Text('Tap the button above to create this month\'s budget',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, color: Colors.black26)),
                    ],
                  ),
                )
              else
                ...docs.map((d) {
                  final m          = d.data();
                  final key        = (m['periodKey'] as String?) ?? '';
                  final label      = (m['period'] as String?) ?? key;
                  final total      = _numify(m['totalNeed']);
                  final minTotal   = _numify(m['totalMin'] ?? 0);
                  final created    = (m['createdAt'] as Timestamp?)?.toDate();
                  final editUntil  = (m['editableUntil'] as Timestamp?)?.toDate();
                  final locked     = editUntil != null &&
                      DateTime.now().isAfter(editUntil);
                  final isThisMonth = key == _periodNowKey;
                  final items      = (m['items'] as List?)?.length ?? 0;
                  final targets    = (m['salesTargets'] as List?)?.length ?? 0;

                  return _MonthCard(
                    label:       label,
                    total:       total,
                    minTotal:    minTotal,
                    itemCount:   items,
                    targetCount: targets,
                    createdAt:   created,
                    locked:      locked,
                    isThisMonth: isThisMonth,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => BudgetTablePage(
                              cid: _cid, budgetDoc: d.reference)),
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

// ── Hero sub-stat ─────────────────────────────────────────────────────────────
class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _HeroStat(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10)),
            ],
          ),
        ),
      );
}

// ── Month card ────────────────────────────────────────────────────────────────
class _MonthCard extends StatelessWidget {
  final String    label;
  final num       total;
  final num       minTotal;
  final int       itemCount;
  final int       targetCount;
  final DateTime? createdAt;
  final bool      locked;
  final bool      isThisMonth;
  final VoidCallback onTap;

  const _MonthCard({
    required this.label,
    required this.total,
    required this.minTotal,
    required this.itemCount,
    required this.targetCount,
    required this.createdAt,
    required this.locked,
    required this.isThisMonth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final money   = NumberFormat('#,##0', 'en');
    final dateFmt = DateFormat('d MMM yyyy');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isThisMonth
                  ? _brand.withValues(alpha: 0.4)
                  : Colors.black12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          // Month icon
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: isThisMonth
                  ? _brand.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isThisMonth
                  ? Icons.calendar_today_rounded
                  : Icons.calendar_month_rounded,
              color: isThisMonth ? _brand : Colors.black38,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isThisMonth ? _brand : Colors.black87)),
                  ),
                  if (isThisMonth)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _brand.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Current',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _brand)),
                    ),
                  if (locked)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Locked',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.red)),
                    ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  _InfoChip(
                      label: '$itemCount items',
                      icon: Icons.list_alt_rounded),
                  const SizedBox(width: 6),
                  _InfoChip(
                      label: '$targetCount targets',
                      icon: Icons.flag_rounded),
                  if (createdAt != null) ...[
                    const SizedBox(width: 6),
                    _InfoChip(
                        label: dateFmt.format(createdAt!),
                        icon: Icons.access_time_rounded),
                  ],
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('৳ ${money.format(total)}',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isThisMonth ? _brand : Colors.black87)),
              Text('min ৳ ${money.format(minTotal)}',
                  style: const TextStyle(
                      fontSize: 10, color: Colors.black38)),
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.black26, size: 18),
            ],
          ),
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String   label;
  final IconData icon;
  const _InfoChip({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.black38),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.black45)),
        ],
      );
}
