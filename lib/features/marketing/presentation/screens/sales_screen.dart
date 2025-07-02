import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'new_invoices_screen.dart';
import 'all_invoices_screen.dart';
import 'sales_report_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  double salesTarget = 100000;
  double orderCount = 0;

  Future<double> _calculateTotalSales() async {
    final snapshot = await FirebaseFirestore.instance.collection('invoices').get();
    double total = 0;
    orderCount = snapshot.docs.length.toDouble();
    for (var doc in snapshot.docs) {
      total += (doc['grandTotal'] ?? 0).toDouble();
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales Dashboard')),
      body: FutureBuilder<double>(
        future: _calculateTotalSales(),
        builder: (context, snapshot) {
          final totalSales = snapshot.data ?? 0;
          final achievement = (totalSales / salesTarget * 100).clamp(0, 100);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: [
                    _buildStatCard('🎯 Sales Target', '৳${salesTarget.toStringAsFixed(0)}'),
                    _buildStatCard('💰 Total Sales', '৳${totalSales.toStringAsFixed(0)}'),
                    _buildStatCard('📦 Total Orders', '${orderCount.toStringAsFixed(0)}'),
                    _buildStatCard('📈 Achievement', '${achievement.toStringAsFixed(1)}%'),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(),
                const Text('Invoice Sections', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.add_circle, color: Colors.green),
                        title: const Text('🆕 New Invoice'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NewInvoicesScreen()),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.list_alt, color: Colors.blue),
                        title: const Text('📄 All Invoices'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AllInvoicesScreen()),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.bar_chart, color: Colors.orange),
                        title: const Text('📊 Sales Report'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SalesReportScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
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