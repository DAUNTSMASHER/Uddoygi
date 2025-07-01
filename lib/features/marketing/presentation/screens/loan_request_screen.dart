import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoanRequestScreen extends StatefulWidget {
  const LoanRequestScreen({super.key});

  @override
  State<LoanRequestScreen> createState() => _LoanRequestScreenState();
}

class _LoanRequestScreenState extends State<LoanRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  Future<void> submitLoanRequest() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance.collection('loan_requests').add({
        'userId': user!.uid,
        'amount': double.parse(_amountController.text.trim()),
        'status': 'pending',
        'timestamp': Timestamp.now(),
      });
      _amountController.clear();
    }
  }

  Future<void> markReceived(String docId) async {
    await FirebaseFirestore.instance.collection('loan_requests').doc(docId).update({
      'status': 'completed',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loan Requests')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: submitLoanRequest,
                    child: const Text('Request'),
                  )
                ],
              ),
            ),
          ),
          const Divider(),
          const Text('Your Loan Requests', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('loan_requests')
                  .where('userId', isEqualTo: user!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final loans = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: loans.length,
                  itemBuilder: (context, index) {
                    final loan = loans[index];
                    return Card(
                      child: ListTile(
                        title: Text('৳${loan['amount']}'),
                        subtitle: Text('Status: ${loan['status']}'),
                        trailing: loan['status'] == 'approved'
                            ? TextButton(
                          onPressed: () => markReceived(loan.id),
                          child: const Text('Mark Received'),
                        )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}