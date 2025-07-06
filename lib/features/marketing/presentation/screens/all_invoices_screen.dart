import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AllInvoicesScreen extends StatefulWidget {
  const AllInvoicesScreen({super.key});

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
    if (session != null) {
      setState(() {
        agentEmail = session['email'];
      });
    }
  }

  Future<void> _generatePdf(Map<String, dynamic> invoice) async {
    final pdf = pw.Document();
    final items = List<Map<String, dynamic>>.from(invoice['items'] ?? []);
    final shipping = invoice['shippingCost'] ?? 0;
    final tax = invoice['tax'] ?? 0;
    final grandTotal = invoice['grandTotal'] ?? 0;

    pdf.addPage(pw.Page(
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Invoice', style: pw.TextStyle(fontSize: 24)),
            pw.SizedBox(height: 10),
            pw.Text('Customer: ${invoice['customerName'] ?? 'N/A'}'),
            pw.Text('Date: ${DateFormat('yyyy-MM-dd').format((invoice['timestamp'] as Timestamp).toDate())}'),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Model', 'Size', 'Color', 'Qty', 'Unit Price', 'Total'],
              data: items.map((item) {
                final total = item['unitPrice'] * item['quantity'];
                return [
                  item['model'],
                  item['size'],
                  item['color'],
                  item['quantity'].toString(),
                  '৳${item['unitPrice']}',
                  '৳$total',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Shipping: ৳$shipping'),
            pw.Text('Tax: ৳$tax'),
            pw.Text(
              'Grand Total: ৳${grandTotal.toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ],
        );
      },
    ));

    final Uint8List bytes = await pdf.save();

    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/invoice_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(path);
    await file.writeAsBytes(bytes);

    final result = await ImageGallerySaverPlus.saveFile(file.path);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['isSuccess'] == true ? '✅ PDF saved to gallery!' : '❌ Failed to save PDF.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Invoices')),
      body: agentEmail == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('invoices')
            .where('agentEmail', isEqualTo: agentEmail)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No invoices found.'));
          }
          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final invoice = docs[index];
              final date = (invoice['timestamp'] as Timestamp).toDate();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text('৳${invoice['grandTotal'].toStringAsFixed(2)}'),
                  subtitle: Text(
                    'Date: ${DateFormat('yyyy-MM-dd').format(date)}\nCustomer: ${invoice['customerName'] ?? 'N/A'}',
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      Text('Items: ${(invoice['items'] as List).length}'),
                      IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () => _generatePdf(invoice.data()),
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
