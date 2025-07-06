import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/local_storage_service.dart';

class OrderProgressScreen extends StatefulWidget {
  const OrderProgressScreen({super.key});

  @override
  State<OrderProgressScreen> createState() => _OrderProgressScreenState();
}

class _OrderProgressScreenState extends State<OrderProgressScreen> {
  Map<String, dynamic>? session;
  List<DocumentSnapshot> userOrders = [];

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final userSession = await LocalStorageService.getSession();
    if (userSession != null) {
      setState(() {
        session = userSession;
      });
      _fetchUserOrders();
    }
  }

  Future<void> _fetchUserOrders() async {
    if (session == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('invoices')
        .where('agentEmail', isEqualTo: session!['email'])
        .orderBy('timestamp', descending: true)
        .get();

    setState(() {
      userOrders = snapshot.docs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Order Progress'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: userOrders.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
          itemCount: userOrders.length,
          itemBuilder: (context, index) {
            final order = userOrders[index];
            final orderData = order.data() as Map<String, dynamic>;
            final date = (orderData['timestamp'] as Timestamp).toDate();
            final status = orderData['status'] ?? 'Pending';

            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.timeline, color: Colors.deepPurple),
                title: Text('Order: ${orderData['customerName'] ?? 'Unknown'}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: $status'),
                    Text('Date: ${DateFormat('yyyy-MM-dd').format(date)}')
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailsScreen(order: order),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class OrderDetailsScreen extends StatelessWidget {
  final DocumentSnapshot order;
  const OrderDetailsScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final orderData = order.data() as Map<String, dynamic>;
    final List items = orderData['items'] ?? [];
    final date = (orderData['timestamp'] as Timestamp).toDate();
    final status = orderData['status'] ?? 'Unknown';
    final country = orderData['country'] ?? 'Not specified';
    final note = orderData['note'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildHeaderRow('Order Date', DateFormat('yyyy-MM-dd').format(date)),
            _buildHeaderRow('Customer', orderData['customerName'] ?? 'N/A'),
            _buildHeaderRow('Country', country),
            _buildHeaderRow('Status', status, color: Colors.indigo),
            _buildHeaderRow('Note', note),
            const Divider(height: 32, color: Colors.deepPurple),
            const Text('Order Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
            const SizedBox(height: 8),
            ...items.map((item) => Card(
              color: Colors.deepPurple.shade50,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text('${item['model']} - ${item['color']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Size: ${item['size']} | Qty: ${item['qty']}'),
                trailing: Text('৳${item['total'].toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            )),
            const Divider(height: 32, color: Colors.deepPurple),
            _buildHeaderRow('Shipping Cost', '৳${orderData['shippingCost'] ?? 0}'),
            _buildHeaderRow('Tax', '৳${orderData['tax'] ?? 0}'),
            _buildHeaderRow(
              'Grand Total',
              '৳${orderData['grandTotal']?.toStringAsFixed(2) ?? '0.00'}',
              isBold: true,
              color: Colors.green.shade700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? Colors.black87,
              ),
            ),
          )
        ],
      ),
    );
  }
}
