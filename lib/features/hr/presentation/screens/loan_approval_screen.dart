import 'package:flutter/material.dart';

class LoanApprovalScreen extends StatelessWidget {
  const LoanApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loan Approval')),
      body: const Center(child: Text('Loan Approval Screen')),
    );
  }
}
