// lib/features/factory/presentation/factory/purchase_order_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({Key? key}) : super(key: key);

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final _poRef = FirebaseFirestore.instance.collection('purchase_orders');

  Future<void> _acceptPO(String docId) async {
    await _poRef.doc(docId).update({
      'status': 'accepted',
      'acceptedAt': Timestamp.now(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ PO accepted')),
    );
  }

  Future<void> _rejectPO(String docId) async {
    String? recommendation;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Purchase Order'),
        content: TextFormField(
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Recommendation'),
          onChanged: (v) => recommendation = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if ((recommendation ?? '').trim().isEmpty) return;
              Navigator.of(ctx).pop();
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if ((recommendation ?? '').trim().isEmpty) return;

    await _poRef.doc(docId).update({
      'status': 'rejected',
      'recommendation': recommendation,
      'rejectedAt': Timestamp.now(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('❌ PO rejected')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders'),
        backgroundColor: _darkBlue,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _poRef.orderBy('timestamp', descending: true).snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No purchase orders found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final data = doc.data();
              final poNo = data['poNo'] as String? ?? doc.id;
              final supplier = data['supplierName'] as String? ?? '';
              final submittedBy = data['submittedBy'] as String? ?? '';
              final ts = data['expectedDate'] as Timestamp?;
              final expected = ts != null
                  ? DateFormat('yyyy-MM-dd').format(ts.toDate())
                  : '—';
              final items = (data['items'] as List?) ?? [];
              final status = data['status'] as String? ?? 'pending';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PO #: $poNo',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Supplier: $supplier'),
                      Text('Submitted by: $submittedBy'),
                      Text('Expected: $expected'),
                      Text('Items: ${items.length}'),
                      const SizedBox(height: 8),
                      if (status != 'accepted' && status != 'rejected')
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Accept'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green),
                              onPressed: () => _acceptPO(doc.id),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Reject'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                              onPressed: () => _rejectPO(doc.id),
                            ),
                          ],
                        )
                      else
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Status: ${status.toUpperCase()}',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: status == 'accepted'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
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
