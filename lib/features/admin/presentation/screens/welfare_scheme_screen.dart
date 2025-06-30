// lib/features/admin/presentation/screens/welfare_scheme_screen.dart

import 'package:flutter/material.dart';

class WelfareSchemeScreen extends StatelessWidget {
  const WelfareSchemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> requests = [
      {
        'employee': 'Yeasin Arafat',
        'department': 'HR',
        'reason': 'Medical treatment support',
        'status': 'Pending'
      },
      {
        'employee': 'Rabbi Hasan',
        'department': 'Factory',
        'reason': 'Child education allowance',
        'status': 'Approved'
      },
      {
        'employee': 'Siam Rahman',
        'department': 'Marketing',
        'reason': 'Housing assistance',
        'status': 'Rejected'
      },
    ];

    Color _getStatusColor(String status) {
      switch (status) {
        case 'Approved':
          return Colors.green;
        case 'Rejected':
          return Colors.red;
        default:
          return Colors.orange;
      }
    }

    IconData _getStatusIcon(String status) {
      switch (status) {
        case 'Approved':
          return Icons.check_circle;
        case 'Rejected':
          return Icons.cancel;
        default:
          return Icons.hourglass_bottom;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welfare Scheme Requests'),
        centerTitle: true,
        backgroundColor: Colors.pink.shade400,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final item = requests[index];
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _getStatusColor(item['status']!),
                        child: Icon(_getStatusIcon(item['status']!), color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item['employee']!,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Chip(
                        label: Text(item['status']!),
                        backgroundColor: _getStatusColor(item['status']!).withOpacity(0.2),
                        labelStyle: TextStyle(color: _getStatusColor(item['status']!)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Department: ${item['department']}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reason: ${item['reason']}',
                    style: const TextStyle(fontSize: 15),
                  ),
                  if (item['status'] == 'Pending') ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.check, color: Colors.green),
                          label: const Text('Approve', style: TextStyle(color: Colors.green)),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text('Reject', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
