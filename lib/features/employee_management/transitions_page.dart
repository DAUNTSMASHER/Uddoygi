import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class TransitionsPage extends StatefulWidget {
  const TransitionsPage({Key? key}) : super(key: key);

  @override
  State<TransitionsPage> createState() => _TransitionsPageState();
}

class _TransitionsPageState extends State<TransitionsPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedDept;
  String? _selectedEmployeeUid;
  String _transitionType = 'promotion';
  String? _selectedPosition;
  bool _loading = false;

  // Define department list
  final List<String> _departments = ['hr', 'marketing', 'factory', 'admin'];

  // Position map per department
  final Map<String, List<String>> _positions = {
    'hr': [
      'HR Assistant', 'HR Executive', 'HR Manager', 'HR Director'
    ],
    'marketing': [
      'Marketing Executive', 'Marketing Specialist', 'Marketing Manager', 'Senior Marketing Manager', 'Marketing Director'
    ],
    'factory': [
      'Machine Operator', 'Senior Operator', 'Production Supervisor', 'Production Manager'
    ],
    'admin': [
      'Admin Assistant', 'Office Manager', 'Operations Manager', 'Administrative Manager'
    ],
  };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    // Fetch selected employee name
    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_selectedEmployeeUid)
        .get();
    final name = userSnap.data()?['fullName'] as String? ??
        userSnap.data()?['email'] as String? ?? 'Unknown';

    // Save transition
    await FirebaseFirestore.instance.collection('promotions').add({
      'employeeUid': _selectedEmployeeUid,
      'employeeName': name,
      'department': _selectedDept,
      'type': _transitionType,
      'newPosition': _selectedPosition,
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transition recorded successfully')),
    );
    _formKey.currentState!.reset();
    setState(() {
      _selectedDept = null;
      _selectedEmployeeUid = null;
      _selectedPosition = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promotion & Assignment'),
        backgroundColor: _darkBlue,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Department
                  DropdownButtonFormField<String>(
                    value: _selectedDept,
                    decoration: const InputDecoration(
                      labelText: 'Select Department',
                      border: OutlineInputBorder(),
                    ),
                    items: _departments
                        .map((d) => DropdownMenuItem(
                      value: d,
                      child: Text(d.toUpperCase()),
                    ))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedDept = v;
                      _selectedEmployeeUid = null;
                      _selectedPosition = null;
                    }),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Employee dropdown (depends on dept)
                  if (_selectedDept != null)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('department', isEqualTo: _selectedDept)
                          .orderBy('fullName')
                          .snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData) return const CircularProgressIndicator();
                        final docs = snap.data!.docs;
                        return DropdownButtonFormField<String>(
                          value: _selectedEmployeeUid,
                          decoration: const InputDecoration(
                            labelText: 'Select Employee',
                            border: OutlineInputBorder(),
                          ),
                          items: docs
                              .map((d) {
                            final data = d.data() as Map<String, dynamic>;
                            final name = data['fullName'] as String? ?? data['email'];
                            return DropdownMenuItem(
                              value: d.id,
                              child: Text(name),
                            );
                          })
                              .toList(),
                          onChanged: (v) => setState(() => _selectedEmployeeUid = v),
                          validator: (v) => v == null ? 'Required' : null,
                        );
                      },
                    ),
                  const SizedBox(height: 16),

                  // Transition type
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Promotion'),
                          value: 'promotion',
                          groupValue: _transitionType,
                          onChanged: (v) => setState(() => _transitionType = v!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Assignment'),
                          value: 'assignment',
                          groupValue: _transitionType,
                          onChanged: (v) => setState(() => _transitionType = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Position dropdown
                  if (_selectedDept != null)
                    DropdownButtonFormField<String>(
                      value: _selectedPosition,
                      decoration: InputDecoration(
                        labelText: _transitionType == 'promotion'
                            ? 'Promoted To'
                            : 'Assigned To',
                        border: const OutlineInputBorder(),
                      ),
                      items: _positions[_selectedDept]!
                          .map((pos) => DropdownMenuItem(
                        value: pos,
                        child: Text(pos),
                      ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedPosition = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),

                  const SizedBox(height: 24),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _darkBlue,
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: _loading
                          ? const CircularProgressIndicator(
                          color: Colors.white)
                          : const Text('Submit', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Text(
              'Latest Promotions & Assignments',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _darkBlue),
            ),
            const Divider(),

            // List recent notices
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('promotions')
                  .orderBy('timestamp', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text('Error loading notices'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No notices yet'));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final name = d['employeeName'] as String? ?? 'Unknown';
                    final type = d['type'] as String? ?? '';
                    final pos = d['newPosition'] as String? ?? '';
                    final ts = (d['timestamp'] as Timestamp?)?.toDate();
                    final dateStr = ts != null
                        ? '${ts.day}/${ts.month}/${ts.year}'
                        : '';
                    return ListTile(
                      leading: Icon(
                        type == 'promotion' ? Icons.arrow_upward : Icons.swap_horiz,
                        color: _darkBlue,
                      ),
                      title: Text('$name'),
                      subtitle: Text(
                          '${type.capitalize()} to $pos on $dateStr'),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Extension to capitalize type
extension StringExtension on String {
  String capitalize() => isEmpty ? '' : this[0].toUpperCase() + substring(1);
}
