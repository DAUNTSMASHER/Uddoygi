import 'package:flutter/material.dart';

class AccountsPayableScreen extends StatelessWidget {
  const AccountsPayableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // changed from Colors.grey[100]
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: const Text(
          'Accounts Payable',
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
                  title: 'Total Payables',
                  amount: '৳ 1,20,000',
                  icon: Icons.account_balance_wallet,
                  context: context,
                ),
                _summaryCard(
                  title: 'Due Today',
                  amount: '৳ 18,000',
                  icon: Icons.today,
                  context: context,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Table/List of Payables
            Expanded(
              child: ListView.builder(
                itemCount: 6,
                itemBuilder: (context, index) {
                  return Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    child: ListTile(
                      leading: const Icon(Icons.business),
                      title: Text('Vendor ${index + 1}'),
                      subtitle: const Text('Due on: 2025-07-15'),
                      trailing: const Text(
                        '৳ 20,000',
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
        label: const Text('Add Payable'),
        onPressed: () {
          // Navigate to Add Payable Form
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
          color: Colors.white, // card background
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
