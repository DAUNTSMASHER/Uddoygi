import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ComplaintsAgainstMeScreen extends StatelessWidget {
  final String userEmail;
  const ComplaintsAgainstMeScreen({super.key, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints Against Me'),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('complaints')
            .where('againstEmail', isEqualTo: userEmail) // <-- updated for clarity
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
                  Icon(Icons.check_circle_outline, size: 54, color: Colors.green),
                  const SizedBox(height: 14),
                  const Text(
                    'No complaints against you!',
                    style: TextStyle(fontSize: 19, color: Colors.indigo, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final subject = data['subject'] ?? '(No Subject)';
              final message = data['message'] ?? '';
              final from = data['submittedByName'] ?? data['submittedBy'] ?? '';
              final status = data['status'] ?? 'pending';
              final ts = data['timestamp'];
              final time = ts is Timestamp ? ts.toDate() : DateTime.now();

              Color statusColor;
              switch (status) {
                case 'resolved': statusColor = Colors.green; break;
                case 'closed': statusColor = Colors.grey; break;
                case 'pending': statusColor = Colors.orange; break;
                case 'forwarded': statusColor = Colors.indigo; break;
                default: statusColor = Colors.blueGrey;
              }

              return Card(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: const Icon(Icons.person_off, color: Colors.white),
                  ),
                  title: Text(
                    subject,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Filed by: $from', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                      Text(
                        message.length > 60 ? message.substring(0, 60) + '...' : message,
                        style: const TextStyle(color: Colors.black87, fontSize: 15),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            Chip(
                              label: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              backgroundColor: statusColor.withOpacity(0.14),
                            ),
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
                    // Show full details in dialog
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: Colors.indigo[50],
                        title: Text(subject, style: const TextStyle(color: Colors.indigo)),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Filed by: $from', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                              const SizedBox(height: 8),
                              Text(message, style: const TextStyle(color: Colors.black87)),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(status.toUpperCase(),
                                        style: TextStyle(color: statusColor)),
                                    backgroundColor: statusColor.withOpacity(0.17),
                                  ),
                                  const Spacer(),
                                  Text(DateFormat('MMM d, yyyy h:mm a').format(time),
                                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
