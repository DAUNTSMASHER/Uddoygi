import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class TaxScreen extends StatefulWidget {
  const TaxScreen({super.key});

  @override
  State<TaxScreen> createState() => _TaxScreenState();
}

class _TaxScreenState extends State<TaxScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _entityNameController = TextEditingController();
  final TextEditingController _incomeController = TextEditingController();

  String _taxType = 'Individual';
  String _companyType = 'Private';
  double? _calculatedTax;

  List<Map<String, dynamic>> _taxHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchTaxHistory();
  }

  void _calculateTax(double amount) {
    double tax = 0;

    if (_taxType == 'Individual') {
      if (amount <= 350000) {
        tax = 0;
      } else if (amount <= 450000) {
        tax = (amount - 350000) * 0.05;
      } else if (amount <= 750000) {
        tax = (450000 - 350000) * 0.05 + (amount - 450000) * 0.10;
      } else if (amount <= 1150000) {
        tax = (450000 - 350000) * 0.05 +
            (750000 - 450000) * 0.10 +
            (amount - 750000) * 0.15;
      } else {
        tax = (450000 - 350000) * 0.05 +
            (750000 - 450000) * 0.10 +
            (1150000 - 750000) * 0.15 +
            (amount - 1150000) * 0.20;
      }
    } else {
      double rate = 0.275;
      if (_companyType == 'Public') rate = 0.225;
      if (_companyType == 'OPC') rate = 0.25;
      tax = amount * rate;
    }

    setState(() {
      _calculatedTax = tax;
    });
  }

  Future<void> _saveTaxToFirebase() async {
    final data = {
      'entity': _entityNameController.text.trim(),
      'type': _taxType,
      'companyType': _taxType == 'Company' ? _companyType : null,
      'income': double.tryParse(_incomeController.text.trim()) ?? 0.0,
      'tax': _calculatedTax,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
    };

    await FirebaseFirestore.instance.collection('taxes').add(data);
    _fetchTaxHistory();
  }

  Future<void> _fetchTaxHistory() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('taxes')
        .orderBy('date', descending: true)
        .get();

    setState(() {
      _taxHistory = snapshot.docs.map((e) => e.data()).toList();
    });
  }

  List<BarChartGroupData> _buildBarChart() {
    Map<String, double> monthlySums = {};

    for (var entry in _taxHistory) {
      final date = DateTime.tryParse(entry['date'] ?? '');
      final month = date != null ? DateFormat('MMM').format(date) : 'Unknown';
      monthlySums[month] = (monthlySums[month] ?? 0) + (entry['tax'] ?? 0.0);
    }

    final months = monthlySums.keys.toList();
    return List.generate(months.length, (index) {
      final month = months[index];
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(toY: monthlySums[month] ?? 0.0, width: 16, color: Colors.indigo)
        ],
      );
    });
  }

  Future<void> _exportToExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Tax'];

    sheet.appendRow(['Entity', 'Type', 'Company Type', 'Income', 'Tax', 'Date']);
    for (var row in _taxHistory) {
      sheet.appendRow([
        row['entity'],
        row['type'],
        row['companyType'] ?? '-',
        row['income'],
        row['tax'],
        row['date'],
      ]);
    }

    final bytes = excel.encode();
    if (bytes != null) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tax_report.xlsx');
      await file.writeAsBytes(bytes, flush: true);
      Share.shareXFiles([XFile(file.path)], text: 'Tax Report');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Management'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportToExcel,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _taxType,
                    items: ['Individual', 'Company']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => _taxType = val!),
                    decoration: const InputDecoration(labelText: 'Tax Type'),
                  ),
                  if (_taxType == 'Company')
                    DropdownButtonFormField<String>(
                      value: _companyType,
                      items: ['Public', 'Private', 'OPC']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) => setState(() => _companyType = val!),
                      decoration: const InputDecoration(labelText: 'Company Type'),
                    ),
                  TextFormField(
                    controller: _entityNameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  TextFormField(
                    controller: _incomeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Annual Income'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      final income = double.tryParse(_incomeController.text.trim());
                      if (income != null) {
                        _calculateTax(income);
                        _saveTaxToFirebase();
                      }
                    },
                    child: const Text('Calculate & Save'),
                  ),
                  if (_calculatedTax != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Calculated Tax: ৳${_calculatedTax!.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, color: Colors.indigo),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text("📊 Monthly Tax Trend", style: TextStyle(fontSize: 16)),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(show: false),
                  barGroups: _buildBarChart(),
                ),
              ),
            ),
            const Divider(),
            const Text("🧾 Tax History", style: TextStyle(fontSize: 16)),
            Expanded(
              child: ListView.builder(
                itemCount: _taxHistory.length,
                itemBuilder: (context, index) {
                  final row = _taxHistory[index];
                  return ListTile(
                    title: Text('${row['entity']} (${row['type']})'),
                    subtitle: Text(
                        '৳${row['tax']} on ৳${row['income']} • ${row['date']} ${row['companyType'] != null ? '• ${row['companyType']}' : ''}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
