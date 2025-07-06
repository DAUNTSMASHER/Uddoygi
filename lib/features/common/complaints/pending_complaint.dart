import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PendingComplaintScreen extends StatefulWidget {
  final String userEmail;
  final bool isCEO; // If true, show CEO actions

  const PendingComplaintScreen({super.key, required this.userEmail, this.isCEO = false});

  @override
  State<PendingComplaintScreen> createState() => _PendingComplaintScreenState();
}

class _PendingComplaintScreenState extends State<PendingComplaintScreen> {
  bool _loading = false;

  Future<void> _showActionDialog(DocumentSnapshot complaint) async {
    String? selectedStatus;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Complaint Action"),
            content: DropdownButtonFormField<String>(
              value: selectedStatus,
              items: [
                DropdownMenuItem(value: 'resolved', child: Text('Mark as Resolved')),
                DropdownMenuItem(value: 'dismissed', child: Text('Dismiss')),
                DropdownMenuItem(value: 'in_review', child: Text('In Review')),
                DropdownMenuItem(value: 'forwarded', child: Text('Forward to CEO')),
              ],
              onChanged: (v) => setDialogState(() => selectedStatus = v),
              decoration: const InputDecoration(labelText: 'Select Action'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Update'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                onPressed: selectedStatus == null
                    ? null
                    : () async {
                  setState(() => _loading = true);
                  await FirebaseFirestore.instance
                      .collection('complaints')
                      .doc(complaint.id)
                      .update({
                    'status': selectedStatus,
                    'actionTakenBy': widget.userEmail,
                    'actionTakenAt': FieldValue.serverTimestamp(),
                  });
                  setState(() => _loading = false);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          );
        });
      },
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'resolved':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'forwarded':
        color = Colors.indigo;
        break;
      case 'dismissed':
        color = Colors.red;
        break;
      case 'in_review':
        color = Colors.blue;
        break;
      default:
        color = Colors.blueGrey;
    }
    return Chip(
      label: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
      backgroundColor: color.withOpacity(0.13),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Complaints'),
        backgroundColor: Colors.indigo,
      ),
      backgroundColor: Colors.indigo[50],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('complaints')
            .where('status', isEqualTo: 'pending')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _loading) {
            return const Center(child: CircularProgressIndicator(color: Colors.indigo));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
                child: Text("No pending complaints.", style: TextStyle(color: Colors.indigo)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final subject = data['subject'] ?? "(No subject)";
              final message = data['message'] ?? "";
              final submittedBy = data['submittedByName'] ?? data['submittedBy'] ?? "";
              final against = data['against'] ?? "";
              final status = data['status'] ?? "";
              final time = data['timestamp'] is Timestamp
                  ? (data['timestamp'] as Timestamp).toDate()
                  : DateTime.now();

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.white,
                elevation: 3,
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(subject, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                      ),
                      _statusChip(status),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("From: $submittedBy", style: const TextStyle(color: Colors.black87)),
                      if (against.isNotEmpty)
                        Text("Against: $against", style: const TextStyle(color: Colors.black87)),
                      const SizedBox(height: 2),
                      Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('MMM d, y h:mm a').format(time),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: widget.isCEO
                      ? IconButton(
                    icon: const Icon(Icons.verified, color: Colors.green),
                    tooltip: "CEO Action",
                    onPressed: () => _showActionDialog(docs[i]),
                  )
                      : PopupMenuButton<String>(
                    onSelected: (value) => _showActionDialog(docs[i]),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'forward',
                        child: Text('Forward to CEO'),
                      ),
                      const PopupMenuItem(
                        value: 'action',
                        child: Text('Take Action'),
                      ),
                    ],
                  ),
                  onTap: () {
                    // Optionally show a dialog with full details
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(subject),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("From: $submittedBy"),
                            if (against.isNotEmpty) Text("Against: $against"),
                            const SizedBox(height: 8),
                            Text(message),
                            const SizedBox(height: 8),
                            Text("Status: $status"),
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
      ),
    );
  }
}
