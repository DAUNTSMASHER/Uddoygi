import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PayslipScreen extends StatefulWidget {
  const PayslipScreen({super.key});

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  Future<void> _downloadPayslip(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Payslip', style: pw.TextStyle(fontSize: 24)),
            pw.SizedBox(height: 16),
            pw.Text('Employee: ${data['employeeName']}'),
            pw.Text('Period: ${data['period']}'),
            pw.SizedBox(height: 10),
            pw.Text('Gross Salary: ৳${data['grossSalary']}'),
            pw.Text('Bonuses: ৳${data['bonus'] ?? 0}'),
            pw.Text('Deductions: ৳${data['loanDeductionTotal'] ?? 0}'),
            pw.Divider(),
            pw.Text(
              'Net Pay: ৳${data['grossSalary'] + (data['bonus'] ?? 0) - (data['loanDeductionTotal'] ?? 0)}',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_searchQuery.isEmpty) return true;
    final name = data['employeeName']?.toLowerCase() ?? '';
    final id = data['employeeId']?.toLowerCase() ?? '';
    return name.contains(_searchQuery.toLowerCase()) || id.contains(_searchQuery.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payslips'),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or employee ID',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim());
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('payrolls')
                  .orderBy('period', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs.where((doc) => _matchesSearch(doc.data() as Map<String, dynamic>)).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text('No matching payslips found.'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final netPay = data['grossSalary'] + (data['bonus'] ?? 0) - (data['loanDeductionTotal'] ?? 0);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ExpansionTile(
                        title: Text('${data['employeeName']} (${data['employeeId']})'),
                        subtitle: Text('৳$netPay • ${data['period']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.picture_as_pdf),
                          onPressed: () => _downloadPayslip(data),
                        ),
                        children: [
                          ListTile(title: Text('Gross Salary: ৳${data['grossSalary']}')),
                          ListTile(title: Text('Bonuses: ৳${data['bonus'] ?? 0}')),
                          ListTile(title: Text('Loan Deduction: ৳${data['loanDeductionTotal'] ?? 0}')),
                          ListTile(
                            title: Text(
                              'Net Pay: ৳$netPay',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
