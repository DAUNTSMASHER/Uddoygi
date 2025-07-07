import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class NewMessageTab extends StatefulWidget {
  final String userEmail;
  final String? userName;

  const NewMessageTab({
    Key? key,
    required this.userEmail,
    this.userName,
  }) : super(key: key);

  @override
  State<NewMessageTab> createState() => _NewMessageTabState();
}

class _NewMessageTabState extends State<NewMessageTab> {
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  String? _selectedDept;
  List<String> _departments = [];
  List<Map<String, String>> _departmentUsers = []; // { email, name }
  String? _selectedRecipient;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    // grab all distinct department values
    final snap = await FirebaseFirestore.instance.collection('users').get();
    final depts = snap.docs
        .map((d) => (d.data()['department'] as String? ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    setState(() => _departments = depts);
  }

  Future<void> _loadUsersForDept(String dept) async {
    final q = await FirebaseFirestore.instance
        .collection('users')
        .where('department', isEqualTo: dept)
        .get();

    final users = q.docs.map((d) {
      final data = d.data();
      final email = (data['personalEmail'] as String?)
          ?.trim()
          .toLowerCase() ??
          (data['officeEmail'] as String?)
              ?.trim()
              .toLowerCase() ??
          '';
      final name = (data['fullName'] as String?)
          ?.trim() ??
          (data['name'] as String?)?.trim() ??
          email;
      return {'email': email, 'name': name};
    })
    // optional: filter out yourself
        .where((u) => u['email'] != widget.userEmail && u['email']!.isNotEmpty)
        .toList()
      ..sort((a, b) => a['name']!.compareTo(b['name']!));

    setState(() {
      _departmentUsers = users;
      _selectedRecipient = null;
    });
  }

  Future<void> _sendMessage() async {
    if (_selectedRecipient == null ||
        _subjectController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) return;

    await FirebaseFirestore.instance.collection('messages').add({
      'from': widget.userEmail,
      'fromName': widget.userName ?? widget.userEmail,
      'to': [_selectedRecipient],
      'subject': _subjectController.text.trim(),
      'body': _bodyController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Message sent!')));

    setState(() {
      _selectedDept = null;
      _departmentUsers = [];
      _selectedRecipient = null;
    });
    _subjectController.clear();
    _bodyController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: Colors.indigo[50],
        elevation: 3,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Compose Message',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _darkBlue),
              ),
              const SizedBox(height: 16),

              // From (disabled)
              TextFormField(
                enabled: false,
                initialValue: widget.userEmail,
                decoration: const InputDecoration(
                  labelText: 'From',
                  prefixIcon: Icon(Icons.email, color: _darkBlue),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color(0xFFF6F8FB),
                ),
                style: const TextStyle(color: _darkBlue),
              ),
              const SizedBox(height: 16),

              // Department selector
              DropdownButtonFormField<String>(
                value: _selectedDept,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  prefixIcon: Icon(Icons.apartment, color: _darkBlue),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color(0xFFF6F8FB),
                ),
                items: _departments
                    .map((dept) => DropdownMenuItem(
                  value: dept,
                  child: Text(dept, style: const TextStyle(color: _darkBlue)),
                ))
                    .toList(),
                onChanged: (dept) {
                  setState(() => _selectedDept = dept);
                  if (dept != null) _loadUsersForDept(dept);
                },
              ),
              const SizedBox(height: 16),

              // Recipient selector
              if (_departmentUsers.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedRecipient,
                  decoration: const InputDecoration(
                    labelText: 'To',
                    prefixIcon: Icon(Icons.person, color: _darkBlue),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFFF6F8FB),
                  ),
                  items: _departmentUsers
                      .map((u) => DropdownMenuItem(
                    value: u['email'],
                    child: Text(
                      '${u['name']} (${u['email']})',
                      style: const TextStyle(color: _darkBlue),
                    ),
                  ))
                      .toList(),
                  onChanged: (email) =>
                      setState(() => _selectedRecipient = email),
                )
              else if (_selectedDept != null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No users found in this department.',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              const SizedBox(height: 16),

              // Subject
              TextField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  prefixIcon: Icon(Icons.title, color: _darkBlue),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color(0xFFF6F8FB),
                ),
              ),
              const SizedBox(height: 16),

              // Message body
              TextField(
                controller: _bodyController,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  prefixIcon: Icon(Icons.message, color: _darkBlue),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color(0xFFF6F8FB),
                ),
              ),
              const SizedBox(height: 24),

              // Send button
              ElevatedButton.icon(
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text('Send', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _darkBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: (_selectedRecipient != null &&
                    _subjectController.text.trim().isNotEmpty &&
                    _bodyController.text.trim().isNotEmpty)
                    ? _sendMessage
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
