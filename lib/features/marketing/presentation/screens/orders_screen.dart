import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _customerController = TextEditingController();
  final _trackingController = TextEditingController();

  final user = FirebaseAuth.instance.currentUser;

  Future<void> submitOrder() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance.collection('orders').add({
        'agentId': user!.uid,
        'customer': _customerController.text.trim(),
        'description': _descriptionController.text.trim(),
        'status': 'order_placed',
        'tracking': '',
        'timestamp': Timestamp.now(),
      });
      _descriptionController.clear();
      _customerController.clear();
    }
  }

  Future<void> markComplete(String docId) async {
    await FirebaseFirestore.instance.collection('orders').doc(docId).update({
      'status': 'completed',
    });
  }

  Future<void> updateTracking(String docId) async {
    await FirebaseFirestore.instance.collection('orders').doc(docId).update({
      'tracking': _trackingController.text.trim(),
    });
    _trackingController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Work Orders')),
      body: Column(
        children: [
          Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextFormField(
                    controller: _customerController,
                    decoration: const InputDecoration(labelText: 'Customer Name'),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Order Description'),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  ElevatedButton(
                    onPressed: submitOrder,
                    child: const Text('Submit to Factory'),
                  )
                ],
              ),
            ),
          ),
          const Divider(),
          const Text('My Orders', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('agentId', isEqualTo: user!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final orders = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Card(
                      child: ListTile(
                        title: Text(order['description']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Customer: ${order['customer']}'),
                            Text('Status: ${order['status']}'),
                            if (order['status'] == 'sent_to_you')
                              TextButton(
                                onPressed: () => markComplete(order.id),
                                child: const Text('Mark as Completed'),
                              ),
                            if (order['status'] == 'ready_to_ship')
                              Column(
                                children: [
                                  TextField(
                                    controller: _trackingController,
                                    decoration: const InputDecoration(labelText: 'Tracking Number'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => updateTracking(order.id),
                                    child: const Text('Submit Tracking'),
                                  )
                                ],
                              )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}