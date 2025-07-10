// lib/features/factory/presentation/screens/work_orders_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'work_order_details_screen.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class WorkOrdersScreen extends StatefulWidget {
  const WorkOrdersScreen({Key? key}) : super(key: key);

  @override
  State<WorkOrdersScreen> createState() => _WorkOrdersScreenState();
}

class _WorkOrdersScreenState extends State<WorkOrdersScreen> {
  final _firestore = FirebaseFirestore.instance;

  Future<void> _acceptOrder(String id) async {
    try {
      await _firestore.collection('work_orders').doc(id).update({
        'status': 'Accepted',
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting: $e')),
      );
    }
  }

  Future<void> _rejectOrder(String id) async {
    final recCtl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Work Order'),
        content: TextField(
          controller: recCtl,
          decoration: const InputDecoration(
            labelText: 'Recommendation',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _darkBlue),
            onPressed: () async {
              final rec = recCtl.text.trim();
              if (rec.isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                await _firestore.collection('work_orders').doc(id).update({
                  'status': 'Rejected',
                  'recommendation': rec,
                  'lastUpdated': FieldValue.serverTimestamp(),
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recommendation saved')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error saving recommendation: $e')),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Orders'),
        backgroundColor: _darkBlue,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('work_orders')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No work orders found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final doc  = docs[i];
              final data = doc.data();
              final woNo   = data['workOrderNo']    as String? ?? doc.id;
              final status = data['status']         as String? ?? 'Pending';
              final rec    = data['recommendation'] as String?;

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                margin: const EdgeInsets.symmetric(vertical: 6),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row: WO No. + status
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              woNo,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            status,
                            style: TextStyle(
                              color: status == 'Rejected'
                                  ? Colors.red
                                  : status == 'Accepted'
                                  ? Colors.green
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      // Recommendation (if any)
                      if (rec != null && rec.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Recommendation:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(rec),
                      ],

                      const SizedBox(height: 12),

                      // Action buttons
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: status == 'Accepted'
                            ? [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _darkBlue,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WorkOrderDetailsScreen(orderId: doc.id),
                                ),
                              );
                            },
                            child: const Text('Go to Updates'),
                          ),
                        ]
                            : [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade100,
                              foregroundColor: _darkBlue,
                            ),
                            onPressed: () => _acceptOrder(doc.id),
                            child: const Text('Accept'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade100,
                              foregroundColor: _darkBlue,
                            ),
                            onPressed: () => _rejectOrder(doc.id),
                            child: const Text('Reject'),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WorkOrderDetailsScreen(orderId: doc.id),
                                ),
                              );
                            },
                            child: const Text('Details'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
