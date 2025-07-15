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
      if (status == 'Approved') a++;
      else if (status == 'Rejected') r++;
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

  Widget _buildPieChart() {
    int total = approved + rejected + pending;
    if (total == 0) total = 1; // avoid divide-by-zero
    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: [
            PieChartSectionData(
              value: approved.toDouble(),
              title: '${((approved / total) * 100).toStringAsFixed(1)}%',
              color: Colors.green,
              radius: 50,
            ),
            PieChartSectionData(
              value: rejected.toDouble(),
              title: '${((rejected / total) * 100).toStringAsFixed(1)}%',
              color: Colors.red,
              radius: 50,
            ),
            PieChartSectionData(
              value: pending.toDouble(),
              title: '${((pending / total) * 100).toStringAsFixed(1)}%',
              color: Colors.orange,
              radius: 50,
            ),
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
      backgroundColor: Colors.indigo[900],
      appBar: AppBar(
        title: const Text('Loan Approval', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo[900],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: () async {
              final snapshot = await FirebaseFirestore.instance.collection('loans').get();
              _exportPDF(snapshot.docs);
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Add logic to open loan form
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Loan', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          const SizedBox(height: 15),
          _buildPieChart(),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                DropdownButton<String>(
                  dropdownColor: Colors.white,
                  value: _selectedStatus,
                  items: ['All', 'Pending', 'Approved', 'Rejected']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedStatus = val!),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.date_range, color: Colors.white),
                  label: Text(
                    _selectedMonth == null
                        ? 'Filter by Month'
                        : DateFormat('MMM yyyy').format(_selectedMonth!),
                    style: const TextStyle(color: Colors.white),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
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
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs
                    .where((doc) => _matchFilters(doc.data() as Map<String, dynamic>))
                    .toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No loan records found.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        title: Text('${data['employeeName']} (${data['status']})'),
                        subtitle: Text(
                          '৳${data['amount']} • ${data['purpose']}\nRequested: ${data['requestedAt']}',
                        ),
                        trailing: const Icon(Icons.more_vert),
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
