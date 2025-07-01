// File: lib/features/admin/presentation/screens/admin_dashboard.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';


class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _DashboardTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _DashboardTile({
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

class _AdminDashboardState extends State<AdminDashboard> {
  double totalSales = 0;
  int totalBuyers = 0;
  int totalSuppliers = 0;
  double budget = 0;
  int totalWorkers = 0;
  double attendancePercent = 0;
  double workPerformance = 0;
  double totalExpenses = 0;
  int rndProjects = 0;

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
  }

  Future<void> fetchDashboardData() async {
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
      sales += (doc['amount'] ?? 0).toDouble();
    }

    double expense = 0;
    for (var doc in expensesSnap.docs) {
      expense += (doc['amount'] ?? 0).toDouble();
    }

    double performanceTotal = 0;
    for (var doc in performanceSnap.docs) {
      performanceTotal += (doc['score'] ?? 0).toDouble();
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
          ? (budgetSnap.docs.first['amount'] ?? 0).toDouble()
          : 0;
      totalWorkers = usersSnap.docs.where((e) => e['role'] == 'worker').length;
      attendancePercent = attendance;
      workPerformance = avgPerformance;
      totalExpenses = expense;
      rndProjects = rndSnap.docs.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _DashboardTile(
          title: 'Total Sales',
          value: '৳${totalSales.toStringAsFixed(0)}',
          icon: Icons.shopping_cart,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SalesListScreen(),
              ),
            );
          }),
      _DashboardTile(
          title: 'Total Buyers',
          value: '$totalBuyers',
          icon: Icons.person,
          onTap: () {}),
      _DashboardTile(
          title: 'Total Suppliers',
          value: '$totalSuppliers',
          icon: Icons.local_shipping,
          onTap: () {}),
      _DashboardTile(
          title: 'Budget',
          value: '৳${budget.toStringAsFixed(0)}',
          icon: Icons.account_balance_wallet,
          onTap: () {}),
      _DashboardTile(
          title: 'Total Workers',
          value: '$totalWorkers',
          icon: Icons.people_alt,
          onTap: () {}),
      _DashboardTile(
          title: 'Attendance Today',
          value: '${attendancePercent.toStringAsFixed(1)}%',
          icon: Icons.check_circle,
          onTap: () {}),
      _DashboardTile(
          title: 'Work Performance',
          value: '${workPerformance.toStringAsFixed(1)}',
          icon: Icons.bar_chart,
          onTap: () {}),
      _DashboardTile(
          title: 'Bills & Expenses',
          value: '৳${totalExpenses.toStringAsFixed(0)}',
          icon: Icons.receipt_long,
          onTap: () {}),
      _DashboardTile(
          title: 'R&D Projects',
          value: '$rndProjects Active',
          icon: Icons.science,
          onTap: () {}),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login'); // or your login route
              }
            },

          )
        ],
      ),
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

class SalesListScreen extends StatelessWidget {
  const SalesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales List')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sales').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No sales data found.'));
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final amount = data['amount'] ?? 0;
              final date = data['date'] ?? 'N/A';
              final buyerId = data['buyerId'] ?? 'Unknown';

              return ListTile(
                leading: const Icon(Icons.monetization_on),
                title: Text('৳${amount.toString()}'),
                subtitle: Text('Buyer: $buyerId\nDate: $date'),
              );
            },
          );
        },
      ),
    );
  }
}
