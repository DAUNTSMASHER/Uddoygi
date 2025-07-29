// lib/features/marketing/presentation/screens/tax_screen.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'tax_calculation.dart';

const Color _darkBlue = Color(0xFF0B3552);
const Color _white    = Colors.white;

class TaxScreen extends StatefulWidget {
  const TaxScreen({Key? key}) : super(key: key);

  @override
  State<TaxScreen> createState() => _TaxScreenState();
}

class _TaxScreenState extends State<TaxScreen> {
  final _formKey               = GlobalKey<FormState>();
  final _entityNameController  = TextEditingController();
  final _incomeController      = TextEditingController();
  String _taxType              = 'Individual';
  String _companyType          = 'Private';
  double? _calculatedTax;
  List<Map<String, dynamic>> _taxHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchTaxHistory();
  }

  @override
  void dispose() {
    _entityNameController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  void _calculateTax(double amount) {
    double tax = 0;
    if (_taxType == 'Individual') {
      if (amount > 350000) {
        tax += (amount.clamp(350001, 450000) - 350000) * 0.05;
      }
      if (amount > 450000) {
        tax += (amount.clamp(450001, 750000) - 450000) * 0.10;
      }
      if (amount > 750000) {
        tax += (amount.clamp(750001, 1150000) - 750000) * 0.15;
      }
      if (amount > 1150000) {
        tax += (amount - 1150000) * 0.20;
      }
    } else {
      double rate = 0.275;
      if (_companyType == 'Public') rate = 0.225;
      if (_companyType == 'OPC')    rate = 0.25;
      tax = amount * rate;
    }
    setState(() => _calculatedTax = tax);
  }

  Future<void> _saveTaxToFirebase() async {
    final data = {
      'entity':       _entityNameController.text.trim(),
      'type':         _taxType,
      'companyType':  _taxType == 'Company' ? _companyType : null,
      'income':       double.tryParse(_incomeController.text.trim()) ?? 0.0,
      'tax':          _calculatedTax,
      'date':         DateFormat('yyyy-MM-dd').format(DateTime.now()),
    };
    await FirebaseFirestore.instance.collection('taxes').add(data);
    _fetchTaxHistory();
  }

  Future<void> _fetchTaxHistory() async {
    final snap = await FirebaseFirestore.instance
        .collection('taxes')
        .orderBy('date', descending: true)
        .get();
    setState(() => _taxHistory = snap.docs.map((d) => d.data()).toList());
  }

  List<BarChartGroupData> _buildBarChart() {
    final sums = <String,double>{};
    for (var row in _taxHistory) {
      final dt = DateTime.tryParse(row['date'] ?? '') ?? DateTime.now();
      final m  = DateFormat('MMM').format(dt);
      sums[m] = (sums[m] ?? 0) + (row['tax'] ?? 0.0);
    }
    final months = sums.keys.toList();
    return List.generate(months.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(toY: sums[months[i]]!, color: _darkBlue, width: 16),
        ],
      );
    });
  }

  Future<void> _exportToExcel() async {
    final ex    = Excel.createExcel();
    final sheet = ex['Tax'];
    sheet.appendRow(['Entity','Type','Company','Income','Tax','Date']);
    for (var r in _taxHistory) {
      sheet.appendRow([
        r['entity'],
        r['type'],
        r['companyType'] ?? '-',
        r['income'],
        r['tax'],
        r['date'],
      ]);
    }
    final bytes = ex.encode();
    if (bytes == null) return;
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/tax_report.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    Share.shareXFiles([XFile(file.path)], text: 'Tax Report');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _white,
      appBar: AppBar(
        backgroundColor: _darkBlue,
        title: const Text('Tax Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: _exportToExcel,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── NEW BUTTON ────────────────────────────────────────
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _darkBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TaxCalculationPage(),
                  ),
                );
              },
              child: const Text(
                'Calculate your tax in detail',
                style: TextStyle(color: _white, fontSize: 16),
              ),
            ),

            const SizedBox(height: 24),

            // ── Input Form ────────────────────────────────────
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _taxType,
                        items: const [
                          DropdownMenuItem(
                              value: 'Individual', child: Text('Individual')),
                          DropdownMenuItem(
                              value: 'Company', child: Text('Company')),
                        ],
                        decoration:
                        const InputDecoration(labelText: 'Tax Type'),
                        onChanged: (v) => setState(() => _taxType = v!),
                      ),
                      if (_taxType == 'Company')
                        DropdownButtonFormField<String>(
                          value: _companyType,
                          items: const [
                            DropdownMenuItem(
                                value: 'Public', child: Text('Public')),
                            DropdownMenuItem(
                                value: 'Private', child: Text('Private')),
                            DropdownMenuItem(value: 'OPC', child: Text('OPC')),
                          ],
                          decoration: const InputDecoration(
                              labelText: 'Company Category'),
                          onChanged: (v) => setState(() => _companyType = v!),
                        ),
                      TextFormField(
                        controller: _entityNameController,
                        decoration:
                        const InputDecoration(labelText: 'Entity Name'),
                      ),
                      TextFormField(
                        controller: _incomeController,
                        decoration:
                        const InputDecoration(labelText: 'Annual Income'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _darkBlue,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        child: const Text('Calculate & Save',
                            style: TextStyle(color: _white)),
                        onPressed: () {
                          final inc = double.tryParse(
                              _incomeController.text.trim());
                          if (inc != null) {
                            _calculateTax(inc);
                            _saveTaxToFirebase();
                          }
                        },
                      ),
                      if (_calculatedTax != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Tax: ৳${_calculatedTax!.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _darkBlue),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Chart ───────────────────────────────────────
            const Text('Monthly Tax Trend', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
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

            const SizedBox(height: 24),

            // ── History ────────────────────────────────────
            const Text('Tax History', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            ..._taxHistory.map((row) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text('${row['entity']} (${row['type']})'),
                  subtitle: Text(
                    '৳${row['tax']} on ৳${row['income']} • ${row['date']}'
                        '${row['companyType'] != null ? ' • ${row['companyType']}' : ''}',
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}