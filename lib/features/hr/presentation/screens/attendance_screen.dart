import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'All'; // Present, Absent, Leave, All

  final List<String> _statuses = ['All', 'Present', 'Absent', 'Leave'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: const Text('Attendance', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Picker
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Date:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today, color: Colors.indigo),
                  label: Text(
                    DateFormat('yyyy-MM-dd').format(_selectedDate),
                    style: const TextStyle(color: Colors.indigo),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Status Filter Chips
            Wrap(
              spacing: 8,
              children: _statuses.map((status) {
                final isSelected = _selectedStatus == status;
                return ChoiceChip(
                  label: Text(status),
                  selected: isSelected,
                  selectedColor: Colors.indigo,
                  backgroundColor: Colors.grey[200],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedStatus = status);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Attendance List (Filtered)
            Expanded(
              child: ListView.builder(
                itemCount: 10,
                itemBuilder: (context, index) {
                  String status = (index % 3 == 0)
                      ? 'Absent'
                      : (index % 2 == 0)
                      ? 'Leave'
                      : 'Present';

                  if (_selectedStatus != 'All' && _selectedStatus != status) {
                    return const SizedBox.shrink();
                  }

                  Color iconColor = status == 'Present'
                      ? Colors.green
                      : status == 'Absent'
                      ? Colors.red
                      : Colors.orange;

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.indigo,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text('Employee ${index + 1}'),
                      subtitle: Text('Status: $status'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: iconColor, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            status,
                            style: TextStyle(
                              color: iconColor,
                              fontWeight: FontWeight.w600,
                            ),
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
      ),

      // FAB: Mark Attendance
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.edit_calendar),
        label: const Text('Mark Attendance'),
        onPressed: () => _showMarkAttendanceSheet(context),
      ),
    );
  }

  void _showMarkAttendanceSheet(BuildContext context) {
    String selectedStatus = 'Present';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Mark Attendance', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Employee ID or Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Present', 'Absent', 'Leave']
                      .map((status) => DropdownMenuItem(
                    value: status,
                    child: Text(status),
                  ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) selectedStatus = value;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Submit attendance entry here
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('Save'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
