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

class _RecipientLite {
  final String uid;
  final String email;
  final String name;
  const _RecipientLite({required this.uid, required this.email, required this.name});
}

class _NewMessageTabState extends State<NewMessageTab> {
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  String? _selectedDept;
  List<String> _departments = [];

  List<_RecipientLite> _departmentUsers = [];
  String? _selectedRecipientUid;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    final snap = await FirebaseFirestore.instance.collection('users').get();
    final depts = snap.docs
        .map((d) => (d.data()['department'] as String? ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (!mounted) return;
    setState(() => _departments = depts);
  }

  Future<void> _loadUsersForDept(String dept) async {
    final q = await FirebaseFirestore.instance
        .collection('users')
        .where('department', isEqualTo: dept)
        .get();

    final users = q.docs.map((d) {
      final data = d.data();
      final email = (data['personalEmail'] as String?)?.trim().toLowerCase() ??
          (data['officeEmail'] as String?)?.trim().toLowerCase() ??
          (data['email'] as String?)?.trim().toLowerCase() ??
          '';
      final name = (data['fullName'] as String?)?.trim() ??
          (data['name'] as String?)?.trim() ??
          email;
      return _RecipientLite(uid: d.id, email: email, name: name);
    }).where((u) => u.email.isNotEmpty && u.email != widget.userEmail.toLowerCase()).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (!mounted) return;
    setState(() {
      _departmentUsers = users;
      _selectedRecipientUid = null;
    });
  }

  Future<void> _sendMessage() async {
    final toUid = _selectedRecipientUid;
    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();

    if (toUid == null || subject.isEmpty || body.isEmpty) return;

    try {
      final recipient = _departmentUsers.firstWhere((u) => u.uid == toUid);

      // 1) Save the message
      final msgRef = await FirebaseFirestore.instance.collection('messages').add({
        'from'      : widget.userEmail.toLowerCase(),
        'fromName'  : widget.userName ?? widget.userEmail,
        'to'        : [recipient.email],      // keep array format
        'toUid'     : recipient.uid,
        'toName'    : recipient.name,
        'subject'   : subject,
        'body'      : body,
        'timestamp' : FieldValue.serverTimestamp(), // <-- used by lists
      });

      // 2) In-app notification document (write both timestamp & createdAt for compatibility)
      final now = DateTime.now();
      await FirebaseFirestore.instance.collection('notifications').add({
        'to'         : recipient.email,
        'toUserId'   : recipient.uid,
        'title'      : 'New message',
        'body'       : '${widget.userName ?? widget.userEmail}: $subject',
        'type'       : 'message',
        'messageId'  : msgRef.id,
        'read'       : false,
        'timestamp'  : Timestamp.fromDate(now), // <-- NotificationPage reads this
        'createdAt'  : Timestamp.fromDate(now),
      });

      // 3) Queue push for the background worker (Firestore->FCM)
      await FirebaseFirestore.instance.collection('alert_dispatch').add({
        'alertId'    : msgRef.id,
        'uids'       : [recipient.uid], // worker resolves tokens
        'title'      : 'New message',
        'body'       : '${widget.userName ?? widget.userEmail}: $subject',
        'priority'   : 'normal',
        'status'     : 'pending',
        'createdAt'  : FieldValue.serverTimestamp(),
        'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Message sent!')));

      // Reset UI
      setState(() {
        _selectedDept = null;
        _departmentUsers = [];
        _selectedRecipientUid = null;
      });
      _subjectController.clear();
      _bodyController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    }
  }

  bool get _canSend =>
      _selectedRecipientUid != null &&
          _subjectController.text.trim().isNotEmpty &&
          _bodyController.text.trim().isNotEmpty;

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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Compose Message',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _darkBlue),
              ),
              const SizedBox(height: 16),

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

              if (_departmentUsers.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedRecipientUid,
                  decoration: const InputDecoration(
                    labelText: 'To',
                    prefixIcon: Icon(Icons.person, color: _darkBlue),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFFF6F8FB),
                  ),
                  items: _departmentUsers
                      .map((u) => DropdownMenuItem(
                    value: u.uid,
                    child: Text(
                      '${u.name} (${u.email})',
                      style: const TextStyle(color: _darkBlue),
                    ),
                  ))
                      .toList(),
                  onChanged: (uid) => setState(() => _selectedRecipientUid = uid),
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

              TextField(
                controller: _subjectController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  prefixIcon: Icon(Icons.title, color: _darkBlue),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color(0xFFF6F8FB),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _bodyController,
                onChanged: (_) => setState(() {}),
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

              ElevatedButton.icon(
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text('Send', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canSend ? _darkBlue : Colors.grey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _canSend ? _sendMessage : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
