import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class RenumerationDashboard extends StatefulWidget {
  const RenumerationDashboard({Key? key}) : super(key: key);

  @override
  State<RenumerationDashboard> createState() => _RenumerationDashboardState();
}

class _RenumerationDashboardState extends State<RenumerationDashboard> {
  String _cid = '';
  double currentMonthTotal = 0;
  double allTimeTotal = 0;
  List<Map<String, dynamic>> userIncentives = [];

  final String currentUserEmail = 'herok@wigbd.com'; // Replace with logged-in user email
  final String currentMonth = DateFormat('MMMM_yyyy').format(DateTime.now()); // e.g. July_2025

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _loadIncentives();
  }

  Future<void> _loadIncentives() async {
    final snapshot = await DB.colSync(_cid, C.marketingIncentives)
        .get();

    double allIncentive = 0;
    double monthIncentive = 0;
    List<Map<String, dynamic>> userReports = [];

    for (var doc in snapshot.docs) {
      final id = doc.id;
      final data = doc.data();
      final total = (data['totalIncentive'] as num?)?.toDouble();

      if (total != null) {
        allIncentive += total;

        if (id.startsWith(currentUserEmail)) {
          userReports.add({
            'id': id,
            'totalIncentive': total,
            'isCurrentMonth': id.contains(currentMonth),
          });

          if (id.contains(currentMonth)) {
            monthIncentive += total;
          }
        }
      }
    }

    setState(() {
      allTimeTotal = allIncentive;
      currentMonthTotal = monthIncentive;
      userIncentives = userReports;
    });
  }

  void _showIncentivePopup(String reportId) async {
    final snapshot = await DB.colSync(_cid, C.marketingIncentives)
        .doc(reportId)
        .get();

    final rows = (snapshot.data()?['rows'] as List<dynamic>? ?? []);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Breakdown: $reportId", style: const TextStyle(fontSize: 14)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 12,
              headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              dataTextStyle: const TextStyle(fontSize: 11),
              columns: const [
                DataColumn(label: Text('Product')),
                DataColumn(label: Text('Qty')),
                DataColumn(label: Text('Sell Price')),
                DataColumn(label: Text('Cost')),
                DataColumn(label: Text('Net Profit')),
                DataColumn(label: Text('Incentive')),
              ],
              rows: rows.map((row) {
                return DataRow(cells: [
                  DataCell(Text(row['productName'] ?? '')),
                  DataCell(Text(row['quantity']?.toString() ?? '')),
                  DataCell(Text(row['sellingPrice']?.toStringAsFixed(2) ?? '')),
                  DataCell(Text(row['purchaseCost']?.toStringAsFixed(2) ?? '')),
                  DataCell(Text(row['netProfit']?.toStringAsFixed(2) ?? '')),
                  DataCell(Text(row['incentive']?.toStringAsFixed(2) ?? '')),
                ]);
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Renumeration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        backgroundColor: _darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              '📊 Incentive Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStatCard("This Month", "৳${currentMonthTotal.toStringAsFixed(0)}"),
            _buildStatCard("All Time", "৳${allTimeTotal.toStringAsFixed(0)}"),
            const SizedBox(height: 20),
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '📁 My Incentive History',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: userIncentives.isEmpty
                  ? const Center(child: Text("No incentive reports found."))
                  : ListView.builder(
                itemCount: userIncentives.length,
                itemBuilder: (_, index) {
                  final report = userIncentives[index];
                  final id = report['id'];
                  final total = report['totalIncentive'];
                  final isCurrentMonth = report['isCurrentMonth'] == true;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(
                        id,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isCurrentMonth ? Colors.green.shade700 : Colors.black,
                        ),
                      ),
                      subtitle: Text("Total Incentive: ৳${total.toStringAsFixed(2)}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.visibility),
                        onPressed: () => _showIncentivePopup(id),
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      color: Colors.indigo.shade50,
      child: ListTile(
        leading: const Icon(Icons.bar_chart, color: _darkBlue),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: _darkBlue,
          ),
        ),
      ),
    );
  }
}
