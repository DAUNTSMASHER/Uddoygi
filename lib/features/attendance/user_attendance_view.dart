import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserAttendanceView extends StatefulWidget {
  final String? email;
  final String? employeeId;

  const UserAttendanceView({
    super.key,
    this.email,
    this.employeeId,
  });

  @override
  State<UserAttendanceView> createState() => _UserAttendanceViewState();
}

class _UserAttendanceViewState extends State<UserAttendanceView> {
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  String? _employeeId;
  String? _userEmail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.employeeId != null && widget.email != null) {
      _employeeId = widget.employeeId;
      _userEmail = widget.email;
      _loading = false;
    } else {
      _fetchEmployeeId();
    }
  }

  Future<void> _fetchEmployeeId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        _showPopup("❌ User not logged in!", isError: true);
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final userEmail = user.email!;

      // First try with 'email'
      QuerySnapshot query = await firestore
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      // If not found, try with 'officeEmail'
      if (query.docs.isEmpty) {
        query = await firestore
            .collection('users')
            .where('officeEmail', isEqualTo: userEmail)
            .limit(1)
            .get();
      }

      if (query.docs.isEmpty) {
        _showPopup("❌ No user found with email $userEmail", isError: true);
        return;
      }

      final doc = query.docs.first;
      setState(() {
        _userEmail = userEmail;
        _employeeId = doc['employeeId'];
        _loading = false;
      });

      _showPopup("✅ Found employee ID: $_employeeId");
    } catch (e) {
      _showPopup("❌ Error fetching user info: $e", isError: true);
    }
  }

  void _showPopup(String msg, {bool isError = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    });
  }

  Stream<List<Map<String, dynamic>>> _attendanceStream() {
    if (_employeeId == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collectionGroup('records')
        .snapshots()
        .map((snapshot) {
      final List<Map<String, dynamic>> filtered = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final recordId = doc.id;
        final dateId = doc.reference.parent.parent?.id;

        if (recordId == _employeeId &&
            dateId != null &&
            dateId.startsWith(_selectedMonth)) {
          filtered.add({
            'date': dateId,
            'status': data['status'] ?? '',
            'remarks': data['remarks'] ?? '',
          });
        }
      }

      filtered.sort((a, b) => a['date'].compareTo(b['date']));
      return filtered;
    });
  }

  Widget _buildAttendanceTable(List<Map<String, dynamic>> records) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor:
        MaterialStateColor.resolveWith((_) => Colors.grey[200]!),
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Remarks')),
        ],
        rows: records.map((r) {
          final status = r['status'].toString().toLowerCase();
          return DataRow(cells: [
            DataCell(Text(DateFormat('MMM d, yyyy')
                .format(DateTime.parse(r['date'])))),
            DataCell(Row(
              children: [
                CircleAvatar(
                  radius: 5,
                  backgroundColor: _statusColor(status),
                ),
                const SizedBox(width: 6),
                Text(status[0].toUpperCase() + status.substring(1)),
              ],
            )),
            DataCell(Text(r['remarks'] ?? '')),
          ]);
        }).toList(),
      ),
    );
  }

  static Color _statusColor(String status) {
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
          final now = DateTime.now();
          final month = DateTime(now.year, i + 1);
          final value = DateFormat('yyyy-MM').format(month);
          return DropdownMenuItem(
            value: value,
            child: Text(DateFormat('MMMM yyyy').format(month)),
          );
        }),
        onChanged: (val) {
          if (val != null) {
            setState(() => _selectedMonth = val);
            _showPopup("📆 Switched to $val");
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance History'),
        backgroundColor: Colors.indigo,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildMonthSelector(),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _attendanceStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  _showPopup(
                    '🔥 Firestore error: ${snapshot.error}',
                    isError: true,
                  );
                  return Center(
                      child: Text('Error: ${snapshot.error}'));
                }

                final records = snapshot.data ?? [];
                if (records.isEmpty) {
                  _showPopup(
                    "❌ No matching records found for this month.",
                    isError: true,
                  );
                  return const Center(
                      child: Text("No attendance records found."));
                }

                _showPopup("✅ Found ${records.length} records.");
                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: _buildAttendanceTable(records),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
