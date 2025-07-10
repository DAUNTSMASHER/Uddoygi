// lib/features/factory/presentation/screens/qc_report_details_screen.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class QCReportDetailsScreen extends StatefulWidget {
  /// If null => show *all* QC reports.
  /// Otherwise => only those with this productionId.
  final String? productionId;

  const QCReportDetailsScreen({Key? key, this.productionId}) : super(key: key);

  @override
  State<QCReportDetailsScreen> createState() => _QCReportDetailsScreenState();
}

class _QCReportDetailsScreenState extends State<QCReportDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  DateTime _dailyDate = DateTime.now();
  DateTime _monthDate = DateTime.now();
  int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _pickDailyDate() async {
    final pick = await showDatePicker(
      context: context,
      initialDate: _dailyDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (pick != null) setState(() => _dailyDate = pick);
  }

  Future<void> _pickMonthDate() async {
    final pick = await showDatePicker(
      context: context,
      initialDate: _monthDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now(),
      helpText: 'Select Month',
    );
    if (pick != null) setState(() => _monthDate = pick);
  }

  Future<void> _pickYear() async {
    final pick = await showDatePicker(
      context: context,
      initialDate: DateTime(_year),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Select Year',
      fieldLabelText: 'Year',
    );
    if (pick != null) setState(() => _year = pick.year);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _streamFor(
      DateTime start, DateTime end) {
    final sTs = Timestamp.fromDate(start);
    final eTs = Timestamp.fromDate(end);

    var query = FirebaseFirestore.instance.collection('qc_reports')
        .where('qcDate', isGreaterThanOrEqualTo: sTs)
        .where('qcDate', isLessThanOrEqualTo: eTs)
        .orderBy('qcDate', descending: true);

    if (widget.productionId != null) {
      query = query.where('productionId', isEqualTo: widget.productionId);
    }

    return query.snapshots();
  }

  Future<void> _exportPdf() async {
    DateTime start, end;
    String label;
    if (_tabs.index == 0) {
      start = DateTime(_dailyDate.year, _dailyDate.month, _dailyDate.day);
      end = start.add(const Duration(hours: 23, minutes: 59, seconds: 59));
      label = DateFormat('yyyyMMdd').format(_dailyDate);
    } else if (_tabs.index == 1) {
      start = DateTime(_monthDate.year, _monthDate.month, 1);
      end = DateTime(_monthDate.year, _monthDate.month + 1, 0, 23, 59, 59);
      label = DateFormat('yyyyMM').format(_monthDate);
    } else {
      start = DateTime(_year, 1, 1);
      end = DateTime(_year, 12, 31, 23, 59, 59);
      label = '$_year';
    }

    final snap = await _streamFor(start, end).first;

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) {
          return [
            pw.Center(
              child: pw.Text(
                'QC Report Details',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 12),
            if (widget.productionId != null)
              pw.Text('Production: ${widget.productionId}', style: const pw.TextStyle(fontSize: 12)),
            pw.Text('Period: $label', style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Model', 'Base', 'Colour', 'Curl', 'Density', 'Qty', 'Remarks', 'QC Date', 'Agent'],
              data: snap.docs.map((d) {
                final m = d.data();
                final qcTs = m['qcDate'] as Timestamp?;
                final qcDate = qcTs == null ? '' : DateFormat('yyyy-MM-dd').format(qcTs.toDate());
                return [
                  m['modelName'] ?? '',
                  m['base'] ?? '',
                  m['colour'] ?? '',
                  m['curl'] ?? '',
                  m['density'] ?? '',
                  m['quantity']?.toString() ?? '',
                  m['remarks'] ?? '',
                  qcDate,
                  m['agentEmail'] ?? '',
                ];
              }).toList(),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/qc_$label.pdf');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([XFile(file.path)], text: 'QC Report ($label)');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QC Report Details'),
        backgroundColor: _darkBlue,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Monthly'),
            Tab(text: 'Yearly'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Download PDF',
            onPressed: _exportPdf,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildTab(
            label: DateFormat.yMMMMd().format(_dailyDate),
            onPick: _pickDailyDate,
            start: DateTime(_dailyDate.year, _dailyDate.month, _dailyDate.day),
            end: (d) => DateTime(d.year, d.month, d.day, 23, 59, 59),
          ),
          _buildTab(
            label: DateFormat.yMMMM().format(_monthDate),
            onPick: _pickMonthDate,
            start: DateTime(_monthDate.year, _monthDate.month, 1),
            end: (d) => DateTime(d.year, d.month + 1, 0, 23, 59, 59),
          ),
          _buildTab(
            label: '$_year',
            onPick: _pickYear,
            start: DateTime(_year, 1, 1),
            end: (d) => DateTime(d.year, 12, 31, 23, 59, 59),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required VoidCallback onPick,
    required DateTime start,
    required DateTime Function(DateTime) end,
  }) {
    final endDate = end(start);

    return Column(
      children: [
        ListTile(
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: IconButton(icon: const Icon(Icons.calendar_today), onPressed: onPick),
        ),
        const Divider(),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _streamFor(start, endDate),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No entries'));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data();
                  final qcTs = d['qcDate'] as Timestamp?;
                  final date = qcTs == null ? '—' : DateFormat('yyyy‑MM‑dd').format(qcTs.toDate());
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d['modelName'] ?? '—',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Base: ${d['base'] ?? '—'}'),
                          Text('Colour: ${d['colour'] ?? '—'}'),
                          Text('Curl: ${d['curl'] ?? '—'}'),
                          Text('Density: ${d['density'] ?? '—'}'),
                          Text('Qty: ${d['quantity'] ?? '—'}'),
                          Text('Remarks: ${d['remarks'] ?? '—'}'),
                          Text('On: $date'),
                          Text('By: ${d['agentEmail'] ?? '—'}',
                              style: const TextStyle(fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
