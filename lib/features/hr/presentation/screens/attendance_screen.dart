// Part 1: Imports and State Setup
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  DateTime _selectedDate = DateTime.now();
  String? _selectedDepartment = 'All';
  String? _searchedId;
  final _darkBlue = Colors.indigo;

  final List<String> _departments = ['All', 'admin', 'hr', 'marketing', 'factory'];

  String get _formattedDate => DateFormat('yyyy-MM-dd').format(_selectedDate);
  bool get _isToday => _formattedDate == DateFormat('yyyy-MM-dd').format(DateTime.now());

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

  Future<bool> _confirmPassword() async {
    String inputPassword = '';
    final user = _auth.currentUser;
    if (user == null || user.email == null) return false;

    return await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Password"),
        content: TextField(
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Enter your password'),
          onChanged: (val) => inputPassword = val,
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _darkBlue),
            onPressed: () async {
              try {
                final credential = EmailAuthProvider.credential(
                    email: user.email!, password: inputPassword);
                await user.reauthenticateWithCredential(credential);
                Navigator.pop(context, true);
              } on FirebaseAuthException catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Auth failed: ${e.message}'),
                ));
                Navigator.pop(context, false);
              }
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    ) ??
        false;
  }

  Future<void> _markAttendance(String empId, String status, String? remarks) async {
    final docRef = _firestore
        .collection('attendance')
        .doc(_formattedDate)
        .collection('records')
        .doc(empId);

    await docRef.update({'status': status, 'remarks': remarks ?? ''});
  }

  void _editStatus(String empId, String currentStatus, String? currentRemarks) async {
    String newStatus = currentStatus;
    String remarks = currentRemarks ?? '';

    if (!_isToday) {
      final confirmed = await _confirmPassword();
      if (!confirmed) return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: newStatus,
              items: ['present', 'absent', 'late', 'leave']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              decoration: const InputDecoration(labelText: 'Select Status'),
              onChanged: (val) => newStatus = val!,
            ),
            const SizedBox(height: 12),
            if (newStatus == 'absent')
              TextFormField(
                initialValue: remarks,
                decoration: const InputDecoration(labelText: 'Reason (Remarks)'),
                onChanged: (val) => remarks = val,
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text("Save"),
              style: ElevatedButton.styleFrom(backgroundColor: _darkBlue),
              onPressed: () {
                Navigator.pop(context);
                _markAttendance(empId, newStatus, remarks);
              },
            ),
          ],
        ),
      ),
    );
  }

// Continue to Part 2...
  Widget _buildTopFilters() {
    return Column(
      children: [
        ListTile(
          title: Text('Date: ${DateFormat('MMM d, yyyy').format(_selectedDate)}'),
          trailing: IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2023),
                lastDate: DateTime(2026),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: DropdownButtonFormField<String>(
            value: _selectedDepartment,
            onChanged: (val) => setState(() => _selectedDepartment = val),
            items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d.toUpperCase()))).toList(),
            decoration: const InputDecoration(labelText: 'Department'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Search by ID',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (val) {
              setState(() => _searchedId = val.trim().isEmpty ? null : val.trim());
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPieChart(List<DocumentSnapshot> records) {
    final dataMap = <String, int>{};

    for (var doc in records) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'] ?? 'unknown';
      dataMap[status] = (dataMap[status] ?? 0) + 1;
    }

    final chartSections = dataMap.entries.map((e) {
      final color = _statusColor(e.key);
      return PieChartSectionData(
        title: '${e.key}\n${e.value}',
        value: e.value.toDouble(),
        color: color,
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return SizedBox(
      height: 200,
      child: PieChart(PieChartData(sections: chartSections)),
    );
  }

  Widget _employeeTile(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final empId = data['employeeId'] ?? '';
    final email = data['email'] ?? '';
    final dept = data['department'] ?? '';
    final status = data['status'] ?? 'absent';
    final remarks = data['remarks'] ?? '';

    final matchesDept = _selectedDepartment == 'All' || dept == _selectedDepartment;
    final matchesSearch = _searchedId == null || empId.contains(_searchedId!);

    if (!matchesDept || !matchesSearch) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(status),
          child: Text(empId.toString().substring(empId.length - 2)),
        ),
        title: Text("ID: $empId"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email),
            if (status == 'absent' && remarks.isNotEmpty)
              Text("Reason: $remarks", style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _editStatus(empId, status, remarks),
          style: ElevatedButton.styleFrom(backgroundColor: _statusColor(status)),
          child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Future<void> _createIfEmpty() async {
    final snap = await _firestore
        .collection('attendance')
        .doc(_formattedDate)
        .collection('records')
        .get();

    if (snap.docs.isEmpty) {
      final users = await _firestore.collection('users').get();
      final batch = _firestore.batch();

      for (final doc in users.docs) {
        final u = doc.data();
        final empId = u['employeeId'];
        if (empId == null) continue;

        final ref = _firestore
            .collection('attendance')
            .doc(_formattedDate)
            .collection('records')
            .doc(empId);
        batch.set(ref, {
          'employeeId': empId,
          'email': u['email'] ?? '',
          'name': u['name'] ?? '',
          'department': u['department'] ?? '',
          'status': 'absent',
          'remarks': '',
          'timestamp': FieldValue.serverTimestamp(),
          'markedBy': _auth.currentUser?.email ?? 'system',
        });
      }

      await batch.commit();
    }
  }

// ⏭ Continue to Part 3: build() method and Monthly Breakdown
  @override
  Widget build(BuildContext context) {
    final colRef = _firestore
        .collection('attendance')
        .doc(_formattedDate)
        .collection('records');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        backgroundColor: _darkBlue,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: colRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final records = snapshot.data!.docs;

          if (records.isEmpty) {
            return Center(
              child: ElevatedButton(
                onPressed: _createIfEmpty,
                style: ElevatedButton.styleFrom(backgroundColor: _darkBlue),
                child: const Text('Create Attendance for This Date'),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              _buildTopFilters(),
              _buildPieChart(records),
              const Divider(),
              ...records.map(_employeeTile),
              const Divider(),
              _buildMonthlyBreakdownChart(),
              _buildSummaryFooter(records),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMonthlyBreakdownChart() {
    return FutureBuilder<QuerySnapshot>(
      future: _firestore.collection('attendance').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final monthMap = <String, Map<String, int>>{};

        for (var doc in snapshot.data!.docs) {
          final dateKey = doc.id;
          final month = dateKey.substring(0, 7); // yyyy-MM

          final dailyRef = _firestore.collection('attendance').doc(dateKey).collection('records');
          // Skip if already loaded (we’ll simplify in Part 4)
        }

        return const SizedBox(); // Placeholder for future chart logic (optional)
      },
    );
  }

  Widget _buildSummaryFooter(List<DocumentSnapshot> records) {
    int present = 0, absent = 0, late = 0, leave = 0;

    for (var doc in records) {
      final status = (doc.data() as Map)['status'];
      switch (status) {
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

    final total = present + absent + late + leave;
    final presentPercent = total == 0 ? 0 : (present / total * 100).toStringAsFixed(1);
    final absentPercent = total == 0 ? 0 : (absent / total * 100).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Summary", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text("Total Records: $total"),
          Text("Present: $present ($presentPercent%)"),
          Text("Absent: $absent ($absentPercent%)"),
          Text("Late: $late"),
          Text("Leave: $leave"),
        ],
      ),
    );
  }

// ⏭ Continue to Part 4: utility functions, chart fix, error fix, and closing braces
  Widget _buildSearchField() {
    return TextField(
      decoration: InputDecoration(
        labelText: 'Search by Employee ID',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onChanged: (val) {
        setState(() => _searchedId = val.trim().isEmpty ? null : val.trim());
      },
    );
  }

  // ✅ Pie Chart Utility for Agent-Wise Status Count
  Widget _buildDepartmentWiseChart() {
    return FutureBuilder<QuerySnapshot>(
      future: _firestore.collection('attendance').doc(_formattedDate).collection('records').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final departmentData = <String, Map<String, int>>{};

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final dept = data['department'] ?? 'unknown';
          final status = data['status'] ?? 'absent';

          departmentData.putIfAbsent(dept, () => {});
          departmentData[dept]![status] = (departmentData[dept]![status] ?? 0) + 1;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: departmentData.entries.map((entry) {
            final dept = entry.key;
            final chartSections = entry.value.entries.map((e) {
              return PieChartSectionData(
                title: '${e.key}\n${e.value}',
                value: e.value.toDouble(),
                color: _statusColor(e.key),
                radius: 40,
                titleStyle: const TextStyle(fontSize: 11, color: Colors.white),
              );
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Department: ${dept.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  height: 160,
                  child: PieChart(PieChartData(sections: chartSections)),
                ),
              ],
            );
          }).toList(),
        );
      },
    );
  }


  @override
  void dispose() {
    super.dispose();
  }
}
