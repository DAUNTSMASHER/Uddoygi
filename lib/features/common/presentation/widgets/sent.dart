import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SentTab extends StatelessWidget {
  final String userEmail;
  const SentTab({super.key, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('from', isEqualTo: userEmail)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.indigo));
        }
        final docs = snapshot.data?.docs ?? [];
        // Debug print to see how many sent messages fetched
        print('SentTab: fetched ${docs.length} sent messages for $userEmail');
        if (docs.isEmpty) {
          // Placeholder if no messages
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                  title: const Text('No sent messages',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                  subtitle: Text('Sent messages for $userEmail',
                      style: const TextStyle(color: Colors.black54)),
                  trailing: const Icon(Icons.check_circle, color: Colors.blueAccent),
                ),
              ),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, idx) {
            final data = docs[idx].data() as Map<String, dynamic>;
            print("Sent Message #$idx: $data"); // Debug each message
            // Defensive null checks
            final toField = data['to'];
            final toList = (toField is List)
                ? toField.join(', ')
                : (toField?.toString() ?? '');
            final subject = data['subject']?.toString() ?? '(No Subject)';
            final body = data['body']?.toString() ?? '';
            final ts = data['timestamp'];
            String time = '';
            if (ts is Timestamp) {
              time = DateFormat('MMM d, h:mm a').format(ts.toDate());
            } else if (ts is DateTime) {
              time = DateFormat('MMM d, h:mm a').format(ts);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                  title: Text(
                    subject,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                  subtitle: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (toList.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 2),
                          child: Text(
                            'To: $toList',
                            style: const TextStyle(color: Colors.black54, fontSize: 13),
                          ),
                        ),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black87, fontSize: 14),
                      ),
                      if (time.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            time,
                            style: const TextStyle(fontSize: 12, color: Colors.indigo),
                          ),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.check_circle, color: Colors.blueAccent),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
