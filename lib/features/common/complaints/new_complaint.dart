import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NewComplaintScreen extends StatefulWidget {
  final String userEmail;
  final String? userName; // Optional, for future use

  const NewComplaintScreen({super.key, required this.userEmail, this.userName});

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
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    final all = snapshot.docs
        .map((doc) => doc.data()['department'] as String?)
        .where((d) => d != null && d.isNotEmpty)
        .toSet()
        .toList();
    setState(() {
      _departments = all.cast<String>();
    });
  }

  Future<void> _fetchUsersByDept(String dept) async {
    setState(() {
      _departmentUsers = [];
      _selectedEmployee = null;
    });
    final q = await FirebaseFirestore.instance
        .collection('users')
        .where('department', isEqualTo: dept)
        .get();
    setState(() {
      _departmentUsers = q.docs
          .map((d) => {
        'email': d['email'],
        'name': d['name'] ?? d['email']
      })
          .toList();
    });
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      await FirebaseFirestore.instance.collection('complaints').add({
        'submittedBy': widget.userEmail,
        'department': _selectedDept ?? "",
        'against': _selectedEmployee ?? "",
        'subject': _subjectController.text.trim(),
        'message': _descriptionController.text.trim(),
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint submitted!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 18, right: 18, top: 22, bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: Form(
        key: _formKey,
        child: Card(
          color: Colors.indigo[50],
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Submit New Complaint",
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
                const SizedBox(height: 18),

                // Department dropdown
                DropdownButtonFormField<String>(
                  value: _selectedDept,
                  items: _departments
                      .map((dept) => DropdownMenuItem(
                    value: dept,
                    child: Text(dept, style: const TextStyle(color: Colors.indigo)),
                  ))
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: 'Select Department',
                    prefixIcon: Icon(Icons.apartment),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFFF6F8FB),
                  ),
                  validator: (v) => v == null ? "Please select department" : null,
                  onChanged: (dept) {
                    setState(() => _selectedDept = dept);
                    if (dept != null) {
                      _fetchUsersByDept(dept);
                    }
                  },
                ),
                const SizedBox(height: 10),

                // Employee dropdown
                if (_departmentUsers.isNotEmpty)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedEmployee,
                    items: _departmentUsers
                        .map((u) => DropdownMenuItem<String>(
                      value: u['email'],
                      child: Text(
                        '${u['name']} (${u['email']})',
                        style: const TextStyle(color: Colors.indigo),
                      ),
                    ))
                        .toList(),
                    decoration: const InputDecoration(
                      labelText: 'To (Select Employee)',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Color(0xFFF6F8FB),
                    ),
                    onChanged: (email) {
                      setState(() => _selectedEmployee = email);
                    },
                    validator: (v) {
                      if (_departmentUsers.isNotEmpty && v == null) {
                        return "Select employee for the department";
                      }
                      return null;
                    },
                  ),
                if (_departmentUsers.isNotEmpty) const SizedBox(height: 10),

                // Subject
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    prefixIcon: Icon(Icons.title),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFFF6F8FB),
                  ),
                  validator: (v) => v!.isEmpty ? "Subject required" : null,
                ),
                const SizedBox(height: 10),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  minLines: 4,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFFF6F8FB),
                  ),
                  validator: (v) => v!.isEmpty ? "Description required" : null,
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _submitting
                        ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ))
                        : const Icon(Icons.send, color: Colors.white),
                    label: Text(_submitting ? 'Submitting...' : 'Submit',
                        style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _submitting ||
                        _selectedDept == null ||
                        _selectedEmployee == null ||
                        _subjectController.text.trim().isEmpty ||
                        _descriptionController.text.trim().isEmpty
                        ? null
                        : _submitComplaint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
