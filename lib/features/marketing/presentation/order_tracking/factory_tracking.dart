// lib/features/marketing/presentation/order_tracking/factory_tracking.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color _darkBlue = Color(0xFF0D47A1);

/// Shows all factory updates for your own work‑orders,
/// stopping before "Submitted to the Head office".
class FactoryTrackingPage extends StatelessWidget {
  const FactoryTrackingPage({Key? key}) : super(key: key);

  Stream<QuerySnapshot<Map<String, dynamic>>> get _myOrdersStream {
    final email = FirebaseAuth.instance.currentUser?.email;
    return FirebaseFirestore.instance
        .collection('work_orders')
        .where('agentEmail', isEqualTo: email)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _updatesFor(String woNo) {
    return FirebaseFirestore.instance
        .collection('work_order_tracking')
    // only stages *before* "Submitted to the Head office"
        .where('workOrderNo', isEqualTo: woNo)
        .where('stage', isNotEqualTo: 'Submitted to the Head office')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Factory Tracker'),
        backgroundColor: _darkBlue,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _myOrdersStream,
        builder: (ctx, orderSnap) {
          if (orderSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = orderSnap.data?.docs ?? [];
          if (orders.isEmpty) {
            return const Center(child: Text('No work‑orders found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (ctx, i) {
              final order = orders[i].data();
              final woNo  = order['workOrderNo'] as String? ?? '—';

              return ExpansionTile(
                title: Text(
                  'WO# $woNo',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _darkBlue,
                  ),
                ),
                children: [
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _updatesFor(woNo),
                    builder: (ctx, updSnap) {
                      if (updSnap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final updates = updSnap.data?.docs ?? [];
                      if (updates.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('No factory updates yet.'),
                        );
                      }
                      return Column(
                        children: updates.map((d) {
                          final data   = d.data();
                          final stage  = data['stage']  as String? ?? '—';
                          final status = (data['status'] as String? ?? '')
                              .toUpperCase();
                          final ts      = (data['lastUpdated'] as Timestamp?)
                              ?.toDate() ??
                              DateTime.now();
                          final timeStr =
                          TimeOfDay.fromDateTime(ts).format(context);

                          return ListTile(
                            dense: true,
                            title: Text(stage),
                            subtitle: Text(
                              '$status • $timeStr',
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  )
                ],
              );
            },
          );
        },
      ),
    );
  }
}
