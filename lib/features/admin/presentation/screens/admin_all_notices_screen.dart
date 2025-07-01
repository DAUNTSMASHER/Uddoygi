import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminAllNoticesScreen extends StatefulWidget {
  const AdminAllNoticesScreen({Key? key}) : super(key: key);

  @override
  State<AdminAllNoticesScreen> createState() => _AdminAllNoticesScreenState();
}

class _AdminAllNoticesScreenState extends State<AdminAllNoticesScreen> {
  void _editNotice(BuildContext context, DocumentSnapshot notice) {
    final TextEditingController titleController =
    TextEditingController(text: notice['title']);
    final TextEditingController descriptionController =
    TextEditingController(text: notice['description']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Notice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('notices')
                  .doc(notice.id)
                  .update({
                'title': titleController.text,
                'description': descriptionController.text,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteNotice(BuildContext context, String id) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Notice'),
        content: const Text('Are you sure you want to delete this notice?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final comments = await FirebaseFirestore.instance
                    .collection('notices')
                    .doc(id)
                    .collection('comments')
                    .get();
                for (var doc in comments.docs) {
                  await doc.reference.delete();
                }
                await FirebaseFirestore.instance
                    .collection('notices')
                    .doc(id)
                    .delete();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error deleting notice: $e")),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _addComment(String noticeId) {
    final _commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Comment'),
        content: TextField(
          controller: _commentController,
          decoration: const InputDecoration(labelText: 'Comment'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('notices')
                  .doc(noticeId)
                  .collection('comments')
                  .add({
                'text': _commentController.text.trim(),
                'timestamp': Timestamp.now(),
              });
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildComments(String noticeId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notices')
          .doc(noticeId)
          .collection('comments')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: snapshot.data!.docs.map((doc) {
            final comment = doc.data() as Map<String, dynamic>;
            final rawTimestamp = comment['timestamp'];
            final DateTime formattedTime = rawTimestamp is Timestamp
                ? rawTimestamp.toDate()
                : DateTime.tryParse(rawTimestamp.toString()) ?? DateTime.now();
            return Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text(
                "↪ ${comment['text'] ?? ''} (${DateFormat.yMd().add_jm().format(formattedTime)})",
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Notices'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notices')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No notices found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final notice = docs[index];
              final rawTimestamp = notice['timestamp'];
              final DateTime time = rawTimestamp is Timestamp
                  ? rawTimestamp.toDate()
                  : DateTime.tryParse(rawTimestamp.toString()) ?? DateTime.now();
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          notice['title'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notice['description']),
                            const SizedBox(height: 4),
                            Text(
                              "Posted on: ${DateFormat.yMd().add_jm().format(time)}",
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editNotice(context, notice),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteNotice(context, notice.id),
                            ),
                            IconButton(
                              icon: const Icon(Icons.comment, color: Colors.grey),
                              onPressed: () => _addComment(notice.id),
                            ),
                          ],
                        ),
                      ),
                      _buildComments(notice.id),
                    ],
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