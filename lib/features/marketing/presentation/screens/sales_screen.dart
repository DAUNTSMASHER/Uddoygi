import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _formKey = GlobalKey<FormState>();
  String? selectedCustomer;
  final TextEditingController _amountController = TextEditingController();

  Future<void> _submitInvoice() async {
    if (_formKey.currentState!.validate() && selectedCustomer != null) {
      await FirebaseFirestore.instance.collection('invoices').add({
        'customerId': selectedCustomer,
        'amount': double.parse(_amountController.text),
        'submitted': false,
        'timestamp': Timestamp.now(),
      });
      _amountController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales & Invoices')),
      body: Column(
        children: [
          Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  StreamBuilder(
                    stream: FirebaseFirestore.instance.collection('customers').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      final docs = snapshot.data!.docs;
                      return DropdownButtonFormField(
                        value: selectedCustomer,
                        hint: const Text('Select Customer'),
                        items: docs.map((doc) {
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text(doc['name']),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => selectedCustomer = val),
                      );
                    },
                  ),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount (৳)'),
                    validator: (value) => value!.isEmpty ? 'Required' : null,
                  ),
                  ElevatedButton(
                    onPressed: _submitInvoice,
                    child: const Text('Add Invoice'),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          const Text('Your Invoices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('invoices').orderBy('timestamp').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return ListTile(
                      title: Text('৳${doc['amount']}'),
                      subtitle: Text('Submitted: ${doc['submitted'] ? "Yes" : "No"}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}