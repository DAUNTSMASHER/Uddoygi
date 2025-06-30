// lib/features/admin/presentation/screens/salary_screen.dart

import 'package:flutter/material.dart';

class SalaryScreen extends StatelessWidget {
  const SalaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> salaryDetails = [
      {
        'name': 'Mahfuz Rahman',
        'department': 'Marketing',
        'amount': '৳25,000',
        'status': 'Received',
        'date': '2025-06-25'
      },
      {
        'name': 'Shahriar Akib',
        'department': 'Factory',
        'amount': '৳22,000',
        'status': 'Pending',
        'date': '2025-06-25'
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salary Details'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: salaryDetails.length,
        itemBuilder: (context, index) {
          final salary = salaryDetails[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.account_circle, color: Colors.blue.shade600),
              title: Text(salary['name']),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Department: ${salary['department']}'),
                  Text('Date: ${salary['date']}'),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    salary['amount'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    salary['status'],
                    style: TextStyle(
                      color: salary['status'] == 'Received'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
