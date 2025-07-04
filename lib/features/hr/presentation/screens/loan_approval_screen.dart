import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class LoanApprovalScreen extends StatefulWidget {
  const LoanApprovalScreen({super.key});

  @override
  State<LoanApprovalScreen> createState() => _LoanApprovalScreenState();
}

class _LoanApprovalScreenState extends State<LoanApprovalScreen> {
  String _selectedStatus = 'All';
  DateTime? _selectedMonth;
  int approved = 0, rejected = 0, pending = 0;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final snapshot = await FirebaseFirestore.instance.collection('loans').get();
    int a = 0, r = 0, p = 0;

    for (var doc in snapshot.docs) {
      final status = doc['status'];
      if (status == 'Approved') {
        a++;
      } else if (status == 'Rejected') r++;
      else p++;
    }

    setState(() {
      approved = a;
      rejected = r;
      pending = p;
    });
  }

  Future<void> _exportPDF(List<QueryDocumentSnapshot> loans) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          children: [
            pw.Text('Loan Report', style: pw.TextStyle(fontSize: 20)),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Name', 'Purpose', 'Amount', 'Status', 'Date'],
              data: loans.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return [
                  data['employeeName'],
                  data['purpose'],
                  data['amount'].toString(),
                  data['status'],
                  data['requestedAt']
                ];
              }).toList(),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  void _showLoanForm({DocumentSnapshot? doc}) {
    final isEdit = doc != null;
    final TextEditingController nameController =
    TextEditingController(text: doc?['employeeName'] ?? '');
    final TextEditingController purposeController =
    TextEditingController(text: doc?['purpose'] ?? '');
    final TextEditingController amountController =
    TextEditingController(text: doc?['amount']?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isEdit ? 'Edit Loan Request' : 'New Loan Request'),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Employee Name')),
            TextField(controller: purposeController, decoration: const InputDecoration(labelText: 'Purpose')),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                final data = {
                  'employeeName': nameController.text.trim(),
                  'purpose': purposeController.text.trim(),
                  'amount': amount,
                  'status': 'Pending',
                  'deductedAmount': 0.0,
                  'requestedAt': DateFormat('yyyy-MM-dd').format(DateTime.now())
                };

                if (isEdit) {
                  await FirebaseFirestore.instance.collection('loans').doc(doc.id).update(data);
                } else {
                  await FirebaseFirestore.instance.collection('loans').add(data);
                }

                Navigator.pop(context);
                _fetchStats();
              },
              child: Text(isEdit ? 'Update' : 'Submit'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _updateLoanStatus(String id, String status) async {
    await FirebaseFirestore.instance.collection('loans').doc(id).update({'status': status});
    _fetchStats();
  }

  void _deleteLoan(String id) async {
    await FirebaseFirestore.instance.collection('loans').doc(id).delete();
    _fetchStats();
  }

  Widget _buildPieChart() {
    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(value: approved.toDouble(), title: 'Approved', color: Colors.green),
            PieChartSectionData(value: rejected.toDouble(), title: 'Rejected', color: Colors.red),
            PieChartSectionData(value: pending.toDouble(), title: 'Pending', color: Colors.orange),
          ],
        ),
      ),
    );
  }

  bool _matchFilters(Map<String, dynamic> data) {
    if (_selectedStatus != 'All' && data['status'] != _selectedStatus) return false;
    if (_selectedMonth != null) {
      final loanDate = DateTime.tryParse(data['requestedAt'] ?? '') ?? DateTime(2000);
      if (loanDate.month != _selectedMonth!.month || loanDate.year != _selectedMonth!.year) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Approval'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final snapshot = await FirebaseFirestore.instance.collection('loans').get();
              _exportPDF(snapshot.docs);
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLoanForm(),
        icon: const Icon(Icons.add),
        label: const Text('New Loan'),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          _buildPieChart(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _selectedStatus,
                  items: ['All', 'Pending', 'Approved', 'Rejected']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedStatus = val!),
                ),
                const Spacer(),
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
                      helpText: 'Select a date to filter month',
                    );
                    if (picked != null) setState(() => _selectedMonth = picked);
                  },
                )
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('loans')
                  .orderBy('requestedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs.where((doc) => _matchFilters(doc.data() as Map<String, dynamic>)).toList();

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text('${data['employeeName']} (${data['status']})'),
                        subtitle: Text('৳${data['amount']} • ${data['purpose']}\nRequested: ${data['requestedAt']}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'approve') {
                              _updateLoanStatus(doc.id, 'Approved');
                            } else if (value == 'reject') {
                              _updateLoanStatus(doc.id, 'Rejected');
                            } else if (value == 'edit') {
                              _showLoanForm(doc: doc);
                            } else if (value == 'delete') {
                              _deleteLoan(doc.id);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'approve', child: Text('Approve')),
                            const PopupMenuItem(value: 'reject', child: Text('Reject')),
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
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
