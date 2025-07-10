// lib/features/marketing/presentation/screens/work_order/add_new_po.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class AddNewPurchaseOrderScreen extends StatefulWidget {
  const AddNewPurchaseOrderScreen({Key? key}) : super(key: key);

  @override
  State<AddNewPurchaseOrderScreen> createState() => _AddNewPurchaseOrderScreenState();
}

class _AddNewPurchaseOrderScreenState extends State<AddNewPurchaseOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  // Invoices
  String? _selectedInvoiceId;
  String? _invoiceNo;
  List<DocumentSnapshot<Map<String, dynamic>>> _invoices = [];

  // Products
  List<DocumentSnapshot<Map<String, dynamic>>> _products = [];

  // PO Items
  List<Map<String, dynamic>> _items = [];
  final List<TextEditingController> _qtyControllers = [];
  final List<TextEditingController> _priceControllers = [];

  DateTime _expectedDate = DateTime.now();
  final TextEditingController _instructionsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInvoices();
    _loadProducts();
    _addItem();
  }

  @override
  void dispose() {
    for (var c in _qtyControllers) c.dispose();
    for (var c in _priceControllers) c.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    final snap = await FirebaseFirestore.instance
        .collection('invoices')
        .where('agentEmail', isEqualTo: userEmail)
        .orderBy('timestamp', descending: true)
        .get();
    setState(() => _invoices = snap.docs);
  }

  Future<void> _loadProducts() async {
    final snap = await FirebaseFirestore.instance
        .collection('products')
        .orderBy('model_name')
        .get();
    setState(() => _products = snap.docs);
  }

  void _addItem() {
    setState(() {
      _items.add({'productId': null, 'qty': 1, 'unitPrice': 0.0});
      _qtyControllers.add(TextEditingController(text: '1'));
      _priceControllers.add(TextEditingController(text: '0'));
    });
  }

  void _removeItem(int i) {
    setState(() {
      _items.removeAt(i);
      _qtyControllers.removeAt(i).dispose();
      _priceControllers.removeAt(i).dispose();
    });
  }

  Future<void> _submitPO() async {
    if (!_formKey.currentState!.validate() || _selectedInvoiceId == null) return;

    for (int i = 0; i < _items.length; i++) {
      _items[i]['qty'] = int.tryParse(_qtyControllers[i].text) ?? 0;
      _items[i]['unitPrice'] = double.tryParse(_priceControllers[i].text) ?? 0.0;
    }

    final dateStr = DateFormat('yyyyMMdd').format(_expectedDate);
    final poNo = '${_invoiceNo!.toLowerCase()}_po_$dateStr';

    final poData = {
      'poNo': poNo,
      'invoiceId': _selectedInvoiceId,
      'invoiceNo': _invoiceNo,
      'items': _items,
      'expectedDate': _expectedDate,
      'instructions': _instructionsController.text,
      'submittedBy': FirebaseAuth.instance.currentUser?.email,
      'timestamp': Timestamp.now(),
    };

    await FirebaseFirestore.instance
        .collection('purchase_orders')
        .doc(poNo)
        .set(poData);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Purchase order submitted!')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('New Purchase Order'),
        backgroundColor: _darkBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Invoice dropdown
                DropdownButtonFormField<String>(
                  value: _selectedInvoiceId,
                  decoration: const InputDecoration(
                    labelText: 'Select Invoice',
                    border: OutlineInputBorder(),
                  ),
                  items: _invoices.map((d) {
                    final invNo = d.data()?['invoiceNo'] as String? ?? d.id;
                    return DropdownMenuItem(
                      value: d.id,
                      child: Text(invNo),
                    );
                  }).toList(),
                  onChanged: (v) {
                    final sel = _invoices.firstWhere((d) => d.id == v);
                    setState(() {
                      _selectedInvoiceId = v;
                      _invoiceNo = sel.data()?['invoiceNo'] as String? ?? sel.id;
                    });
                  },
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // PO Items
                const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  itemBuilder: (ctx, i) {
                    final itm = _items[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            // Product dropdown
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: itm['productId'] as String?,
                                decoration:
                                const InputDecoration(border: OutlineInputBorder()),
                                items: _products.map((p) {
                                  final data = p.data()!;
                                  return DropdownMenuItem(
                                    value: p.id,
                                    child: Text(data['model_name'] as String),
                                  );
                                }).toList(),
                                onChanged: (v) => setState(() => itm['productId'] = v),
                                validator: (v) => v == null ? 'Req' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Qty
                            SizedBox(
                              width: 60,
                              child: TextFormField(
                                controller: _qtyControllers[i],
                                decoration:
                                const InputDecoration(labelText: 'Qty'),
                                keyboardType: TextInputType.number,
                                validator: (v) => v == null || v.isEmpty ? 'Req' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Unit Price
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                controller: _priceControllers[i],
                                decoration: const InputDecoration(
                                    labelText: 'Unit Price'),
                                keyboardType: TextInputType.number,
                                validator: (v) => v == null || v.isEmpty ? 'Req' : null,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent),
                              onPressed: () => _removeItem(i),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add, color: _darkBlue),
                    label: const Text('Add Item',
                        style: TextStyle(color: _darkBlue)),
                    onPressed: _addItem,
                  ),
                ),

                const SizedBox(height: 16),
                Text(
                  'Expected Date: ${DateFormat('yyyy-MM-dd').format(_expectedDate)}',
                ),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _expectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _expectedDate = d);
                  },
                  child: const Text('Select Date'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _instructionsController,
                  decoration: const InputDecoration(
                    labelText: 'Special Instructions',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _darkBlue),
                    onPressed: _submitPO,
                    child: const Text('Submit PO'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
