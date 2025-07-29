// lib/features/factory/presentation/screens/address_validation_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _darkBlue = Color(0xFF0D47A1);
const String _addressStage = 'Address validation';

class AddressValidationPage extends StatefulWidget {
  const AddressValidationPage({Key? key}) : super(key: key);

  @override
  State<AddressValidationPage> createState() => _AddressValidationPageState();
}

class _AddressValidationPageState extends State<AddressValidationPage> {
  Stream<QuerySnapshot<Map<String, dynamic>>> get _ordersToValidateStream =>
      FirebaseFirestore.instance
          .collection('work_orders')
          .where('currentStage', isEqualTo: 'Submit to the Head office')
          .orderBy('lastUpdated', descending: true)
          .snapshots();

  Future<void> _validateAddress(
      String orderDocId,
      String workOrderNo,
      String? invoiceId,
      ) async {
    final now = Timestamp.now();
    final batch = FirebaseFirestore.instance.batch();

    // 1) record in tracking history
    final trackingRef =
    FirebaseFirestore.instance.collection('work_order_tracking').doc();
    batch.set(trackingRef, {
      'workOrderNo': workOrderNo,
      'stage': _addressStage,
      'notes': '',
      'assignedTo': '',
      'timeLimit': now,
      'createdAt': now,
      'lastUpdated': now,
    });

    // 2) update the work_orders doc
    final orderRef =
    FirebaseFirestore.instance.collection('work_orders').doc(orderDocId);
    batch.update(orderRef, {
      'currentStage': _addressStage,
      'lastUpdated': now,
    });

    await batch.commit();

    // 3) fetch customer email via invoice → customer
    String? customerEmail;
    if (invoiceId != null) {
      final invSnap = await FirebaseFirestore.instance
          .collection('invoices')
          .doc(invoiceId)
          .get();
      final custId = invSnap.data()?['customerId'] as String?;
      if (custId != null) {
        final custSnap = await FirebaseFirestore.instance
            .collection('customers')
            .doc(custId)
            .get();
        customerEmail = custSnap.data()?['email'] as String?;
      }
    }

    // 4) launch email client
    if (customerEmail != null && customerEmail.isNotEmpty) {
      final emailUri = Uri(
        scheme: 'mailto',
        path: customerEmail,
        queryParameters: {
          'subject': 'Please confirm your address for order $workOrderNo',
          'body':
          'Dear Customer,\n\nPlease verify your shipping address for work order $workOrderNo by replying to this email.\n\nThank you.',
        },
      );
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email client.')),
        );
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address validation requested.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Address Validation'),
        backgroundColor: _darkBlue,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _ordersToValidateStream,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('No orders awaiting Head Office submission.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final data = doc.data();
              final no = data['workOrderNo'] as String? ?? '—';
              final invoiceId = data['invoiceId'] as String?;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text('Order $no',
                      style: const TextStyle(
                          fontSize: 16, color: _darkBlue)),
                  subtitle: Text('Stage: Submit to the Head office',
                      style: const TextStyle(fontSize: 12)),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _darkBlue),
                    onPressed: () =>
                        _validateAddress(doc.id, no, invoiceId),
                    child: const Text('Validate Address'),
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
