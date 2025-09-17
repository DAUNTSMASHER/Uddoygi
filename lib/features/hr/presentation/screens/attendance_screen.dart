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

  // ---- UI / Filters ----
  DateTime _selectedDate = DateTime.now();
  String? _selectedDepartment = 'All';
  String? _searchedId;

  // Palette
  static const Color _primary = Color(0xFF25BC5F); // indigo-ish
  static const Color _primaryDark = Color(0xFF065F46);
  static const Color _bg = Color(0xFFC3D8C2);
  static const Color _cardBorder = Color(0x14000000);

  final List<String> _departments = const ['All', 'admin', 'hr', 'marketing', 'factory'];

  String get _formattedDate => DateFormat('yyyy-MM-dd').format(_selectedDate);
  bool get _isToday => _formattedDate == DateFormat('yyyy-MM-dd').format(DateTime.now());

  // ---- Status colors ----
  Color _statusColor(String status) {
    switch (status) {
      case 'present':
        return const Color(0xFF16A34A); // green
      case 'absent':
        return const Color(0xFFDC2626); // red
      case 'late':
        return const Color(0xFFF59E0B); // amber
      case 'leave':
        return const Color(0xFF2563EB); // blue
      default:
        return Colors.grey;
    }
  }

  // =============== Auth confirm for backdate ===============
  Future<bool> _confirmPassword() async {
    String inputPassword = '';
    final user = _auth.currentUser;
    if (user == null || user.email == null) return false;

    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text("Confirm change"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "You're editing a past date. Please confirm with your password.",
              style: TextStyle(height: 1.3),
            ),
            const SizedBox(height: 10),
            TextField(
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => inputPassword = val,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              try {
                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: inputPassword,
                );
                await user.reauthenticateWithCredential(credential);
                if (context.mounted) Navigator.pop(context, true);
              } on FirebaseAuthException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Auth failed: ${e.message}')),
                  );
                  Navigator.pop(context, false);
                }
              }
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    ) ??
        false;
  }

  // =============== Data ops ===============
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
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16,
        ),
        child: Wrap(
          runSpacing: 12,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text('Update Status', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            DropdownButtonFormField<String>(
              value: newStatus,
              items: ['present', 'absent', 'late', 'leave']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                  .toList(),
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => newStatus = val!,
            ),
            if (newStatus == 'absent')
              TextFormField(
                initialValue: remarks,
                decoration: const InputDecoration(
                  labelText: 'Reason (Remarks)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => remarks = val,
                minLines: 2,
                maxLines: 4,
              ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("Save"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _markAttendance(empId, newStatus, remarks);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============== Create daily records if empty ===============
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

  // =============== UI ===============
  @override
  Widget build(BuildContext context) {
    final colRef = _firestore
        .collection('attendance')
        .doc(_formattedDate)
        .collection('records');

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Attendance', style: TextStyle(fontWeight: FontWeight.w800)),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Color(0xFF065F46),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary, _primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: colRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data!.docs;

          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _filtersCard(),
                  const SizedBox(height: 12),
                  _emptyCreateCard(),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            children: [
              _filtersCard(),
              const SizedBox(height: 8),
              _summaryDonut(records),
              const SizedBox(height: 8),
              _legendRow(records),
              const SizedBox(height: 8),
              _departmentHeader(),
              const SizedBox(height: 6),
              ...records.map(_employeeTile),
              const SizedBox(height: 12),
              _buildSummaryFooter(records),
            ],
          );
        },
      ),
    );
  }

  // ---- Filters card (date + dept + search) ----
  Widget _filtersCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.today, color: _primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Date: ${DateFormat('EEE, d MMM yyyy').format(_selectedDate)}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              TextButton.icon(
                icon: const Icon(Icons.calendar_month, size: 18),
                label: const Text('Change'),
                style: TextButton.styleFrom(foregroundColor: _primary),
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
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Department
              Expanded(
                flex: 12,
                child: DropdownButtonFormField<String>(
                  value: _selectedDepartment,
                  onChanged: (val) => setState(() => _selectedDepartment = val),
                  items: _departments
                      .map((d) => DropdownMenuItem(value: d, child: Text(d.toUpperCase())))
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Search ID
              Expanded(
                flex: 12,
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search by ID',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    setState(() => _searchedId = val.trim().isEmpty ? null : val.trim());
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Donut chart + total in center ----
  Widget _summaryDonut(List<DocumentSnapshot> records) {
    final counts = _statusCounts(records);
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final sections = <PieChartSectionData>[];

    counts.forEach((status, count) {
      if (count == 0) return;
      sections.add(
        PieChartSectionData(
          color: _statusColor(status),
          value: count.toDouble(),
          title: '$count',
          radius: 56,
          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
        ),
      );
    });

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          const SizedBox(height: 4),
          const Text('Today’s Summary', style: TextStyle(fontWeight: FontWeight.w900)),
          SizedBox(
            height: 210,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 2,
                    centerSpaceRadius: 48,
                    borderData: FlBorderData(show: false),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('TOTAL', style: TextStyle(color: Colors.black54, fontSize: 11)),
                    Text('$total', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Legend row ----
  Widget _legendRow(List<DocumentSnapshot> records) {
    final c = _statusCounts(records);
    final items = [
      _legendChip('present', c['present'] ?? 0),
      _legendChip('absent', c['absent'] ?? 0),
      _legendChip('late', c['late'] ?? 0),
      _legendChip('leave', c['leave'] ?? 0),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items,
    );
  }

  Widget _legendChip(String status, int count) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        border: Border.all(color: color.withOpacity(.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            '${status.toUpperCase()} · $count',
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Map<String, int> _statusCounts(List<DocumentSnapshot> records) {
    final map = <String, int>{'present': 0, 'absent': 0, 'late': 0, 'leave': 0};
    for (final d in records) {
      final m = d.data() as Map<String, dynamic>;
      final st = (m['status'] ?? 'absent').toString();
      map[st] = (map[st] ?? 0) + 1;
    }
    return map;
  }

  // ---- Section header for list ----
  Widget _departmentHeader() {
    return Row(
      children: [
        const Icon(Icons.groups_2, color: _primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _selectedDepartment == 'All'
                ? 'All Departments'
                : 'Department: ${_selectedDepartment!.toUpperCase()}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  // ---- Employee tile ----
  Widget _employeeTile(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final empId = (data['employeeId'] ?? '').toString();
    final email = (data['email'] ?? '').toString();
    final name = (data['name'] ?? '').toString();
    final dept = (data['department'] ?? '').toString();
    final status = (data['status'] ?? 'absent').toString();
    final remarks = (data['remarks'] ?? '').toString();

    final matchesDept = _selectedDepartment == 'All' || dept == _selectedDepartment;
    final matchesSearch = _searchedId == null || empId.contains(_searchedId!);
    if (!matchesDept || !matchesSearch) return const SizedBox.shrink();

    final initials = (empId.isNotEmpty && empId.length >= 2) ? empId.substring(empId.length - 2) : 'ID';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: _statusColor(status),
          child: Text(
            initials,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          name.isNotEmpty ? name : 'ID: $empId',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (name.isNotEmpty) Text('ID: $empId', style: const TextStyle(fontSize: 12)),
            if (email.isNotEmpty) Text(email, style: const TextStyle(fontSize: 12)),
            Text(dept.toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (status == 'absent' && remarks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Reason: $remarks', style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _editStatus(empId, status, remarks),
          style: ElevatedButton.styleFrom(
            backgroundColor: _statusColor(status),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          child: Text(
            status.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  // ---- Empty state (create records) ----
  Widget _emptyCreateCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Text('No records found for this date.', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create Attendance for This Date'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _createIfEmpty,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Summary footer ----
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
    final presentPercent = total == 0 ? '0.0' : (present / total * 100).toStringAsFixed(1);
    final absentPercent = total == 0 ? '0.0' : (absent / total * 100).toStringAsFixed(1);

    Widget cell(String label, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _cardBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            cell('Total', '$total'),
            const SizedBox(width: 8),
            cell('Present', '$present ($presentPercent%)'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            cell('Absent', '$absent ($absentPercent%)'),
            const SizedBox(width: 8),
            cell('Late • Leave', '$late • $leave'),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
