import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
const Color _darkBlue = Color(0xFF0D47A1);
class IncentiveHistoryScreen extends StatelessWidget {
  const IncentiveHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final incentivesRef = FirebaseFirestore.instance.collection('marketing_incentives');

    return Scaffold(
      appBar: AppBar(
        title: const Text(('Incentive History') , style: TextStyle(color: Colors.white)),
        backgroundColor: _darkBlue,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: incentivesRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs
              .where((doc) =>
          doc.id.contains('_sales') &&
              (doc.data() as Map<String, dynamic>)['totalIncentive'] != null)
              .toList();

          if (docs.isEmpty) return const Center(child: Text('No incentive records available.'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final totalIncentive = (data['totalIncentive'] ?? 0.0).toDouble();
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
              final agentId = doc.id.split('_sales').first;
              final parts = agentId.split('_');
              final email = parts.first;
              final month = parts.length >= 2 ? parts[1] : 'Unknown';
              final year = parts.length >= 3 ? parts[2] : 'Unknown';

              final formattedDate = timestamp != null
                  ? DateFormat.yMMMMd().format(timestamp.toLocal())
                  : 'Unknown Date';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Month: $month, Year: $year'),
                      Text('Incentive: ৳${totalIncentive.toStringAsFixed(2)}'),
                      Text('Timestamp: $formattedDate'),
                    ],
                  ),
                  onTap: () => _showBreakdownDialog(context, data),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showBreakdownDialog(BuildContext context, Map<String, dynamic> data) {
    final rows = (data['rows'] as List<dynamic>? ?? []);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Incentive Breakdown'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.indigo.shade50),
              headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              dataTextStyle: const TextStyle(fontSize: 10),
              columns: const [
                DataColumn(label: Text('Product')),
                DataColumn(label: Text('Qty')),
                DataColumn(label: Text('Unit Price')),
                DataColumn(label: Text('Cost')),
                DataColumn(label: Text('Profit')),
                DataColumn(label: Text('Net Profit')),
                DataColumn(label: Text('Incentive')),
              ],
              rows: rows.map((row) {
                final product = row['productName'] ?? '';
                final qty = (row['quantity'] ?? 0).toString();
                final price = (row['sellingPrice'] ?? 0.0).toStringAsFixed(2);
                final cost = (row['purchaseCost'] ?? 0.0).toStringAsFixed(2);
                final profit = (row['netProfit'] != null && row['factoryCostingPercent'] != null)
                    ? ((row['sellingPrice'] ?? 0.0) - (row['purchaseCost'] ?? 0.0)) * ((100 - row['factoryCostingPercent']) / 100)
                    : 0.0;
                final netProfit = (row['netProfit'] ?? profit).toStringAsFixed(2);
                final incentive = (row['incentive'] ?? 0.0).toStringAsFixed(2);

                return DataRow(cells: [
                  DataCell(Text(product)),
                  DataCell(Text(qty)),
                  DataCell(Text(price)),
                  DataCell(Text(cost)),
                  DataCell(Text(profit.toStringAsFixed(2))),
                  DataCell(Text(netProfit)),
                  DataCell(Text(incentive)),
                ]);
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
