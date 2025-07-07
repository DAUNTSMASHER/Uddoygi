import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class HRRecommendationsPage extends StatelessWidget {
  const HRRecommendationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final recommendationsStream = FirebaseFirestore.instance
        .collection('recommendation')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('HR Recommendations'),
        backgroundColor: _darkBlue,
      ),
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: recommendationsStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Failed to load recommendations'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No recommendations yet'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final name = (data['fullName'] as String?) ?? 'Unnamed';
              final dept = (data['department'] as String?) ?? 'Unknown';
              final status = (data['status'] as String?) ?? 'Pending';
              final statusColor = status == 'Approved'
                  ? Colors.green
                  : status == 'Rejected'
                  ? Colors.red
                  : Colors.orange;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: _darkBlue, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text(dept, style: const TextStyle(fontSize: 14)),
                  trailing: Text(
                    status,
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold),
                  ),
                  onTap: () => _showDetails(context, data),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetails(BuildContext context, Map<String, dynamic> data) {
    final name = data['fullName'] as String? ?? '';
    final email = data['personalEmail'] as String? ?? '';
    final phone = data['personalPhone'] as String? ?? '';
    final recommendation = data['recommendation'] as String? ?? '';
    final status = data['status'] as String? ?? '';
    final reasons = data['reasons'] as String? ?? '—';
    final sentToCEO = data['sentToCEO'] as bool? ?? false;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Recommendation for $name'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Email', email),
              _infoRow('Phone', phone),
              _infoRow('Recommendation', recommendation),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Status: ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(status,
                      style: TextStyle(
                          color: status == 'Approved'
                              ? Colors.green
                              : status == 'Rejected'
                              ? Colors.red
                              : Colors.orange,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              if (status == 'Rejected')
                _infoRow('Reasons', reasons),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('Sent to CEO: ',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Icon(
                    sentToCEO ? Icons.check_circle : Icons.hourglass_bottom,
                    color: sentToCEO ? Colors.green : Colors.grey,
                  )
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
            const Text('Close', style: TextStyle(color: _darkBlue)),
          )
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
