import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class BalanceUpdateScreen extends StatefulWidget {
  const BalanceUpdateScreen({super.key});

  @override
  State<BalanceUpdateScreen> createState() => _BalanceUpdateScreenState();
}

class _BalanceUpdateScreenState extends State<BalanceUpdateScreen> {
  String _updateType = 'Add';
  String _accountType = 'Cash';
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Balance Update', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: generatePdfReport,
            tooltip: 'Export Logs to PDF',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _balanceCard(),
            const SizedBox(height: 20),
            _buildDropdown('Update Type', ['Add', 'Subtract'], _updateType, (value) {
              setState(() => _updateType = value);
            }),
            const SizedBox(height: 16),
            _buildDropdown('Account Type', ['Cash', 'Bank', 'Wallet'], _accountType, (value) {
              setState(() => _accountType = value);
            }),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(Icons.currency_exchange),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note / Reason',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Date:', style: TextStyle(fontWeight: FontWeight.w600)),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today, color: Colors.indigo),
                  label: Text(
                    DateFormat('yyyy-MM-dd').format(_selectedDate),
                    style: const TextStyle(color: Colors.indigo),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Submit Update'),
              onPressed: _submitUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Current Balance', style: TextStyle(color: Colors.white70)),
          SizedBox(height: 8),
          Text(
            '৳ 5,00,000',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> options, String currentValue, void Function(String) onChanged) {
    return DropdownButtonFormField<String>(
      value: currentValue,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: options
          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  Future<void> _submitUpdate() async {
    final amount = double.tryParse(_amountController.text.trim());
    final note = _noteController.text.trim();
    final accountKey = _accountType.toLowerCase();

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }

    final logData = {
      'amount': amount,
      'type': _updateType,
      'account': _accountType,
      'note': note,
      'date': _selectedDate,
      'updatedBy': 'admin@email.com', // replace with actual auth
    };

    final accountRef = FirebaseFirestore.instance.collection('accounts').doc('main');
    final logRef = FirebaseFirestore.instance.collection('balance_logs');

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(accountRef);
        double currentBalance = snapshot.data()?[accountKey]?.toDouble() ?? 0;
        double newBalance = _updateType == 'Add'
            ? currentBalance + amount
            : currentBalance - amount;

        transaction.update(accountRef, {
          accountKey: newBalance,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        transaction.set(logRef.doc(), logData);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Balance updated successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> generatePdfReport() async {
    final logSnapshot = await FirebaseFirestore.instance
        .collection('balance_logs')
        .orderBy('date', descending: true)
        .get();

    final pdf = pw.Document();
    final logs = logSnapshot.docs;

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Balance Logs Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Date', 'Type', 'Amount', 'Account', 'Note'],
            data: logs.map((doc) {
              final data = doc.data();
              return [
                DateFormat('yyyy-MM-dd').format((data['date'] as Timestamp).toDate()),
                data['type'] ?? '',
                '৳ ${data['amount'].toString()}',
                data['account'] ?? '',
                data['note'] ?? '',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            border: pw.TableBorder.all(color: PdfColors.grey),
            cellPadding: const pw.EdgeInsets.all(6),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
