import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  double totalSales = 0;
  int totalBuyers = 0;
  int totalSuppliers = 0;
  double budget = 0;
  int totalWorkers = 0;
  double attendancePercent = 0;
  double workPerformance = 0;
  double totalExpenses = 0;
  int rndProjects = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchReportData();
  }

  Future<void> fetchReportData() async {
    try {
      final firestore = FirebaseFirestore.instance;

      final salesSnap = await firestore.collection('sales').get();
      final buyersSnap = await firestore.collection('buyers').get();
      final suppliersSnap = await firestore.collection('suppliers').get();
      final budgetSnap = await firestore.collection('budget').limit(1).get();
      final usersSnap = await firestore.collection('users').get();
      final attendanceSnap = await firestore.collection('attendance').get();
      final performanceSnap = await firestore.collection('performance').get();
      final expensesSnap = await firestore.collection('expenses').get();
      final rndSnap = await firestore.collection('rnd_updates').get();

      double sales = 0;
      for (var doc in salesSnap.docs) {
        sales += (doc.data()['amount'] ?? 0).toDouble();
      }

      double expense = 0;
      for (var doc in expensesSnap.docs) {
        expense += (doc.data()['amount'] ?? 0).toDouble();
      }

      double performanceTotal = 0;
      for (var doc in performanceSnap.docs) {
        performanceTotal += (doc.data()['score'] ?? 0).toDouble();
      }

      double avgPerformance = performanceSnap.docs.isNotEmpty
          ? performanceTotal / performanceSnap.docs.length
          : 0;

      int present = 0;
      int total = 0;
      final today = DateTime.now().toIso8601String().split('T').first;
      for (var doc in attendanceSnap.docs) {
        if (doc['date'] == today) {
          total++;
          if (doc['status'] == 'present') present++;
        }
      }

      double attendance = total > 0 ? (present / total) * 100 : 0;

      setState(() {
        totalSales = sales;
        totalBuyers = buyersSnap.docs.length;
        totalSuppliers = suppliersSnap.docs.length;
        budget = budgetSnap.docs.isNotEmpty
            ? (budgetSnap.docs.first.data()['amount'] ?? 0).toDouble()
            : 0;
        totalWorkers =
            usersSnap.docs.where((e) => e.data()['role'] == 'worker').length;
        attendancePercent = attendance;
        workPerformance = avgPerformance;
        totalExpenses = expense;
        rndProjects = rndSnap.docs.length;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tiles = [
      _ReportTile(
          title: 'Total Sales',
          value: '৳${totalSales.toStringAsFixed(0)}',
          icon: Icons.shopping_cart,
          onTap: () {
            Navigator.pushNamed(context, '/admin/reports/sales');
          }),
      _ReportTile(
          title: 'Total Buyers',
          value: '$totalBuyers',
          icon: Icons.person,
          onTap: () {
            Navigator.pushNamed(context, '/admin/reports/buyers');
          }),
      _ReportTile(
          title: 'Total Suppliers',
          value: '$totalSuppliers',
          icon: Icons.local_shipping,
          onTap: () {
            Navigator.pushNamed(context, '/admin/reports/suppliers');
          }),
      _ReportTile(
          title: 'Budget',
          value: '৳${budget.toStringAsFixed(0)}',
          icon: Icons.account_balance_wallet,
          onTap: () {
            Navigator.pushNamed(context, '/admin/reports/budget');
          }),
      _ReportTile(
          title: 'Total Workers',
          value: '$totalWorkers',
          icon: Icons.people_alt,
          onTap: () {
            Navigator.pushNamed(context, '/admin/reports/workers');
          }),
      _ReportTile(
          title: 'Attendance Today',
          value: '${attendancePercent.toStringAsFixed(1)}%',
          icon: Icons.check_circle,
          onTap: () {
            Navigator.pushNamed(context, '/admin/reports/attendance');
          }),
      _ReportTile(
          title: 'Work Performance',
          value: workPerformance.toStringAsFixed(1),
          icon: Icons.bar_chart,
          onTap: () {
            Navigator.pushNamed(context, '/admin/reports/performance');
          }),
      _ReportTile(
          title: 'Bills & Expenses',
          value: '৳${totalExpenses.toStringAsFixed(0)}',
          icon: Icons.receipt_long,
          onTap: () {
            Navigator.pushNamed(context, '/admin/reports/expenses');
          }),
      _ReportTile(
          title: 'R&D Projects',
          value: '$rndProjects Active',
          icon: Icons.science,
          onTap: () {
            Navigator.pushNamed(context, '/admin/reports/rnd');
          }),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Reports Overview')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: tiles,
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _ReportTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: Colors.indigo),
              const SizedBox(height: 10),
              Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
