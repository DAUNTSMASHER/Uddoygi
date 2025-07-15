import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class BenefitsCompensationScreen extends StatefulWidget {
  const BenefitsCompensationScreen({super.key});

  @override
  State<BenefitsCompensationScreen> createState() =>
      _BenefitsCompensationScreenState();
}

class _BenefitsCompensationScreenState
    extends State<BenefitsCompensationScreen> {
  final List<String> _types = ['All', 'Bonus', 'Incentive', 'Allowance'];
  String _selectedType = 'All';
  String _searchEmployee = '';
  DateTime? _filterDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50], // soft blue background
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        title: const Text(
          'Benefits & Compensation',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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
            // Type filter chips
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 10,
                runSpacing: 6,
                children: _types.map((type) {
                  final isSelected = type == _selectedType;
                  return ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    selectedColor: Colors.blue[800],
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.blue[900],
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _selectedType = type),
                    elevation: 3,
                    shadowColor: Colors.blueGrey.withOpacity(0.3),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Search & Date filter row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search Employee...',
                      prefixIcon: const Icon(Icons.search, color: Colors.blue),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) =>
                        setState(() => _searchEmployee = value.trim()),
                  ),
                ),
                const SizedBox(width: 12),
                // Date picker button
                Material(
                  color: Colors.blue[800],
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _filterDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _filterDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: const Icon(Icons.calendar_today, color: Colors.white),
                    ),
                  ),
                ),
                if (_filterDate != null) ...[
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.red[600],
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _filterDate = null),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: const Icon(Icons.clear, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),

            // Benefits list from Firestore
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('benefits')
                    .orderBy('date', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Error loading data',
                          style: TextStyle(color: Colors.red)),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final matchesType =
                        _selectedType == 'All' || data['type'] == _selectedType;
                    final matchesEmployee = data['employee']
                        .toString()
                        .toLowerCase()
                        .contains(_searchEmployee.toLowerCase());
                    final matchesDate = _filterDate == null ||
                        DateFormat('yyyy-MM-dd').format(
                            (data['date'] as Timestamp).toDate()) ==
                            DateFormat('yyyy-MM-dd').format(_filterDate!);
                    return matchesType && matchesEmployee && matchesDate;
                  }).toList();

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No benefits found for selected filters.',
                        style: TextStyle(color: Colors.blueGrey, fontSize: 16),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final type = data['type'] ?? 'Bonus';
                      final employee = data['employee'] ?? 'Unknown';
                      final note = data['note'] ?? '';
                      final amount = (data['amount'] is num)
                          ? (data['amount'] as num).toStringAsFixed(0)
                          : '0';
                      final date = (data['date'] as Timestamp).toDate();

                      Color typeColor;
                      switch (type.toLowerCase()) {
                        case 'bonus':
                          typeColor = Colors.green;
                          break;
                        case 'incentive':
                          typeColor = Colors.orange;
                          break;
                        case 'allowance':
                          typeColor = Colors.purple;
                          break;
                        default:
                          typeColor = Colors.blueGrey;
                      }

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: typeColor,
                            child: const Icon(Icons.monetization_on,
                                color: Colors.white),
                          ),
                          title: Text(
                            employee,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text(
                            'Type: $type\nNote: $note\nDate: ${DateFormat('yyyy-MM-dd').format(date)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          trailing: Text(
                            '৳ $amount',
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
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
        backgroundColor: Colors.blue[800],
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
            child: StatefulBuilder(
              builder: (context, setModalState) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Add Benefit / Compensation',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                    items: ['Bonus', 'Incentive', 'Allowance']
                        .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setModalState(() => benefitType = value);
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

                      if (employee.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Employee name/ID is required')),
                        );
                        return;
                      }
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter a valid amount')),
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
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
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
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text('Benefits & Compensation Report',
              style:
              pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
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
            border: pw.TableBorder.all(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            headerDecoration: pw.BoxDecoration(color: PdfColors.blue300),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
