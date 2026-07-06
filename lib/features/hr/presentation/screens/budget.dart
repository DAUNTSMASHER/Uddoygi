import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:uddoygi/theme/app_fonts.dart';

import 'budget_table.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────
final _money      = UddoygiDesign.moneyFormat;
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

  Future<DocumentReference<Map<String, dynamic>>> _openOrCreate(String key, String display) async {
    final ref = DB.colSync(_cid, C.budgets).doc(key);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'periodKey': key,
        'period':    display,
        'totalNeed': 0,
        'totalMin':  0,
        'createdAt': FieldValue.serverTimestamp(),
        'editableUntil': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      }, SetOptions(merge: true));
    }
    return ref;
  }

  @override
  Widget build(BuildContext context) {
    if (!_cidLoaded) {
      return Scaffold(
        backgroundColor: UddoygiDesign.surface,
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF065F46))),
      );
    }

    final stream = DB.colSync(_cid, C.budgets)
        .orderBy('periodKey', descending: true)
        .limit(24)
        .snapshots();

    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        backgroundColor: const Color(0xFF065F46),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Budget Planner', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_chart_rounded),
            onPressed: () async {
              final nav = Navigator.of(context);
              final ref = await _openOrCreate(_periodNowKey, _periodNowDisplay);
              if (!mounted) return;
              nav.push(MaterialPageRoute(builder: (_) => BudgetTablePage(cid: _cid, budgetDoc: ref)));
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (ctx, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> unique = {};
          for (final d in snap.data!.docs) {
            final data = d.data();
            final key  = (data['periodKey'] as String?) ?? _keyFromDisplay((data['period'] ?? '') as String);
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

          final docs = unique.values.toList()..sort((a, b) {
            final ak = (a.data()['periodKey'] as String?) ?? '';
            final bk = (b.data()['periodKey'] as String?) ?? '';
            return bk.compareTo(ak);
          });

          final prevDate  = DateTime(_now.year, _now.month - 1, 1);
          final prevKey   = _keyFromDate(prevDate);
          final prevLabel = _displayFromDate(prevDate);

          QueryDocumentSnapshot<Map<String, dynamic>>? byKey(String k) {
             for (final d in docs) {
               if (((d.data()['periodKey'] as String?) ?? '') == k) return d;
             }
             return null;
          }

          final nowDoc   = byKey(_periodNowKey);
          final prevDoc  = byKey(prevKey);
          final nowTotal = nowDoc == null ? 0 : _numify(nowDoc.data()['totalNeed']);
          final prevTotal = prevDoc == null ? 0 : _numify(prevDoc.data()['totalNeed']);
          final diff     = nowTotal - prevTotal;

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(UddoygiDesign.space20),
            children: [
              Container(
                padding: const EdgeInsets.all(UddoygiDesign.space24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF065F46), Color(0xFF059669)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(UddoygiDesign.radiusL),
                  boxShadow: [BoxShadow(color: const Color(0xFF065F46).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_periodNowDisplay.toUpperCase(), style: AppFonts.banglaHeading(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Text(nowDoc == null ? 'No budget yet' : '৳ ${_money.format(nowTotal)}', style: AppFonts.banglaData(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text('Total budget need this month', style: AppFonts.banglaBody(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _HeroStat(label: 'vs $prevLabel', value: prevTotal == 0 ? '—' : '${diff >= 0 ? '▲' : '▼'} ৳ ${_money.format(diff.abs())}', color: diff >= 0 ? const Color(0xFFFBBF24) : const Color(0xFF86EFAC)),
                        const SizedBox(width: 16),
                        _HeroStat(label: 'Months on record', value: '${docs.length}', color: const Color(0xFF86EFAC)),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),
              const SizedBox(height: UddoygiDesign.space24),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final ref = await _openOrCreate(_periodNowKey, _periodNowDisplay);
                    if (!mounted) return;
                    nav.push(MaterialPageRoute(builder: (_) => BudgetTablePage(cid: _cid, budgetDoc: ref)));
                  },
                  icon: const Icon(Icons.grid_on_rounded, size: 20),
                  label: Text(nowDoc == null ? 'Create Budget for $_periodNowDisplay' : 'Open Budget Table', style: AppFonts.banglaHeading(fontWeight: FontWeight.w800, fontSize: 15)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF065F46), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UddoygiDesign.radiusM))),
                ),
              ),
              const SizedBox(height: UddoygiDesign.space32),
              Row(
                children: [
                  Container(width: 4, height: 16, decoration: BoxDecoration(color: const Color(0xFF065F46), borderRadius: UddoygiDesign.borderFull)),
                  const SizedBox(width: 10),
                  Text('Budget History', style: AppFonts.banglaHeading(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E0040))),
                  const Spacer(),
                  Text('${docs.length} months', style: AppFonts.banglaHeading(fontSize: 12, color: Colors.grey[400], fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: UddoygiDesign.space16),
              if (docs.isEmpty)
                UCard(
                  padding: const EdgeInsets.all(UddoygiDesign.space32),
                  child: Column(
                    children: [
                      Icon(Icons.grid_off_rounded, size: 48, color: Colors.grey[200]),
                      const SizedBox(height: 16),
                      Text('No budgets yet', style: AppFonts.banglaHeading(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey[400])),
                      const SizedBox(height: 4),
                      Text('Tap the button above to start your first budget', textAlign: TextAlign.center, style: AppFonts.banglaBody(fontSize: 12, color: Colors.grey[400])),
                    ],
                  ),
                )
              else
                ...docs.map((d) {
                  final m = d.data();
                  final key = (m['periodKey'] as String?) ?? '';
                  return _MonthCard(
                    label: (m['period'] as String?) ?? key,
                    total: _numify(m['totalNeed']),
                    minTotal: _numify(m['totalMin'] ?? 0),
                    itemCount: (m['items'] as List?)?.length ?? 0,
                    targetCount: (m['salesTargets'] as List?)?.length ?? 0,
                    createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
                    locked: (m['editableUntil'] as Timestamp?)?.toDate() != null && DateTime.now().isAfter((m['editableUntil'] as Timestamp).toDate()),
                    isThisMonth: key == _periodNowKey,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BudgetTablePage(cid: _cid, budgetDoc: d.reference))),
                  ).animate().fadeIn(delay: 100.ms * docs.indexOf(d)).slideY(begin: 0.1, end: 0);
                }),
            ],
          );
        },
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _HeroStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(UddoygiDesign.space12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(UddoygiDesign.radiusM)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppFonts.banglaData(color: color, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label, style: AppFonts.banglaBody(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

class _MonthCard extends StatelessWidget {
  final String label;
  final num total, minTotal;
  final int itemCount, targetCount;
  final DateTime? createdAt;
  final bool locked, isThisMonth;
  final VoidCallback onTap;

  const _MonthCard({required this.label, required this.total, required this.minTotal, required this.itemCount, required this.targetCount, required this.createdAt, required this.locked, required this.isThisMonth, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return UCard(
      margin: const EdgeInsets.only(bottom: UddoygiDesign.space12),
      padding: const EdgeInsets.all(UddoygiDesign.space16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(UddoygiDesign.radiusM),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: (isThisMonth ? const Color(0xFF065F46) : Colors.grey[200]!).withOpacity(0.1), borderRadius: BorderRadius.circular(UddoygiDesign.radiusM)),
              child: Icon(isThisMonth ? Icons.calendar_today_rounded : Icons.calendar_month_rounded, color: isThisMonth ? const Color(0xFF065F46) : Colors.grey[400], size: 24),
            ),
            const SizedBox(width: UddoygiDesign.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label, style: AppFonts.banglaHeading(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E0040))),
                      if (isThisMonth) ...[SizedBox(width: 8), Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Color(0xFF065F46).withOpacity(0.1), borderRadius: UddoygiDesign.borderFull), child: Text('NOW', style: AppFonts.banglaHeading(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF065F46))))],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _InfoIcon(Icons.list_alt_rounded, '$itemCount items'),
                      const SizedBox(width: 12),
                      _InfoIcon(Icons.flag_rounded, '$targetCount targets'),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('৳ ${_money.format(total)}', style: AppFonts.banglaData(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF065F46))),
                Text('min ৳ ${_money.format(minTotal)}', style: AppFonts.banglaBody(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[300], size: 20),
          ],
        ),
      ),
    );
  }
}

class _InfoIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoIcon(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 12, color: Colors.grey[400]),
      const SizedBox(width: 4),
      Text(label, style: AppFonts.banglaBody(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
    ],
  );
}
