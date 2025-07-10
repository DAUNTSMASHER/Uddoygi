// lib/features/marketing/presentation/screens/incoming_products.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class IncomingProductsScreen extends StatelessWidget {
  const IncomingProductsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming Products'),
        backgroundColor: _darkBlue,
      ),
      body: userEmail == null
          ? const Center(
        child: Text('Please sign in to view incoming products'),
      )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('work_orders')
            .where('invoiceData.agentEmail', isEqualTo: userEmail)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('No incoming products found.'),
            );
          }

          // Build DataRow list
          final rows = <DataRow>[];
          for (final doc in docs) {
            final data = doc.data();
            final woNo = data['workOrderNo'] as String? ?? doc.id;
            final invoiceNo =
                (data['invoiceData']?['invoiceNo'] as String?) ?? '';
            final deliveryDays =
            (data['deliveryDays']?.toString() ?? '');
            final finalTs = data['finalDate'] as Timestamp?;
            final finalDate = finalTs != null
                ? finalTs.toDate()
                : DateTime.fromMillisecondsSinceEpoch(0);
            final instructions = data['instructions'] as String? ?? '';

            final items = List<Map<String, dynamic>>.from(
              data['items'] ?? [],
            );

            for (final item in items) {
              rows.add(
                DataRow(cells: [
                  DataCell(Text(woNo)),
                  DataCell(Text(invoiceNo)),
                  DataCell(Text(item['model'] ?? '')),
                  DataCell(Text(item['colour'] ?? '')),
                  DataCell(Text(item['size'] ?? '')),
                  DataCell(Text('${item['qty'] ?? ''}')),
                  DataCell(Text(deliveryDays)),
                  DataCell(
                    Text(DateFormat('yyyy-MM-dd').format(finalDate)),
                  ),
                  DataCell(Text(instructions)),
                ]),
              );
            }
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('WO No')),
                DataColumn(label: Text('Invoice No')),
                DataColumn(label: Text('Model')),
                DataColumn(label: Text('Colour')),
                DataColumn(label: Text('Size')),
                DataColumn(label: Text('Qty')),
                DataColumn(label: Text('Delivery Days')),
                DataColumn(label: Text('Final Date')),
                DataColumn(label: Text('Instructions')),
              ],
              rows: rows,
            ),
          );
        },
      ),
    );
  }
}
