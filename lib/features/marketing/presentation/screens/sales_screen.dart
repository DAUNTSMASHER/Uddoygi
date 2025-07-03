import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'new_invoices_screen.dart';
import 'all_invoices_screen.dart';
import 'sales_report_screen.dart';
import 'order_progress_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  double salesTarget = 100000;
  int orderCount = 0;
  double totalSales = 0;
  String? userEmail;
  bool targetReached = false;
  DateTime selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadUserSession();
  }

  Future<void> _loadUserSession() async {
    final session = await LocalStorageService.getSession();
    if (session != null && mounted) {
      userEmail = session['email'];
      await _calculateUserSales();
    }
  }

  Future<void> _calculateUserSales() async {
    if (userEmail == null) return;
    final startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final endOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

    final snapshot = await FirebaseFirestore.instance
        .collection('invoices')
        .where('agentEmail', isEqualTo: userEmail)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    double total = 0;
    int count = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data.containsKey('grandTotal')) {
        total += (data['grandTotal'] as num).toDouble();
      }
      count++;
    }

    if (mounted) {
      setState(() {
        totalSales = total;
        orderCount = count;
        targetReached = totalSales >= salesTarget;
      });
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2025, 1),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null && picked != selectedMonth) {
      setState(() {
        selectedMonth = picked;
      });
      await _calculateUserSales();
    }
  }

  @override
  Widget build(BuildContext context) {
    final achievement = (totalSales / salesTarget * 100).clamp(0, 100).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Dashboard'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _selectMonth(context),
            tooltip: 'Filter Month',
          )
        ],
      ),
      body: userEmail == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (targetReached)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.emoji_events, color: Colors.green),
                    SizedBox(width: 10),
                    Expanded(child: Text("🎉 Congratulations! You've hit your monthly sales target!")),
                  ],
                ),
              ),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    children: [
                      _buildStatCard('🎯 Sales Target', '৳${salesTarget.toStringAsFixed(0)}'),
                      _buildStatCard('💰 Total Sales', '৳${totalSales.toStringAsFixed(0)}'),
                      _buildStatCard('📦 Total Orders', '$orderCount'),
                      _buildStatCard('📈 Achievement', '${achievement.toStringAsFixed(1)}%'),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      const Text('Sales Achievement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(value: achievement, color: Colors.indigo, title: 'Achieved'),
                              PieChartSectionData(value: 100 - achievement, color: Colors.grey.shade300, title: 'Left'),
                            ],
                            centerSpaceRadius: 40,
                            sectionsSpace: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(),
            const Text('Invoice Sections', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: const Icon(Icons.add_circle, color: Colors.green),
                    title: const Text('🆕 New Invoice', style: TextStyle(fontSize: 18)),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NewInvoicesScreen()),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.list_alt, color: Colors.blue),
                    title: const Text('📄 All Invoices', style: TextStyle(fontSize: 18)),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AllInvoicesScreen()),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.bar_chart, color: Colors.orange),
                    title: const Text('📊 Sales Report', style: TextStyle(fontSize: 18)),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SalesReportScreen()),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.timeline, color: Colors.deepPurple),
                    title: const Text('📦 Order Progress', style: TextStyle(fontSize: 18)),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OrderProgressScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
        ],
      ),
    );
  }
}
