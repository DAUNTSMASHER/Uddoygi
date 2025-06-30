import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedDepartment = 'marketing';

  final List<String> _departments = ['admin', 'hr', 'marketing', 'factory'];
  bool _loading = false;

  Future<void> _createEmployee() async {
    setState(() => _loading = true);
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': _emailController.text.trim(),
        'department': _selectedDepartment,
        'isHead': false,
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Employee added successfully.")),
      );

      _emailController.clear();
      _passwordController.clear();
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.message}")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _setAsDepartmentHead(String uid) async {
    final doc = _firestore.collection('users').doc(uid);
    final data = (await doc.get()).data();
    final dept = data?['department'];

    // Remove previous head if exists
    final existingHead = await _firestore
        .collection('users')
        .where('department', isEqualTo: dept)
        .where('isHead', isEqualTo: true)
        .get();

    for (var head in existingHead.docs) {
      await head.reference.update({'isHead': false});
    }

    // Set current as new head
    await doc.update({'isHead': true});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Head assigned for $dept")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Management'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Employee Email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedDepartment,
                  items: _departments
                      .map((dept) => DropdownMenuItem(value: dept, child: Text(dept.toUpperCase())))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedDepartment = value!),
                  decoration: const InputDecoration(labelText: 'Department'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _createEmployee,
                  child: _loading
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator())
                      : const Text("Add Employee"),
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text("All Employees", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Failed to load employees'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No employees found'));
                }

                final users = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final data = users[index].data() as Map<String, dynamic>;
                    final uid = users[index].id;
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(data['email'] ?? 'Unknown'),
                      subtitle: Text('Dept: ${data['department']}'),
                      trailing: data['isHead'] == true
                          ? const Chip(label: Text("Head", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green)
                          : ElevatedButton(
                        onPressed: () => _setAsDepartmentHead(uid),
                        child: const Text("Make Head"),
                      ),
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
}
