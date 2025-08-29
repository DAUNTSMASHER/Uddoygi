import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:fl_chart/fl_chart.dart';

class BalanceUpdateScreen extends StatefulWidget {
  const BalanceUpdateScreen({super.key});

  @override
  State<BalanceUpdateScreen> createState() => _BalanceUpdateScreenState();
}

class _BalanceUpdateScreenState extends State<BalanceUpdateScreen> {
  // ---------- UI helpers ----------
  final _money = NumberFormat.currency(locale: 'en_BD', symbol: '৳');
  final _dateFmt = DateFormat('yyyy-MM-dd');

  // Filters (default = this month)
  late DateTime _periodStart;
  late DateTime _periodEnd;

  // Form inputs (kept for compatibility; UI removed)
  static const _updateTypes = ['Add', 'Subtract'];
  static const _accountTypes = ['Cash', 'Bank', 'Wallet'];
  String _updateType = _updateTypes.first;
  String _accountType = _accountTypes.first;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _expenseCategory = 'Other';

  static const _expenseCategories = <String>[
    'Rent', 'Utilities', 'Payroll', 'Supplies', 'Maintenance', 'Transport', 'Marketing', 'Other'
  ];

  // Distinct color palette for charts
  static const List<Color> _palette = [
    Colors.indigo,
    Colors.blue,
    Colors.teal,
    Colors.green,
    Colors.lime,
    Colors.orange,
    Colors.deepOrange,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.brown,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodStart = DateTime(now.year, now.month, 1);
    _periodEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ---------- Queries (respecting date range) ----------
  Query _ledgerQuery() => FirebaseFirestore.instance
      .collection('ledger')
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_periodStart))
      .where('date', isLessThanOrEqualTo: Timestamp.fromDate(_periodEnd))
      .orderBy('date', descending: true);

  Query _expensesQuery() => FirebaseFirestore.instance
      .collection('expenses')
      .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(_periodStart))
      .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(_periodEnd))
      .orderBy('dueDate', descending: true);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(fontSizeFactor: 1.15),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
      colorScheme: Theme.of(context).colorScheme.copyWith(primary: Colors.indigo),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Balance & Summary',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Recent Updates',
              onPressed: _openHistoryDialog,
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Export Summary PDF',
              onPressed: generatePdfReport,
            ),
          ],
        ),

        // History FAB (replaces add/subtract)
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.indigo,
          icon: const Icon(Icons.history),
          label: const Text('History'),
          onPressed: _openHistoryDialog,
        ),

        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Period picker
              _PeriodPicker(
                label: 'Period: ${DateFormat('MMM yyyy').format(_periodStart)}',
                onTap: _pickPeriod,
              ),
              const SizedBox(height: 12),

              // Summary (combine 2 streams)
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _ledgerQuery().snapshots(),
                  builder: (context, ledgerSnap) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: _expensesQuery().snapshots(),
                      builder: (context, expenseSnap) {
                        if (ledgerSnap.connectionState == ConnectionState.waiting ||
                            expenseSnap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final ledgerDocs = ledgerSnap.data?.docs ?? [];
                        final expenseDocs = expenseSnap.data?.docs ?? [];

                        // Totals + groupings
                        num totalCredit = 0;
                        final Map<String, num> creditByAccount = {};
                        for (final d in ledgerDocs) {
                          final m = d.data() as Map<String, dynamic>;
                          final c = _n(m['credit']);
                          totalCredit += c;
                          final acc = (m['account'] as String?)?.trim().isNotEmpty == true
                              ? (m['account'] as String)
                              : 'Other';
                          creditByAccount[acc] = (creditByAccount[acc] ?? 0) + c;
                        }

                        num totalExpense = 0;
                        final Map<String, num> expenseByCategory = {};
                        for (final d in expenseDocs) {
                          final m = d.data() as Map<String, dynamic>;
                          final amt = _n(m['amount']);
                          final cat = (m['category'] as String?)?.trim().isNotEmpty == true
                              ? (m['category'] as String)
                              : 'Other';
                          totalExpense += amt;
                          expenseByCategory[cat] = (expenseByCategory[cat] ?? 0) + amt;
                        }

                        final profit = totalCredit - totalExpense;

                        return ListView(
                          children: [
                            // Big summary cards
                            Row(
                              children: [
                                Expanded(
                                  child: _summaryCard('Total Credit', _money.format(totalCredit),
                                      Icons.arrow_downward, Colors.green),
                                ),
                                Expanded(
                                  child: _summaryCard('Total Expense',
                                      _money.format(totalExpense), Icons.arrow_upward, Colors.red),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _ProfitCard(value: _money.format(profit), positive: profit >= 0),
                            const SizedBox(height: 16),

                            // ---------- ONE CHART PER ROW ----------
                            _ChartCard(
                              title: 'Credit by Account (Pie)',
                              child: _PieCard(
                                data: creditByAccount,
                                total: totalCredit.toDouble(),
                                palette: _palette,
                                money: _money,
                              ),
                            ),
                            const SizedBox(height: 12),

                            _ChartCard(
                              title: 'Expense by Category (Pie)',
                              child: _PieCard(
                                data: expenseByCategory,
                                total: totalExpense.toDouble(),
                                palette: _palette,
                                money: _money,
                              ),
                            ),
                            const SizedBox(height: 12),

                            _ChartCard(
                              title: 'Credit (৳) by Account',
                              child: _BarCard(
                                data: creditByAccount,
                                palette: _palette,
                                money: _money,
                              ),
                            ),
                            const SizedBox(height: 12),

                            _ChartCard(
                              title: 'Expense (৳) by Category',
                              child: _BarCard(
                                data: expenseByCategory,
                                palette: _palette,
                                money: _money,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Existing minimal bars (kept)
                            _CategoryBreakdown(
                              byCategory: expenseByCategory,
                              total: totalExpense,
                              money: _money,
                            ),

                            const SizedBox(height: 16),

                            // Recent activity (period-scoped)
                            Text('Recent Credits (Ledger)',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium!
                                    .copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            _ActivityList(
                              items: ledgerDocs
                                  .take(5)
                                  .map((d) => _ActivityItem.fromLedger(d, _dateFmt, _money))
                                  .toList(),
                            ),
                            const SizedBox(height: 14),
                            Text('Recent Expenses',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium!
                                    .copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            _ActivityList(
                              items: expenseDocs
                                  .take(5)
                                  .map((d) => _ActivityItem.fromExpense(d, _dateFmt, _money))
                                  .toList(),
                            ),
                            const SizedBox(height: 24),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Recent updates (global) ----------
  Future<void> _openHistoryDialog() async {
    try {
      final ledger = await FirebaseFirestore.instance
          .collection('ledger')
          .orderBy('date', descending: true)
          .limit(20)
          .get();

      final expenses = await FirebaseFirestore.instance
          .collection('expenses')
          .orderBy('dueDate', descending: true)
          .limit(20)
          .get();

      final items = <_HistoryItem>[];

      for (final d in ledger.docs) {
        final m = d.data() as Map<String, dynamic>;
        items.add(
          _HistoryItem(
            when: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
            title: (m['account'] ?? 'Account').toString(),
            subtitle: (m['description'] ?? '').toString(),
            amount: _n(m['credit']).toDouble(),
            isCredit: true,
          ),
        );
      }
      for (final d in expenses.docs) {
        final m = d.data() as Map<String, dynamic>;
        items.add(
          _HistoryItem(
            when: (m['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
            title: (m['vendor'] ?? 'Expense').toString(),
            subtitle: (m['category'] ?? '').toString(),
            amount: _n(m['amount']).toDouble(),
            isCredit: false,
          ),
        );
      }

      items.sort((a, b) => b.when.compareTo(a.when));
      final limited = items.take(30).toList();

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recent Updates',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: limited.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final it = limited[i];
                        final color = it.isCredit ? Colors.green : Colors.red;
                        final icon = it.isCredit ? Icons.trending_up : Icons.trending_down;
                        return ListTile(
                          leading: Icon(icon, color: color),
                          title: Text(it.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle:
                          Text('${_dateFmt.format(it.when)} • ${it.subtitle}'.trim()),
                          trailing: Text(
                            _money.format(it.amount),
                            style: TextStyle(fontWeight: FontWeight.bold, color: color),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load history: $e')));
    }
  }

  // ---------- Period picker ----------
  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final thisStart = DateTime(now.year, now.month, 1);
    final lastStart = DateTime(now.year, now.month - 1, 1);
    final lastEnd = DateTime(now.year, now.month, 0, 23, 59, 59);

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Choose Period', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _PeriodOption(
              icon: Icons.today,
              label: 'This Month',
              onTap: () {
                setState(() {
                  _periodStart = thisStart;
                  _periodEnd = DateTime(thisStart.year, thisStart.month + 1, 0, 23, 59, 59);
                });
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            _PeriodOption(
              icon: Icons.history,
              label: 'Last Month',
              onTap: () {
                setState(() {
                  _periodStart = lastStart;
                  _periodEnd = lastEnd;
                });
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            _PeriodOption(
              icon: Icons.calendar_month_outlined,
              label: 'Custom Range',
              onTap: () async {
                Navigator.pop(context);
                final s = await showDatePicker(
                  context: context,
                  initialDate: _periodStart,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (s == null) return;
                final e = await showDatePicker(
                  context: context,
                  initialDate: _periodEnd,
                  firstDate: s,
                  lastDate: DateTime.now(),
                );
                if (e == null) return;
                setState(() {
                  _periodStart = DateTime(s.year, s.month, s.day);
                  _periodEnd = DateTime(e.year, e.month, e.day, 23, 59, 59);
                });
              },
            ),
            const SizedBox(height: 6),
          ]),
        ),
      ),
    );
  }

  // ---------- Export PDF (summary only) ----------
  Future<void> generatePdfReport() async {
    final ledgerSnap = await _ledgerQuery().get();
    final expenseSnap = await _expensesQuery().get();

    num totalCredit = 0;
    for (final d in ledgerSnap.docs) {
      final m = d.data() as Map<String, dynamic>;
      totalCredit += _n(m['credit']);
    }

    num totalExpense = 0;
    for (final d in expenseSnap.docs) {
      final m = d.data() as Map<String, dynamic>;
      totalExpense += _n(m['amount']);
    }
    final profit = totalCredit - totalExpense;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(margin: const pw.EdgeInsets.all(24)),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Balance Summary',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(
              'Period: ${_dateFmt.format(_periodStart)} → ${_dateFmt.format(_periodEnd)}',
              style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 12),
            ),
            pw.Divider(),
          ],
        ),
        build: (_) {
          final widgets = <pw.Widget>[];

          widgets.add(pw.Text('Totals',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(pw.Text('Total Credit: ${_fmt(totalCredit)}'));
          widgets.add(pw.Text('Total Expense: ${_fmt(totalExpense)}'));
          widgets.add(pw.Text('Profit: ${_fmt(profit)}'));
          widgets.add(pw.SizedBox(height: 12));

          widgets.add(pw.Text('Recent Credits (Ledger)',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)));
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(
            pw.Table.fromTextArray(
              headers: ['Date', 'Account', 'Description', 'Credit'],
              data: ledgerSnap.docs.take(10).map((doc) {
                final m = doc.data() as Map<String, dynamic>;
                return [
                  _safeDate(m['date']),
                  (m['account'] ?? '').toString(),
                  (m['description'] ?? '').toString(),
                  _fmt(_n(m['credit'])),
                ];
              }).toList(),
            ),
          );
          widgets.add(pw.SizedBox(height: 12));

          widgets.add(pw.Text('Recent Expenses',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)));
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(
            pw.Table.fromTextArray(
              headers: ['Date', 'Vendor', 'Category', 'Amount'],
              data: expenseSnap.docs.take(10).map((doc) {
                final m = doc.data() as Map<String, dynamic>;
                return [
                  _safeDate(m['dueDate']),
                  (m['vendor'] ?? '').toString(),
                  (m['category'] ?? '').toString(),
                  _fmt(_n(m['amount'])),
                ];
              }).toList(),
            ),
          );

          return widgets;
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  // ---------- helpers ----------
  static num _n(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    if (v is String) return num.tryParse(v.replaceAll(',', '')) ?? 0;
    return 0;
  }

  static String _fmt(num n) => n.toStringAsFixed(2);

  String _safeDate(dynamic v) {
    if (v is Timestamp) return _dateFmt.format(v.toDate());
    return '-';
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// ---------- History model ----------
class _HistoryItem {
  final DateTime when;
  final String title;
  final String subtitle;
  final double amount;
  final bool isCredit;

  _HistoryItem({
    required this.when,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCredit,
  });
}

/// ---------- Profit Card ----------
class _ProfitCard extends StatelessWidget {
  final String value;
  final bool positive;

  const _ProfitCard({required this.value, required this.positive, super.key});

  @override
  Widget build(BuildContext context) {
    final color = positive ? Colors.green : Colors.red;
    final icon = positive ? Icons.trending_up : Icons.trending_down;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text('Profit',
                style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

/// ---------- Chart container ----------
class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 12), // spacing top & bottom
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            // Dynamic height: chart fills remaining space,
            // adapts to Pie vs Bar automatically
            AspectRatio(
              aspectRatio: 0.8, // Pie looks balanced; Bar won’t overflow
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}


/// ---------- Pie Chart (true pie, readable labels, no overflow legend) ----------
class _PieCard extends StatelessWidget {
  final Map<String, num> data;
  final double total;
  final List<Color> palette;
  final NumberFormat money;

  const _PieCard({
    super.key,
    required this.data,
    required this.total,
    required this.palette,
    required this.money,
  });

  Color _labelColorFor(Color c) {
    final luminance = c.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || total <= 0) {
      return const Center(child: Text('No data'));
    }

    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < entries.length; i++) {
      final value = entries[i].value.toDouble();
      final pct = (value / total * 100);
      final color = palette[i % palette.length];

      final showTitle = pct >= 6.0;

      sections.add(
        PieChartSectionData(
          value: value,
          color: color,
          radius: 80,
          title: showTitle ? '${pct.toStringAsFixed(pct >= 10 ? 0 : 1)}%' : '',
          titlePositionPercentageOffset: 0.58,
          titleStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _labelColorFor(color),
            shadows: const [Shadow(blurRadius: 2, color: Colors.black26)],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 0,   // true pie (no donut)
              startDegreeOffset: 270, // start at top
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Non-overflowing legend: one row per item with ellipsis
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(entries.length, (i) {
            final label = entries[i].key;
            final value = entries[i].value.toDouble();
            final pct = value / total * 100;
            final color = palette[i % palette.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _LegendRow(
                color: color,
                text: '$label • ${pct.toStringAsFixed(pct >= 10 ? 0 : 1)}% (${money.format(value)})',
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// ---------- Legend row (safe width) ----------
class _LegendRow extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendRow({required this.color, required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// ---------- Vertical Bar Chart ----------
class _BarCard extends StatelessWidget {
  final Map<String, num> data;
  final List<Color> palette;
  final NumberFormat money;

  const _BarCard({
    super.key,
    required this.data,
    required this.palette,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxY = entries.map((e) => e.value.toDouble()).fold<double>(0, (p, n) => n > p ? n : p);
    final groups = <BarChartGroupData>[];

    for (int i = 0; i < entries.length; i++) {
      final v = entries[i].value.toDouble();
      final color = palette[i % palette.length];
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: v,
              width: 18,
              borderRadius: BorderRadius.circular(6),
              color: color,
            )
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        maxY: (maxY * 1.2).clamp(1, double.infinity),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: groups,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                String label;
                if (value >= 1e7) {
                  label = '${(value / 1e7).toStringAsFixed(1)}cr';
                } else if (value >= 1e5) {
                  label = '${(value / 1e5).toStringAsFixed(1)}L';
                } else if (value >= 1e3) {
                  label = '${(value / 1e3).toStringAsFixed(0)}k';
                } else {
                  label = value.toStringAsFixed(0);
                }
                return Text(label, style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                final label = entries[i].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SizedBox(
                    width: 64,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = entries[group.x].key;
              return BarTooltipItem(
                '$label\n${money.format(rod.toY)}',
                const TextStyle(fontWeight: FontWeight.w700),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// ---------- Category breakdown (minimal “graph”) ----------
class _CategoryBreakdown extends StatelessWidget {
  final Map<String, num> byCategory;
  final num total;
  final NumberFormat money;

  const _CategoryBreakdown({
    super.key,
    required this.byCategory,
    required this.total,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    if (total <= 0 || byCategory.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Text('No expenses in this period.'),
        ),
      );
    }

    final entries = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Expense by Category', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...entries.map((e) {
              final pct = (e.value / total).clamp(0, 1).toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: pct,
                            child: Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.indigo,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 160,
                      child: Text('${e.key} • ${money.format(e.value)}',
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

/// ---------- Recent activity list (period-scoped) ----------
class _ActivityList extends StatelessWidget {
  final List<_ActivityItem> items;
  const _ActivityList({required this.items, super.key});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('No recent activity.'),
        ),
      );
    }
    return Column(
      children: items.map((i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: ListTile(
            leading: Icon(i.icon, color: i.color),
            title: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(i.subtitle),
            trailing:
            Text(i.trailing, style: TextStyle(fontWeight: FontWeight.bold, color: i.color)),
          ),
        );
      }).toList(),
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String trailing;

  _ActivityItem(
      {required this.icon,
        required this.color,
        required this.title,
        required this.subtitle,
        required this.trailing});

  static _ActivityItem fromLedger(
      QueryDocumentSnapshot d, DateFormat fmt, NumberFormat money) {
    final m = d.data() as Map<String, dynamic>;
    final date = (m['date'] as Timestamp?)?.toDate();
    return _ActivityItem(
      icon: Icons.trending_up,
      color: Colors.green,
      title: (m['account'] ?? 'Account').toString(),
      subtitle: '${fmt.format(date ?? DateTime.now())} • ${(m['description'] ?? '').toString()}',
      trailing: money.format(_n(m['credit'])),
    );
  }

  static _ActivityItem fromExpense(
      QueryDocumentSnapshot d, DateFormat fmt, NumberFormat money) {
    final m = d.data() as Map<String, dynamic>;
    final date = (m['dueDate'] as Timestamp?)?.toDate();
    return _ActivityItem(
      icon: Icons.trending_down,
      color: Colors.red,
      title: (m['vendor'] ?? 'Expense').toString(),
      subtitle: '${fmt.format(date ?? DateTime.now())} • ${(m['category'] ?? '').toString()}',
      trailing: money.format(_n(m['amount'])),
    );
  }

  static num _n(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    if (v is String) return num.tryParse(v.replaceAll(',', '')) ?? 0;
    return 0;
  }
}

/// ---------- Tiny UI atoms ----------
class _PeriodPicker extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PeriodPicker({required this.label, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black26),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.calendar_month, color: Colors.indigo),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
              const Icon(Icons.arrow_drop_down, color: Colors.indigo),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PeriodOption({required this.icon, required this.label, required this.onTap, super.key});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)),
      leading: Icon(icon, color: Colors.indigo),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
