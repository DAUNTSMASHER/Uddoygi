// lib/features/factory/presentation/factory/purchase_order_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:intl/intl.dart';

const Color _darkBlue = Color(0xFF40062D);

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({Key? key}) : super(key: key);

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  String _cid = '';
  final _priceController    = TextEditingController();
  final _quantityController = TextEditingController();
  final _supplierController = TextEditingController();
  final _productController  = TextEditingController();
  final _agentController    = TextEditingController();

  String? _selectedInvoice;

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    _supplierController.dispose();
    _productController.dispose();
    _agentController.dispose();
    super.dispose();
  }

  Future<void> _acceptPO(String docId) async {
    if (_cid.isEmpty) return;
    await DB.colSync(_cid, C.purchaseOrders).doc(docId).update({
      'status': 'accepted',
      'acceptedAt': Timestamp.now(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Purchase order accepted')),
      );
    }
  }

  Future<void> _rejectPO(String docId) async {
    if (_cid.isEmpty) return;
    String? recommendation;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Purchase Order'),
        content: TextFormField(
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Reason / Recommendation'),
          onChanged: (v) => recommendation = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if ((recommendation ?? '').trim().isEmpty) return;
              Navigator.of(ctx).pop();
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if ((recommendation ?? '').trim().isEmpty) return;

    await DB.colSync(_cid, C.purchaseOrders).doc(docId).update({
      'status': 'rejected',
      'recommendation': recommendation,
      'rejectedAt': Timestamp.now(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Purchase order rejected')),
      );
    }
  }

  Future<void> _submitPurchaseDetails() async {
    if (_productController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _quantityController.text.isEmpty ||
        _supplierController.text.isEmpty ||
        _selectedInvoice == null ||
        _agentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    await DB.colSync(_cid, C.productPrices).add({
      'product':   _productController.text.trim(),
      'price':     double.tryParse(_priceController.text.trim()) ?? 0,
      'quantity':  int.tryParse(_quantityController.text.trim()) ?? 0,
      'supplier':  _supplierController.text.trim(),
      'invoice':   _selectedInvoice,
      'agent':     _agentController.text.trim(),
      'timestamp': Timestamp.now(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📝 Purchase details saved.')),
      );
    }

    _priceController.clear();
    _quantityController.clear();
    _supplierController.clear();
    _productController.clear();
    _agentController.clear();
    setState(() => _selectedInvoice = null);
  }

  Future<List<String>> _getInvoiceIDs() async {
    if (_cid.isEmpty) return [];
    final snap = await DB.colSync(_cid, C.invoices).get();
    return snap.docs.map((d) => d.id).toList();
  }

  Future<String?> _getAgentForInvoice(String invoiceId) async {
    if (_cid.isEmpty) return null;
    final doc = await DB.colSync(_cid, C.invoices).doc(invoiceId).get();
    return doc.data()?['submittedBy'] as String?;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        backgroundColor: _darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Section 1: Existing Purchase Orders
            Padding(
              padding: const EdgeInsets.all(12),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _cid.isEmpty
                    ? const Stream.empty()
                    : DB.colSync(_cid, C.purchaseOrders).orderBy('timestamp', descending: true).snapshots(),
                builder: (ctx, snap) {
                  if (_cid.isEmpty || snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No purchase orders found.'));
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (ctx, i) {
                      final doc = docs[i];
                      final data = doc.data();
                      final poNo = data['poNo'] as String? ?? doc.id;
                      final supplier = data['supplierName'] as String? ?? '';
                      final submittedBy = data['submittedBy'] as String? ?? '';
                      final ts = data['expectedDate'] as Timestamp?;
                      final expected = ts != null
                          ? DateFormat('yyyy-MM-dd').format(ts.toDate())
                          : '—';
                      final items = (data['items'] as List?) ?? [];
                      final status = data['status'] as String? ?? 'pending';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PO #: $poNo',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('Supplier: $supplier'),
                              Text('Submitted by: $submittedBy'),
                              Text('Expected: $expected'),
                              Text('Items: ${items.length}'),
                              const SizedBox(height: 8),
                              if (status != 'accepted' && status != 'rejected')
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.check, size: 18),
                                      label: const Text('Accept'),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green),
                                      onPressed: () => _acceptPO(doc.id),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.close, size: 18),
                                      label: const Text('Reject'),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red),
                                      onPressed: () => _rejectPO(doc.id),
                                    ),
                                  ],
                                )
                              else
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'Status: ${status == 'accepted' ? 'Accepted' : 'Rejected'}',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: status == 'accepted'
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Section 2: Product Price Entry
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(thickness: 1),
                  const Text(
                    'Product Price Entry',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Invoice Dropdown
                  FutureBuilder<List<String>>(
                    future: _getInvoiceIDs(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) return const CircularProgressIndicator();
                      return DropdownButtonFormField<String>(
                        value: _selectedInvoice,
                        decoration: const InputDecoration(
                          labelText: 'Invoice Number',
                          border: OutlineInputBorder(),
                        ),
                        items: snap.data!
                            .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                            .toList(),
                        onChanged: (val) async {
                          final agent = await _getAgentForInvoice(val!);
                          setState(() {
                            _selectedInvoice = val;
                            _agentController.text = agent ?? '';
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Agent Name (editable)
                  TextFormField(
                    controller: _agentController,
                    decoration: const InputDecoration(
                      labelText: 'Agent Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Product Name (editable)
                  TextFormField(
                    controller: _productController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quantity
                  TextFormField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Price per unit
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'প্রতি ইউনিট Price',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Supplier
                  TextFormField(
                    controller: _supplierController,
                    decoration: const InputDecoration(
                      labelText: 'Supplierর নাম',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitPurchaseDetails,
                      icon: const Icon(Icons.save),
                      label: const Text('Price এন্ট্রি জমা দিন'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _darkBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
