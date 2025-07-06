import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAllBuyersPage extends StatelessWidget {
  const AdminAllBuyersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Buyers'),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('customers').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading buyers'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No buyers found'));
          }

          final buyers = snapshot.data!.docs;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Total Buyers: ${buyers.length}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: buyers.length,
                  itemBuilder: (context, index) {
                    final buyer = buyers[index];
                    final name = buyer['name'] ?? 'No Name';
                    final email = buyer['email'] ?? 'No Email';
                    final phone = buyer.data().toString().contains('phone') ? buyer['phone'] : 'No Phone';
                    final address = buyer.data().toString().contains('address') ? buyer['address'] : 'No Address';
                    final addedBy = buyer.data().toString().contains('agentName') ? buyer['agentName'] : 'Unknown';

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: Colors.indigo,
                                  child: Icon(Icons.person, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(email, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.phone, color: Colors.indigo.shade200),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Phone: $phone', style: const TextStyle(fontSize: 13)),
                                Text('Agent: $addedBy', style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Address: $address', style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
