import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NewComplaintScreen extends StatefulWidget {
  final String userEmail;
  final String? userName; // Optional, for future use

  const NewComplaintScreen({
    super.key,
    required this.userEmail,
    this.userName,
  });

  @override
  State<NewComplaintScreen> createState() => _NewComplaintScreenState();
}

class _NewComplaintScreenState extends State<NewComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedDept;
  String? _selectedEmployee;
  List<String> _departments = [];
  List<Map<String, dynamic>> _departmentUsers = []; // {email, name}
  bool _loadingDepts = false;
  bool _loadingUsers = false;
  bool _submitting = false;

  // Palette
  static const Color _brandTeal = Color(0xFF001863);
  static const Color _card = Color(0xFFF6F8FB);

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchDepartments() async {
    setState(() {
      _loadingDepts = true;
      _departments = [];
      _selectedDept = null;
      _selectedEmployee = null;
      _departmentUsers = [];
    });

    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final set = <String>{};
      for (final doc in snapshot.docs) {
        final dep = doc.data()['department'];
        if (dep is String && dep.trim().isNotEmpty) set.add(dep.trim());
      }
      final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _departments = list;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load departments: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingDepts = false);
    }
  }

  Future<void> _fetchUsersByDept(String dept) async {
    setState(() {
      _loadingUsers = true;
      _departmentUsers = [];
      _selectedEmployee = null;
    });

    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('department', isEqualTo: dept)
          .get();

      final users = q.docs.map((d) {
        final data = d.data();
        return {
          'email': data['email'] ?? '',
          'name': (data['name'] ?? data['email'] ?? '').toString(),
        };
      }).where((u) => (u['email'] as String).isNotEmpty).toList();

      users.sort((a, b) =>
          (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));

      if (!mounted) return;
      setState(() {
        _departmentUsers = users;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load employees: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      await FirebaseFirestore.instance.collection('complaints').add({
        'submittedBy': widget.userEmail,
        'department': _selectedDept ?? '',
        // If no users in department, allow empty 'against'
        'against': _selectedEmployee ?? '',
        'subject': _subjectController.text.trim(),
        'message': _descriptionController.text.trim(),
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint submitted!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBFB),
      appBar: AppBar(
        backgroundColor: _brandTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('New Complaint', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _headerCard(),

                const SizedBox(height: 16),

                // ==== Form Card ====
                Card(
                  elevation: 2,
                  color: _card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Department
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Department',
                              style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedDept,
                          items: _departments
                              .map((dept) => DropdownMenuItem(
                            value: dept,
                            child: Text(dept,
                                overflow: TextOverflow.ellipsis),
                          ))
                              .toList(),
                          decoration: InputDecoration(
                            hintText: _loadingDepts ? 'Loading departments…' : 'Select department',
                            prefixIcon: const Icon(Icons.apartment),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          ),
                          validator: (v) => v == null ? 'Please select a department' : null,
                          onChanged: (dept) {
                            setState(() => _selectedDept = dept);
                            if (dept != null) _fetchUsersByDept(dept);
                          },
                        ),
                        const SizedBox(height: 14),

                        // Employee (only if department has users)
                        if (_loadingUsers)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text('Loading employees…'),
                            ),
                          ),
                        if (!_loadingUsers && _departmentUsers.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('To (Employee)',
                                style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedEmployee,
                            items: _departmentUsers
                                .map((u) => DropdownMenuItem<String>(
                              value: u['email'] as String,
                              child: Text(
                                '${u['name']} (${u['email']})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                                .toList(),
                            decoration: InputDecoration(
                              hintText: 'Select employee',
                              prefixIcon: const Icon(Icons.person),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            ),
                            onChanged: (email) => setState(() => _selectedEmployee = email),
                            validator: (v) {
                              if (_departmentUsers.isNotEmpty && v == null) {
                                return 'Select employee for the department';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (!_loadingUsers && _selectedDept != null && _departmentUsers.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: const Text(
                              'No employees found in this department. You can still submit the complaint to the department.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),

                        const SizedBox(height: 16),

                        // Subject
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Subject',
                              style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _subjectController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: 'Enter a short title',
                            prefixIcon: const Icon(Icons.title),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                          ),
                          validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Subject required' : null,
                        ),

                        const SizedBox(height: 14),

                        // Description
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Description',
                              style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descriptionController,
                          minLines: 5,
                          maxLines: 10,
                          decoration: InputDecoration(
                            hintText: 'Describe the issue with specific details…',
                            prefixIcon: const Icon(Icons.description),
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                          ),
                          validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Description required' : null,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Submit button (enabled unless submitting; actual checks done by validators)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _submitComplaint,
                    icon: _submitting
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(Icons.send, color: Colors.white),
                    label: Text(
                      _submitting ? 'Submitting…' : 'Submit Complaint',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandTeal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Header with a subtle gradient & quick tips
  Widget _headerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF0B2D9F), Color(0xFF1D5DF1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Submit New Complaint',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          SizedBox(height: 6),
          Text(
            'Choose a department, optionally select a recipient, add a subject and details. '
                'HR/concerned team will review and follow up.',
            style: TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
          ),
        ],
      ),
    );
  }
}
