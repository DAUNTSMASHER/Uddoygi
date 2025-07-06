import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class LeaveManagementScreen extends StatefulWidget {
  const LeaveManagementScreen({super.key});

  @override
  State<LeaveManagementScreen> createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen> {
  int approved = 0, rejected = 0, pending = 0;
  bool showNewAlert = false;

  @override
  void initState() {
    super.initState();
    _fetchLeaveStats();
  }

  Future<void> _fetchLeaveStats() async {
    final snapshot = await FirebaseFirestore.instance.collection('leaves').get();
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
      showNewAlert = p > 0;
    });
  }

  Future<void> _exportPDF(List<QueryDocumentSnapshot> leaves) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          children: [
            pw.Text('Leave Report', style: pw.TextStyle(fontSize: 20)),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Name', 'Reason', 'From', 'To', 'Status'],
              data: leaves.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return [
                  data['employeeName'],
                  data['reason'],
                  data['fromDate'],
                  data['toDate'],
                  data['status']
                ];
              }).toList(),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  void _updateLeaveStatus(String id, String status) async {
    await FirebaseFirestore.instance.collection('leaves').doc(id).update({'status': status});
    _fetchLeaveStats();
  }

  void _deleteLeave(String id) async {
    await FirebaseFirestore.instance.collection('leaves').doc(id).delete();
    _fetchLeaveStats();
  }

  void _showLeaveForm({DocumentSnapshot? doc}) {
    final isEdit = doc != null;
    final TextEditingController nameController =
    TextEditingController(text: doc?['employeeName'] ?? '');
    final TextEditingController reasonController =
    TextEditingController(text: doc?['reason'] ?? '');
    DateTime fromDate = doc != null ? DateTime.parse(doc['fromDate']) : DateTime.now();
    DateTime toDate = doc != null ? DateTime.parse(doc['toDate']) : DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isEdit ? 'Edit Leave' : 'Apply for Leave'),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason')),
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: fromDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setState(() => fromDate = date);
                  },
                  child: Text('From: ${DateFormat('yyyy-MM-dd').format(fromDate)}'),
                ),
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: toDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) setState(() => toDate = date);
                  },
                  child: Text('To: ${DateFormat('yyyy-MM-dd').format(toDate)}'),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'employeeName': nameController.text,
                  'reason': reasonController.text,
                  'fromDate': DateFormat('yyyy-MM-dd').format(fromDate),
                  'toDate': DateFormat('yyyy-MM-dd').format(toDate),
                  'status': 'Pending',
                  'appliedAt': DateFormat('yyyy-MM-dd').format(DateTime.now())
                };

                if (isEdit) {
                  await FirebaseFirestore.instance.collection('leaves').doc(doc.id).update(data);
                } else {
                  await FirebaseFirestore.instance.collection('leaves').add(data);
                }

                Navigator.pop(context);
                _fetchLeaveStats();
              },
              child: const Text('Submit'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(
              value: approved.toDouble(),
              color: Colors.green,
              title: 'Approved',
            ),
            PieChartSectionData(
              value: rejected.toDouble(),
              color: Colors.red,
              title: 'Rejected',
            ),
            PieChartSectionData(
              value: pending.toDouble(),
              color: Colors.orange,
              title: 'Pending',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Management'),
        backgroundColor: Colors.indigo,
        actions: [
          Icon(Icons.notifications, color: showNewAlert ? Colors.yellow : Colors.white),
          const SizedBox(width: 10),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLeaveForm(),
        backgroundColor: Colors.indigo,
        label: const Text('New Leave'),
        icon: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('leaves')
            .orderBy('appliedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final leaves = snapshot.data!.docs;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildPieChart(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _exportPDF(leaves),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export PDF'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: leaves.length,
                  itemBuilder: (context, index) {
                    final doc = leaves[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text('${data['employeeName']} (${data['status']})'),
                        subtitle: Text('${data['fromDate']} → ${data['toDate']}\nReason: ${data['reason']}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'approve') {
                              _updateLeaveStatus(doc.id, 'Approved');
                            } else if (value == 'reject') {
                              _updateLeaveStatus(doc.id, 'Rejected');
                            } else if (value == 'edit') {
                              _showLeaveForm(doc: doc);
                            } else {
                              _deleteLeave(doc.id);
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
