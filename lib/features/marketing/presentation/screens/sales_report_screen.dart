import 'package:flutter/material.dart';

class SalesReportScreen extends StatelessWidget {
  const SalesReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder: later we can add filters, chart, or export options
    return Scaffold(
      appBar: AppBar(title: const Text('Sales Report')),
      body: const Center(
        child: Text(
          'Sales report feature coming soon!',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
