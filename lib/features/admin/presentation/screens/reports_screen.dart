import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/features/attendance/admin_detail_view.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(('Reports Overview') , style: TextStyle(color: Colors.white)),
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
          _ExpensesTile(),
          _RndProjectsTile(),
          _IncentiveTile(), // ✅ NEW
        ],
      ),
    );
  }
}

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
          value: '৳${total.toStringAsFixed(0)}',
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
      stream: FirebaseFirestore.instance.collection('budget').limit(1).snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const _ReportTile.loading();
        final docs = snap.data!.docs;
        final amt = docs.isEmpty ? 0.0 : (docs.first.get('amount') as num).toDouble();
        return _ReportTile(
          title: 'Budget',
          value: '৳${amt.toStringAsFixed(0)}',
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
    final users = userSnap.docs;

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

      if (status == 'present') stats[empId]!['present'] = stats[empId]!['present']! + 1;
      else if (status == 'absent') stats[empId]!['absent'] = stats[empId]!['absent']! + 1;
      else if (status == 'leave') stats[empId]!['leave'] = stats[empId]!['leave']! + 1;
      else if (status == 'late') stats[empId]!['late'] = stats[empId]!['late']! + 1;

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

    return totalCount > 0
        ? ((totalPresent + totalLate) / totalCount) * 100
        : 0.0;
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
              (sum, d) => sum + ((d.get('amount') as num).toDouble()),
        );
        return _ReportTile(
          title: 'Bills & Expenses',
          value: '৳${total.toStringAsFixed(0)}',
          icon: Icons.receipt_long,
          onTap: () => Navigator.pushNamed(context, '/admin/reports/expenses'),
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
