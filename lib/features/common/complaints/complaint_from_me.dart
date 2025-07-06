import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ComplaintsFromMeScreen extends StatelessWidget {
  final String userEmail;
  final String? userName;

  const ComplaintsFromMeScreen({
    super.key,
    required this.userEmail,
    this.userName,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      case 'pending':
        return Colors.orange;
      case 'forwarded':
        return Colors.indigo;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _statusChip(String status) {
    final statusColor = _getStatusColor(status);
    return Chip(
      label: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      backgroundColor: statusColor.withOpacity(0.13),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints From Me'),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('complaints')
            .where('submittedBy', isEqualTo: userEmail)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.indigo));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 50, color: Colors.indigo),
                  const SizedBox(height: 12),
                  const Text(
                    'No complaints submitted by you!',
                    style: TextStyle(fontSize: 18, color: Colors.indigo, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final subject = data['subject'] ?? '';
              final body = data['message'] ?? '';
              final against = (data['against'] ?? '').toString().toUpperCase();
              final status = (data['status'] ?? 'pending').toString();
              final ts = data['timestamp'];
              final DateTime time = ts is Timestamp ? ts.toDate() : DateTime.now();

              final statusColor = _getStatusColor(status);

              return Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 14),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor,
                    child: const Icon(Icons.report, color: Colors.white),
                  ),
                  title: Text(
                    subject,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (against.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, bottom: 2),
                          child: Text(
                            'AGAINST: $against',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      Text(
                        body.length > 60 ? body.substring(0, 60) + '...' : body,
                        style: const TextStyle(color: Colors.black87, fontSize: 15),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            _statusChip(status),
                            const Spacer(),
                            Text(
                              DateFormat('MMM d, h:mm a').format(time),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: Colors.indigo[50],
                        title: Text(subject, style: const TextStyle(color: Colors.indigo)),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (against.isNotEmpty)
                                Text(
                                  'AGAINST: $against',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Text(body, style: const TextStyle(color: Colors.black87)),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  _statusChip(status),
                                  const Spacer(),
                                  Text(
                                    DateFormat('MMM d, yyyy h:mm a').format(time),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            child: const Text('Close', style: TextStyle(color: Colors.indigo)),
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
      ),
    );
  }
}
