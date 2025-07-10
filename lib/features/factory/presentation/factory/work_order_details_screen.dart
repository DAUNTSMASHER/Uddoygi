// lib/features/factory/presentation/screens/work_order_details_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class WorkOrderDetailsScreen extends StatefulWidget {
  final String orderId;
  const WorkOrderDetailsScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<WorkOrderDetailsScreen> createState() => _WorkOrderDetailsScreenState();
}

class _WorkOrderDetailsScreenState extends State<WorkOrderDetailsScreen> {
  final _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _workOrder;
  Map<String, dynamic>? _invoice;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchWorkOrderAndInvoice();
  }

  Future<void> _fetchWorkOrderAndInvoice() async {
    // 1) load work order
    final woSnap = await _firestore
        .collection('work_orders')
        .doc(widget.orderId)
        .get();
    final woData = woSnap.data();
    if (woData == null) return;

    // 2) load linked invoice (if any)
    Map<String, dynamic>? invData;
    final invId = woData['invoiceId'] as String?;
    if (invId != null) {
      final invSnap = await _firestore.collection('invoices').doc(invId).get();
      invData = invSnap.data();
    }

    setState(() {
      _workOrder = woData;
      _invoice = invData;
      _loading = false;
    });
  }

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final doc = pw.Document();
    final items = List<Map<String, dynamic>>.from(_workOrder!['items'] ?? []);
    final woNo = _workOrder!['workOrderNo'] as String? ?? widget.orderId;
    final finalTs = _workOrder!['finalDate'] as Timestamp;
    final finalDate = finalTs.toDate();

    final invNo = _invoice?['invoiceNo'] as String? ?? '';
    final cust  = _invoice?['customerName'] as String? ?? '';
    // invoice date field was stored as a Timestamp via cloud_firestore
    DateTime invDate = DateTime.now();
    if (_invoice?['date'] != null) {
      invDate = (_invoice!['date'] as Timestamp).toDate();
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        build: (ctx) => [
          pw.Header(level: 0, child: pw.Text('Work Order', style: pw.TextStyle(fontSize: 24))),
          pw.Text('WO No: $woNo', style: pw.TextStyle(fontSize: 14)),
          pw.Text('Invoice: $invNo'),
          pw.Text('Customer: $cust'),
          pw.Text('Invoice Date: ${DateFormat.yMMMMd().format(invDate)}'),
          pw.Text('Final Delivery: ${DateFormat.yMMMMd().format(finalDate)}'),
          pw.SizedBox(height: 12),
          pw.Text('Items', style: pw.TextStyle(fontSize: 18)),
          pw.Table.fromTextArray(
            context: ctx,
            headers: ['Model', 'Colour', 'Size', 'Qty'],
            data: items.map((it) => [
              it['model']  ?? '',
              it['colour'] ?? '',
              it['size']   ?? '',
              (it['qty'] ?? '').toString(),
            ]).toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Special Instructions:', style: pw.TextStyle(fontSize: 16)),
          pw.Text(_workOrder!['instructions'] as String? ?? ''),
        ],
      ),
    );

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details'), backgroundColor: _darkBlue),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: _darkBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: 'Download PDF',
            onPressed: () async {
              final bytes = await _buildPdf(PdfPageFormat.a4);
              await Printing.sharePdf(
                bytes: bytes,
                filename: 'workorder_${widget.orderId}.pdf',
              );
            },
          ),
        ],
      ),
      // PdfPreview gives a scrollable, zoomable PDF “reader” experience
      body: PdfPreview(
        build: (format) => _buildPdf(format),
        initialPageFormat: PdfPageFormat.a4,
        allowPrinting: false,
        allowSharing: false,
      ),
    );
  }
}
