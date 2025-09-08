import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color _indigo = Color(0xFF0D47A1); // brand primary
const Color _accent = Color(0xFF448AFF); // blueAccent-ish
const Color _cardBG = Colors.white;
const Color _chipBg = Color(0xFFEFF3FF);

class NewInvoicesScreen extends StatefulWidget {
  const NewInvoicesScreen({Key? key}) : super(key: key);

  @override
  State<NewInvoicesScreen> createState() => _NewInvoicesScreenState();
}

class _NewInvoicesScreenState extends State<NewInvoicesScreen> {
  final _formKey = GlobalKey<FormState>();

  // Session / Agent
  String? _uid;
  String? _agentEmail;
  String  _agentName = '';

  // Buyer
  String? selectedCustomerId;
  String  selectedCustomerName = '';

  // Date
  DateTime selectedDate = DateTime.now();

  // Charges
  final _shippingController = TextEditingController();
  final _taxController      = TextEditingController();
  final _noteController     = TextEditingController();
  final _countryController  = TextEditingController();

  // Pipeline (limit to Payment Taken)
  static const List<String> kFullSteps = [
    'Invoice Created',                         // 0
    'Payment Requested',                       // 1
    'Payment Taken',                           // 2 (max editable here)
    'Submitted to Factory for Production',     // 3
    'Production In Progress',                  // 4
    'Quality Check',                           // 5
    'Product Received at Warehouse',           // 6
    'Address Validation of the Customer',      // 7
    'Packed & Ready',                          // 8
    'Shipped to Shipping Company',             // 9
    'In Transit',                              //10
    'Delivered / Completed',                   //11
  ];
  static const int kMaxEditableStepIndex = 2;
  int _statusIndex = 0;

  // Payment (optional)
  bool   _isPaymentTaken = false;
  final  _paymentAmountCtl = TextEditingController();
  String _paymentMethod    = 'Cash';
  final  _paymentRefCtl    = TextEditingController();
  DateTime? _paymentDate;

  // Products
  List<DocumentSnapshot<Map<String, dynamic>>> _products = [];

  // Items (each: model, colour, size, qty, autoPrice, unitPrice, lineTotal)
  final List<Map<String, dynamic>> items = [];

  // ---------- lifecycle ----------
  @override
  void initState() {
    super.initState();
    _loadAgent();
    _loadProducts();
    _addItem();
  }

  @override
  void dispose() {
    _shippingController.dispose();
    _taxController.dispose();
    _noteController.dispose();
    _countryController.dispose();
    _paymentAmountCtl.dispose();
    _paymentRefCtl.dispose();
    super.dispose();
  }

  // ---------- data ----------
  Future<void> _loadAgent() async {
    final user = FirebaseAuth.instance.currentUser;
    _uid = user?.uid;
    _agentEmail = user?.email;
    if (_uid != null) {
      final udoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      _agentName = (udoc.data()?['fullName'] as String?) ?? (user?.displayName ?? '');
    }
    setState(() {});
  }

  Future<void> _loadProducts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .orderBy('model_name')
        .get();
    setState(() => _products = snapshot.docs);
  }

  // ---------- items ----------
  void _addItem() {
    setState(() {
      items.add({
        'model'    : null,
        'colour'   : null,
        'size'     : null,
        'qty'      : 1,
        'autoPrice': true,
        'unitPrice': 0.0,
        'lineTotal': 0.0,
      });
    });
  }

  void _removeItem(int i) {
    setState(() => items.removeAt(i));
  }

  double _autoUnitPrice(String? model, String? colour, String? size) {
    if (model == null || colour == null || size == null) return 0.0;
    for (final p in _products) {
      final d = p.data()!;
      if (d['model_name'] == model && d['colour'] == colour && d['size'] == size) {
        final up = d['unit_price'];
        if (up is num) return up.toDouble();
        if (up is String) return double.tryParse(up) ?? 0.0;
      }
    }
    return 0.0;
  }

  void _recomputeItem(int i) {
    final itm = items[i];
    final qty = (itm['qty'] as int?) ?? 1;
    double unit = itm['autoPrice'] == true
        ? _autoUnitPrice(itm['model'], itm['colour'], itm['size'])
        : ((itm['unitPrice'] is num) ? itm['unitPrice'].toDouble() : double.tryParse('${itm['unitPrice']}') ?? 0.0);
    unit = max(0, unit);
    items[i]['unitPrice'] = unit;
    items[i]['lineTotal'] = unit * max(1, qty);
  }

  void _recomputeAll() {
    for (var i = 0; i < items.length; i++) _recomputeItem(i);
    setState(() {});
  }

  // ---------- totals ----------
  double _subtotal() {
    double s = 0;
    for (final itm in items) {
      final lt = itm['lineTotal'];
      s += (lt is num) ? lt.toDouble() : double.tryParse('$lt') ?? 0.0;
    }
    return s;
  }

  double _grandTotal() {
    final ship = double.tryParse(_shippingController.text) ?? 0;
    final tax  = double.tryParse(_taxController.text) ?? 0;
    return _subtotal() + ship + tax;
  }

  String _money(num v) => v.toStringAsFixed(2);

  InputDecoration _decor(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    filled: true,
    fillColor: Colors.grey[50],
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFB0BEC5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _indigo, width: 1.5),
    ),
    labelStyle: const TextStyle(fontSize: 12),
  );

  // ---------- submit ----------
  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a buyer')));
      return;
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one item')));
      return;
    }
    for (final itm in items) {
      if (itm['model'] == null || itm['colour'] == null || itm['size'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete item specs')));
        return;
      }
      final up = (itm['unitPrice'] is num) ? itm['unitPrice'].toDouble() : double.tryParse('${itm['unitPrice']}') ?? 0.0;
      final qty = (itm['qty'] as int?) ?? 0;
      if (up <= 0 || qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Qty & price must be > 0')));
        return;
      }
    }

    _recomputeAll();

    // invoice id
    final safeName  = selectedCustomerName.isEmpty
        ? 'cust'
        : selectedCustomerName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final datePart  = DateFormat('yyyyMMdd').format(selectedDate);
    final totalPart = _grandTotal().toStringAsFixed(0);
    final rnd       = Random().nextInt(900) + 100;
    final invoiceNo = '${safeName}_$datePart\_${totalPart}_$rnd';

    // items map
    final invoiceItems = items.map((itm) => {
      'model'    : itm['model'],
      'colour'   : itm['colour'],
      'size'     : itm['size'],
      'qty'      : itm['qty'],
      'unitPrice': (itm['unitPrice'] is num) ? itm['unitPrice'].toDouble() : double.tryParse('${itm['unitPrice']}') ?? 0.0,
      'lineTotal': (itm['lineTotal'] is num) ? itm['lineTotal'].toDouble() : double.tryParse('${itm['lineTotal']}') ?? 0.0,
    }).toList();

    final user        = FirebaseAuth.instance.currentUser;
    final uid         = user?.uid ?? _uid;
    final agentEmail  = user?.email ?? _agentEmail ?? '';

    Map<String, dynamic>? payment;
    if (_isPaymentTaken) {
      payment = {
        'taken' : true,
        'amount': double.tryParse(_paymentAmountCtl.text) ?? 0.0,
        'method': _paymentMethod,
        'ref'   : _paymentRefCtl.text.trim(),
        'date'  : _paymentDate != null ? Timestamp.fromDate(_paymentDate!) : FieldValue.serverTimestamp(),
      };
    }

    final payload = {
      'invoiceNo'   : invoiceNo,
      'customerId'  : selectedCustomerId,
      'customerName': selectedCustomerName,
      'ownerUid'    : uid,
      'ownerEmail'  : agentEmail,              // used by summaries
      'agentId'     : uid,                     // legacy
      'agentEmail'  : agentEmail,              // legacy
      'agentName'   : _agentName,
      'date'        : selectedDate,
      'createdAt'   : FieldValue.serverTimestamp(),
      'items'       : invoiceItems,
      'shippingCost': double.tryParse(_shippingController.text) ?? 0.0,
      'tax'         : double.tryParse(_taxController.text) ?? 0.0,
      'grandTotal'  : _grandTotal(),
      'country'     : _countryController.text.trim(),
      'note'        : _noteController.text.trim(),
      'status'      : kFullSteps[_statusIndex],
      'statusStep'  : _statusIndex,
      'timestamp'   : Timestamp.fromDate(selectedDate),
      if (payment != null) 'payment': payment,
    };

    try {
      await FirebaseFirestore.instance.collection('invoices').doc(invoiceNo).set(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Invoice saved')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Failed: $e')));
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: _indigo,
        foregroundColor: Colors.white,
        title: const Text('New Invoice', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      bottomNavigationBar: _summaryBar(
        subtotal: _subtotal(),
        shipping: double.tryParse(_shippingController.text) ?? 0,
        tax: double.tryParse(_taxController.text) ?? 0,
        grand: _grandTotal(),
        onSubmit: () {
          _recomputeAll();
          _submitInvoice();
        },
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 90), // leave space for summary bar
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _section(
                  icon: Icons.person_pin_circle,
                  title: 'Buyer & Date',
                  child: Column(
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: (_agentEmail == null)
                            ? const Stream.empty()
                            : FirebaseFirestore.instance
                            .collection('customers')
                            .where('ownerEmail', isEqualTo: _agentEmail)
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (ctx, snap) {
                          if (!snap.hasData) {
                            return const SizedBox(
                              height: 36,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(width: 160, child: LinearProgressIndicator(minHeight: 2)),
                              ),
                            );
                          }
                          final docs = snap.data!.docs;
                          return DropdownButtonFormField<String>(
                            value: selectedCustomerId,
                            decoration: _decor('Select Buyer'),
                            items: docs.map((d) {
                              final name = (d['name'] ?? 'Unnamed').toString();
                              return DropdownMenuItem(value: d.id, child: Text(name, style: const TextStyle(fontSize: 13)));
                            }).toList(),
                            onChanged: (v) {
                              final name = docs.firstWhere((d) => d.id == v)['name'];
                              setState(() {
                                selectedCustomerId   = v;
                                selectedCustomerName = (name ?? '').toString();
                              });
                            },
                            validator: (v) => v == null ? 'Required' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _infoTile(
                              'Date',
                              DateFormat('yyyy-MM-dd').format(selectedDate),
                              icon: Icons.event,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit_calendar, size: 18),
                            label: const Text('Change Date'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _indigo,
                              side: const BorderSide(color: _indigo),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                                builder: (c, w) => Theme(
                                  data: Theme.of(c).copyWith(
                                    colorScheme: const ColorScheme.light(primary: _indigo),
                                  ),
                                  child: w!,
                                ),
                              );
                              if (picked != null) setState(() => selectedDate = picked);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                _section(
                  icon: Icons.flag,
                  title: 'Status (up to Payment Taken)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<int>(
                        value: _statusIndex,
                        decoration: _decor('Current Step'),
                        items: List.generate(kMaxEditableStepIndex + 1, (i) => i)
                            .map((i) => DropdownMenuItem(value: i, child: Text(kFullSteps[i])))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _statusIndex    = v ?? 0;
                            _isPaymentTaken = _statusIndex >= 2;
                            if (_isPaymentTaken && _paymentDate == null) _paymentDate = DateTime.now();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _pipelineChips(currentIndex: _statusIndex),
                    ],
                  ),
                ),

                _section(
                  icon: Icons.shopping_bag,
                  title: 'Items (Auto or Manual Pricing)',
                  child: Column(
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        itemBuilder: (_, i) => _itemCard(i),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add, color: _indigo),
                          label: const Text('Add Item', style: TextStyle(color: _indigo)),
                        ),
                      ),
                    ],
                  ),
                ),

                _section(
                  icon: Icons.local_shipping,
                  title: 'Charges & Notes',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _shippingController,
                              keyboardType: TextInputType.number,
                              decoration: _decor('Shipping Cost'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _taxController,
                              keyboardType: TextInputType.number,
                              decoration: _decor('Tax'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _countryController,
                        decoration: _decor('Country'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _noteController,
                        maxLines: 2,
                        decoration: _decor('Note'),
                      ),
                    ],
                  ),
                ),

                _section(
                  icon: Icons.payments,
                  title: 'Payment (Optional)',
                  child: Column(
                    children: [
                      CheckboxListTile(
                        value: _isPaymentTaken,
                        onChanged: (v) {
                          setState(() {
                            _isPaymentTaken = v ?? false;
                            if (_isPaymentTaken && _statusIndex < 2) _statusIndex = 2;
                            if (_isPaymentTaken && _paymentDate == null) _paymentDate = DateTime.now();
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Payment Taken'),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _isPaymentTaken ? 1 : .45,
                        child: IgnorePointer(
                          ignoring: !_isPaymentTaken,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _paymentAmountCtl,
                                      keyboardType: TextInputType.number,
                                      decoration: _decor('Amount Received'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _paymentMethod,
                                      items: const ['Cash', 'Bank', 'Card', 'Mobile Banking']
                                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                          .toList(),
                                      onChanged: (v) => setState(() => _paymentMethod = v ?? 'Cash'),
                                      decoration: _decor('Method'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _paymentRefCtl,
                                decoration: _decor('Reference / Txn ID'),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _infoTile(
                                      'Payment Date',
                                      _paymentDate == null
                                          ? '-'
                                          : DateFormat('yyyy-MM-dd').format(_paymentDate!),
                                      icon: Icons.event_available,
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: () async {
                                      final d = await showDatePicker(
                                        context: context,
                                        initialDate: _paymentDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                        builder: (c, w) => Theme(
                                          data: Theme.of(c).copyWith(
                                            colorScheme: const ColorScheme.light(primary: _indigo),
                                          ),
                                          child: w!,
                                        ),
                                      );
                                      if (d != null) setState(() => _paymentDate = d);
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _indigo,
                                      side: const BorderSide(color: _indigo),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Change'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----- widgets -----
  Widget _itemCard(int i) {
    final itm = items[i];

    final models = _products
        .map((p) => p.data()!['model_name'] as String)
        .toSet()
        .toList()
      ..sort();

    final colours = (itm['model'] != null)
        ? _products
        .where((p) => p.data()!['model_name'] == itm['model'])
        .map((p) => p.data()!['colour'] as String)
        .toSet()
        .toList()
        : <String>[];
    colours.sort();

    final sizes = (itm['model'] != null && itm['colour'] != null)
        ? _products
        .where((p) => p.data()!['model_name'] == itm['model'] && p.data()!['colour'] == itm['colour'])
        .map((p) => p.data()!['size'] as String)
        .toSet()
        .toList()
        : <String>[];
    sizes.sort();

    return Card(
      color: _cardBG,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: itm['model'],
                    decoration: _decor('Model'),
                    items: models.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) {
                      setState(() {
                        itm['model']  = v;
                        itm['colour'] = null;
                        itm['size']   = null;
                      });
                      _recomputeItem(i);
                    },
                    validator: (v) => v == null ? 'Req' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: itm['colour'],
                    decoration: _decor('Colour'),
                    items: colours.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) {
                      setState(() {
                        itm['colour'] = v;
                        itm['size']   = null;
                      });
                      _recomputeItem(i);
                    },
                    validator: (v) => v == null ? 'Req' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: itm['size'],
                    decoration: _decor('Size'),
                    items: sizes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) {
                      setState(() => itm['size'] = v);
                      _recomputeItem(i);
                    },
                    validator: (v) => v == null ? 'Req' : null,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    initialValue: '${itm['qty']}',
                    keyboardType: TextInputType.number,
                    decoration: _decor('Qty'),
                    onChanged: (v) {
                      final q = int.tryParse(v) ?? 1;
                      setState(() => itm['qty'] = q <= 0 ? 1 : q);
                      _recomputeItem(i);
                    },
                    validator: (v) => (v == null || v.isEmpty) ? 'Req' : null,
                  ),
                ),
                IconButton(
                  onPressed: () => _removeItem(i),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'Remove item',
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Switch(
                        value: (itm['autoPrice'] as bool?) ?? true,
                        activeColor: _indigo,
                        onChanged: (val) {
                          setState(() => itm['autoPrice'] = val);
                          _recomputeItem(i);
                        },
                      ),
                      const SizedBox(width: 6),
                      const Text('Auto price', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      const Tooltip(
                        message: 'If ON, price comes from products.unit_price by Model/Colour/Size',
                        triggerMode: TooltipTriggerMode.tap,
                        child: Icon(Icons.info_outline, size: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 140,
                  child: TextFormField(
                    enabled: (items[i]['autoPrice'] == false),
                    initialValue: _money((items[i]['unitPrice'] as num?)?.toDouble() ?? 0),
                    keyboardType: TextInputType.number,
                    decoration: _decor('Unit Price'),
                    onChanged: (v) {
                      items[i]['unitPrice'] = double.tryParse(v) ?? 0.0;
                      _recomputeItem(i);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Chip(
                backgroundColor: _chipBg,
                label: Text(
                  'Line Total: ৳${_money((items[i]['lineTotal'] as num?)?.toDouble() ?? 0)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pipelineChips({required int currentIndex}) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(kFullSteps.length, (i) {
        final active = i <= currentIndex;
        final editable = i <= kMaxEditableStepIndex;
        return Chip(
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          backgroundColor: active ? _indigo : _chipBg,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.check_circle : (editable ? Icons.circle_outlined : Icons.lock_outline),
                size: 14,
                color: active ? Colors.white : _indigo,
              ),
              const SizedBox(width: 6),
              Text(
                kFullSteps[i],
                style: TextStyle(
                  fontSize: 11,
                  color: active ? Colors.white : _indigo,
                  fontWeight: active ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _section({required IconData icon, required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _cardBG,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              gradient: LinearGradient(colors: [_indigo, _accent]),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white,
                  child: Icon(icon, size: 16, color: _indigo),
                ),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, {IconData? icon}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB0BEC5)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: _indigo),
            const SizedBox(width: 8),
          ],
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700, color: _indigo)),
          Flexible(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _summaryBar({
    required double subtotal,
    required double shipping,
    required double tax,
    required double grand,
    required VoidCallback onSubmit,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -2))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: DefaultTextStyle(
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Subtotal: ৳${_money(subtotal)}'),
                    Text('Shipping: ৳${_money(shipping)}'),
                    Text('Tax: ৳${_money(tax)}'),
                    const SizedBox(height: 4),
                    Text('Grand Total: ৳${_money(grand)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: _indigo)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.send),
              label: const Text('Submit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
