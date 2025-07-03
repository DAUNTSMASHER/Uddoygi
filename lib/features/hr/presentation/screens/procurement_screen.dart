import 'package:flutter/material.dart';

class ProcurementScreen extends StatelessWidget {
  const ProcurementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Procurement')),
      body: const Center(child: Text('Procurement Screen')),
    );
  }
}
