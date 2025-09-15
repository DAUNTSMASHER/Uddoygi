import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminMessagesScreen extends StatefulWidget {
  const AdminMessagesScreen({super.key});

  @override
  State<AdminMessagesScreen> createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends State<AdminMessagesScreen> {
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _emailController.text.trim().isEmpty) return;

    await _firestore.collection('messages').add({
      'email': _emailController.text.trim(),
      'message': _messageController.text.trim(),
      'status': 'pending',
      'timestamp': Timestamp.now(),
    });

    _messageController.clear();
    _emailController.clear();
  }

  Future<void> _approveMessage(String docId) async {
    await _firestore.collection('messages').doc(docId).update({
      'status': 'approved',
    });
  }

  Future<void> _sendReply(String messageId, String replyText) async {
    if (replyText.trim().isEmpty) return;

    await _firestore.collection('messages').doc(messageId).collection('replies').add({
      'sender': 'admin@company.com', // Customize as needed
      'text': replyText.trim(),
      'timestamp': Timestamp.now(),
    });
  }

  void _showReplyBottomSheet(String messageId) {
    final replyController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: replyController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reply to Message',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                await _sendReply(messageId, replyController.text);
                Navigator.pop(context);
              },
              child: const Text('Send Reply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplies(String messageId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('messages')
          .doc(messageId)
          .collection('replies')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(top: 6, left: 8),
              child: Text(
                "↪ ${data['sender'] ?? ''}: ${data['text'] ?? ''}",
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
      appBar: AppBar(title: const Text('Employee Messages')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Your Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message to Admin',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _sendMessage,
              child: const Text('Send Message'),
            ),
            const Divider(height: 30),
            const Text('All Messages:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Center(child: Text('No messages found.'));
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'] ?? 'pending';
                      final isApproved = status == 'approved';

                      // ✅ Safe timestamp conversion
                      final rawTimestamp = data['timestamp'];
                      final DateTime formattedTime = rawTimestamp is Timestamp
                          ? rawTimestamp.toDate()
                          : DateTime.tryParse(rawTimestamp.toString()) ?? DateTime.now();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(data['message'] ?? ''),
                                subtitle: Text(
                                  'From: ${data['email']}\nStatus: $status\n${DateFormat.yMd().add_jm().format(formattedTime)}',
                                ),
                                trailing: Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.reply, color: Colors.deepPurple),
                                      onPressed: () => _showReplyBottomSheet(doc.id),
                                    ),
                                    if (!isApproved)
                                      IconButton(
                                        icon: const Icon(Icons.check, color: Colors.deepPurple),
                                        onPressed: () => _approveMessage(doc.id),
                                      ),
                                    if (isApproved)
                                      const Icon(Icons.check_circle, color: Colors.green),
                                  ],
                                ),
                              ),
                              _buildReplies(doc.id),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
