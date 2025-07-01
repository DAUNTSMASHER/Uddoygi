import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TaskAssignmentScreen extends StatefulWidget {
  const TaskAssignmentScreen({super.key});

  @override
  State<TaskAssignmentScreen> createState() => _TaskAssignmentScreenState();
}

class _TaskAssignmentScreenState extends State<TaskAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _taskController = TextEditingController();
  String? selectedJuniorId;
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;

  Future<List<Map<String, dynamic>>> fetchJuniors() async {
    final users = await FirebaseFirestore.instance.collection('users').get();
    final currentUser = users.docs.firstWhere((e) => e.id == currentUserId);
    final currentJoinDate = currentUser['joinDate'];

    return users.docs.where((doc) {
      return doc['department'] == 'marketing' &&
          doc['joinDate'].compareTo(currentJoinDate) > 0;
    }).map((doc) => {'id': doc.id, 'name': doc['name']}).toList();
  }

  Future<void> assignTask() async {
    if (_formKey.currentState!.validate() && selectedJuniorId != null) {
      await FirebaseFirestore.instance.collection('tasks').add({
        'assigner': currentUserId,
        'assignee': selectedJuniorId,
        'description': _taskController.text.trim(),
        'status': 'pending',
        'timestamp': Timestamp.now(),
      });
      _taskController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task Assignment')),
      body: FutureBuilder(
        future: fetchJuniors(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final juniors = snapshot.data as List<Map<String, dynamic>>;
          return Column(
            children: [
              Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField(
                        hint: const Text('Select Junior'),
                        items: juniors.map((junior) {
                          return DropdownMenuItem(
                            value: junior['id'],
                            child: Text(junior['name']),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => selectedJuniorId = val as String),
                      ),
                      TextFormField(
                        controller: _taskController,
                        decoration: const InputDecoration(labelText: 'Task Description'),
                        validator: (value) => value!.isEmpty ? 'Required' : null,
                      ),
                      ElevatedButton(
                        onPressed: assignTask,
                        child: const Text('Assign Task'),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              const Text('Tasks You Assigned', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance.collection('tasks')
                      .where('assigner', isEqualTo: currentUserId).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final task = docs[index];
                        return ListTile(
                          title: Text(task['description']),
                          subtitle: Text('Status: ${task['status']}'),
                        );
                      },
                    );
                  },
                ),
              )
            ],
          );
        },
      ),
    );
  }
}