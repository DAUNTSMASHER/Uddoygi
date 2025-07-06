import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'customer_order_summary.dart';
import 'customer_details.dart';

class CustomerListView extends StatelessWidget {
  final String userId;
  final String email;

  const CustomerListView({
    super.key,
    required this.userId,
    required this.email,
  });

  String _extractAgentName(String email) {
    final namePart = email.split('@')[0];
    return namePart
        .split('.')
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final agentName = _extractAgentName(email);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Customers'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('customers')
            .where('agentName', isEqualTo: agentName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error fetching customers.'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No customers found.'));
          }

          final customers = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              final name = customer['name'] ?? 'No Name';
              final customerEmail = customer.data().toString().contains('email') ? customer['email'] : 'No Email';
              final phone = customer.data().toString().contains('phone') ? customer['phone'] : 'No Phone';
              final address = customer.data().toString().contains('address') ? customer['address'] : 'No Address';
              final agent = customer.data().toString().contains('agentName') ? customer['agentName'] : 'Unknown Agent';

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.blueAccent,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.receipt_long),
                            tooltip: 'Order Summary',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CustomerOrderSummary(email: customerEmail),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.info_outline),
                            tooltip: 'View Details',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CustomerDetailsPage(customerId: customer.id),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Email: $customerEmail'),
                      Text('Phone: $phone'),
                      Text('Address: $address'),
                      Text('Agent: $agent'),
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
