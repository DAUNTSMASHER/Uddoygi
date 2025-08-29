import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:uddoygi/features/attendance/admin_detail_view.dart';

const Color _darkBlue = Color(0xFF0D47A1);

final _money = NumberFormat.currency(locale: 'en_BD', symbol: '৳');

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        const Text('Reports Overview', style: TextStyle(color: Colors.white)),
        backgroundColor: _darkBlue,
      ),
      backgroundColor: Colors.white,
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: const [
          _TotalSalesTile(),
          _TotalBuyersTile(),
          _TotalSuppliersTile(),
          _BudgetTile(),
          _TotalWorkersTile(),
          _AttendanceTile(),
          _PerformanceTile(),
          _ExpensesTile(),      // opens Expenses breakdown
          _RndProjectsTile(),
          _IncentiveTile(),
          _TotalMoneyInTile(),  // opens Money In breakdown
          _TotalProfitTile(),   // opens Profit breakdown
        ],
      ),
    );
  }
}

/* ===================== DASH TILES (REAL-TIME NUMBERS ONLY) ===================== */

class _TotalSalesTile extends StatelessWidget {
  const _TotalSalesTile();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('invoices').snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const _ReportTile.loading();
        final total = snap.data!.docs.fold<double>(
          0,
              (sum, doc) {
            final val = doc.get('grandTotal');
            return sum + ((val is num) ? val.toDouble() : 0);
          },
        );
        return _ReportTile(
          title: 'Total Sales',
          value: _money.format(total),
          icon: Icons.shopping_cart,
          onTap: () => Navigator.pushNamed(context, '/admin/reports/sales'),
        );
      },
    );
  }
}

class _TotalBuyersTile extends StatelessWidget {
  const _TotalBuyersTile();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('buyers').snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const _ReportTile.loading();
        return _ReportTile(
          title: 'Total Buyers',
          value: '${snap.data!.docs.length}',
          icon: Icons.person,
          onTap: () => Navigator.pushNamed(context, '/admin/reports/buyers'),
        );
      },
    );
  }
}

class _TotalSuppliersTile extends StatelessWidget {
  const _TotalSuppliersTile();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('suppliers').snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const _ReportTile.loading();
        return _ReportTile(
          title: 'Total Suppliers',
          value: '${snap.data!.docs.length}',
          icon: Icons.local_shipping,
          onTap: () => Navigator.pushNamed(context, '/admin/reports/suppliers'),
        );
      },
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
      FirebaseFirestore.instance.collection('budget').limit(1).snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const _ReportTile.loading();
        final docs = snap.data!.docs;
        final amt =
        docs.isEmpty ? 0.0 : (docs.first.get('amount') as num).toDouble();
        return _ReportTile(
          title: 'Budget',
          value: _money.format(amt),
          icon: Icons.account_balance_wallet,
          onTap: () => Navigator.pushNamed(context, '/admin/reports/budget'),
        );
      },
    );
  }
}

class _TotalWorkersTile extends StatelessWidget {
  const _TotalWorkersTile();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('department', isEqualTo: 'factory')
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const _ReportTile.loading();
        return _ReportTile(
          title: 'Total Workers',
          value: '${snap.data!.docs.length}',
          icon: Icons.people_alt,
          onTap: () => Navigator.pushNamed(context, '/admin/reports/workers'),
        );
      },
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile();

  Future<double> _calculateAverageAttendance() async {
    final now = DateTime.now();
    final String year = now.year.toString();
    final String month = now.month.toString().padLeft(2, '0');

    final recordSnap =
    await FirebaseFirestore.instance.collectionGroup('records').get();
    final userSnap =
    await FirebaseFirestore.instance.collection('users').get();

    final records = recordSnap.docs;
    final Map<String, Map<String, int>> stats = {};

    for (final record in records) {
      final parentId = record.reference.parent.parent?.id ?? '';
      final parts = parentId.split('-');
      if (parts.length != 3 || parts[0] != year || parts[1] != month) continue;

      final data = record.data() as Map<String, dynamic>;
      final empId = data['employeeId'];
      final status = (data['status'] ?? '').toLowerCase();

      if (empId == null) continue;

      stats.putIfAbsent(empId, () => {
        'present': 0,
        'absent': 0,
        'leave': 0,
        'late': 0,
        'total': 0,
      });

      if (status == 'present') {
        stats[empId]!['present'] = stats[empId]!['present']! + 1;
      } else if (status == 'absent') {
        stats[empId]!['absent'] = stats[empId]!['absent']! + 1;
      } else if (status == 'leave') {
        stats[empId]!['leave'] = stats[empId]!['leave']! + 1;
      } else if (status == 'late') {
        stats[empId]!['late'] = stats[empId]!['late']! + 1;
      }

      stats[empId]!['total'] = stats[empId]!['total']! + 1;
    }

    int totalPresent = 0;
    int totalLate = 0;
    int totalCount = 0;

    for (final stat in stats.values) {
      totalPresent += stat['present']!;
      totalLate += stat['late']!;
      totalCount += stat['total']!;
    }

    return totalCount > 0 ? ((totalPresent + totalLate) / totalCount) * 100 : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: _calculateAverageAttendance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const _ReportTile.loading();

        final avg = snapshot.data!;

        return _ReportTile(
          title: 'Average Attendance',
          value: '${avg.toStringAsFixed(1)}%',
          icon: Icons.check_circle_outline,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminDetailView()),
            );
          },
        );
      },
    );
  }
}

class _PerformanceTile extends StatelessWidget {
  const _PerformanceTile();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('performance').snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const _ReportTile.loading();
        final docs = snap.data!.docs;
        final totalScore = docs.fold<double>(
          0,
              (sum, d) => sum + ((d.get('score') as num).toDouble()),
        );
        final avg = docs.isEmpty ? 0.0 : totalScore / docs.length;
        return _ReportTile(
          title: 'Work Performance',
          value: avg.toStringAsFixed(1),
          icon: Icons.bar_chart,
          onTap: () => Navigator.pushNamed(context, '/admin/reports/performance'),
        );
      },
    );
  }
}

class _ExpensesTile extends StatelessWidget {
  const _ExpensesTile();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const _ReportTile.loading();
        final total = snap.data!.docs.fold<double>(
          0,
              (sum, d) => sum + _asDouble(d.get('amount')),
        );
        return _ReportTile(
          title: 'Bills & Expenses',
          value: _money.format(total),
          icon: Icons.receipt_long,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExpensesBreakdownScreen()),
          ),
        );
      },
    );
  }
}

class _RndProjectsTile extends StatelessWidget {
  const _RndProjectsTile();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('rnd_updates').snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const _ReportTile.loading();
        return _ReportTile(
          title: 'R&D Projects',
          value: '${snap.data!.docs.length} Active',
          icon: Icons.science,
          onTap: () => Navigator.pushNamed(context, '/admin/reports/rnd'),
        );
      },
    );
  }
}

class _IncentiveTile extends StatelessWidget {
  const _IncentiveTile();

  @override
  Widget build(BuildContext context) {
    return _ReportTile(
      title: 'Incentives & Bonus',
      value: 'View',
      icon: Icons.monetization_on,
      onTap: () => Navigator.pushNamed(context, '/admin/reports/incentives'),
    );
  }
}

class _TotalMoneyInTile extends StatelessWidget {
  const _TotalMoneyInTile();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('ledger').snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const _ReportTile.loading();
        final totalIn = snap.data!.docs.fold<double>(
          0,
              (sum, d) => sum + _asDouble(d.get('credit')),
        );
        return _ReportTile(
          title: 'Total Money In',
          value: _money.format(totalIn),
          icon: Icons.account_balance,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MoneyInBreakdownScreen()),
          ),
        );
      },
    );
  }
}

class _TotalProfitTile extends StatelessWidget {
  const _TotalProfitTile();

  @override
  Widget build(BuildContext context) {
    final ledgerStream =
    FirebaseFirestore.instance.collection('ledger').snapshots();
    final expenseStream =
    FirebaseFirestore.instance.collection('expenses').snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: ledgerStream,
      builder: (ctx, ledgerSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: expenseStream,
          builder: (ctx, expenseSnap) {
            if (!ledgerSnap.hasData || !expenseSnap.hasData) {
              return const _ReportTile.loading();
            }

            final totalIn = ledgerSnap.data!.docs.fold<double>(
              0,
                  (sum, d) => sum + _asDouble(d.get('credit')),
            );

            final totalOut = expenseSnap.data!.docs.fold<double>(
              0,
                  (sum, d) => sum + _asDouble(d.get('amount')),
            );

            final profit = totalIn - totalOut;

            return _ReportTile(
              title: 'Total Profit',
              value: _money.format(profit),
              icon: Icons.trending_up,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfitBreakdownScreen()),
              ),
            );
          },
        );
      },
    );
  }
}

/* ===================== TILE WIDGET ===================== */

class _ReportTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const _ReportTile({
    this.title = '',
    this.value = '',
    this.icon = Icons.widgets,
    this.onTap,
  });

  const _ReportTile.loading()
      : title = '',
        value = '…',
        icon = Icons.hourglass_empty,
        onTap = null;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: _darkBlue),
              const SizedBox(height: 12),
              Text(
                value,
                style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ===================== BREAKDOWN SCREENS (LIKE BALANCE PAGE) ===================== */

const List<Color> _palette = [
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

/* ---------- Shared chart shells ---------- */

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 0.8, // keeps charts balanced and avoids overflow
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _PieCard extends StatelessWidget {
  final Map<String, num> data;
  final double total;
  final List<Color> palette;

  const _PieCard({
    super.key,
    required this.data,
    required this.total,
    required this.palette,
  });

  Color _labelColorFor(Color c) =>
      c.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || total <= 0) {
      return const Center(child: Text('No data'));
    }

    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < entries.length; i++) {
      final v = entries[i].value.toDouble();
      final pct = v / total * 100;
      final color = palette[i % palette.length];
      final showTitle = pct >= 6.0;

      sections.add(
        PieChartSectionData(
          value: v,
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
              startDegreeOffset: 270,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(entries.length, (i) {
            final label = entries[i].key;
            final v = entries[i].value.toDouble();
            final pct = v / total * 100;
            final color = palette[i % palette.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$label • ${pct.toStringAsFixed(pct >= 10 ? 0 : 1)}% (${_money.format(v)})',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BarCard extends StatelessWidget {
  final Map<String, num> data;

  const _BarCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No data'));

    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxY = entries.isEmpty
        ? 1.0
        : entries.map((e) => e.value.toDouble()).reduce((a, b) => a > b ? a : b);

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < entries.length; i++) {
      final v = entries[i].value.toDouble();
      final color = _palette[i % _palette.length];
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
                '$label\n${_money.format(rod.toY)}',
                const TextStyle(fontWeight: FontWeight.w700),
              );
            },
          ),
        ),
      ),
    );
  }
}

/* ---------- Money In Breakdown ---------- */

class MoneyInBreakdownScreen extends StatelessWidget {
  const MoneyInBreakdownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        const Text('Money In Breakdown', style: TextStyle(color: Colors.white)),
        backgroundColor: _darkBlue,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('ledger').snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;

          double totalIn = 0;
          final Map<String, num> byAccount = {};
          for (final d in docs) {
            final m = d.data() as Map<String, dynamic>;
            final acc = (m['account'] ?? 'Other').toString();
            final credit = _asDouble(m['credit']);
            totalIn += credit;
            byAccount[acc] = (byAccount[acc] ?? 0) + credit;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _headline('Total Money In', totalIn, Icons.trending_up, Colors.green),
              const SizedBox(height: 12),
              _ChartCard(
                title: 'By Account (Pie)',
                child: _PieCard(data: byAccount, total: totalIn, palette: _palette),
              ),
              _ChartCard(
                title: 'By Account (Bar)',
                child: _BarCard(data: byAccount),
              ),
            ],
          );
        },
      ),
    );
  }
}

/* ---------- Profit Breakdown ---------- */

class ProfitBreakdownScreen extends StatelessWidget {
  const ProfitBreakdownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ledgerStream = FirebaseFirestore.instance.collection('ledger').snapshots();
    final expenseStream = FirebaseFirestore.instance.collection('expenses').snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit Breakdown', style: TextStyle(color: Colors.white)),
        backgroundColor: _darkBlue,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ledgerStream,
        builder: (ctx, ledgerSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: expenseStream,
            builder: (ctx, expenseSnap) {
              if (!ledgerSnap.hasData || !expenseSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // Money In
              double totalIn = 0;
              final Map<String, num> inByAccount = {};
              for (final d in ledgerSnap.data!.docs) {
                final m = d.data() as Map<String, dynamic>;
                final acc = (m['account'] ?? 'Other').toString();
                final credit = _asDouble(m['credit']);
                totalIn += credit;
                inByAccount[acc] = (inByAccount[acc] ?? 0) + credit;
              }

              // Expenses
              double totalOut = 0;
              final Map<String, num> outByCategory = {};
              for (final d in expenseSnap.data!.docs) {
                final m = d.data() as Map<String, dynamic>;
                final cat = (m['category'] ?? 'Other').toString();
                final amt = _asDouble(m['amount']);
                totalOut += amt;
                outByCategory[cat] = (outByCategory[cat] ?? 0) + amt;
              }

              final profit = totalIn - totalOut;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _headline('Total Profit', profit,
                      profit >= 0 ? Icons.trending_up : Icons.trending_down,
                      profit >= 0 ? Colors.green : Colors.red),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _miniStat('', totalIn, Icons.arrow_downward, Colors.green)),
                      const SizedBox(width: 12),
                      Expanded(child: _miniStat('', totalOut, Icons.arrow_upward, Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ChartCard(
                    title: 'Money In by Account (Pie)',
                    child: _PieCard(data: inByAccount, total: totalIn, palette: _palette),
                  ),
                  _ChartCard(
                    title: 'Expenses by Category (Pie)',
                    child: _PieCard(data: outByCategory, total: totalOut, palette: _palette),
                  ),
                  _ChartCard(
                    title: 'Money In by Account (Bar)',
                    child: _BarCard(data: inByAccount),
                  ),
                  _ChartCard(
                    title: 'Expenses by Category (Bar)',
                    child: _BarCard(data: outByCategory),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/* ---------- Expenses Breakdown ---------- */

class ExpensesBreakdownScreen extends StatelessWidget {
  const ExpensesBreakdownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        const Text('Bills & Expenses', style: TextStyle(color: Colors.white)),
        backgroundColor: _darkBlue,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;

          double total = 0;
          final Map<String, num> byCategory = {};
          for (final d in docs) {
            final m = d.data() as Map<String, dynamic>;
            final cat = (m['category'] ?? 'Other').toString();
            final amt = _asDouble(m['amount']);
            total += amt;
            byCategory[cat] = (byCategory[cat] ?? 0) + amt;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _headline('Total Expenses', total, Icons.trending_up, Colors.red),
              const SizedBox(height: 12),
              _ChartCard(
                title: 'By Category (Pie)',
                child: _PieCard(data: byCategory, total: total, palette: _palette),
              ),
              _ChartCard(
                title: 'By Category (Bar)',
                child: _BarCard(data: byCategory),
              ),
            ],
          );
        },
      ),
    );
  }
}

/* ===================== SMALL HELPERS ===================== */

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? 0.0;
  return 0.0;
}

Widget _headline(String title, double value, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        Text(_money.format(value),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      ],
    ),
  );
}

Widget _miniStat(String title, double value, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
        Text(_money.format(value),
            style: TextStyle(fontWeight: FontWeight.w800, color: color)),
      ],
    ),
  );
}
