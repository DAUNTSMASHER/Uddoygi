import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNoticeScreen extends StatefulWidget {
  const AdminNoticeScreen({super.key});

  @override
  State<AdminNoticeScreen> createState() => _AdminNoticeScreenState();
}

class _AdminNoticeScreenState extends State<AdminNoticeScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _loading = false;

  Future<void> _publishNotice() async {
    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();

    if (title.isEmpty || description.isEmpty) return;

    setState(() => _loading = true);

    try {
      await FirebaseFirestore.instance.collection('notices').add({
        'title': title,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'publishedBy': 'admin',
      });

      _titleController.clear();
      _descriptionController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Notice published successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to publish: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publish Notice'),
        backgroundColor: Colors.purple.shade400,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.publish),
                label: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Publish Notice'),
                onPressed: _loading ? null : _publishNotice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}