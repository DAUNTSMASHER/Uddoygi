import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const _brandBlue = Color(0xFF0D47A1);

class NotificationPage extends StatelessWidget {
  const NotificationPage({Key? key}) : super(key: key);

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    final mail = FirebaseAuth.instance.currentUser?.email ?? '';
    // Adjust filters to your schema if needed
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('to', isEqualTo: mail) // or remove if global
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _markAllRead(BuildContext context) async {
    final mail = FirebaseAuth.instance.currentUser?.email ?? '';
    final q = await FirebaseFirestore.instance
        .collection('notifications')
        .where('to', isEqualTo: mail)
        .where('read', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final d in q.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    }
  }

  String _when(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: _brandBlue,
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            icon: const Icon(Icons.mark_email_read),
            onPressed: () => _markAllRead(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No notifications'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final m = docs[i].data();
              final title = (m['title'] ?? 'Notification').toString();
              final body  = (m['body']  ?? '').toString();
              final read  = (m['read']  ?? false) == true;
              final ts    = m['timestamp'] as Timestamp?;
              return Container(
                decoration: BoxDecoration(
                  color: read ? Colors.white : const Color(0xFFE8F0FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x1A0D47A1)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: Icon(read ? Icons.notifications_none : Icons.notifications_active, color: _brandBlue),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (body.isNotEmpty) Text(body),
                      const SizedBox(height: 4),
                      Text(_when(ts), style: const TextStyle(fontSize: 11, color: Colors.black54)),
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
