// lib/features/marketing/presentation/screens/work_order_updates_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class WorkOrderUpdatesScreen extends StatefulWidget {
  const WorkOrderUpdatesScreen({Key? key}) : super(key: key);

  @override
  State<WorkOrderUpdatesScreen> createState() => _WorkOrderUpdatesScreenState();
}

class _WorkOrderUpdatesScreenState extends State<WorkOrderUpdatesScreen> {
  String _cid = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _updatesStream(String userEmail) {
    if (_cid.isEmpty) return const Stream.empty();
    return DB.colSync(_cid, C.workOrders)
        .where('agentEmail', isEqualTo: userEmail)
        .orderBy('lastUpdated', descending: true)
        .snapshots();
  }

  Future<void> _acknowledge(BuildContext context, String docId) async {
    try {
      await (await DB.col(C.workOrders))
          .doc(docId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work order acknowledged and removed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error acknowledging: $e')),
      );
    }
  }

  void _trackOrder(String woNo) {
    debugPrint('Track $woNo');
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your work orders')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Order Updates', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        backgroundColor: _darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _updatesStream(userEmail),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No work orders to show.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final doc  = docs[i];
              final data = doc.data();

              final woNo   = data['workOrderNo'] as String? ?? doc.id;
              final status = (data['status'] as String?)?.trim().isNotEmpty == true
                  ? data['status']!
                  : 'Pending';
              final rec    = data['recommendation'] as String? ?? '';
              final ts     = (data['lastUpdated'] as Timestamp?)
                  ?? (data['timestamp']   as Timestamp?);
              final updated = ts != null
                  ? DateFormat.yMMMd().add_jm().format(ts.toDate())
                  : 'Unknown';

              // Badge styling by status
              Color badgeColor;
              Color badgeTextColor;
              switch (status) {
                case 'Accepted':
                  badgeColor     = Colors.green.shade100;
                  badgeTextColor = Colors.green.shade700;
                  break;
                case 'Rejected':
                  badgeColor     = Colors.red.shade100;
                  badgeTextColor = Colors.red.shade700;
                  break;
                default:
                  badgeColor     = Colors.orange.shade100;
                  badgeTextColor = Colors.orange.shade700;
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row: WO# + status badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Work Order: $woNo',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _darkBlue,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: badgeTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Body varies by status
                      if (status == 'Accepted') ...[
                        const Text(
                          'The factory has started working on your order.',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Updated: $updated',
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const Divider(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _darkBlue,
                            ),
                            onPressed: () => _trackOrder(woNo),
                            child: const Text('Track'),
                          ),
                        ),
                      ] else if (status == 'Rejected') ...[
                        Text(
                          'Recommendation:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _darkBlue,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          rec.isNotEmpty ? rec : '-',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Updated: $updated',
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const Divider(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _darkBlue,
                            ),
                            onPressed: () => _acknowledge(context, doc.id),
                            child: const Text('Acknowledge'),
                          ),
                        ),
                      ] else ...[
                        // Pending
                        const Text(
                          'Your work order is pending. You will be notified once the factory responds.',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Submitted: $updated',
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
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
