// lib/features/marketing/presentation/screens/add_new_wo.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'work_order_updates_screen.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class AddNewWorkOrderScreen extends StatefulWidget {
  const AddNewWorkOrderScreen({Key? key}) : super(key: key);

  @override
  State<AddNewWorkOrderScreen> createState() => _AddNewWorkOrderScreenState();
}

class _AddNewWorkOrderScreenState extends State<AddNewWorkOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedInvoiceId;
  Map<String, dynamic>? _invoiceData;
  List<Map<String, dynamic>> _invoiceItems = [];
  final List<TextEditingController> _quantityControllers = [];
  final _instructionsController = TextEditingController();

  int _deliveryDays = 7;
  DateTime _finalDate = DateTime.now();

  // toggle between “add” form and nothing
  bool _showForm = false;

  @override
  void dispose() {
    for (var c in _quantityControllers) c.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _onInvoiceSelected(String? id) async {
    if (id == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('invoices')
        .doc(id)
        .get();
    final data = doc.data();
    if (data == null) return;
    setState(() {
      _selectedInvoiceId = id;
      _invoiceData = data;
      _invoiceItems = List<Map<String, dynamic>>.from(data['items'] ?? []);
      _quantityControllers
        ..clear()
        ..addAll(_invoiceItems.map((item) =>
            TextEditingController(text: '${item['qty'] ?? ''}')));
    });
  }

  Future<void> _submitWorkOrder() async {
    if (!_formKey.currentState!.validate() ||
        _selectedInvoiceId == null ||
        _invoiceData == null) return;

    // update qty on each item
    for (int i = 0; i < _invoiceItems.length; i++) {
      final qty = int.tryParse(_quantityControllers[i].text) ?? 0;
      _invoiceItems[i]['qty'] = qty;
    }

    final invoiceNo =
        _invoiceData!['invoiceNo'] as String? ?? _selectedInvoiceId!;
    final dateStr = DateFormat('yyyyMMdd').format(_finalDate);
    final workNo = '${invoiceNo}_WO_$dateStr';

    final userEmail = FirebaseAuth.instance.currentUser?.email;

    // Build the work order document, now including a 'status' field
    final workOrder = <String, dynamic>{
      'workOrderNo': workNo,
      'invoiceId': _selectedInvoiceId,
      'items': _invoiceItems,
      'deliveryDays': _deliveryDays,
      'finalDate': _finalDate,
      'instructions': _instructionsController.text,
      'submittedToFactory': false,
      'timestamp': Timestamp.now(),
      'agentEmail': userEmail,
      'status': 'Pending', // ← NEW: set initial status
    };

    await FirebaseFirestore.instance
        .collection('work_orders')
        .doc(workNo)
        .set(workOrder);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Work order submitted!')),
    );

    // After submit, go to updates
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WorkOrderUpdatesScreen()),
    );
  }

  Widget _buildTopGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _showForm ? Colors.white : _darkBlue,
              foregroundColor: _showForm ? _darkBlue : Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add New\nWork Order', textAlign: TextAlign.center),
            onPressed: () => setState(() => _showForm = !_showForm),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: !_showForm ? Colors.white : _darkBlue,
              foregroundColor: !_showForm ? _darkBlue : Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.list),
            label: const Text('All\nWork Orders', textAlign: TextAlign.center),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WorkOrderUpdatesScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Orders'),
        backgroundColor: _darkBlue,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildTopGrid(),
            if (_showForm)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Invoice selector
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('invoices')
                            .where('agentEmail', isEqualTo: userEmail)
                            .orderBy('timestamp', descending: true)
                            .snapshots(),
                        builder: (ctx, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final docs = snap.data?.docs ?? [];
                          return DropdownButtonFormField<String>(
                            value: _selectedInvoiceId,
                            decoration: const InputDecoration(
                              labelText: 'Select Invoice',
                              border: OutlineInputBorder(),
                            ),
                            items: docs.map((d) {
                              final invNo = d.data()['invoiceNo'] as String? ?? d.id;
                              return DropdownMenuItem(
                                value: d.id,
                                child: Text(invNo),
                              );
                            }).toList(),
                            onChanged: _onInvoiceSelected,
                            validator: (v) => v == null ? 'Required' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // Invoice items
                      if (_invoiceData != null) ...[
                        const Text('Invoice Items',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _invoiceItems.length,
                          itemBuilder: (ctx, i) {
                            final item = _invoiceItems[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(child: Text(item['model'] as String? ?? '')),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 60,
                                    child: TextFormField(
                                      controller: _quantityControllers[i],
                                      decoration: const InputDecoration(labelText: 'Qty'),
                                      keyboardType: TextInputType.number,
                                      validator: (v) =>
                                      (v == null || v.isEmpty) ? 'Req' : null,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        // Delivery days
                        DropdownButtonFormField<int>(
                          value: _deliveryDays,
                          decoration: const InputDecoration(
                            labelText: 'Delivery Time (days)',
                            border: OutlineInputBorder(),
                          ),
                          items: [7, 14, 21]
                              .map((d) => DropdownMenuItem(value: d, child: Text('$d days')))
                              .toList(),
                          onChanged: (v) => setState(() => _deliveryDays = v!),
                        ),
                        const SizedBox(height: 16),
                        // Final date
                        Text(
                            'Final Date: ${DateFormat('yyyy-MM-dd').format(_finalDate)}'),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _finalDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => _finalDate = picked);
                          },
                          child: const Text('Select Date'),
                        ),
                        const SizedBox(height: 16),
                        // Instructions
                        TextFormField(
                          controller: _instructionsController,
                          decoration: const InputDecoration(
                            labelText: 'Special Instructions',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: _darkBlue),
                            onPressed: _submitWorkOrder,
                            child: const Text('Submit to Factory'),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
