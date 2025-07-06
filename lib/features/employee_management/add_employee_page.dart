import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/services/local_storage_service.dart';

class AddEmployeePage extends StatefulWidget {
  const AddEmployeePage({super.key});

  @override
  State<AddEmployeePage> createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedDepartment = 'marketing';
  bool _loading = false;
  String? _lastEmployeeId;
  String? _addedByEmail;

  static const _darkBlue = Color(0xFF0D47A1);
  final List<String> _departments = ['admin', 'hr', 'marketing', 'factory'];

  @override
  void initState() {
    super.initState();
    _loadSession();
    _fetchLastEmployeeId();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    if (session != null && mounted) {
      setState(() {
        _addedByEmail = session['email'] as String?;
      });
    }
  }

  Future<void> _fetchLastEmployeeId() async {
    final snap = await _firestore
        .collection('users')
        .orderBy('employeeId', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty && mounted) {
      setState(() {
        _lastEmployeeId = snap.docs.first.data()['employeeId'] as String?;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Confirm Add Employee'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReviewRow('Added by', _addedByEmail ?? 'Unknown'),
            _buildReviewRow('Employee ID', _idController.text.trim()),
            _buildReviewRow('Email', _emailController.text.trim()),
            _buildReviewRow('Department', _selectedDepartment),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _darkBlue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await _firestore.collection('users').doc(cred.user!.uid).set({
        'employeeId': _idController.text.trim(),
        'email': _emailController.text.trim(),
        'department': _selectedDepartment,
        'addedBy': _addedByEmail,
        'isHead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Success'),
          content: const Text('Employee added successfully.'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _darkBlue),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label:',
              style: TextStyle(fontWeight: FontWeight.bold, color: _darkBlue)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _darkBlue),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _darkBlue),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _darkBlue, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add Employee', style: TextStyle(color: Colors.white)),
        backgroundColor: _darkBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [


                    // Employee ID
                    TextFormField(
                      controller: _idController,
                      decoration: _inputDecoration('Employee ID'),
                      validator: (v) =>
                      (v != null && v.trim().isNotEmpty) ? null : 'Enter an Employee ID',
                    ),
                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      decoration: _inputDecoration('Email / Username'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                      v != null && v.contains('@') ? null : 'Enter a valid email',
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      decoration: _inputDecoration('Password'),
                      obscureText: true,
                      validator: (v) => (v != null && v.length >= 6)
                          ? null
                          : 'Min 6 characters',
                    ),
                    const SizedBox(height: 16),

                    // Department
                    DropdownButtonFormField<String>(
                      value: _selectedDepartment,
                      decoration: _inputDecoration('Department'),
                      items: _departments
                          .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(d.toUpperCase(),
                            style: const TextStyle(color: _darkBlue)),
                      ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedDepartment = v!),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _darkBlue),
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Submit',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ——— BOTTOM BANNER ———
            if (_lastEmployeeId != null)
              Container(
                width: double.infinity,
                color: _darkBlue,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Last added employee ID was $_lastEmployeeId',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
