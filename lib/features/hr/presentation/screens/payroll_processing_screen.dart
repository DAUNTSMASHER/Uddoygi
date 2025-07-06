import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'dart:typed_data';

class PayrollProcessingScreen extends StatefulWidget {
  const PayrollProcessingScreen({super.key});

  @override
  State<PayrollProcessingScreen> createState() => _PayrollProcessingScreenState();
}

class _PayrollProcessingScreenState extends State<PayrollProcessingScreen> {
  String selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());
  String filterEmployeeId = '';
  String filterDepartment = '';
  final _empIdController = TextEditingController();
  final _salaryController = TextEditingController();

  List<DocumentSnapshot> payrollDocs = [];
  DocumentSnapshot? lastDoc;
  bool isLoading = false;
  bool hasMore = true;
  static const int batchSize = 10;

  @override
  void initState() {
    super.initState();
    _loadPayrolls();
  }

  Future<void> _loadPayrolls() async {
    if (isLoading || !hasMore) return;
    setState(() => isLoading = true);

    Query query = FirebaseFirestore.instance
        .collection('payrolls')
        .where('period', isEqualTo: selectedMonth)
        .orderBy('generatedAt', descending: true)
        .limit(batchSize);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc!);
    }

    final snapshot = await query.get();
    if (snapshot.docs.isNotEmpty) {
      payrollDocs.addAll(snapshot.docs);
      lastDoc = snapshot.docs.last;
    }
    if (snapshot.docs.length < batchSize) hasMore = false;

    setState(() => isLoading = false);
  }

  Future<void> generatePayroll(String employeeId, double grossSalary) async {
    final loansSnapshot = await FirebaseFirestore.instance
        .collection('loans')
        .where('employeeName', isEqualTo: employeeId)
        .where('status', isEqualTo: 'Approved')
        .get();

    double totalDeduction = 0.0;
    List<Map<String, dynamic>> loanBreakdown = [];

    for (final doc in loansSnapshot.docs) {
      final loan = doc.data();
      final double amount = loan['amount'] ?? 0;
      final double deducted = loan['deductedAmount'] ?? 0;
      final remaining = amount - deducted;
      final thisMonthDeduction = remaining >= 2000 ? 2000 : remaining;

      totalDeduction += thisMonthDeduction;
      loanBreakdown.add({
        'loanId': doc.id,
        'amount': amount,
        'deducted': deducted,
        'thisMonth': thisMonthDeduction,
      });

      await FirebaseFirestore.instance.collection('loans').doc(doc.id).update({
        'deductedAmount': FieldValue.increment(thisMonthDeduction),
      });

      if ((deducted + thisMonthDeduction) >= amount) {
        await FirebaseFirestore.instance.collection('loans').doc(doc.id).update({'status': 'Closed'});
      }
    }

    final netSalary = grossSalary - totalDeduction;

    await FirebaseFirestore.instance.collection('payrolls').add({
      'employeeId': employeeId,
      'department': 'General',
      'period': selectedMonth,
      'grossSalary': grossSalary,
      'loanDeduction': totalDeduction,
      'netSalary': netSalary,
      'loanBreakdown': loanBreakdown,
      'generatedAt': DateTime.now().toIso8601String(),
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Payroll generated for $employeeId')));

    setState(() {
      payrollDocs.clear();
      lastDoc = null;
      hasMore = true;
    });

    _loadPayrolls();
  }

  Future<void> exportPayrollToExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Payroll'];

    sheet.appendRow(['Employee ID', 'Department', 'Gross', 'Loan', 'Net', 'Period']);
    for (var doc in payrollDocs) {
      final d = doc.data() as Map<String, dynamic>;
      sheet.appendRow([
        d['employeeId'],
        d['department'],
        d['grossSalary'],
        d['loanDeduction'],
        d['netSalary'],
        d['period']
      ]);
    }

    final Uint8List bytes = Uint8List.fromList(excel.encode()!);
    await Printing.sharePdf(bytes: bytes, filename: 'payroll_${selectedMonth.replaceAll(' ', '_')}.xlsx');
  }

  Future<void> exportPayrollToPDF() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (_) => pw.Column(
          children: [
            pw.Text('Payroll Report - $selectedMonth', style: pw.TextStyle(fontSize: 18)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Employee ID', 'Gross', 'Loan', 'Net', 'Department'],
              data: payrollDocs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return [
                  d['employeeId'],
                  d['grossSalary'].toString(),
                  d['loanDeduction'].toString(),
                  d['netSalary'].toString(),
                  d['department'] ?? ''
                ];
              }).toList(),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final filteredDocs = payrollDocs.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      final matchesEmp = filterEmployeeId.isEmpty || d['employeeId'].toString().contains(filterEmployeeId);
      final matchesDept = filterDepartment.isEmpty || (d['department'] ?? '').toString().contains(filterDepartment);
      return matchesEmp && matchesDept;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll Processing'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: exportPayrollToPDF),
          IconButton(icon: const Icon(Icons.file_copy), onPressed: exportPayrollToExcel),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add),
        label: const Text('Generate Payroll'),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('New Payroll'),
                  TextField(controller: _empIdController, decoration: const InputDecoration(labelText: 'Employee ID')),
                  TextField(
                    controller: _salaryController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Gross Salary'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      final emp = _empIdController.text.trim();
                      final gross = double.tryParse(_salaryController.text.trim()) ?? 0;
                      if (emp.isNotEmpty && gross > 0) {
                        generatePayroll(emp, gross);
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Generate'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => filterEmployeeId = v.trim()),
                    decoration: const InputDecoration(labelText: 'Filter by Employee ID'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => filterDepartment = v.trim()),
                    decoration: const InputDecoration(labelText: 'Filter by Department'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredDocs.length + 1,
              itemBuilder: (context, index) {
                if (index == filteredDocs.length) {
                  if (hasMore) {
                    _loadPayrolls();
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ));
                  } else {
                    return const SizedBox();
                  }
                }

                final data = filteredDocs[index].data() as Map<String, dynamic>;
                final breakdown = (data['loanBreakdown'] ?? []) as List;

                return ExpansionTile(
                  title: Text('${data['employeeId']} – ৳${data['netSalary']}'),
                  subtitle: Text('Gross: ৳${data['grossSalary']} • Loan: ৳${data['loanDeduction']}'),
                  children: breakdown.map<Widget>((entry) {
                    return ListTile(
                      title: Text('Loan ID: ${entry['loanId']}'),
                      subtitle: Text(
                        'Original: ৳${entry['amount']} | Deducted: ৳${entry['deducted']} | This Month: ৳${entry['thisMonth']}',
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
}
