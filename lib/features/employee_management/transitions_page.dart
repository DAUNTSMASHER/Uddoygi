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
  String _transitionType = 'Promotion';
  String? _selectedPosition;
  bool _loading = false;

  // now lowercase to match your Firestore document field
  final List<String> _departments = ['hr', 'marketing', 'factory', 'admin'];

  // keyed by lowercase too
  final Map<String, List<String>> _positions = {
    'hr': ['HR Assistant', 'HR Executive', 'HR Manager', 'HR Director'],
    'marketing': [
      'Marketing Executive',
      'Marketing Specialist',
      'Marketing Manager',
      'Senior Marketing Manager',
      'Marketing Director'
    ],
    'factory': [
      'Machine Operator',
      'Senior Operator',
      'Production Supervisor',
      'Production Manager'
    ],
    'admin': [
      'Admin Assistant',
      'Office Manager',
      'Operations Manager',
      'Administrative Manager'
    ],
  };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_selectedEmployeeUid);
    final userSnap = await userRef.get();
    final userData = userSnap.data()!;
    final employeeName = (userData['fullName'] as String?)
        ?? (userData['name'] as String?)
        ?? 'Unnamed';

    // 1) record in promotions
    await FirebaseFirestore.instance.collection('promotions').add({
      'employeeUid': _selectedEmployeeUid,
      'employeeName': employeeName,
      'department': _selectedDept,
      'type': _transitionType.toLowerCase(),
      'newPosition': _selectedPosition,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2) update that user’s doc
    final updates = <String, dynamic>{ 'designation': _selectedPosition };
    if (_transitionType == 'Assignment') {
      updates['department'] = _selectedDept;
    }
    await userRef.update(updates);

    setState(() {
      _loading = false;
      _formKey.currentState!.reset();
      _selectedDept = null;
      _selectedEmployeeUid = null;
      _selectedPosition = null;
      _transitionType = 'Promotion';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transition recorded & user updated')),
    );
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Department selector
              DropdownButtonFormField<String>(
                value: _selectedDept,
                decoration: const InputDecoration(
                  labelText: 'Select Department',
                  border: OutlineInputBorder(),
                ),
                items: _departments.map((d) {
                  return DropdownMenuItem(
                    value: d,
                    child: Text(d.toUpperCase()),
                  );
                }).toList(),
                onChanged: (v) => setState(() {
                  _selectedDept = v;
                  _selectedEmployeeUid = null;
                  _selectedPosition = null;
                }),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Employee dropdown (filtered by lowercase dept)
              if (_selectedDept != null)
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('department', isEqualTo: _selectedDept)
                      .snapshots(),
                  builder: (ctx, snap) {
                    if (snap.hasError) {
                      return const Text('Error loading employees');
                    }
                    if (!snap.hasData) {
                      return const LinearProgressIndicator();
                    }
                    final docs = snap.data!.docs.toList()
                      ..sort((a, b) {
                        final na = (a.data()['fullName'] as String?) ?? '';
                        final nb = (b.data()['fullName'] as String?) ?? '';
                        return na.compareTo(nb);
                      });

                    return DropdownButtonFormField<String>(
                      value: _selectedEmployeeUid,
                      decoration: const InputDecoration(
                        labelText: 'Select Employee',
                        border: OutlineInputBorder(),
                      ),
                      items: docs.map((d) {
                        final data = d.data();
                        final name = (data['fullName'] as String?)
                            ?? (data['name'] as String?)
                            ?? 'Unnamed';
                        return DropdownMenuItem(
                          value: d.id,
                          child: Text(name),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setState(() => _selectedEmployeeUid = v),
                      validator: (v) => v == null ? 'Required' : null,
                    );
                  },
                ),
              const SizedBox(height: 16),

              // Promotion vs Assignment
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Promotion'),
                      value: 'Promotion',
                      groupValue: _transitionType,
                      activeColor: _darkBlue,
                      onChanged: (v) =>
                          setState(() => _transitionType = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Assignment'),
                      value: 'Assignment',
                      groupValue: _transitionType,
                      activeColor: _darkBlue,
                      onChanged: (v) =>
                          setState(() => _transitionType = v!),
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
                    labelText: _transitionType == 'Promotion'
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
                  onChanged: (v) =>
                      setState(() => _selectedPosition = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
              const SizedBox(height: 24),

              // Submit button
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _darkBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                )
                    : const Text('Submit', style: TextStyle(fontSize: 16)),
              ),

              const SizedBox(height: 32),
              Text(
                'Latest Promotions & Assignments',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _darkBlue),
              ),
              const Divider(),

              // recent entries
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('promotions')
                    .orderBy('timestamp', descending: true)
                    .limit(10)
                    .snapshots(),
                builder: (ctx, snap) {
                  if (snap.hasError) {
                    return const Center(
                        child: Text('Error loading history'));
                  }
                  if (!snap.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  final docs = snap.data!.docs;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (c, i) {
                      final d = docs[i].data();
                      final name = d['employeeName'] as String? ?? '';
                      final type = (d['type'] as String? ?? '')
                          .capitalize();
                      final pos = d['newPosition'] as String? ?? '';
                      final ts =
                      (d['timestamp'] as Timestamp?)?.toDate();
                      final dateStr = ts != null
                          ? '${ts.day}/${ts.month}/${ts.year}'
                          : '';
                      return ListTile(
                        leading: Icon(
                          type == 'Promotion'
                              ? Icons.arrow_upward
                              : Icons.swap_horiz,
                          color: _darkBlue,
                        ),
                        title: Text(name),
                        subtitle: Text('$type to $pos on $dateStr'),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() => isEmpty
      ? ''
      : this[0].toUpperCase() + substring(1).toLowerCase();
}
