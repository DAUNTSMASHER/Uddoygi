import 'package:flutter/material.dart';

class AccountsReceivableScreen extends StatelessWidget {
  const AccountsReceivableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: const Text(
          'Accounts Receivable',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Summary Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summaryCard(
                  title: 'Total Receivables',
                  amount: '৳ 85,000',
                  icon: Icons.attach_money,
                  context: context,
                ),
                _summaryCard(
                  title: 'Due This Week',
                  amount: '৳ 15,000',
                  icon: Icons.calendar_today,
                  context: context,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // List of Receivables
            Expanded(
              child: ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) {
                  return Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text('Customer ${index + 1}'),
                      subtitle: const Text('Due on: 2025-07-12'),
                      trailing: const Text(
                        '৳ 10,000',
                        style: TextStyle(
                          color: Colors.indigo,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add),
        label: const Text('Add Invoice'),
        onPressed: () {
          // Navigate to Add Invoice Form
        },
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String amount,
    required IconData icon,
    required BuildContext context,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.indigo, size: 28),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(
              amount,
              style: const TextStyle(
                color: Colors.indigo,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
