import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NewMessageTab extends StatefulWidget {
  final String userEmail;
  final String? userName; // Optional, if you want to display

  const NewMessageTab({super.key, required this.userEmail, this.userName});

  @override
  State<NewMessageTab> createState() => _NewMessageTabState();
}

class _NewMessageTabState extends State<NewMessageTab> {
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  String? _selectedDept;
  List<String> _departments = [];
  List<Map<String, dynamic>> _departmentUsers = []; // {email, name}
  String? _selectedRecipient;

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
      _selectedRecipient = null;
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

  Future<void> _sendMessage() async {
    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'from': widget.userEmail,
        'fromName': widget.userName ?? widget.userEmail,
        'to': [_selectedRecipient], // as array for consistency
        'subject': _subjectController.text.trim(),
        'body': _bodyController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent!')),
      );
      setState(() {
        _selectedDept = null;
        _departmentUsers = [];
        _selectedRecipient = null;
      });
      _subjectController.clear();
      _bodyController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
                'Compose Message',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
              const SizedBox(height: 16),
              TextFormField(
                enabled: false,
                initialValue: widget.userEmail,
                decoration: const InputDecoration(
                  labelText: 'From',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color(0xFFF6F8FB),
                  disabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.indigo)),
                ),
                style: const TextStyle(color: Colors.indigo),
              ),
              const SizedBox(height: 14),
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
                onChanged: (dept) {
                  setState(() => _selectedDept = dept);
                  if (dept != null) {
                    _fetchUsersByDept(dept);
                  }
                },
              ),
              const SizedBox(height: 10),
              if (_departmentUsers.isNotEmpty)
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _selectedRecipient,
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
                    labelText: 'To (Select Recipient)',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFFF6F8FB),
                  ),
                  onChanged: (email) {
                    setState(() {
                      _selectedRecipient = email;
                    });
                  },
                ),
              const SizedBox(height: 10),
              TextField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color(0xFFF6F8FB),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bodyController,
                minLines: 6,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  prefixIcon: Icon(Icons.message),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color(0xFFF6F8FB),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send, color: Colors.white),
                  label: const Text('Send', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _selectedRecipient != null &&
                      _subjectController.text.trim().isNotEmpty &&
                      _bodyController.text.trim().isNotEmpty
                      ? _sendMessage
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
