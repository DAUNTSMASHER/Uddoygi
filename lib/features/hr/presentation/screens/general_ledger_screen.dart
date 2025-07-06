import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class GeneralLedgerScreen extends StatefulWidget {
  const GeneralLedgerScreen({super.key});

  @override
  State<GeneralLedgerScreen> createState() => _GeneralLedgerScreenState();
}

class _GeneralLedgerScreenState extends State<GeneralLedgerScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: const Text('General Ledger', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _exportPdf)
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(_startDate == null
                        ? 'Start Date'
                        : DateFormat('yyyy-MM-dd').format(_startDate!)),
                    onPressed: () => _pickDate(isStart: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(_endDate == null
                        ? 'End Date'
                        : DateFormat('yyyy-MM-dd').format(_endDate!)),
                    onPressed: () => _pickDate(isStart: false),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    _startDate = null;
                    _endDate = null;
                  }),
                )
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ledger')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final grouped = <String, List<Map<String, dynamic>>>{};

                for (final doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final date = DateTime.tryParse(data['date'] ?? '');
                  if (_startDate != null && (date == null || date.isBefore(_startDate!))) continue;
                  if (_endDate != null && (date == null || date.isAfter(_endDate!))) continue;

                  final account = data['account'] ?? 'Unknown';
                  grouped.putIfAbsent(account, () => []).add(data);
                }

                if (grouped.isEmpty) {
                  return const Center(child: Text('No ledger entries found.'));
                }

                return ListView(
                  children: grouped.entries.map((entry) {
                    final account = entry.key;
                    final records = entry.value;

                    final debitTotal = records.fold<num>(0, (sum, item) => sum + (item['debit'] ?? 0));
                    final creditTotal = records.fold<num>(0, (sum, item) => sum + (item['credit'] ?? 0));

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(account, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Debit: \$${debitTotal.toStringAsFixed(2)} • Credit: \$${creditTotal.toStringAsFixed(2)}'),
                        children: records.map((entry) {
                          return ListTile(
                            dense: true,
                            title: Text(entry['description'] ?? '-'),
                            subtitle: Text('Date: ${entry['date'] ?? ''}'),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Debit: \$${entry['debit'] ?? 0}'),
                                Text('Credit: \$${entry['credit'] ?? 0}'),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _exportPdf() async {
    final query = await FirebaseFirestore.instance.collection('ledger').orderBy('date').get();
    final pdf = pw.Document();

    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final doc in query.docs) {
      final data = doc.data();
      final date = DateTime.tryParse(data['date'] ?? '');
      if (_startDate != null && (date == null || date.isBefore(_startDate!))) continue;
      if (_endDate != null && (date == null || date.isAfter(_endDate!))) continue;

      final account = data['account'] ?? 'Unknown';
      grouped.putIfAbsent(account, () => []).add(data);
    }

    pdf.addPage(pw.MultiPage(
      build: (context) => [
        pw.Text('General Ledger', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        for (final entry in grouped.entries) ...[
          pw.Text('Account: ${entry.key}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Table.fromTextArray(
            headers: ['Date', 'Description', 'Debit', 'Credit'],
            data: entry.value.map((e) {
              return [
                e['date'] ?? '',
                e['description'] ?? '',
                e['debit'].toString(),
                e['credit'].toString()
              ];
            }).toList(),
            border: pw.TableBorder.all(color: PdfColors.grey),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
        ]
      ],
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
