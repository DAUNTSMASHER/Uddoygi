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
  static const _updateTypes = ['Add', 'Subtract'];
  static const _accountTypes = ['Cash', 'Bank', 'Wallet'];

  String _updateType = _updateTypes.first;
  String _accountType = _accountTypes.first;

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
            _buildDropdown('Update Type', _updateTypes, _updateType, (val) => setState(() => _updateType = val)),
            const SizedBox(height: 16),
            _buildDropdown('Account Type', _accountTypes, _accountType, (val) => setState(() => _accountType = val)),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _amountController,
              label: 'Amount',
              icon: Icons.currency_exchange,
              inputType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _noteController,
              label: 'Note / Reason',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildDatePicker(),
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        decoration: InputDecoration(labelText:
