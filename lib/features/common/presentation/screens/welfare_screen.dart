import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WelfareScreen extends StatelessWidget {
  const WelfareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welfare Schemes', style: TextStyle(color: Colors.white)),
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
            return const Center(
              child: CircularProgressIndicator(color: Colors.indigo),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No welfare schemes found.',
                style: TextStyle(color: Colors.indigo, fontSize: 16),
              ),
            );
          }

          final welfareDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: welfareDocs.length,
            itemBuilder: (context, index) {
              final data = welfareDocs[index].data() as Map<String, dynamic>;
              return _buildWelfareCard(data);
            },
          );
        },
      ),
    );
  }

  Widget _buildWelfareCard(Map<String, dynamic> data) {
    final title = data['title'] ?? '';
    final description = data['description'] ?? '';
    final publishedBy = data['publishedBy'] ?? 'Admin';
    final timestamp = data['timestamp'];
    final formattedDate = timestamp is Timestamp
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
            _buildTitleRow(title),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            _buildFooterRow(publishedBy, formattedDate),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleRow(String title) {
    return Row(
      children: [
        Icon(Icons.volunteer_activism, color: Colors.indigo.shade400),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.indigo,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterRow(String publishe_
