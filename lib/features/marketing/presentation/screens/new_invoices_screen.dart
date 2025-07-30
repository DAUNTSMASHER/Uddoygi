import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class NewInvoicesScreen extends StatefulWidget {
  const NewInvoicesScreen({Key? key}) : super(key: key);

  @override
  State<NewInvoicesScreen> createState() => _NewInvoicesScreenState();
}

class _NewInvoicesScreenState extends State<NewInvoicesScreen> {
  final _formKey = GlobalKey<FormState>();
  String? selectedCustomer;
  String selectedCustomerName = '';
  DateTime selectedDate = DateTime.now();
  final _shippingController = TextEditingController();
  final _taxController = TextEditingController();
  final _noteController = TextEditingController();
  final _countryController = TextEditingController();
  String selectedStatus = 'Invoice Created';

  List<Map<String, dynamic>> items = [];
  List<DocumentSnapshot<Map<String, dynamic>>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _addItem();
  }

  @override
  void dispose() {
    _shippingController.dispose();
    _taxController.dispose();
    _noteController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .orderBy('model_name')
        .get();
    setState(() => _products = snapshot.docs);
  }

  void _addItem() {
    setState(() {
      items.add({'model': null, 'colour': null, 'size': null, 'qty': 1});
    });
  }

  void _removeItem(int index) {
    setState(() => items.removeAt(index));
  }

  double _calculateGrandTotal() {
    double subtotal = 0;
    for (var itm in items) {
      final model = itm['model'] as String?;
      final colour = itm['colour'] as String?;
      final size = itm['size'] as String?;
      DocumentSnapshot<Map<String, dynamic>>? match;
      if (model != null && colour != null && size != null) {
        for (var p in _products) {
          final d = p.data()!;
          if (d['model_name'] == model &&
              d['colour'] == colour &&
              d['size'] == size) {
            match = p;
            break;
          }
        }
      }
      final price = (match?.data()?['unit_price'] as num?)?.toDouble() ?? 0.0;
      subtotal += price * (itm['qty'] ?? 1);
    }
    final ship = double.tryParse(_shippingController.text) ?? 0;
    final tax = double.tryParse(_taxController.text) ?? 0;
    return subtotal + ship + tax;
  }

  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate() || selectedCustomer == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid;
    final agentEmail = currentUser?.email ?? '';
    final userDoc = uid != null
        ? await FirebaseFirestore.instance.collection('users').doc(uid).get()
        : null;
    final agentName =
        userDoc?.data()?['fullName'] as String? ?? currentUser?.displayName ?? '';

    final invoiceNo = '${selectedCustomerName.toLowerCase()}_'
        '${DateFormat('ddMMyyyy').format(selectedDate)}_'
        '${_calculateGrandTotal().toStringAsFixed(0)}';

    final invoiceItems = <Map<String, dynamic>>[];
    for (var itm in items) {
      final model = itm['model'] as String?;
      final colour = itm['colour'] as String?;
      final size = itm['size'] as String?;
      DocumentSnapshot<Map<String, dynamic>>? prod;
      if (model != null && colour != null && size != null) {
        for (var p in _products) {
          final d = p.data()!;
          if (d['model_name'] == model &&
              d['colour'] == colour &&
              d['size'] == size) {
            prod = p;
            break;
          }
        }
      }

      final price = (prod?.data()?['unit_price'] as num?)?.toDouble() ?? 0.0;
      final qty = itm['qty'] as int;

      invoiceItems.add({
        'productId': prod?.id,
        'model': model,
        'colour': colour,
        'size': size,
        'qty': qty,
        'price': price,
        'total': price * qty,
      });
    }

    final invoiceData = {
      'invoiceNo': invoiceNo,
      'customerId': selectedCustomer,
      'customerName': selectedCustomerName,
      'agentId': uid,
      'agentEmail': agentEmail,
      'agentName': agentName,
      'date': selectedDate,
      'items': invoiceItems,
      'shippingCost': double.tryParse(_shippingController.text) ?? 0,
      'tax': double.tryParse(_taxController.text) ?? 0,
      'grandTotal': _calculateGrandTotal(),
      'country': _countryController.text,
      'note': _noteController.text,
      'status': selectedStatus,
      'timestamp': Timestamp.fromDate(selectedDate),

    };

    try {
      await FirebaseFirestore.instance
          .collection('invoices')
          .doc(invoiceNo)
          .set(invoiceData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Invoice added to Firestore')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to submit invoice: $e')),
      );
    }
  }


  InputDecoration _fieldDecoration([String? label]) {
    return InputDecoration(
      isDense       : true,
      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      labelText     : label,
      labelStyle    : const TextStyle(fontSize: 12),
      border        : OutlineInputBorder(
        borderSide  : BorderSide(color: _darkBlue),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom + 32;

    return Scaffold(
      appBar: AppBar(
        title          : const Text('New Invoice', style: TextStyle(fontSize: 16)),
        backgroundColor: _darkBlue,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left  : 16,
            right : 16,
            top   : 16,
            bottom: bottomInset,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer selector
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('customers').snapshots(),
                  builder: (ctx, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snap.data!.docs;
                    return DropdownButtonFormField<String>(
                      value     : selectedCustomer,
                      decoration: _fieldDecoration('Select Customer'),
                      items     : docs.map((d) => DropdownMenuItem(
                        value: d.id,
                        child: Text(d['name'], style: const TextStyle(color: _darkBlue, fontSize: 12)),
                      )).toList(),
                      onChanged: (v) {
                        final name = docs.firstWhere((d) => d.id == v)['name'];
                        setState(() {
                          selectedCustomer     = v;
                          selectedCustomerName = name;
                        });
                      },
                      validator: (v) => v == null ? 'Required' : null,
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Date & Change button
                Text('Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}',
                    style: const TextStyle(color: _darkBlue, fontSize: 12)),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context    : context,
                      initialDate: selectedDate,
                      firstDate  : DateTime(2020),
                      lastDate   : DateTime(2100),
                      builder    : (c, w) => Theme(
                        data: Theme.of(c).copyWith(
                          colorScheme: const ColorScheme.light(primary: _darkBlue),
                        ),
                        child: w!,
                      ),
                    );
                    if (picked != null) setState(() => selectedDate = picked);
                  },
                  child: const Text('Change Date', style: TextStyle(color: _darkBlue, fontSize: 12)),
                ),
                const Divider(color: _darkBlue),

                // Items list
                const Text('Items', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _darkBlue)),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final itm = items[i];
                    final models = _products.map((p) => p.data()!['model_name'] as String).toSet().toList();
                    final colours = itm['model'] != null
                        ? _products.where((p) => p.data()!['model_name'] == itm['model'])
                        .map((p) => p.data()!['colour'] as String).toSet().toList()
                        : <String>[];
                    final sizes = itm['model'] != null && itm['colour'] != null
                        ? _products.where((p) =>
                    p.data()!['model_name'] == itm['model'] &&
                        p.data()!['colour']     == itm['colour'])
                        .map((p) => p.data()!['size'] as String).toSet().toList()
                        : <String>[];

                    return Card(
                      elevation: 1,
                      margin   : const EdgeInsets.symmetric(vertical: 4),
                      shape    : RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(children: [
                          Row(children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value     : itm['model'],
                                decoration: _fieldDecoration('Select Model'),
                                items     : models.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                onChanged : (v) => setState(() {
                                  itm['model']  = v;
                                  itm['colour'] = null;
                                  itm['size']   = null;
                                }),
                                validator : (v) => v == null ? 'Req' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value     : itm['colour'],
                                decoration: _fieldDecoration('Select Colour'),
                                items     : colours.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                onChanged : (v) => setState(() {
                                  itm['colour'] = v;
                                  itm['size']   = null;
                                }),
                                validator : (v) => v == null ? 'Req' : null,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value     : itm['size'],
                                decoration: _fieldDecoration('Select Size'),
                                items     : sizes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged : (v) => setState(() => itm['size'] = v),
                                validator : (v) => v == null ? 'Req' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 70,
                              child: TextFormField(
                                initialValue : itm['qty'].toString(),
                                decoration  : _fieldDecoration('Qty'),
                                keyboardType: TextInputType.number,
                                onChanged   : (v) => setState(() => itm['qty'] = int.tryParse(v) ?? 1),
                                validator   : (v) => v == null || v.isEmpty ? 'Req' : null,
                              ),
                            ),
                            IconButton(
                              icon    : const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                              onPressed: () => _removeItem(i),
                            ),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),

                // Add item button
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon    : const Icon(Icons.add, color: _darkBlue, size: 18),
                    label   : const Text('Add Item', style: TextStyle(color: _darkBlue, fontSize: 12)),
                    onPressed: _addItem,
                  ),
                ),

                const SizedBox(height: 12),

                // Shipping & Tax
                TextFormField(
                  controller : _shippingController,
                  decoration : _fieldDecoration('Shipping Cost'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller : _taxController,
                  decoration : _fieldDecoration('Tax'),
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 8),

                // Country
                TextFormField(
                  controller : _countryController,
                  decoration : _fieldDecoration('Country'),
                ),

                const SizedBox(height: 8),

                // Status
                DropdownButtonFormField<String>(
                  value     : selectedStatus,
                  decoration: _fieldDecoration('Status'),
                  items     : [
                    'Invoice Created',
                    'Payment Done',
                    'Submitted to Factory for Production',
                    'Product Received',
                    'Address Validation of the Customer',
                    'Shipped to Shipping Company'
                  ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged : (v) => setState(() => selectedStatus = v!),
                ),

                const SizedBox(height: 8),

                // Note
                TextFormField(
                  controller: _noteController,
                  maxLines  : 2,
                  decoration: _fieldDecoration('Note'),
                ),

                const SizedBox(height: 12),

                // Grand Total
                Text(
                  'Grand Total: ৳${_calculateGrandTotal().toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _darkBlue),
                ),

                const SizedBox(height: 8),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon  : const Icon(Icons.send),
                    label : const Text('Submit Invoice', style: TextStyle(fontSize: 14)),
                    style : ElevatedButton.styleFrom(
                      backgroundColor: _darkBlue,
                      padding        : const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _submitInvoice,
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
