// lib/features/factory/presentation/screens/attendance_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color _deepPurple = Color(0xFF0B3552);
const Color _white      = Colors.white;

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate    = DateTime.now();
  String _selectedStatus    = 'All';
  final List<String> _statuses = ['All', 'Present', 'Absent', 'Leave'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _white,
      appBar: AppBar(
        backgroundColor: _deepPurple,
        title: const Text('Employee Attendance'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ─── Filters ───────────────────────────────────────────
          Container(
            color: _deepPurple,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: _white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat.yMMMMd().format(_selectedDate),
                        style: const TextStyle(color: _white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: _selectedStatus,
                  dropdownColor: _deepPurple,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.filter_list, color: _white),
                  items: _statuses.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(s, style: const TextStyle(color: _white)),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedStatus = v!),
                ),
              ],
            ),
          ),

          // ─── Attendance List ───────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 12,
              itemBuilder: (ctx, i) {
                // demo status, replace with your real data
                final status = (i % 3 == 0)
                    ? 'Absent'
                    : (i % 2 == 0)
                    ? 'Leave'
                    : 'Present';
                if (_selectedStatus != 'All' && _selectedStatus != status) {
                  return const SizedBox.shrink();
                }

                Color dotColor;
                switch (status) {
                  case 'Present':
                    dotColor = Colors.green;
                    break;
                  case 'Absent':
                    dotColor = Colors.red;
                    break;
                  default:
                    dotColor = Colors.orange;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: _deepPurple,
                      child: const Icon(Icons.person, color: _white),
                    ),
                    title: Text(
                      'Employee ${i + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Checked in on ${DateFormat.jm().format(DateTime.now().subtract(Duration(minutes: i * 5)))}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: dotColor, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          status,
                          style: TextStyle(color: dotColor, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // ─── FAB ─────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _deepPurple,
        foregroundColor: _white,
        icon: const Icon(Icons.add_task),
        label: const Text('Mark Attendance'),
        onPressed: () => _showMarkAttendanceSheet(context),
      ),
    );
  }

  void _showMarkAttendanceSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    String selected = 'Present';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: MediaQuery.of(ctx).viewInsets,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Mark Attendance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Employee Name or ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selected,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Present', 'Absent', 'Leave']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => selected = v!,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _deepPurple,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      // TODO: save attendance
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
