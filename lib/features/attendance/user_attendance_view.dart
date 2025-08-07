import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class UserAttendanceView extends StatefulWidget {
  const UserAttendanceView({super.key});

  @override
  State<UserAttendanceView> createState() => _UserAttendanceViewState();
}

class _UserAttendanceViewState extends State<UserAttendanceView> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  late String _userEmail;
  late String _employeeId;
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _userEmail = _auth.currentUser?.email ?? '';
    _fetchEmployeeId();
  }

  Future<void> _fetchEmployeeId() async {
    final snap = await _firestore
        .collection('users')
        .where('email', isEqualTo: _userEmail)
        .get();

    if (snap.docs.isNotEmpty) {
      setState(() {
        _employeeId = snap.docs.first.data()['employeeId'] ?? '';
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAttendanceRecords() async {
    final attendanceDates = await _firestore.collection('attendance').get();
    List<Map<String, dynamic>> allRecords = [];

    for (var doc in attendanceDates.docs) {
      if (doc.id.startsWith(_selectedMonth)) {
        final record = await _firestore
            .collection('attendance')
            .doc(doc.id)
            .collection('records')
            .doc(_employeeId)
            .get();

        if (record.exists) {
          final data = record.data()!;
          allRecords.add({
            'date': doc.id,
            'status': data['status'],
            'remarks': data['remarks'] ?? '',
          });
        }
      }
    }
    return allRecords;
  }

  Widget _buildPieChart(List<Map<String, dynamic>> records) {
    final Map<String, int> statusCount = {};

    for (var record in records) {
      final status = record['status'];
      statusCount[status] = (statusCount[status] ?? 0) + 1;
    }

    final total = records.length.toDouble();
    final sections = statusCount.entries.map((entry) {
      final value = entry.value.toDouble();
      return PieChartSectionData(
        title: '${entry.key}\n${((value / total) * 100).toStringAsFixed(1)}%',
        value: value,
        radius: 40,
        color: _statusColor(entry.key),
        titleStyle: const TextStyle(fontSize: 11, color: Colors.white),
      );
    }).toList();

    return PieChart(PieChartData(sections: sections));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'late':
        return Colors.orange;
      case 'leave':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildMonthSelector() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: DropdownButtonFormField<String>(
        value: _selectedMonth,
        decoration: const InputDecoration(labelText: "Select Month"),
        items: List.generate(12, (i) {
          final month = DateTime(DateTime.now().year, i + 1);
          final value = DateFormat('yyyy-MM').format(month);
          return DropdownMenuItem(
              value: value, child: Text(DateFormat('MMMM yyyy').format(month)));
        }),
        onChanged: (val) {
          if (val != null) {
            setState(() {
              _selectedMonth = val;
            });
          }
        },
      ),
    );
  }

  Widget _buildAttendanceSummary(List<Map<String, dynamic>> records) {
    int present = 0, absent = 0, late = 0, leave = 0;

    for (var r in records) {
      switch (r['status']) {
        case 'present':
          present++;
          break;
        case 'absent':
          absent++;
          break;
        case 'late':
          late++;
          break;
        case 'leave':
          leave++;
          break;
      }
    }

    final total = records.length;
    final percent = (int v) =>
    total == 0 ? '0%' : '${((v / total) * 100).toStringAsFixed(1)}%';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monthly Summary', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Present: $present (${percent(present)})"),
            Text("Absent: $absent (${percent(absent)})"),
            Text("Late: $late (${percent(late)})"),
            Text("Leave: $leave (${percent(leave)})"),
            Text("Total Days: $total"),
          ],
        ),
      ),
    );
  }

  Widget _buildDateWiseCards(List<Map<String, dynamic>> records) {
    records.sort((a, b) => a['date'].compareTo(b['date']));
    return Column(
      children: records.map((r) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _statusColor(r['status']),
              child: Text(DateFormat('d').format(DateTime.parse(r['date']))),
            ),
            title: Text("Date: ${DateFormat('MMM d, yyyy').format(DateTime.parse(r['date']))}"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Status: ${r['status']}"),
                if (r['remarks'].toString().isNotEmpty)
                  Text("Remarks: ${r['remarks']}", style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance Overview'),
        backgroundColor: Colors.indigo,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchAttendanceRecords(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final records = snapshot.data!;
          return ListView(
            children: [
              _buildMonthSelector(),
              SizedBox(height: 200, child: _buildPieChart(records)),
              _buildAttendanceSummary(records),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text("Date-wise Details",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              _buildDateWiseCards(records),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}
