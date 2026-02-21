import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InboxTab extends StatefulWidget {
  final String userEmail;
  const InboxTab({super.key, required this.userEmail});

  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> {
  String _cid = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _cid.isEmpty
          ? const Stream.empty()
          : DB.colSync(_cid, C.messages)
              .where('to', arrayContains: widget.userEmail)
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
                  leading: const CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: const Text('No new messages',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                  subtitle: const Text('Your inbox is empty.',
                      style: TextStyle(color: Colors.black54)),
                  trailing: const Icon(Icons.inbox, color: Colors.indigo),
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
            final fromField = data['from']?.toString() ?? '';
            final subject = data['subject']?.toString() ?? '(No Subject)';
            final body = data['body']?.toString() ?? '';
            final ts = data['timestamp'];
            String time = '';
            if (ts is Timestamp) {
              time = DateFormat('MMM d, h:mm a').format(ts.toDate());
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(subject,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                  subtitle: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (fromField.isNotEmpty)
                        Text('From: $fromField',
                            style: const TextStyle(color: Colors.black54, fontSize: 13)),
                      Text(body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black87, fontSize: 14)),
                      if (time.isNotEmpty)
                        Text(time, style: const TextStyle(fontSize: 12, color: Colors.indigo)),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.indigo),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
