// lib/features/marketing/presentation/screens/work_order/qc_report.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class QCReportScreen extends StatelessWidget {
  const QCReportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email;

    if (userEmail == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('QC Report'),
          backgroundColor: _darkBlue,
        ),
        body: const Center(
          child: Text('Please sign in to view QC reports'),
        ),
      );
    }

    final Stream<QuerySnapshot<Map<String, dynamic>>> qcStream =
    FirebaseFirestore.instance
        .collection('qc_reports')
        .where('agentEmail', isEqualTo: userEmail)
        .where('productType', isEqualTo: 'wig')
        .orderBy('qcDate', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('QC Report'),
        backgroundColor: _darkBlue,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: qcStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('No QC reports found.'),
            );
          }

          final List<DataRow> rows = docs.map((doc) {
            final data = doc.data();
            final reportId = doc.id;
            final model = data['productModel'] as String? ?? 'Unknown';
            final ts = data['qcDate'] as Timestamp?;
            final dateStr = ts != null
                ? DateFormat('yyyy-MM-dd').format(ts.toDate())
                : 'N/A';
            final status = data['status'] as String? ?? 'N/A';
            final remarks = data['remarks'] as String? ?? '';

            return DataRow(cells: [
              DataCell(Text(reportId)),
              DataCell(Text(model)),
              DataCell(Text(dateStr)),
              DataCell(Text(status)),
              DataCell(Text(remarks)),
            ]);
          }).toList();

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Report ID')),
                DataColumn(label: Text('Model')),
                DataColumn(label: Text('QC Date')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Remarks')),
              ],
              rows: rows,
            ),
          );
        },
      ),
    );
  }
}
