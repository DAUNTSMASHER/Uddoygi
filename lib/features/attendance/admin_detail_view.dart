import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'user_attendance_view.dart'; // <-- make sure this is imported

const Color _darkBlue = Color(0xFF2A0A4B);

class AdminDetailView extends StatefulWidget {
  const AdminDetailView({super.key});

  @override
  State<AdminDetailView> createState() => _AdminDetailViewState();
}

class _AdminDetailViewState extends State<AdminDetailView> {
  String _cid = '';
  String selectedMonth = DateFormat('MMMM').format(DateTime.now());
  String selectedYear = DateFormat('yyyy').format(DateTime.now());
  String? _errorMessage;

  final List<String> months =
  List.generate(12, (i) => DateFormat('MMMM').format(DateTime(0, i + 1)));
  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Summary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        backgroundColor: _darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task_rounded),
            onPressed: () => _showManualEntryDialog(),
            tooltip: 'Manual Entry',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCards(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedMonth,
                        items: months.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => selectedMonth = v!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedYear,
                        items: List.generate(5, (i) {
                          final y = (DateTime.now().year - i).toString();
                          return DropdownMenuItem(value: y, child: Text(y));
                        }),
                        onChanged: (v) => setState(() => selectedYear = v!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_errorMessage!,
                  style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: DB.colSync(_cid, C.attendance)
                  .snapshots(),
              builder: (context, attendanceSnap) {
                if (!attendanceSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = attendanceSnap.data!.docs;
                final selectedMonthIndex =
                    months.indexOf(selectedMonth) + 1;
                final monthStr = selectedMonthIndex.toString().padLeft(2, '0');

                final filteredDocs = allDocs.where((doc) {
                  final id = doc.id;
                  final parts = id.split('-');
                  return parts.length == 3 &&
                      parts[0] == selectedYear &&
                      parts[1] == monthStr;
                }).toList();

                return StreamBuilder<QuerySnapshot>(
                  stream: DB.firestore
                      .collectionGroup('records')
                      .snapshots(),
                  builder: (context, recordSnap) {
                    if (!recordSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allRecords = recordSnap.data!.docs;
                    final stats = <String, Map<String, int>>{};

                    for (final record in allRecords) {
                      final parentId =
                          record.reference.parent.parent?.id ?? '';
                      final parts = parentId.split('-');
                      if (parts.length != 3 ||
                          parts[0] != selectedYear ||
                          parts[1] != monthStr) continue;

                      final data = record.data() as Map<String, dynamic>;
                      final empId = data['employeeId'];
                      final status = (data['status'] ?? '').toLowerCase();

                      if (empId == null) continue;

                      stats.putIfAbsent(empId, () => {
                        'present': 0,
                        'absent': 0,
                        'leave': 0,
                        'late': 0,
                        'total': 0,
                      });

                      if (status == 'present') stats[empId]!['present'] = stats[empId]!['present']! + 1;
                      else if (status == 'absent') stats[empId]!['absent'] = stats[empId]!['absent']! + 1;
                      else if (status == 'leave') stats[empId]!['leave'] = stats[empId]!['leave']! + 1;
                      else if (status == 'late') stats[empId]!['late'] = stats[empId]!['late']! + 1;

                      stats[empId]!['total'] = stats[empId]!['total']! + 1;
                    }

                    return FutureBuilder<QuerySnapshot>(
                      future: DB.colSync(_cid, C.users)
                          .get(),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final userDocs = userSnap.data!.docs;
                        int count = userDocs.length;

                        int sumPresent = 0;
                        int sumAbsent = 0;
                        int sumLate = 0;
                        int sumLeave = 0;
                        int sumTotal = 0;

                        String avg(int val) =>
                            count > 0 ? (val / count).toStringAsFixed(1) : '0.0';

                        final rows = userDocs.map((userDoc) {
                          final user = userDoc.data() as Map<String, dynamic>;
                          final empId = user['employeeId'] ?? '';
                          final name = user['name'] ?? 'Unnamed';
                          final dept = user['department'] ?? 'N/A';
                          final stat = stats[empId] ??
                              {
                                'present': 0,
                                'absent': 0,
                                'leave': 0,
                                'late': 0,
                                'total': 0,
                              };

                          sumPresent += stat['present']!;
                          sumAbsent += stat['absent']!;
                          sumLate += stat['late']!;
                          sumLeave += stat['leave']!;
                          sumTotal += stat['total']!;

                          final percentage = stat['total']! > 0
                              ? ((stat['present']! + stat['late']!) /
                              stat['total']! *
                              100)
                              .toStringAsFixed(1)
                              : '0.0';

                          return DataRow(cells: [
                            DataCell(Text(empId.toString())),
                            DataCell(Text(name)),
                            DataCell(Text(dept)),
                            DataCell(Text('${stat['total']}')),
                            DataCell(Text('${stat['present']}')),
                            DataCell(Text('${stat['absent']}')),
                            DataCell(Text('${stat['late']}')),
                            DataCell(Text('${stat['leave']}')),
                            DataCell(Text('$percentage%')),

                            for (int day = 1; day <= 31; day++)
                              DataCell(Text(
                                _getDailyStatus(empId, day, selectedMonthIndex,
                                    selectedYear, allRecords),
                                style: const TextStyle(fontSize: 12),
                              )),

                            DataCell(
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => UserAttendanceView(
                                        employeeId: empId,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('View'),
                              ),
                            ),
                          ]);
                        }).toList();

                        final totalPercentage = sumTotal > 0
                            ? (((sumPresent + sumLate) / sumTotal) * 100)
                            .toStringAsFixed(1)
                            : '0.0';

                        rows.add(DataRow(
                          color: MaterialStateProperty.all(Colors.indigo.shade50),
                          cells: [
                            const DataCell(Text('Average', style: TextStyle(fontWeight: FontWeight.bold))),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            DataCell(Text(avg(sumTotal), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(avg(sumPresent), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(avg(sumAbsent), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(avg(sumLate), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(avg(sumLeave), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text('$totalPercentage%', style: const TextStyle(fontWeight: FontWeight.bold))),
                            for (int i = 1; i <= 31; i++) const DataCell(Text('-')),
                            const DataCell(Text('-')),
                          ],
                        ));

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: DataTable(
                              columnSpacing: 12,
                              columns: [
                                const DataColumn(label: Text('Emp ID')),
                                const DataColumn(label: Text('Name')),
                                const DataColumn(label: Text('Dept')),
                                const DataColumn(label: Text('Working')),
                                const DataColumn(label: Text('P')),
                                const DataColumn(label: Text('A')),
                                const DataColumn(label: Text('L')),
                                const DataColumn(label: Text('Lv')),
                                const DataColumn(label: Text('%')),
                                for (int i = 1; i <= 31; i++) DataColumn(label: Text(i.toString())),
                                const DataColumn(label: Text('View')),
                              ],
                              rows: rows,
                            ),
                          ),
                        );
                      },
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

  String _getDailyStatus(
      String empId,
      int day,
      int selectedMonthIndex,
      String selectedYear,
      List<QueryDocumentSnapshot> allRecords,
      ) {
    final dateId =
        '$selectedYear-${selectedMonthIndex.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

    for (final doc in allRecords) {
      final parentId = doc.reference.parent.parent?.id ?? '';
      if (parentId != dateId) continue;

      final data = doc.data() as Map<String, dynamic>;
      if (data['employeeId'] != empId) continue;

      final status = (data['status'] ?? '').toLowerCase();
      if (status == 'present') return 'P';
      if (status == 'absent') return 'A';
      if (status == 'leave') return 'Lv';
      if (status == 'late') return 'L';
    }

    return '-';
  }

  Widget _buildSummaryCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: DB.colSync(_cid, C.attendance).doc(DateFormat('yyyy-MM-dd').format(DateTime.now())).collection(C.records).snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final present = docs.where((d) => d['status'] == 'present' || d['status'] == 'late').length;
        final late = docs.where((d) => d['status'] == 'late').length;

        return Container(
          padding: const EdgeInsets.all(16),
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _SummaryCard(label: 'Today Present', value: '$present', color: Colors.green, icon: Icons.people_rounded),
              _SummaryCard(label: 'Today Late', value: '$late', color: Colors.orange, icon: Icons.timer_rounded),
              _SummaryCard(label: 'Active Shifters', value: '24', color: Colors.blue, icon: Icons.schedule_rounded),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showManualEntryDialog() async {
    final _empIdController = TextEditingController();
    DateTime _date = DateTime.now();
    String _status = 'present';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Manual Attendance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _empIdController, decoration: const InputDecoration(labelText: 'Employee ID')),
              ListTile(
                title: Text('Date: ${DateFormat('yyyy-MM-dd').format(_date)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final pick = await showDatePicker(context: ctx, initialDate: _date, firstDate: DateTime(2024), lastDate: DateTime.now());
                  if (pick != null) setDialogState(() => _date = pick);
                },
              ),
              DropdownButton<String>(
                value: _status,
                items: ['present', 'late', 'absent', 'leave'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                onChanged: (v) => setDialogState(() => _status = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (_empIdController.text.isEmpty) return;
                final dateId = DateFormat('yyyy-MM-dd').format(_date);
                await DB.colSync(_cid, C.attendance).doc(dateId).collection(C.records).doc(_empIdController.text).set({
                  'employeeId': _empIdController.text,
                  'status': _status,
                  'date': dateId,
                  'timestamp': FieldValue.serverTimestamp(),
                  'manual': true,
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _SummaryCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }
}
