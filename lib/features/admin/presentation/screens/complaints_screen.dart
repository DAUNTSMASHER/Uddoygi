import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _addRecommendation(String complaintId, String recommendation) async {
    await _firestore.collection('complaints').doc(complaintId).update({
      'recommendation': recommendation,
      'status': 'forwarded_to_hr',
      'adminUpdatedAt': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recommendation sent to HR.')),
    );
  }

  void _showRecommendationDialog(String complaintId) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Recommendation'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Write recommendation for HR...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _addRecommendation(complaintId, controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints Management'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('complaints').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final complaints = snapshot.data!.docs;

          if (complaints.isEmpty) {
            return const Center(child: Text('No complaints found.'));
          }

          return ListView.builder(
            itemCount: complaints.length,
            itemBuilder: (context, index) {
              final data = complaints[index].data() as Map<String, dynamic>;
              final complaintId = complaints[index].id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(data['subject'] ?? 'No Subject'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('From: ${data['submittedBy'] ?? 'Unknown'}'),
                      const SizedBox(height: 4),
                      Text('Message: ${data['message'] ?? ''}'),
                      if (data['recommendation'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Recommendation: ${data['recommendation']}',
                              style: const TextStyle(color: Colors.blue)),
                        ),
                      const SizedBox(height: 4),
                      Text('Status: ${data['status'] ?? 'pending'}',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_note),
                    onPressed: () => _showRecommendationDialog(complaintId),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
