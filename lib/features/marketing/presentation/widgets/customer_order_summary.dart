import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/marketing/presentation/widgets/order_details.dart';

class CustomerOrderSummary extends StatefulWidget {
  final String email;
  const CustomerOrderSummary({super.key, required this.email});

  @override
  State<CustomerOrderSummary> createState() => _CustomerOrderSummaryState();
}

class _CustomerOrderSummaryState extends State<CustomerOrderSummary> {
  String? agentEmail;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    final session = await LocalStorageService.getSession();
    if (session != null) {
      setState(() {
        agentEmail = session['email'];
      });
    }
  }

  int _extractQty(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Customer Orders Summary"),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      body: agentEmail == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('invoices')
            .where('agentEmail', isEqualTo: agentEmail)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No orders found.'));
          }

          final orders = snapshot.data!.docs;
          double totalAmount = 0;
          int totalQuantity = 0;
          int shipped = 0;
          int pending = 0;

          for (var doc in orders) {
            final data = doc.data() as Map<String, dynamic>;
            final grandTotal = (data['grandTotal'] ?? 0);
            final items = data['items'] as List<dynamic>? ?? [];
            final quantity = items.fold<int>(0, (sum, item) => sum + _extractQty(item['qty']));

            final status = data['status'] ?? 'Pending';
            totalAmount += grandTotal is num ? grandTotal.toDouble() : 0.0;
            totalQuantity += quantity;
            if (status == 'Shipped') shipped++;
            if (status == 'Pending') pending++;
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatBox('Orders', orders.length.toString(), Icons.list),
                        _buildStatBox('Amount', '৳${totalAmount.toStringAsFixed(0)}', Icons.monetization_on),
                        _buildStatBox('Quantity', totalQuantity.toString(), Icons.inventory),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Order Status Distribution',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(value: shipped.toDouble(), title: 'Shipped'),
                        PieChartSectionData(value: pending.toDouble(), title: 'Pending'),
                      ],
                      sectionsSpace: 4,
                      centerSpaceRadius: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Detailed Orders',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final doc = orders[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final date = (data['date'] as Timestamp?)?.toDate();
                      final formattedDate = date != null ? DateFormat('yyyy-MM-dd').format(date) : 'Unknown';
                      final items = data['items'] as List<dynamic>? ?? [];
                      final quantity = items.fold<int>(0, (sum, item) => sum + _extractQty(item['qty']));

                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long, color: Colors.indigo),
                          title: Text('৳${(data['grandTotal'] ?? 0.0).toStringAsFixed(2)} • Qty: $quantity'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Status: ${data['status'] ?? 'Pending'}'),
                              Text('Country: ${data['country'] ?? 'N/A'}'),
                              Text('Date: $formattedDate'),
                              if (data['note'] != null)
                                Text('Note: ${data['note']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OrderDetailsScreen(order: doc),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.indigo, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}