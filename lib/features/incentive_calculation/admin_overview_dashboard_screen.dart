import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
const Color _darkBlue = Color(0xFF0D47A1);
class AdminOverviewDashboardScreen extends StatefulWidget {
  const AdminOverviewDashboardScreen({super.key});

  @override
  State<AdminOverviewDashboardScreen> createState() =>
      _AdminOverviewDashboardScreenState();
}

class _AdminOverviewDashboardScreenState
    extends State<AdminOverviewDashboardScreen> {
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  final Map<String, int> monthMap = const {
    'January': 1,
    'February': 2,
    'March': 3,
    'April': 4,
    'May': 5,
    'June': 6,
    'July': 7,
    'August': 8,
    'September': 9,
    'October': 10,
    'November': 11,
    'December': 12,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(('Incentive Summary') , style: TextStyle(color: Colors.white)),
        backgroundColor: _darkBlue,
      ),
      body: Column(
        children: [
          _buildFilter(),

          // 🧾 Main Table
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('marketing_incentives')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('❌ Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                final filteredDocs = _filterDocsByMonthYear(docs);

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('⚠️ No data for selected month and year.'));
                }

                double totalSaleAll = 0;
                double totalIncentiveAll = 0;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.indigo.shade50),
                    headingTextStyle: const TextStyle(fontWeight: FontWeight.bold),
                    dataTextStyle: const TextStyle(fontSize: 12),
                    columns: const [
                      DataColumn(label: Text('S/N')),
                      DataColumn(label: Text('Agent Email')),
                      DataColumn(label: Text('Total Sale')),
                      DataColumn(label: Text('Total Product')),
                      DataColumn(label: Text('Total Incentive')),
                    ],
                    rows: List.generate(filteredDocs.length, (index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final agentEmail = doc.id.split('_').first;
                      final rows = (data['rows'] as List?) ?? [];

                      double totalSale = 0;
                      int totalQty = 0;
                      double totalIncentive = (data['totalIncentive'] ?? 0.0).toDouble();

                      for (var row in rows) {
                        final qty = row['quantity'];
                        final price = row['sellingPrice'];
                        if (qty is int && price is num) {
                          totalSale += qty * price;
                          totalQty += qty;
                        }
                      }

                      totalSaleAll += totalSale;
                      totalIncentiveAll += totalIncentive;

                      return DataRow(cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(Text(agentEmail)),
                        DataCell(Text('৳${totalSale.toStringAsFixed(2)}')),
                        DataCell(Text('$totalQty')),
                        DataCell(Text('৳${totalIncentive.toStringAsFixed(2)}')),
                      ]);
                    }),
                  ),
                );
              },
            ),
          ),

          // 📊 Summary Footer
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('marketing_incentives')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();

                final filteredDocs = _filterDocsByMonthYear(snapshot.data!.docs);

                double totalSaleAll = 0;
                double totalIncentiveAll = 0;

                for (final doc in filteredDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final rows = (data['rows'] as List?) ?? [];
                  final totalIncentive = (data['totalIncentive'] ?? 0.0).toDouble();

                  double sale = 0;
                  for (var row in rows) {
                    final qty = row['quantity'];
                    final price = row['sellingPrice'];
                    if (qty is int && price is num) {
                      sale += qty * price;
                    }
                  }

                  totalSaleAll += sale;
                  totalIncentiveAll += totalIncentive;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    Text('🔢 Total Sale: ৳${totalSaleAll.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('💰 Total Incentive: ৳${totalIncentiveAll.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 🧠 Month name-aware filtering
  List<QueryDocumentSnapshot> _filterDocsByMonthYear(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final id = doc.id;
      if (!id.contains('_sales')) return false;

      final parts = id.split('_');
      if (parts.length < 4) {
        print('❌ Skipped invalid ID: $id');
        return false;
      }

      final monthRaw = parts[parts.length - 3];
      final yearRaw = parts[parts.length - 2];

      final month = int.tryParse(monthRaw) ?? monthMap[monthRaw];
      final year = int.tryParse(yearRaw);

      if (month == null || year == null) {
        print('❌ Invalid month/year in ID: $id');
        return false;
      }

      return month == selectedMonth && year == selectedYear;
    }).toList();
  }

  /// 🎛️ Dropdowns
  Widget _buildFilter() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          DropdownButton<int>(
            value: selectedMonth,
            items: List.generate(12, (index) {
              return DropdownMenuItem(
                value: index + 1,
                child: Text(DateFormat.MMMM().format(DateTime(0, index + 1))),
              );
            }),
            onChanged: (val) {
              if (val != null) setState(() => selectedMonth = val);
            },
          ),
          const SizedBox(width: 16),
          DropdownButton<int>(
            value: selectedYear,
            items: List.generate(5, (index) {
              final year = DateTime.now().year - 2 + index;
              return DropdownMenuItem(value: year, child: Text('$year'));
            }),
            onChanged: (val) {
              if (val != null) setState(() => selectedYear = val);
            },
          ),
        ],
      ),
    );
  }
}
