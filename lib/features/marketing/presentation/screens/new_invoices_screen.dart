import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NewInvoicesScreen extends StatefulWidget {
  const NewInvoicesScreen({super.key});

  @override
  State<NewInvoicesScreen> createState() => _NewInvoicesScreenState();
}

class _NewInvoicesScreenState extends State<NewInvoicesScreen> {
  final _formKey = GlobalKey<FormState>();
  String? selectedCustomer;
  DateTime selectedDate = DateTime.now();
  final TextEditingController _shippingController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  String selectedStatus = 'Invoice Created';
  List<Map<String, dynamic>> items = [
    {'model': '', 'size': '', 'color': '', 'qty': 1, 'price': 0.0, 'total': 0.0}
  ];

  final List<String> countryList = [
    'Australia', 'Bangladesh', 'Canada', 'Denmark', 'Egypt', 'France', 'Germany',
    'India', 'Japan', 'Kuwait', 'Malaysia', 'Nepal', 'Oman', 'Pakistan',
    'Qatar', 'Russia', 'Saudi Arabia', 'Thailand', 'United Arab Emirates', 'USA', 'Vietnam'
  ];

  final List<String> statusOptions = [
    'Invoice Created',
    'Payment Done',
    'Submitted to Factory for Production',
    'Product Received',
    'Address Validation of the Customer',
    'Shipped to Shipping Company'
  ];

  double _calculateGrandTotal() {
    double subtotal = items.fold(0, (sum, item) => sum + item['total']);
    double shipping = double.tryParse(_shippingController.text) ?? 0;
    double tax = double.tryParse(_taxController.text) ?? 0;
    return subtotal + shipping + tax;
  }

  void _addRow() {
    setState(() {
      items.add({'model': '', 'size': '', 'color': '', 'qty': 1, 'price': 0.0, 'total': 0.0});
    });
  }

  Future<void> _submitInvoice() async {
    if (_formKey.currentState!.validate() && selectedCustomer != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final customerDoc = await FirebaseFirestore.instance.collection('customers').doc(selectedCustomer).get();

      final invoiceData = {
        'customerId': selectedCustomer,
        'customerName': customerDoc.data()?['name'] ?? '',
        'agentId': uid,
        'agentEmail': userDoc.data()?['email'] ?? '',
        'agentName': userDoc.data()?['fullName'] ?? '',
        'date': selectedDate,
        'items': items.map((item) => {
          'model': item['model'],
          'size': item['size'],
          'color': item['color'],
          'qty': item['qty'],
          'price': item['price'],
          'total': item['qty'] * item['price'],
        }).toList(),
        'shippingCost': double.tryParse(_shippingController.text) ?? 0,
        'tax': double.tryParse(_taxController.text) ?? 0,
        'grandTotal': _calculateGrandTotal(),
        'country': _countryController.text,
        'note': _noteController.text,
        'status': selectedStatus,
        'submitted': false,
        'timestamp': Timestamp.now(),
      };

      await FirebaseFirestore.instance.collection('invoices').add(invoiceData);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice submitted successfully!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Invoice'), backgroundColor: Colors.indigo),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text("Date: "),
                  Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                    child: const Text("Change"),
                  )
                ],
              ),
              const Divider(),
              const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Model', item, 'model')),
                          Expanded(child: _buildTextField('Size', item, 'size')),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Color', item, 'color')),
                          Expanded(child: _buildNumberField('Qty', item, 'qty')),
                          Expanded(child: _buildNumberField('Unit Price', item, 'price')),
                          Text('৳${item['total'].toStringAsFixed(2)}')
                        ],
                      ),
                      const Divider()
                    ],
                  );
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                  onPressed: _addRow,
                ),
              ),
              const SizedBox(height: 8),
              _buildNumberField('Shipping Cost', {'value': _shippingController.text}, 'value', controller: _shippingController),
              _buildNumberField('Tax', {'value': _taxController.text}, 'value', controller: _taxController),
              const SizedBox(height: 8),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  return countryList.where((String option) => option.toLowerCase().startsWith(textEditingValue.text.toLowerCase()));
                },
                fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                  _countryController.text = controller.text;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder()),
                    onEditingComplete: onEditingComplete,
                  );
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField(
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                value: selectedStatus,
                items: statusOptions.map((status) => DropdownMenuItem(
                  value: status,
                  child: Text(status),
                )).toList(),
                onChanged: (val) => setState(() => selectedStatus = val!),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Text('Grand Total: ৳${_calculateGrandTotal().toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Submit Invoice'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  onPressed: _submitInvoice,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, Map<String, dynamic> item, String key) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: TextFormField(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        initialValue: item[key],
        onChanged: (val) => item[key] = val,
        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _buildNumberField(String label, Map<String, dynamic> item, String key, {TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        keyboardType: TextInputType.number,
        onChanged: (val) {
          if (controller == null) {
            item[key] = double.tryParse(val) ?? 0;
            if (item.containsKey('qty') && item.containsKey('price')) {
              item['total'] = (item['qty'] ?? 0) * (item['price'] ?? 0);
            }
            setState(() {});
          } else {
            setState(() {});
          }
        },
        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      ),
    );
  }
}