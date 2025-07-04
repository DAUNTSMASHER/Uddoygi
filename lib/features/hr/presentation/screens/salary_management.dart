import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SalaryManagementScreen extends StatefulWidget {
  const SalaryManagementScreen({super.key});

  @override
  State<SalaryManagementScreen> createState() => _SalaryManagementScreenState();
}

class _SalaryManagementScreenState extends State<SalaryManagementScreen> {
  String? _selectedEmployee;
  DateTime? _selectedMonth;
  final _salaryController = TextEditingController();
  final _bonusController = TextEditingController();
  final _deductionController = TextEditingController();

  Future<void> _exportPDF(List<QueryDocumentSnapshot> salaries) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          children: [
            pw.Text('Salary Report', style: pw.TextStyle(fontSize: 20)),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Name', 'Month', 'Base', 'Bonus', 'Deduction', 'Net'],
              data: salaries.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final net = (d['base'] ?? 0) + (d['bonus'] ?? 0) - (d['deduction'] ?? 0);
                return [
                  d['employeeName'] ?? '',
                  d['month'] ?? '',
                  d['base'].toString(),
                  d['bonus'].toString(),
                  d['deduction'].toString(),
                  net.toString()
                ];
              }).toList(),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  void _showSalaryForm({DocumentSnapshot? doc}) {
    final isEdit = doc != null;
    _salaryController.text = doc?['base']?.toString() ?? '';
    _bonusController.text = doc?['bonus']?.toString() ?? '';
    _deductionController.text = doc?['deduction']?.toString() ?? '';
    final employeeName = doc?['employeeName'] ?? _selectedEmployee ?? '';
    final month = doc?['month'] ?? DateFormat('yyyy-MM').format(DateTime.now());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16, right: 16, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _salaryController, decoration: const InputDecoration(labelText: 'Base Salary'), keyboardType: TextInputType.number),
            TextField(controller: _bonusController, decoration: const InputDecoration(labelText: 'Bonus'), keyboardType: TextInputType.number),
            TextField(controller: _deductionController, decoration: const InputDecoration(labelText: 'Deduction'), keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'employeeName': employeeName,
                  'month': month,
                  'base': double.tryParse(_salaryController.text) ?? 0.0,
                  'bonus': double.tryParse(_bonusController.text) ?? 0.0,
                  'deduction': double.tryParse(_deductionController.text) ?? 0.0,
                };
                if (isEdit) {
                  await FirebaseFirestore.instance.collection('salaries').doc(doc.id).update(data);
                } else {
                  await FirebaseFirestore.instance.collection('salaries').add(data);
                }
                Navigator.pop(context);
              },
              child: Text(isEdit ? 'Update' : 'Submit'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  bool _matchFilters(Map<String, dynamic> data) {
    if (_selectedEmployee != null && data['employeeName'] != _selectedEmployee) return false;
    if (_selectedMonth != null) {
      final parts = (data['month'] ?? '').split('-');
      if (parts.length == 2) {
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[0]);
        if (month != _selectedMonth!.month || year != _selectedMonth!.year) return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salary Management'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final snapshot = await FirebaseFirestore.instance.collection('salaries').get();
              _exportPDF(snapshot.docs);
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSalaryForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Salary'),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Filter by Employee'),
                    onChanged: (val) => setState(() => _selectedEmployee = val.isEmpty ? null : val),
                  ),
                ),
                TextButton(
                  child: Text(_selectedMonth == null
                      ? 'Filter by Month'
                      : DateFormat('MMM yyyy').format(_selectedMonth!)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      helpText: 'Select a month',
                    );
                    if (picked != null) setState(() => _selectedMonth = picked);
                  },
                )
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('salaries').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs.where((doc) => _matchFilters(doc.data() as Map<String, dynamic>)).toList();

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final net = (data['base'] ?? 0) + (data['bonus'] ?? 0) - (data['deduction'] ?? 0);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text('${data['employeeName']} • ৳$net'),
                        subtitle: Text('Base: ৳${data['base']}, Bonus: ৳${data['bonus']}, Deduction: ৳${data['deduction']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showSalaryForm(doc: doc),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
