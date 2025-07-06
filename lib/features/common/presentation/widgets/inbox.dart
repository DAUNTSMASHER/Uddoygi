import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InboxTab extends StatelessWidget {
  final String userEmail;
  const InboxTab({super.key, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('to', arrayContains: userEmail)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.indigo));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  title: const Text('No new messages',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                  subtitle: Text('Inbox for $userEmail',
                      style: const TextStyle(color: Colors.black54)),
                  trailing: const Icon(Icons.inbox, color: Colors.blueAccent),
                ),
              ),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final from = data['from'] ?? '';
            final subject = data['subject'] ?? '(No subject)';
            final body = data['body'] ?? '';
            final ts = data['timestamp'];
            final DateTime time = ts is Timestamp ? ts.toDate() : DateTime.now();

            return Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: Text(
                    (from.isNotEmpty ? from[0].toUpperCase() : '?'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  subject,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('From: $from', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                    const SizedBox(height: 3),
                    Text(
                      body.length > 50 ? body.substring(0, 50) + '...' : body,
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM d, yyyy, h:mm a').format(time),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.inbox, color: Colors.blueAccent),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(subject),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('From: $from', style: const TextStyle(color: Colors.black54)),
                          const SizedBox(height: 8),
                          Text(body),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('MMM d, yyyy, h:mm a').format(time),
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          child: const Text('Close'),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
