import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class BenefitsCompensationScreen extends StatefulWidget {
  const BenefitsCompensationScreen({super.key});

  @override
  State<BenefitsCompensationScreen> createState() => _BenefitsCompensationScreenState();
}

class _BenefitsCompensationScreenState extends State<BenefitsCompensationScreen> {
  final List<String> _types = ['All', 'Bonus', 'Incentive', 'Allowance'];
  String _selectedType = 'All';
  String _searchEmployee = '';
  DateTime? _filterDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: const Text('Benefits & Compensation', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportPdf,
            tooltip: 'Export to PDF',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Filters: Type
            Wrap(
              spacing: 8,
              children: _types.map((type) {
                final isSelected = type == _selectedType;
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  selectedColor: Colors.indigo,
                  backgroundColor: Colors.grey[200],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                  onSelected: (_) => setState(() => _selectedType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),

            // Filters: Date & Employee
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search Employee...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _searchEmployee = value.trim()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today, color: Colors.indigo),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _filterDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _filterDate = picked);
                  },
                ),
                if (_filterDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () => setState(() => _filterDate = null),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Firebase List of Benefits
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('benefits')
                    .orderBy('date', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading data'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final matchesType = _selectedType == 'All' || data['type'] == _selectedType;
                    final matchesEmployee = data['employee']
                        .toString()
                        .toLowerCase()
                        .contains(_searchEmployee.toLowerCase());
                    final matchesDate = _filterDate == null ||
                        DateFormat('yyyy-MM-dd').format((data['date'] as Timestamp).toDate()) ==
                            DateFormat('yyyy-MM-dd').format(_filterDate!);
                    return matchesType && matchesEmployee && matchesDate;
                  }).toList();

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final type = data['type'] ?? 'Bonus';
                      final employee = data['employee'] ?? 'Unknown';
                      final note = data['note'] ?? '';
                      final amount = data['amount']?.toStringAsFixed(0) ?? '0';
                      final date = (data['date'] as Timestamp).toDate();

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.indigo,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(employee),
                          subtitle: Text('Type: $type\nNote: $note\nDate: ${DateFormat('yyyy-MM-dd').format(date)}'),
                          trailing: Text(
                            '৳ $amount',
                            style: const TextStyle(
                              color: Colors.indigo,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add),
        label: const Text('Add Benefit'),
        onPressed: () => _showAddBenefitSheet(context),
      ),
    );
  }

  void _showAddBenefitSheet(BuildContext context) {
    final employeeController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String benefitType = 'Bonus';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Add Benefit / Compensation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                  controller: employeeController,
                  decoration: const InputDecoration(
                    labelText: 'Employee Name / ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: benefitType,
                  decoration: const InputDecoration(
                    labelText: 'Benefit Type',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Bonus', 'Incentive', 'Allowance'].map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) benefitType = value;
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_exchange),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Save'),
                  onPressed: () async {
                    final employee = employeeController.text.trim();
                    final note = noteController.text.trim();
                    final amount = double.tryParse(amountController.text.trim());

                    if (employee.isEmpty || amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid input')),
                      );
                      return;
                    }

                    await FirebaseFirestore.instance.collection('benefits').add({
                      'employee': employee,
                      'type': benefitType,
                      'amount': amount,
                      'note': note,
                      'date': DateTime.now(),
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Benefit added successfully')),
                    );
                  },
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
      },
    );
  }

  Future<void> _exportPdf() async {
    final query = await FirebaseFirestore.instance
        .collection('benefits')
        .orderBy('date', descending: true)
        .get();

    final pdf = pw.Document();
    final logs = query.docs;

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Benefits Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Date', 'Employee', 'Type', 'Amount', 'Note'],
            data: logs.map((doc) {
              final data = doc.data();
              return [
                DateFormat('yyyy-MM-dd').format((data['date'] as Timestamp).toDate()),
                data['employee'] ?? '',
                data['type'] ?? '',
                '৳ ${data['amount'].toString()}',
                data['note'] ?? '',
              ];
            }).toList(),
            border: pw.TableBorder.all(color: PdfColors.grey),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.all(6),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
