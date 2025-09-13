// lib/features/factory/presentation/screens/stock_history.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// ===== Factory Dashboard Palette (match your stock screen) =====
const Color _darkBlue   = Color(0xFF0D47A1);
const Color _accent     = Color(0xFFFFC107);
const Color _surface    = Color(0xFFF7F8FB);
const Color _okGreen    = Color(0xFF10B981);
const Color _lowRed     = Color(0xFFE11D48);
const Color _highIndigo = Color(0xFF4338CA);

/// Defaults (override per item via fields on stocks doc)
const int kDefaultLowThreshold  = 100;
const int kDefaultHighThreshold = 500;

/// ===== Entry point screen with BottomNav =====
class StockHistoryScreen extends StatefulWidget {
  const StockHistoryScreen({Key? key}) : super(key: key);

  @override
  State<StockHistoryScreen> createState() => _StockHistoryScreenState();
}

class _StockHistoryScreenState extends State<StockHistoryScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _DashboardTab(),
      const _HistoryTab(),
      const _ProductsTab(),
    ];

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _darkBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Stock Overview'),
      ),

      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Products'),
        ],
      ),
    );
  }
}

/// ===== DASHBOARD =====
class _DashboardTab extends StatelessWidget {
  const _DashboardTab({Key? key}) : super(key: key);

  Stream<_AggBundle> _bundleStream() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final dayStart   = DateTime(now.year, now.month, now.day);

    // Server-sorted. Firestore may ask you to create a *collection group* index on "logs.ts".
    final logsQ = FirebaseFirestore.instance
        .collectionGroup('logs')
        .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .orderBy('ts', descending: false);

    final stocksQ = FirebaseFirestore.instance.collection('stocks');

    // Print any index error to console so you can click the link.
    final logsStream = logsQ.snapshots().handleError((e, st) {
      final msg = _explainFirestoreError(e);
      debugPrint('[STOCK DASHBOARD] $msg');
    });

    return logsStream.asyncMap((_logsSnap) async {
      final stocksSnap = await stocksQ.get();

      int monthIn = 0, monthOut = 0, todayIn = 0, todayOut = 0;

      for (final d in _logsSnap.docs) {
        final m = d.data() as Map<String, dynamic>;
        final delta = (m['delta'] as int?) ?? 0;

        DateTime when;
        final ts = (m['ts'] as Timestamp?);
        if (ts != null) {
          when = ts.toDate();
        } else {
          final ds = (m['date'] as String?) ?? '';
          when = ds.isNotEmpty ? DateTime.tryParse(ds) ?? DateTime.now() : DateTime.now();
        }

        if (!when.isBefore(monthStart)) {
          if (delta >= 0) monthIn += delta; else monthOut += -delta;
        }
        if (!when.isBefore(dayStart)) {
          if (delta >= 0) todayIn += delta; else todayOut += -delta;
        }
      }

      int ok = 0, low = 0, high = 0, totalQty = 0;
      for (final s in stocksSnap.docs) {
        final m = s.data();
        final qty  = (m['qty'] as int?) ?? 0;
        final minT = (m['minThreshold'] as int?) ?? kDefaultLowThreshold;
        final maxT = (m['maxThreshold'] as int?) ?? kDefaultHighThreshold;
        totalQty += qty;
        if (qty < minT) {
          low++;
        } else if (qty > maxT) {
          high++;
        } else {
          ok++;
        }
      }

      return _AggBundle(
        todayIn: todayIn,
        todayOut: todayOut,
        monthIn: monthIn,
        monthOut: monthOut,
        totalItems: stocksSnap.docs.length,
        totalQty: totalQty,
        lowCount: low,
        highCount: high,
        okCount: ok,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_AggBundle>(
      stream: _bundleStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorState(message: _explainFirestoreError(snap.error));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final agg = snap.data!;
        const spacing = 10.0;

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Summary cards
            LayoutBuilder(builder: (ctx, c) {
              final w = c.maxWidth;
              final cardW = (w - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _SummaryCard(width: cardW, title: 'Today In',  value: agg.todayIn,  color: _okGreen),
                  _SummaryCard(width: cardW, title: 'Today Out', value: agg.todayOut, color: _lowRed),
                  _SummaryCard(width: cardW, title: 'Month In',  value: agg.monthIn,  color: _darkBlue),
                  _SummaryCard(width: cardW, title: 'Month Out', value: agg.monthOut, color: _highIndigo),
                ],
              );
            }),
            const SizedBox(height: 12),
            _TileSection(
              title: 'Inventory Status',
              child: Row(
                children: [
                  Expanded(child: _StatusChip(label: 'OK',    value: agg.okCount,   color: _okGreen)),
                  const SizedBox(width: 8),
                  Expanded(child: _StatusChip(label: 'LOW',   value: agg.lowCount,  color: _lowRed)),
                  const SizedBox(width: 8),
                  Expanded(child: _StatusChip(label: 'HIGH',  value: agg.highCount, color: _highIndigo)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _TileSection(
              title: 'Totals',
              child: Row(
                children: [
                  Expanded(child: _SimpleCardDark(title: 'Items', value: '${agg.totalItems}')),
                  const SizedBox(width: 8),
                  Expanded(child: _SimpleCardDark(title: 'Total Qty', value: '${agg.totalQty}')),
                  const SizedBox(width: 8),
                  Expanded(child: _SimpleCardDark(title: 'Net Today', value: '${agg.todayIn - agg.todayOut}')),
                ],
              ),
            ),

          ],
        );
      },
    );
  }
}

class _AggBundle {
  final int todayIn, todayOut, monthIn, monthOut;
  final int totalItems, totalQty, lowCount, highCount, okCount;
  _AggBundle({
    required this.todayIn,
    required this.todayOut,
    required this.monthIn,
    required this.monthOut,
    required this.totalItems,
    required this.totalQty,
    required this.lowCount,
    required this.highCount,
    required this.okCount,
  });
}

/// ===== HISTORY =====
enum _HistoryMode { daily, monthly }

class _HistoryTab extends StatefulWidget {
  const _HistoryTab({Key? key}) : super(key: key);

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  _HistoryMode _mode = _HistoryMode.daily;

  Stream<List<_HistoryRowData>> _historyStream({required int daysBack}) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: daysBack));

    // Server-sorted. May require the same collection-group index on logs.ts.
    final q = FirebaseFirestore.instance
        .collectionGroup('logs')
        .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .orderBy('ts', descending: true);

    final stream = q.snapshots().handleError((e, st) {
      final msg = _explainFirestoreError(e);
      debugPrint('[STOCK HISTORY] $msg');
    });

    return stream.map((snap) {
      if (_mode == _HistoryMode.daily) {
        final Map<String, _Agg> byDay = {};
        for (final d in snap.docs) {
          final m = d.data() as Map<String, dynamic>;
          final delta = (m['delta'] as int?) ?? 0;

          DateTime when;
          final ts = (m['ts'] as Timestamp?);
          if (ts != null) {
            when = ts.toDate();
          } else {
            final ds = (m['date'] as String?) ?? '';
            when = ds.isNotEmpty ? DateTime.tryParse(ds) ?? DateTime.now() : DateTime.now();
          }

          final key = _keyDay(when);
          final agg = byDay.putIfAbsent(key, () => _Agg(DateTime(when.year, when.month, when.day)));
          if (delta >= 0) {
            agg.inQty += delta;
          } else {
            agg.outQty += -delta;
          }
        }
        final rows = byDay.values.toList()
          ..sort((a, b) => b.day.compareTo(a.day)); // newest first
        return rows.map((a) => _HistoryRowData(
          title: _labelDay(a.day),
          sub:  '${a.inQty} in • ${a.outQty} out',
          inQty: a.inQty,
          outQty: a.outQty,
          when: a.day,
        )).toList();
      } else {
        final Map<String, _AggMonth> byMonth = {};
        for (final d in snap.docs) {
          final m = d.data() as Map<String, dynamic>;
          final delta = (m['delta'] as int?) ?? 0;

          DateTime when;
          final ts = (m['ts'] as Timestamp?);
          if (ts != null) {
            when = ts.toDate();
          } else {
            final ds = (m['date'] as String?) ?? '';
            when = ds.isNotEmpty ? DateTime.tryParse(ds) ?? DateTime.now() : DateTime.now();
          }

          final key = _keyMonth(when);
          final agg = byMonth.putIfAbsent(key, () => _AggMonth(DateTime(when.year, when.month)));
          if (delta >= 0) {
            agg.inQty += delta;
          } else {
            agg.outQty += -delta;
          }
        }
        final rows = byMonth.values.toList()
          ..sort((a, b) => b.month.compareTo(a.month)); // newest first
        return rows.map((a) => _HistoryRowData(
          title: _labelMonth(a.month),
          sub:  '${a.inQty} in • ${a.outQty} out',
          inQty: a.inQty,
          outQty: a.outQty,
          when: a.month,
        )).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _Choice(
                label: 'Daily',
                selected: _mode == _HistoryMode.daily,
                onTap: () => setState(() => _mode = _HistoryMode.daily),
              ),
              const SizedBox(width: 8),
              _Choice(
                label: 'Monthly',
                selected: _mode == _HistoryMode.monthly,
                onTap: () => setState(() => _mode = _HistoryMode.monthly),
              ),
              const Spacer(),
              const Text('Last 60 days', style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<List<_HistoryRowData>>(
            stream: _historyStream(daysBack: 60),
            builder: (context, snap) {
              if (snap.hasError) {
                return _ErrorState(message: _explainFirestoreError(snap.error));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = snap.data!;
              if (rows.isEmpty) {
                return const Center(child: Text('No recent stock movements'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final r = rows[i];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: ListTile(
                      title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(r.sub),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('+${r.inQty}', style: const TextStyle(color: _okGreen, fontWeight: FontWeight.w800)),
                          Text('-${r.outQty}', style: const TextStyle(color: _lowRed, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Agg {
  final DateTime day;
  int inQty = 0;
  int outQty = 0;
  _Agg(this.day);
}

class _AggMonth {
  final DateTime month; // normalized to first day
  int inQty = 0;
  int outQty = 0;
  _AggMonth(this.month);
}

class _HistoryRowData {
  final String title;
  final String sub;
  final int inQty;
  final int outQty;
  final DateTime when;
  _HistoryRowData({
    required this.title,
    required this.sub,
    required this.inQty,
    required this.outQty,
    required this.when,
  });
}

String _keyDay(DateTime d)   => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
String _keyMonth(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}';
String _labelDay(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
String _labelMonth(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}';

/// ===== PRODUCTS =====
class _ProductsTab extends StatefulWidget {
  const _ProductsTab({Key? key}) : super(key: key);

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  final _searchCtl = TextEditingController();

  Stream<QuerySnapshot<Map<String, dynamic>>> _stocksStream() {
    return FirebaseFirestore.instance.collection('stocks').orderBy('name').snapshots();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _searchCtl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search product name or SKU',
              prefixIcon: const Icon(Icons.search, color: _darkBlue),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stocksStream(),
            builder: (context, snap) {
              if (snap.hasError) {
                return _ErrorState(message: _explainFirestoreError(snap.error));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final q = _searchCtl.text.trim().toLowerCase();
              final docs = snap.data!.docs.where((d) {
                final m = d.data();
                final name = (m['name'] as String?)?.toLowerCase() ?? '';
                final sku  = (m['sku']  as String?)?.toLowerCase() ?? '';
                return q.isEmpty || name.contains(q) || sku.contains(q);
              }).toList();

              if (docs.isEmpty) {
                return const Center(child: Text('No products'));
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = docs[i];
                  final m = d.data();
                  final name = (m['name'] as String?) ?? 'Unnamed';
                  final sku  = (m['sku'] as String?)  ?? '';
                  final qty  = (m['qty'] as int?) ?? 0;
                  final unit = (m['unit'] as String?) ?? 'pcs';
                  final minT = (m['minThreshold'] as int?) ?? kDefaultLowThreshold;
                  final maxT = (m['maxThreshold'] as int?) ?? kDefaultHighThreshold;

                  final status = qty < minT ? 'LOW' : (qty > maxT ? 'HIGH' : 'OK');
                  final statusColor = qty < minT ? _lowRed : (qty > maxT ? _highIndigo : _okGreen);

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: ListTile(
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                          ),
                          if (sku.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: _Pill(text: sku, color: Colors.black54),
                            ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            _Pill(text: '$qty $unit', color: Colors.black87),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: statusColor),
                              ),
                              child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}



class _SummaryCard extends StatelessWidget {
  final double width;
  final String title;
  final int value;
  final Color color;

  /// Optional custom styles
  final TextStyle? valueStyle;
  final TextStyle? titleStyle;

  /// Animation config
  final Duration animationDuration;
  final Curve animationCurve;

  const _SummaryCard({
    Key? key,
    required this.width,
    required this.title,
    required this.value,
    required this.color,
    this.valueStyle,
    this.titleStyle,
    this.animationDuration = const Duration(milliseconds: 280),
    this.animationCurve = Curves.easeOutCubic,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final defaultValueStyle = const TextStyle(
      color: Colors.white,
      fontSize: 26,
      fontWeight: FontWeight.w800,
      height: 1.1,
    );

    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center, // center label + value
        children: [
          // Centered label
          Text(
            title,
            textAlign: TextAlign.center,
            style: titleStyle ??
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),

          // Centered + animated number
          AnimatedDefaultTextStyle(
            duration: animationDuration,
            curve: animationCurve,
            style: valueStyle ?? defaultValueStyle,
            textAlign: TextAlign.center,
            child: AnimatedSwitcher(
              duration: animationDuration,
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                ),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Text(
                '$value',
                key: ValueKey<int>(value), // re-animate when value changes
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class _TileSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _TileSection({Key? key, required this.title, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _SimpleCardDark extends StatelessWidget {
  final String title;
  final String value;
  const _SimpleCardDark({Key? key, required this.title, required this.value}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _darkBlue,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: _darkBlue,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _darkBlue.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // center align if you prefer
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleCard extends StatelessWidget {
  final String title;
  final String value;
  const _SimpleCard({Key? key, required this.title, required this.value}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatusChip({Key? key, required this.label, required this.value, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text('$value', style: TextStyle(fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Choice({Key? key, required this.label, required this.selected, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: selected ? Colors.white : _darkBlue)),
      selected: selected,
      selectedColor: _darkBlue,
      backgroundColor: Colors.white,
      shape: StadiumBorder(side: BorderSide(color: selected ? _darkBlue : Colors.black12)),
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({Key? key, required this.text, required this.color}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// ===== Error helper =====
class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

String _explainFirestoreError(Object? error) {
  final s = error?.toString() ?? '';

  // Try to surface the Firestore "create index" URL so you can click it in logs.
  final url = _extractIndexUrl(s);
  if (s.contains('failed-precondition') && s.contains('index')) {
    if (url != null) {
      return 'Firestore requires a collection-group index for logs.ts.\n'
          '👉 Open this link to create it:\n$url';
    }
    return 'Firestore requires a collection-group index for logs.ts.\n'
        'Check the debug console for the auto-generated link.';
  }
  return 'Failed to load data.\n$s';
}

String? _extractIndexUrl(String s) {
  final rx = RegExp(r'https:\/\/console\.firebase\.google\.com\/[^\s]+');
  final m = rx.firstMatch(s);
  return m?.group(0);
}
