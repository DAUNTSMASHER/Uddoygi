import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:csc_picker/csc_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

const Color _primary = Color(0xFF2563EB);
const Color _primaryDk = Color(0xFF1E3A8A);
const Color _bg = Color(0xFFF7F9FC);
const Color _cardBG = Colors.white;
const Color _border = Color(0xFFE2E8F0);
const Color _text = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);

class NewInvoicesScreen extends StatefulWidget {
  final String? initialCustomerId;
  final String? initialCustomerName;
  final String? initialCustomerEmail;
  
  final String? initialProductModel;
  final String? initialProductColour;
  final String? initialProductSize;
  final double? initialProductPrice;

  const NewInvoicesScreen({
    Key? key,
    this.initialCustomerId,
    this.initialCustomerName,
    this.initialCustomerEmail,
    this.initialProductModel,
    this.initialProductColour,
    this.initialProductSize,
    this.initialProductPrice,
  }) : super(key: key);

  @override
  State<NewInvoicesScreen> createState() => _NewInvoicesScreenState();
}

class _NewInvoicesScreenState extends State<NewInvoicesScreen> {
  String _cid = '';
  final _formKey = GlobalKey<FormState>();

  // Session / Agent
  String? _uid;
  String? _agentEmail;
  String _agentName = '';

  // Buyer
  String? selectedCustomerId;
  String selectedCustomerName = '';
  String? selectedCustomerEmail;

  // Date
  DateTime selectedDate = DateTime.now();

  // Charges & Discounts
  final _shippingController = TextEditingController();
  final _taxController = TextEditingController();
  final _discountController = TextEditingController();
  final _noteController = TextEditingController();

  // Shipping state
  String? _shipCountryName;
  String? _shipCountryCode;
  String? _shipState;
  String? _shipCity;

  final _addr1Ctl = TextEditingController();
  final _addr2Ctl = TextEditingController();
  final _zipCtl   = TextEditingController();

  // Phone
  String _phoneIso = '';
  String _phoneDial = '';
  String _phoneNational = '';

  // Payment
  bool _isPaymentTaken = false;
  final _paymentAmountCtl = TextEditingController();
  String _paymentMethod = 'Cash';
  final _paymentRefCtl = TextEditingController();
  DateTime? _paymentDate;

  // Products
  List<DocumentSnapshot<Map<String, dynamic>>> _products = [];
  final List<Map<String, dynamic>> items = [];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCustomerId != null) {
      selectedCustomerId = widget.initialCustomerId;
      selectedCustomerName = widget.initialCustomerName ?? '';
      selectedCustomerEmail = widget.initialCustomerEmail;
    }
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _loadAgent();
    _loadProducts();
    _addItem(
      model: widget.initialProductModel,
      colour: widget.initialProductColour,
      size: widget.initialProductSize,
      unitPrice: widget.initialProductPrice,
    );
  }

  @override
  void dispose() {
    _shippingController.dispose();
    _taxController.dispose();
    _discountController.dispose();
    _noteController.dispose();
    _addr1Ctl.dispose();
    _addr2Ctl.dispose();
    _zipCtl.dispose();
    _paymentAmountCtl.dispose();
    _paymentRefCtl.dispose();
    super.dispose();
  }

  Future<void> _loadAgent() async {
    final user = FirebaseAuth.instance.currentUser;
    _uid = user?.uid;
    _agentEmail = user?.email;
    if (_uid != null) {
      final udoc = await (await DB.col(C.users)).doc(_uid).get();
      _agentName = (udoc.data()?['fullName'] as String?) ?? (user?.displayName ?? '');
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadProducts() async {
    final snapshot = await (await DB.col(C.products)).orderBy('model_name').get();
    if (mounted) setState(() => _products = snapshot.docs);
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _customersStream() {
    final col = DB.colSync(_cid, C.customers);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? _uid;
    if (uid == null) return const Stream.empty();
    return col.where('createdBy', isEqualTo: uid).snapshots().map((snap) {
      final docs = snap.docs.toList();
      DateTime ts(Map<String, dynamic> m) {
        final t = (m['updatedAt'] ?? m['createdAt'] ?? m['timestamp']) as Timestamp?;
        return t?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      docs.sort((a, b) {
        final an = (a.data()['name'] ?? '').toString().toLowerCase();
        final bn = (b.data()['name'] ?? '').toString().toLowerCase();
        final byName = an.compareTo(bn);
        return byName != 0 ? byName : ts(b.data()).compareTo(ts(a.data()));
      });
      return docs;
    });
  }

  void _addItem({String? model, String? colour, String? size, double? unitPrice}) {
    setState(() {
      items.add({
        'model': model,
        'colour': colour,
        'size': size,
        'qty': 1,
        'autoPrice': unitPrice == null,
        'unitPrice': unitPrice ?? 0.0,
        'lineTotal': unitPrice ?? 0.0,
      });
    });
  }

  void _removeItem(int i) => setState(() => items.removeAt(i));

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

  double _subtotal() {
    double s = 0;
    for (final itm in items) {
      final lt = itm['lineTotal'];
      s += (lt is num) ? lt.toDouble() : double.tryParse('$lt') ?? 0.0;
    }
    return s;
  }

  int _totalPieces() {
    int n = 0;
    for (final itm in items) {
      n += ((itm['qty'] as int?) ?? 0);
    }
    return n;
  }

  double _grandTotal() {
    final ship = double.tryParse(_shippingController.text) ?? 0.0;
    final tax = double.tryParse(_taxController.text) ?? 0.0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    return max(0, _subtotal() + ship + tax - discount);
  }

  String _money(num v) => v.toStringAsFixed(2);

  InputDecoration _decor(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _primary, width: 1.5),
    ),
    labelStyle: AppFonts.banglaBody(fontSize: 13, color: _muted),
    hintStyle: AppFonts.banglaBody(color: _muted),
  );

  String _makeInvoiceNo(String buyerName, DateTime date, double grand) {
    final safeName = buyerName.isEmpty ? 'cust' : buyerName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final datePart = DateFormat('yyyyMMdd').format(date);
    final totalPart = grand.toStringAsFixed(0);
    final rnd = Random().nextInt(900) + 100;
    return '${safeName}_$datePart\_${totalPart}_$rnd';
  }

  String _trackingFromInvoiceNo(String invoiceNo) {
    return 'TRK-${invoiceNo.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '').toUpperCase()}';
  }

  Future<DateTime?> _showModernDatePicker() async {
    return await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primary,
              onPrimary: Colors.white,
              onSurface: _text,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Future<void> _submitInvoice({required bool isDraft}) async {
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

    if (!isDraft) {
      if (_addr1Ctl.text.trim().isEmpty ||
          (_shipCity == null || _shipCity!.trim().isEmpty) ||
          _zipCtl.text.trim().isEmpty ||
          ((_shipCountryName == null || _shipCountryName!.trim().isEmpty) &&
              (_shipCountryCode == null || _shipCountryCode!.trim().isEmpty))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please complete Shipping Address for submission')),
        );
        return;
      }
      if (_phoneNational.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a shipping phone')));
        return;
      }
    }

    setState(() => _isSubmitting = true);
    _recomputeAll();

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? _uid;
    final agentEmail = user?.email ?? _agentEmail ?? '';

    final invoiceItems = items.map((itm) => {
      'model': itm['model'],
      'colour': itm['colour'],
      'size': itm['size'],
      'qty': (itm['qty'] as int?) ?? 0,
      'unitPrice': (itm['unitPrice'] is num) ? itm['unitPrice'].toDouble() : double.tryParse('${itm['unitPrice']}') ?? 0.0,
      'lineTotal': (itm['lineTotal'] is num) ? itm['lineTotal'].toDouble() : double.tryParse('${itm['lineTotal']}') ?? 0.0,
    }).toList();

    final subtotal = _subtotal();
    final shipping = double.tryParse(_shippingController.text) ?? 0.0;
    final tax = double.tryParse(_taxController.text) ?? 0.0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    final grand = _grandTotal();

    final invoiceNo = _makeInvoiceNo(selectedCustomerName, selectedDate, grand);
    final tracking = _trackingFromInvoiceNo(invoiceNo);

    Map<String, dynamic>? payment;
    if (_isPaymentTaken && !isDraft) {
      payment = {
        'taken': true,
        'amount': double.tryParse(_paymentAmountCtl.text) ?? 0.0,
        'method': _paymentMethod,
        'ref': _paymentRefCtl.text.trim(),
        'date': _paymentDate != null ? Timestamp.fromDate(_paymentDate!) : FieldValue.serverTimestamp(),
      };
    }

    final String phoneE164 = (_phoneDial.isNotEmpty && _phoneNational.isNotEmpty)
        ? '$_phoneDial$_phoneNational'.replaceAll(' ', '') : '';

    final Map<String, dynamic> shippingObj = {
      'address1': _addr1Ctl.text.trim(),
      'address2': _addr2Ctl.text.trim(),
      'city': _shipCity ?? '',
      'state': _shipState ?? '',
      'postalCode': _zipCtl.text.trim(),
      'country': {
        'name': _shipCountryName ?? '',
        if ((_shipCountryCode ?? '').isNotEmpty) 'code': _shipCountryCode,
      },
      'phone': {
        'isoCode': _phoneIso,
        'countryDialCode': _phoneDial,
        'national': _phoneNational,
        'e164': phoneE164,
      },
    };

    final String invoiceStatus = isDraft ? 'Draft' : 'Awaiting HR Approval';

    final payload = <String, dynamic>{
      'invoiceNo': invoiceNo,
      'tracking_number': tracking,
      'customerId': selectedCustomerId,
      'customerEmail': selectedCustomerEmail ?? '',
      'customerName': selectedCustomerName,
      'agentId': uid,
      'agentEmail': agentEmail,
      'agentName': _agentName,
      'date': Timestamp.fromDate(selectedDate),
      'createdAt': FieldValue.serverTimestamp(),
      'items': invoiceItems,
      'totalPieces': _totalPieces(),
      'totalAmount': subtotal,
      'shippingCost': shipping,
      'tax': tax,
      'discount': discount,
      'grandTotal': grand,
      'shipping': shippingObj,
      'note': _noteController.text.trim(),
      'status': invoiceStatus,
      'statusStep': isDraft ? -1 : 0,
      'submitted': !isDraft,
      'paymentStatus': _isPaymentTaken ? 'Paid' : 'Pending',
      'timestamp': Timestamp.fromDate(selectedDate),
      if (payment != null) ...{
        'payment': payment,
        'paymentMethod': _paymentMethod,
        'paymentRef': _paymentRefCtl.text.trim(),
      },
    };

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // 1. Save Invoice
      final invRef = (await DB.col(C.invoices)).doc(invoiceNo);
      batch.set(invRef, payload);
      
      if (!isDraft) {
        // 2. CREATE WORK ORDER 
        final woRef = (await DB.col(C.workOrders)).doc(tracking);
        final woPayload = {
          'workOrderNo': tracking,
          'relatedInvoiceNo': invoiceNo,
          'buyerName': selectedCustomerName,
          'customerId': selectedCustomerId,
          'agentEmail': agentEmail,
          'timestamp': Timestamp.fromDate(selectedDate),
          'createdAt': FieldValue.serverTimestamp(),
          'items': invoiceItems,
          'totalPieces': _totalPieces(),
          'status': 'Awaiting Factory',
          'currentStage': 'Production Queue',
          'priority': 'Normal',
          'revenueValue': grand,
        };
        batch.set(woRef, woPayload);

        // 3. INVENTORY SYNC: Reduce Stock
        for (final itm in invoiceItems) {
          final model = itm['model'];
          final color = itm['colour'];
          final size  = itm['size'];
          final qty   = (itm['qty'] as int?) ?? 0;
          
          final prodSnap = await (await DB.col(C.products))
              .where('model_name', isEqualTo: model)
              .where('colour', isEqualTo: color)
              .where('size', isEqualTo: size)
              .limit(1)
              .get();
              
          if (prodSnap.docs.isNotEmpty) {
            final pRef = prodSnap.docs.first.reference;
            batch.update(pRef, {'stock': FieldValue.increment(-qty)});
          }
        }

        // 4. FINANCIAL SYNC
        if (_isPaymentTaken && payment != null) {
          final amt = payment['amount'] as double;
          if (amt > 0) {
            final profRef = DB.colSync(_cid, 'company_profile').doc('main');
            batch.update(profRef, {'cash_in': FieldValue.increment(amt)});
            
            final cfRef = (await DB.col(C.cashFlow)).doc();
            batch.set(cfRef, {
              'amount': amt,
              'type': 'cash_in',
              'category': 'Sales Revenue',
              'note': 'Payment for Invoice #$invoiceNo',
              'invoiceNo': invoiceNo,
              'agentEmail': agentEmail,
              'createdAt': FieldValue.serverTimestamp(),
              'status': 'confirmed',
            });
          }
        }
      }

      await batch.commit();

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isDraft ? '✅ Draft Saved' : '✅ Invoice Submitted to HR')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Failed: $e')));
    }
  }


  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: _primary, size: 20),
          const SizedBox(width: 8),
          Text(title, style: AppFonts.banglaBody(fontSize: 16, fontWeight: FontWeight.w700, color: _primaryDk)),
        ],
      ),
    );
  }

  Widget _cardWrapper(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBG,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _itemCard(int i) {
    final itm = items[i];

    final models = _products.map((p) => p.data()!['model_name'] as String).toSet().toList()..sort();
    final colours = (itm['model'] != null)
        ? _products.where((p) => p.data()!['model_name'] == itm['model']).map((p) => p.data()!['colour'] as String).toSet().toList()
        : <String>[];
    colours.sort();
    final sizes = (itm['model'] != null && itm['colour'] != null)
        ? _products.where((p) => p.data()!['model_name'] == itm['model'] && p.data()!['colour'] == itm['colour']).map((p) => p.data()!['size'] as String).toSet().toList()
        : <String>[];
    sizes.sort();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: models.contains(itm['model']) ? itm['model'] : null,
                  decoration: _decor('Product Model'),
                  items: models.map((m) => DropdownMenuItem(value: m, child: Text(m, style: AppFonts.banglaBody(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() {
                    itm['model'] = v;
                    itm['colour'] = null;
                    itm['size'] = null;
                    _recomputeItem(i);
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: colours.contains(itm['colour']) ? itm['colour'] : null,
                  decoration: _decor('Colour'),
                  items: colours.map((c) => DropdownMenuItem(value: c, child: Text(c, style: AppFonts.banglaBody(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() {
                    itm['colour'] = v;
                    itm['size'] = null;
                    _recomputeItem(i);
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: sizes.contains(itm['size']) ? itm['size'] : null,
                  decoration: _decor('Size'),
                  items: sizes.map((s) => DropdownMenuItem(value: s, child: Text(s, style: AppFonts.banglaBody(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() {
                    itm['size'] = v;
                    _recomputeItem(i);
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextFormField(
                  initialValue: '${itm['qty'] ?? 1}',
                  keyboardType: TextInputType.number,
                  decoration: _decor('Qty'),
                  onChanged: (v) => setState(() {
                    itm['qty'] = int.tryParse(v) ?? 1;
                    _recomputeItem(i);
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  key: ValueKey('up_$i'),
                  initialValue: _money((itm['unitPrice'] is num) ? itm['unitPrice'].toDouble() : 0.0),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _decor('Price'),
                  onChanged: (v) => setState(() {
                    itm['autoPrice'] = false;
                    itm['unitPrice'] = double.tryParse(v) ?? 0.0;
                    _recomputeItem(i);
                  }),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _removeItem(i),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total: ৳${_money((itm['lineTotal'] is num) ? itm['lineTotal'].toDouble() : 0.0)}',
              style: AppFonts.banglaBody(fontWeight: FontWeight.w700, color: _primaryDk),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primaryDk,
        foregroundColor: Colors.white,
        title: Text('Create Invoice', style: AppFonts.banglaBody(fontWeight: FontWeight.w700, fontSize: 18)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_primary, _primaryDk], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Text('Status: New', style: AppFonts.banglaBody(color: Colors.amber.shade900, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                      onPressed: () async {
                        final picked = await _showModernDatePicker();
                        if (picked != null) setState(() => selectedDate = picked);
                      },
                    )
                  ],
                ),
                const SizedBox(height: 16),
                
                // Customer Section
                _sectionHeader('Customer Details', Icons.person_outline),
                _cardWrapper(
                  Column(
                    children: [
                      StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                        stream: _customersStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                          final docs = snapshot.data ?? const [];
                          return DropdownButtonFormField<String>(
                            value: selectedCustomerId,
                            decoration: _decor('Search / Select Customer'),
                            items: docs.map((d) {
                              final m = d.data();
                              final name = (m['name'] ?? 'Unnamed').toString();
                              final email = (m['email'] ?? '').toString();
                              return DropdownMenuItem(value: d.id, child: Text(email.isEmpty ? name : '$name  •  $email', style: AppFonts.banglaBody(fontSize: 13)));
                            }).toList(),
                            onChanged: (v) {
                              final doc = docs.firstWhere((d) => d.id == v);
                              final m = doc.data();
                              setState(() {
                                selectedCustomerId = v;
                                selectedCustomerName = (m['name'] ?? '').toString();
                                selectedCustomerEmail = (m['email'] ?? '').toString();
                                _shipCountryName ??= (m['country'] ?? '').toString().trim().isEmpty ? null : (m['country'] as String);
                                _shipCountryCode ??= (m['countryCode'] ?? '').toString().trim().isEmpty ? null : (m['countryCode'] as String);
                                if (_addr1Ctl.text.trim().isEmpty) _addr1Ctl.text = (m['addressLine'] ?? m['address'] ?? '').toString();
                                _shipCity ??= (m['city'] ?? '').toString();
                                _shipState ??= (m['state'] ?? '').toString();
                                if (_zipCtl.text.trim().isEmpty) _zipCtl.text = (m['zip'] ?? '').toString();
                                final dial = (m['phoneCountryCode'] ?? '').toString();
                                if (dial.isNotEmpty && _phoneDial.isEmpty) _phoneDial = '+$dial';
                                if (_phoneIso.isEmpty && (m['countryCode'] ?? '').toString().isNotEmpty) _phoneIso = (m['countryCode'] as String);
                                if (_phoneNational.isEmpty) _phoneNational = (m['phone'] ?? '').toString();
                              });
                            },
                            validator: (v) => v == null ? 'Required' : null,
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Products Section
                _sectionHeader('Products', Icons.inventory_2_outlined),
                _cardWrapper(
                  Column(
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
                          onPressed: () => _addItem(),
                          icon: const Icon(Icons.add, color: _primary),
                          label: Text('Add Row', style: AppFonts.banglaBody(fontWeight: FontWeight.w600, color: _primary)),
                        ),
                      )
                    ],
                  )
                ),

                // Shipping & Charges
                _sectionHeader('Shipping & Charges', Icons.local_shipping_outlined),
                _cardWrapper(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CSCPicker(
                        showStates: true,
                        showCities: true,
                        layout: Layout.vertical,
                        flagState: CountryFlag.ENABLE,
                        dropdownDecoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _border), color: const Color(0xFFF8FAFC)),
                        disabledDropdownDecoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _border), color: Colors.grey.shade100),
                        onCountryChanged: (c) => setState(() { _shipCountryName = c; _shipCountryCode = null; _shipState = null; _shipCity = null; }),
                        onStateChanged: (s) => setState(() => _shipState = s ?? ''),
                        onCityChanged: (c) => setState(() => _shipCity = c ?? ''),
                        currentCountry: _shipCountryName, currentState: _shipState, currentCity: _shipCity,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(controller: _addr1Ctl, decoration: _decor('Address Line 1 *')),
                      const SizedBox(height: 8),
                      TextFormField(controller: _addr2Ctl, decoration: _decor('Address Line 2 (Optional)')),
                      const SizedBox(height: 8),
                      TextFormField(controller: _zipCtl, decoration: _decor('ZIP / Postal Code *')),
                      const SizedBox(height: 8),
                      IntlPhoneField(
                        initialCountryCode: _phoneIso.isNotEmpty ? _phoneIso : (_shipCountryCode ?? 'BD'),
                        initialValue: _phoneNational.isNotEmpty ? _phoneNational : null,
                        decoration: _decor('Phone *'),
                        onChanged: (p) => setState(() { _phoneIso = p.countryISOCode; _phoneDial = '+${p.countryCode}'; _phoneNational = p.number; _shipCountryCode = p.countryISOCode; }),
                      ),
                      const Divider(height: 32),
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _shippingController, keyboardType: TextInputType.number, decoration: _decor('Shipping'), onChanged: (_) => setState(() {}))),
                          const SizedBox(width: 8),
                          Expanded(child: TextFormField(controller: _taxController, keyboardType: TextInputType.number, decoration: _decor('Tax'), onChanged: (_) => setState(() {}))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(controller: _discountController, keyboardType: TextInputType.number, decoration: _decor('Discount'), onChanged: (_) => setState(() {})),
                      const SizedBox(height: 8),
                      TextFormField(controller: _noteController, maxLines: 2, decoration: _decor('Note to HR / Finance')),
                    ],
                  ),
                ),

                // Payment
                _sectionHeader('Payment Details', Icons.payments_outlined),
                _cardWrapper(
                  Column(
                    children: [
                      CheckboxListTile(
                        value: _isPaymentTaken,
                        onChanged: (v) => setState(() { _isPaymentTaken = v ?? false; if (_isPaymentTaken && _paymentDate == null) _paymentDate = DateTime.now(); }),
                        title: Text('Payment already taken', style: AppFonts.banglaBody(fontWeight: FontWeight.w600, fontSize: 14)),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_isPaymentTaken) ...[
                        Row(
                          children: [
                            Expanded(child: TextFormField(controller: _paymentAmountCtl, keyboardType: TextInputType.number, decoration: _decor('Amount'))),
                            const SizedBox(width: 8),
                            Expanded(child: DropdownButtonFormField<String>(value: _paymentMethod, items: ['Cash', 'Bank', 'Card', 'Mobile Banking'].map((m) => DropdownMenuItem(value: m, child: Text(m, style: AppFonts.banglaBody(fontSize: 13)))).toList(), onChanged: (v) => setState(() => _paymentMethod = v ?? 'Cash'), decoration: _decor('Method'))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(controller: _paymentRefCtl, decoration: _decor('Reference')),
                      ]
                    ]
                  )
                ),

                const SizedBox(height: 24),
                
                // Summary Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _primaryDk,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _summaryRow('Subtotal', _subtotal()),
                      _summaryRow('Shipping', double.tryParse(_shippingController.text) ?? 0.0),
                      _summaryRow('Tax', double.tryParse(_taxController.text) ?? 0.0),
                      _summaryRow('Discount', double.tryParse(_discountController.text) ?? 0.0, isNegative: true),
                      const Divider(color: Colors.white24, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Grand Total', style: AppFonts.banglaBody(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                          Text('৳${_money(_grandTotal())}', style: AppFonts.banglaBody(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                        ],
                      )
                    ],
                  )
                ),

                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: _primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        onPressed: _isSubmitting ? null : () => _submitInvoice(isDraft: true),
                        child: Text('Save Draft', style: AppFonts.banglaBody(fontWeight: FontWeight.w700, color: _primary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: _isSubmitting ? null : () => _submitInvoice(isDraft: false),
                        child: _isSubmitting 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Submit to HR for Review', style: AppFonts.banglaBody(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double val, {bool isNegative = false}) {
    if (val == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppFonts.banglaBody(color: Colors.white70, fontSize: 14)),
          Text('${isNegative ? '-' : ''}৳${_money(val)}', style: AppFonts.banglaBody(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
