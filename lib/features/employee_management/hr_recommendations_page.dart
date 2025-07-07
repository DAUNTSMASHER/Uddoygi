import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'employee_details_page.dart';

const Color _darkBlue = Color(0xFF0D47A1);

/// Displays a list of employees recommended by HR.
class HRRecommendationsPage extends StatelessWidget {
  const HRRecommendationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('users')
        .where('hrRecommended', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('HR Recommendations'),
        backgroundColor: _darkBlue,
      ),
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load recommendations'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No HR recommendations at this time'));
          }

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              // Use the same email field that EmployeeDetailsPage expects:
              final email = data['officeEmail'] as String? ?? data['email'] as String? ?? 'Unknown';
              final dept = (data['department'] as String? ?? '').toUpperCase();

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: _darkBlue, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: const Icon(Icons.thumb_up, color: _darkBlue),
                  title: Text(email),
                  subtitle: Text('Dept: $dept'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    var employeeId;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EmployeeDetailsPage(
                          uid: doc.id,
                          userEmail: email, 
                          employeeId: employeeId,// ← now passing the email
                        ),
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
