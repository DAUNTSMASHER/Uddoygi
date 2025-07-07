// lib/features/admin/presentation/screens/reports_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports Overview'),
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
      // <— listen to your invoices, not a non‑existent “sales” collection
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
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().split('T').first;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('attendance').snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const _ReportTile.loading();
        final todayList = snap.data!.docs.where((d) => d.get('date') == today);
        final present =
            todayList.where((d) => d.get('status') == 'present').length;
        final pct = todayList.isEmpty ? 0.0 : present / todayList.length * 100;
        return _ReportTile(
          title: 'Attendance Today',
          value: '${pct.toStringAsFixed(1)}%',
          icon: Icons.check_circle,
          onTap: () => Navigator.pushNamed(context, '/admin/reports/attendance'),
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
