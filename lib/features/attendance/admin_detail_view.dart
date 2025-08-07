import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class AdminDetailView extends StatefulWidget {
  const AdminDetailView({super.key});

  @override
  State<AdminDetailView> createState() => _AdminDetailViewState();
}

class _AdminDetailViewState extends State<AdminDetailView> {
  String selectedMonth = DateFormat('MMMM').format(DateTime.now());
  String selectedYear = DateFormat('yyyy').format(DateTime.now());
  String? _errorMessage;

  final List<String> months =
  List.generate(12, (i) => DateFormat('MMMM').format(DateTime(0, i + 1)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Attendance Summary'),
        backgroundColor: _darkBlue,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: selectedMonth,
                  items: months
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedMonth = v!),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: selectedYear,
                  items: List.generate(5, (i) {
                    final y = (DateTime.now().year - i).toString();
                    return DropdownMenuItem(value: y, child: Text(y));
                  }),
                  onChanged: (v) => setState(() => selectedYear = v!),
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
              stream: FirebaseFirestore.instance
                  .collection('attendance')
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
                  stream: FirebaseFirestore.instance
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
                      future: FirebaseFirestore.instance
                          .collection('users')
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
                                  // existing logic
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
}
