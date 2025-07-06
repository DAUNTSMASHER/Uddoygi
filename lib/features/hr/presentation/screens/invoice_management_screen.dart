import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class InvoiceManagementScreen extends StatefulWidget {
  const InvoiceManagementScreen({super.key});

  @override
  State<InvoiceManagementScreen> createState() => _InvoiceManagementScreenState();
}

class _InvoiceManagementScreenState extends State<InvoiceManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showInvoiceForm({DocumentSnapshot? doc}) {
    final isEdit = doc != null;
    final TextEditingController invoiceNoController =
    TextEditingController(text: doc?['invoiceNo'] ?? '');
    final TextEditingController customerController =
    TextEditingController(text: doc?['customerName'] ?? '');
    final TextEditingController amountController =
    TextEditingController(text: doc?['amount']?.toString() ?? '');
    String status = doc?['status'] ?? 'Unpaid';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isEdit ? 'Edit Invoice' : 'Add Invoice', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
              controller: invoiceNoController,
              decoration: const InputDecoration(labelText: 'Invoice No'),
            ),
            TextField(
              controller: customerController,
              decoration: const InputDecoration(labelText: 'Customer Name'),
            ),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            DropdownButtonFormField<String>(
              value: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: ['Unpaid', 'Paid', 'Partial']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => status = val ?? 'Unpaid',
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'invoiceNo': invoiceNoController.text.trim(),
                  'customerName': customerController.text.trim(),
                  'amount': double.tryParse(amountController.text.trim()) ?? 0.0,
                  'status': status,
                  'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                };

                if (isEdit) {
                  await FirebaseFirestore.instance
                      .collection('invoices')
                      .doc(doc.id)
                      .update(data);
                } else {
                  await FirebaseFirestore.instance.collection('invoices').add(data);
                }

                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              child: Text(isEdit ? 'Update' : 'Save'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _deleteInvoice(String id) async {
    await FirebaseFirestore.instance.collection('invoices').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Management'),
        backgroundColor: Colors.indigo,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInvoiceForm(),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
        label: const Text('Add Invoice'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by Customer/Invoice No',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchText = '');
                  },
                ),
              ),
              onChanged: (val) => setState(() => _searchText = val.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('invoices')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs.where((doc) {
                  final invoice = doc.data() as Map<String, dynamic>;
                  return invoice['invoiceNo'].toString().toLowerCase().contains(_searchText) ||
                      invoice['customerName'].toString().toLowerCase().contains(_searchText);
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text('No invoices found.'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final invoice = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(invoice['invoiceNo'] ?? ''),
                        subtitle: Text('Customer: ${invoice['customerName']}\n'
                            'Date: ${invoice['date']}'),
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('৳${invoice['amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(invoice['status'], style: TextStyle(
                                color: invoice['status'] == 'Paid' ? Colors.green :
                                invoice['status'] == 'Partial' ? Colors.orange :
                                Colors.red)),
                          ],
                        ),
                        onTap: () => _showInvoiceForm(doc: doc),
                        onLongPress: () => _deleteInvoice(doc.id),
                      ),
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
