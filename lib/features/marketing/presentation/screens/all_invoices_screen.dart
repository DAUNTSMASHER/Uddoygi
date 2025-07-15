// lib/features/marketing/presentation/screens/all_invoices_screen.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

const Color _darkBlue = Color(0xFF0D47A1);  // ← add this

class AllInvoicesScreen extends StatefulWidget {
  const AllInvoicesScreen({Key? key}) : super(key: key);

  @override
  State<AllInvoicesScreen> createState() => _AllInvoicesScreenState();
}

class _AllInvoicesScreenState extends State<AllInvoicesScreen> {
  String? agentEmail;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    final session = await LocalStorageService.getSession();
    if (session != null && mounted) {
      setState(() {
        agentEmail = session['email'] as String?;
      });
    }
  }

  Future<void> _generatePdf(Map<String, dynamic> inv) async {
    final pdf = pw.Document();

    final items      = List<Map<String, dynamic>>.from(inv['items'] ?? []);
    final shipping   = inv['shippingCost'] ?? 0;
    final tax        = inv['tax'] ?? 0;
    final grandTotal = inv['grandTotal'] ?? 0;
    final date       = (inv['timestamp'] as Timestamp).toDate();
    final customer   = inv['customerName'] ?? 'N/A';
    final invoiceNo  = inv['invoiceNo'] ?? '';

    pdf.addPage(pw.Page(
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Invoice #$invoiceNo', style: pw.TextStyle(fontSize: 24)),
          pw.SizedBox(height: 8),
          pw.Text('Customer: $customer'),
          pw.Text('Date: ${DateFormat('yyyy-MM-dd').format(date)}'),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Model','Colour','Size','Qty','Unit Price','Total'],
            data: items.map((item) {
              final total = (item['total'] as num).toDouble();
              return [
                item['model'] ?? '',
                item['colour'] ?? '',
                item['size'] ?? '',
                (item['qty'] as num).toString(),
                '৳${(item['unit_price'] as num).toStringAsFixed(2)}',
                '৳${total.toStringAsFixed(2)}',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Shipping: ৳${shipping.toStringAsFixed(2)}'),
          pw.Text('Tax: ৳${tax.toStringAsFixed(2)}'),
          pw.SizedBox(height: 6),
          pw.Text(
            'Grand Total: ৳${(grandTotal as num).toStringAsFixed(2)}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    ));

    final bytes = await pdf.save();
    final dir   = await getTemporaryDirectory();
    final path  = '${dir.path}/invoice_$invoiceNo.pdf';
    final file  = File(path)..writeAsBytesSync(bytes);

    final result = await ImageGallerySaverPlus.saveFile(path);
    final success = result['isSuccess'] == true;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '✅ PDF saved to gallery!' : '❌ Failed to save PDF')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (agentEmail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('All Invoices')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('All Invoices')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('invoices')
            .where('agentEmail', isEqualTo: agentEmail)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No invoices found.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc     = docs[i];
              final inv      = doc.data();
              final invoiceNo= inv['invoiceNo'] as String? ?? doc.id;
              final total    = (inv['grandTotal'] as num).toDouble();
              final date     = (inv['timestamp'] as Timestamp).toDate();
              final customer = inv['customerName'] as String? ?? 'N/A';
              final itemCount= (inv['items'] as List).length;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long, color: _darkBlue),
                  title: Text('Invoice #$invoiceNo'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total: ৳${total.toStringAsFixed(2)}'),
                      Text('Date: ${DateFormat('yyyy-MM-dd').format(date)}'),
                      Text('Customer: $customer'),
                      Text('Items: $itemCount'),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.download, color: _darkBlue),
                    onPressed: () => _generatePdf(inv),
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