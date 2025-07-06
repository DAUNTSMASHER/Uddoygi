import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WelfareScreen extends StatelessWidget {
  const WelfareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Welfare Schemes',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('welfare')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.indigo));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No welfare schemes found.',
                  style: TextStyle(color: Colors.indigo, fontSize: 16)),
            );
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, idx) {
              final data = docs[idx].data() as Map<String, dynamic>;
              final title = data['title'] ?? '';
              final desc = data['description'] ?? '';
              final publishedBy = data['publishedBy'] ?? 'Admin';
              final timestamp = data['timestamp'];
              final dateStr = timestamp is Timestamp
                  ? DateFormat('MMM d, yyyy').format(timestamp.toDate())
                  : '';

              return Card(
                color: Colors.indigo[50],
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.volunteer_activism,
                              color: Colors.indigo.shade400),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.indigo
                                )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        desc,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            'Published by: $publishedBy',
                            style: const TextStyle(color: Colors.indigo, fontSize: 13),
                          ),
                          const Spacer(),
                          Text(
                            dateStr,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
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
