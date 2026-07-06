import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

const Color _primary = Color(0xFF0D47A1);
const Color _bg = Color(0xFFF4F6F9);
const Color _border = Color(0xFFE2E8F0);
const Color _muted = Color(0xFF64748B);

class AddNewWorkOrderScreen extends StatefulWidget {
  const AddNewWorkOrderScreen({Key? key}) : super(key: key);

  @override
  State<AddNewWorkOrderScreen> createState() => _AddNewWorkOrderScreenState();
}

class _AddNewWorkOrderScreenState extends State<AddNewWorkOrderScreen> {
  String _cid = '';
  final _formKey = GlobalKey<FormState>();

  String? _selectedInvoiceId;
  Map<String, dynamic>? _invoiceData;
  List<Map<String, dynamic>> _items = [];

  final _noteController = TextEditingController();
  DateTime _deadline = DateTime.now().add(const Duration(days: 14));
  String _priority = 'Normal';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _niceDate(DateTime d) => DateFormat('MMM dd, yyyy').format(d);

  InputDecoration _decor(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 2)),
    labelStyle: GoogleFonts.inter(fontSize: 13, color: _muted),
  );

  void _onInvoiceSelected(String invoiceId, Map<String, dynamic> data) {
    setState(() {
      _selectedInvoiceId = invoiceId;
      _invoiceData = data;
      
      final itemsRaw = (data['items'] as List?) ?? [];
      _items = itemsRaw.cast<Map>().map((e) {
        return {
          'model': e['model'] ?? '',
          'qty': e['qty'] ?? 1,
          'base': e['base'] ?? '',
          'colour': e['colour'] ?? '',
          'size': e['size'] ?? '',
          'density': '',
          'hairLength': '',
          'customizationNote': '',
        };
      }).toList();
    });
  }

  String _generateTracking() {
    final ts = DateFormat('yyyyMMddHHmm').format(DateTime.now());
    final rnd = (Random().nextInt(9000) + 1000).toString();
    return 'TRK-WO-$ts$rnd';
  }

  Future<void> _submit(bool dispatch) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedInvoiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an invoice.')));
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      final tracking = _generateTracking();
      final woRef = DB.colSync(_cid, C.workOrders).doc(tracking);
      final invRef = DB.colSync(_cid, C.invoices).doc(_selectedInvoiceId);

      final user = FirebaseAuth.instance.currentUser;

      int totalQty = 0;
      for (var it in _items) {
        totalQty += (it['qty'] as int?) ?? 0;
      }

      batch.set(woRef, {
        'workOrderNo': tracking,
        'relatedInvoiceNo': _invoiceData!['invoiceNo'],
        'customerId': _invoiceData!['customerId'],
        'buyerName': _invoiceData!['customerName'],
        'agentEmail': user?.email,
        'makerUid': user?.uid,
        'items': _items,
        'totalPieces': totalQty,
        'deadline': Timestamp.fromDate(_deadline),
        'priority': _priority,
        'marketingNote': _noteController.text.trim(),
        'status': dispatch ? 'Awaiting Factory' : 'Draft',
        'currentStage': dispatch ? 'Production Queue' : null,
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        if (dispatch) 'dispatchedAt': FieldValue.serverTimestamp(),
      });

      if (dispatch) {
        batch.update(invRef, {'status': 'Work Order Created'});
      }

      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dispatch ? '✅ Work Order Dispatched!' : '✅ Draft Saved')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: Text('Create Work Order', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CARD 1: SOURCE SELECTION
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Approved Invoice', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.invoices).where('status', isEqualTo: 'HR Verified').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
                        final docs = snapshot.data?.docs ?? [];
                        
                        return DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedInvoiceId,
                          decoration: _decor('Search HR Verified Invoices'),
                          items: docs.map((d) {
                            final m = d.data() as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value: d.id,
                              child: Text('Inv #${m['invoiceNo']} • ${m['customerName']}'),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              final doc = docs.firstWhere((d) => d.id == v);
                              _onInvoiceSelected(v, doc.data() as Map<String, dynamic>);
                            }
                          },
                          validator: (v) => v == null ? 'Required' : null,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // CARD 2: PRODUCT SPECIFICATIONS
              if (_selectedInvoiceId != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Product Specifications', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 16),
                      ...List.generate(_items.length, (i) {
                        final it = _items[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${it['model']}', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: _primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Text('Qty: ${it['qty']}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _primary)),
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8, runSpacing: 8,
                                children: [
                                  if (it['base'].toString().isNotEmpty) Chip(label: Text('Base: ${it['base']}')),
                                  if (it['colour'].toString().isNotEmpty) Chip(label: Text('Colour: ${it['colour']}')),
                                  if (it['size'].toString().isNotEmpty) Chip(label: Text('Size: ${it['size']}')),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: it['density'],
                                      decoration: _decor('Density (e.g. 130%)'),
                                      onChanged: (v) => _items[i]['density'] = v,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: it['hairLength'],
                                      decoration: _decor('Hair Length (e.g. 18")'),
                                      onChanged: (v) => _items[i]['hairLength'] = v,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                initialValue: it['customizationNote'],
                                decoration: _decor('Customization Notes (Curl, Parting, etc.)'),
                                maxLines: 2,
                                onChanged: (v) => _items[i]['customizationNote'] = v,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // CARD 3: PRODUCTION INSTRUCTIONS
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Production Instructions', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _priority,
                            decoration: _decor('Priority'),
                            items: ['Normal', 'Urgent', 'VIP'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setState(() => _priority = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _deadline,
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) setState(() => _deadline = picked);
                            },
                            child: InputDecorator(
                              decoration: _decor('Delivery Deadline'),
                              child: Text(_niceDate(_deadline), style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteController,
                      decoration: _decor('Marketing Instructions (Visible to Factory)'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ACTION BUTTONS
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: _muted,
                        side: BorderSide(color: _border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: () => _submit(false),
                      child: Text('Save Draft', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: Text('Dispatch to Factory', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Confirm Dispatch'),
                            content: const Text('This will send the Work Order directly to the Factory. You will not be able to edit the product specifications once dispatched.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: _primary),
                                onPressed: () {
                                  Navigator.pop(c);
                                  _submit(true);
                                },
                                child: const Text('Dispatch', style: TextStyle(color: Colors.white)),
                              )
                            ],
                          )
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
