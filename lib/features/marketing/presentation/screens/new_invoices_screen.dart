import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:csc_picker/csc_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

// PDF & share
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

// Design system: clean, low-fatigue invoice form
const Color _indigo = Color(0xFF2563EB);
const Color _indigoDk = Color(0xFF1E3A8A);
const Color _accent = Color(0xFF3B82F6);
const Color _cardBG = Colors.white;
const Color _chipBg = Color(0xFFEFF6FF);
const Color _border = Color(0xFFE2E8F0);
const Color _fg = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);
const double _radius = 12.0;
const double _radiusCard = 16.0;

class NewInvoicesScreen extends StatefulWidget {
  const NewInvoicesScreen({Key? key}) : super(key: key);

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
  String? selectedCustomerEmail; // NEW

  String _agentNameFromEmail(String? email) {
    if (email == null || email.isEmpty) return '';
    final namePart = email.split('@').first;
    return namePart
        .split('.')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }

  // Date
  DateTime selectedDate = DateTime.now();

  // Charges
  final _shippingController = TextEditingController();
  final _taxController = TextEditingController();
  final _noteController = TextEditingController();

  // ── Shipping state ──
  String? _shipCountryName;   // e.g., Bangladesh
  String? _shipCountryCode;   // e.g., BD (infer from phone widget)
  String? _shipState;         // Division/State/Province
  String? _shipCity;

  final _addr1Ctl = TextEditingController();
  final _addr2Ctl = TextEditingController();
  final _zipCtl   = TextEditingController();

  // Phone (country code picker)
  String _phoneIso = '';      // e.g., BD
  String _phoneDial = '';     // e.g., +880
  String _phoneNational = ''; // national part only

  // UI: which step is in view (for step indicator)
  int _currentStep = 0;
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _stepKeys = List.generate(4, (_) => GlobalKey());

  // Pipeline (limit to Payment Taken)
  static const List<String> kFullSteps = [
    'Invoice Created', // 0
    'Payment Requested', // 1
    'Payment Taken', // 2 (max editable here)

  ];
  static const int kMaxEditableStepIndex = 2;
  int _statusIndex = 0;

  // Payment (optional)
  bool _isPaymentTaken = false;
  final _paymentAmountCtl = TextEditingController();
  String _paymentMethod = 'Cash';
  final _paymentRefCtl = TextEditingController();
  DateTime? _paymentDate;

  // Products
  List<DocumentSnapshot<Map<String, dynamic>>> _products = [];

  // Items (each: model, colour, size, qty, autoPrice, unitPrice, lineTotal)
  final List<Map<String, dynamic>> items = [];

  // ---------- lifecycle ----------
  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _loadAgent();
    _loadProducts();
    _addItem();
  }
// Add this helper inside _NewInvoicesScreenState

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _customersStream() {
    final col = DB.colSync(_cid, C.customers);

    // use UID — this matches “customers added by this agent”
    final uid = FirebaseAuth.instance.currentUser?.uid ?? _uid;
    if (uid == null) {
      // no session yet — return an empty stream until _loadAgent() finishes
      return const Stream.empty();
    }

    return col
        .where('createdBy', isEqualTo: uid) // 👈 primary filter
        .snapshots()
        .map((snap) {
      final docs = snap.docs.toList();

      // stable, friendly ordering (name, then newest timestamp)
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



  @override
  void dispose() {
    _scrollController.dispose();
    _shippingController.dispose();
    _taxController.dispose();
    _noteController.dispose();

    _addr1Ctl.dispose();
    _addr2Ctl.dispose();
    _zipCtl.dispose();

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
      final udoc = await (await DB.col(C.users)).doc(_uid).get();
      _agentName = (udoc.data()?['fullName'] as String?) ?? (user?.displayName ?? '');
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadProducts() async {
    final snapshot = await (await DB.col(C.products)).orderBy('model_name').get();
    if (mounted) setState(() => _products = snapshot.docs);
  }

  // ---------- items ----------
  void _addItem() {
    setState(() {
      items.add({
        'model': null,
        'colour': null,
        'size': null,
        'qty': 1,
        'autoPrice': true,
        'unitPrice': 0.0,
        'lineTotal': 0.0,
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

  // ---------- totals ----------
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
    final ship = double.tryParse(_shippingController.text) ?? 0;
    final tax = double.tryParse(_taxController.text) ?? 0;
    return _subtotal() + ship + tax;
  }

  String _money(num v) => v.toStringAsFixed(2);

  InputDecoration _decor(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radius),
      borderSide: const BorderSide(color: _border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radius),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_radius),
      borderSide: const BorderSide(color: _indigo, width: 1.5),
    ),
    labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: _muted),
    hintStyle: GoogleFonts.plusJakartaSans(color: _muted),
  );

  // ---------- id helpers ----------
  String _makeInvoiceNo(String buyerName, DateTime date, double grand) {
    final safeName = buyerName.isEmpty ? 'cust' : buyerName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final datePart = DateFormat('yyyyMMdd').format(date);
    final totalPart = grand.toStringAsFixed(0);
    final rnd = Random().nextInt(900) + 100;
    return '${safeName}_$datePart\_${totalPart}_$rnd';
  }

  String _trackingFromInvoiceNo(String invoiceNo) {
    // Stable and human readable; aligns with your data workflow
    return 'TRK-${invoiceNo.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '').toUpperCase()}';
  }

  // ---------- Modern Date Picker (Bottom Sheet) ----------
  Future<DateTime?> _showModernDatePicker({
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    bool allowClear = false,
    String title = 'Select date',
  }) async {
    // Work with date-only precision
    DateTime temp = DateTime(initialDate.year, initialDate.month, initialDate.day);

    // Do NOT name these "min"/"max" to avoid shadowing dart:math
    final DateTime minDate = firstDate ?? DateTime(2020);
    final DateTime maxDate = lastDate ?? DateTime(2100);

    DateTime? result;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (c) {
        return StatefulBuilder(
          builder: (c, setM) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.55, // responsive height
              minChildSize: 0.40,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      // Keep calendar height reasonable on all screens
                      final double calHeight =
                      ((constraints.maxHeight * 0.55).clamp(280.0, 420.0)) as double;

                      // Ensure initialDate is in range
                      final DateTime safeInitial = temp.isBefore(minDate)
                          ? minDate
                          : (temp.isAfter(maxDate) ? maxDate : temp);

                      return SingleChildScrollView(
                        controller: scrollController,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title row
                            Row(
                              children: [
                                const Icon(Icons.event, color: _indigo),
                                const SizedBox(width: 8),
                                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                const Spacer(),
                                if (allowClear)
                                  TextButton(
                                    onPressed: () {
                                      result = null; // clear
                                      Navigator.pop(c);
                                    },
                                    child: const Text('Clear'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Calendar (clamped height to avoid overflow)
                            SizedBox(
                              height: calHeight,
                              child: CalendarDatePicker(
                                initialDate: safeInitial,
                                firstDate: minDate,
                                lastDate: maxDate,
                                onDateChanged: (d) => setM(() => temp = d),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Quick-pick chips
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ActionChip(
                                  label: const Text('Today'),
                                  onPressed: () => setM(() {
                                    final now = DateTime.now();
                                    temp = DateTime(now.year, now.month, now.day);
                                  }),
                                ),
                                ActionChip(
                                  label: const Text('+ 1 week'),
                                  onPressed: () => setM(() {
                                    final now = DateTime.now().add(const Duration(days: 7));
                                    temp = DateTime(now.year, now.month, now.day);
                                  }),
                                ),
                                ActionChip(
                                  label: const Text('+ 1 month'),
                                  onPressed: () => setM(() {
                                    final now = DateTime.now();
                                    final plus = DateTime(now.year, now.month + 1, now.day);
                                    temp = plus;
                                  }),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Actions
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c),
                                  child: const Text('Cancel'),
                                ),
                                const Spacer(),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.check),
                                  onPressed: () {
                                    // Final clamp to be extra safe
                                    final DateTime picked = temp.isBefore(minDate)
                                        ? minDate
                                        : (temp.isAfter(maxDate) ? maxDate : temp);
                                    result = picked;
                                    Navigator.pop(c);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _indigo,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  label: const Text('Done'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );

    return result;
  }



  // ---------- Firestore submit ----------
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

    // Validate Shipping minimal fields
    if (_addr1Ctl.text.trim().isEmpty ||
        (_shipCity == null || _shipCity!.trim().isEmpty) ||
        _zipCtl.text.trim().isEmpty ||
        ((_shipCountryName == null || _shipCountryName!.trim().isEmpty) &&
            (_shipCountryCode == null || _shipCountryCode!.trim().isEmpty))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete Shipping Address')),
      );
      return;
    }
    // Phone: basic check
    if (_phoneNational.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a shipping phone')));
      return;
    }

    _recomputeAll();

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? _uid;
    final agentEmail = user?.email ?? _agentEmail ?? '';

    final invoiceItems = items
        .map((itm) => {
      'model': itm['model'],
      'colour': itm['colour'],
      'size': itm['size'],
      'qty': (itm['qty'] as int?) ?? 0,
      'unitPrice': (itm['unitPrice'] is num)
          ? itm['unitPrice'].toDouble()
          : double.tryParse('${itm['unitPrice']}') ?? 0.0,
      'lineTotal': (itm['lineTotal'] is num)
          ? itm['lineTotal'].toDouble()
          : double.tryParse('${itm['lineTotal']}') ?? 0.0,
    })
        .toList();

    final subtotal = _subtotal();
    final shipping = double.tryParse(_shippingController.text) ?? 0.0;
    final tax = double.tryParse(_taxController.text) ?? 0.0;
    final grand = _grandTotal();

    final invoiceNo = _makeInvoiceNo(selectedCustomerName, selectedDate, grand);
    final tracking = _trackingFromInvoiceNo(invoiceNo);

    Map<String, dynamic>? payment;
    if (_isPaymentTaken) {
      payment = {
        'taken': true,
        'amount': double.tryParse(_paymentAmountCtl.text) ?? 0.0,
        'method': _paymentMethod,
        'ref': _paymentRefCtl.text.trim(),
        'date': _paymentDate != null ? Timestamp.fromDate(_paymentDate!) : FieldValue.serverTimestamp(),
      };
    }

    // Normalized Shipping object
    final String phoneE164 = (_phoneDial.isNotEmpty && _phoneNational.isNotEmpty)
        ? '$_phoneDial$_phoneNational'.replaceAll(' ', '')
        : '';

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
        'isoCode': _phoneIso, // e.g., BD
        'countryDialCode': _phoneDial, // e.g., +880
        'national': _phoneNational,
        'e164': phoneE164,
      },
    };

    final payload = <String, dynamic>{
      'invoiceNo': invoiceNo,
      'tracking_number': tracking,
      'customerId': selectedCustomerId,
      'customerEmail': selectedCustomerEmail ?? '',
      'customerName': selectedCustomerName,
      'buyerName': selectedCustomerName, // mirror for compatibility
      'ownerUid': uid,
      'ownerEmail': agentEmail,
      'agentId': uid, // legacy support
      'agentEmail': agentEmail,
      'agentName': _agentName,
      'date': Timestamp.fromDate(selectedDate), // store as Timestamp
      'createdAt': FieldValue.serverTimestamp(),
      'items': invoiceItems,
      'totalPieces': _totalPieces(),
      'totalAmount': subtotal,
      'shippingCost': shipping,
      'tax': tax,
      'grandTotal': grand,
      'shipping': shippingObj, // NEW normalized shipping block
      'note': _noteController.text.trim(),
      'status': kFullSteps[_statusIndex],
      'statusStep': _statusIndex,
      'submitted': true,
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
      
      // 2. CREATE WORK ORDER (Synchronization Link)
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
        'status': 'Pending Admin Review',
        'currentStage': 'Sales Approval',
        'priority': 'Normal',
        'revenueValue': grand,
      };
      batch.set(woRef, woPayload);

      // 3. INVENTORY SYNC: Reduce Stock (Stock Out)
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

      // 4. FINANCIAL SYNC: Cash In (if payment taken)
      if (_isPaymentTaken) {
        final amt = double.tryParse(_paymentAmountCtl.text) ?? 0.0;
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

      await batch.commit();


      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Invoice saved (Tracking: $tracking)')),
      );

      // After save: Show quick next steps with Work Order tip & PDF actions.
      _showAfterSaveSheet(invoiceNo, payload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Failed: $e')));
    }
  }

  // ---------- PDF ----------
  Future<pw.Document> _buildPdfDoc({
    required String invoiceNo,
    required String tracking,
    required String buyerName,
    required DateTime invDate,
    required List<Map<String, dynamic>> rows,
    required double shipping,
    required double tax,
    required double subtotal,
    required double grand,
    required String country,
    String? paymentMethod,
    String? paymentRef,
  }) async {
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: pw.Font.times(), bold: pw.Font.timesBold(), italic: pw.Font.timesItalic(), boldItalic: pw.Font.timesBoldItalic()));

    final blue = PdfColor.fromInt(0xFF0D47A1);
    final light = PdfColor.fromInt(0xFFEFF3FF);

    pw.Widget header() => pw.Container(
      padding: const pw.EdgeInsets.all(14),
      color: blue,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('INVOICE',
                  style: pw.TextStyle(
                      color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Wig Bangladesh', style: pw.TextStyle(color: PdfColors.white, fontSize: 12)),
              pw.Text('support@wigbd.com', style: pw.TextStyle(color: PdfColors.white, fontSize: 10)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Invoice No: $invoiceNo',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 12)),
              pw.Text('Date: ${DateFormat('yyyy-MM-dd').format(invDate)}',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 12)),
              pw.Text('Tracking: $tracking',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 10)),
            ],
          ),
        ],
      ),
    );

    pw.Widget parties() => pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: light),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Invoice to:',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: blue)),
            pw.SizedBox(height: 4),
            pw.Text(buyerName),
            if (country.isNotEmpty) pw.Text(country, style: const pw.TextStyle(fontSize: 10)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Payment Method',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: blue)),
            pw.SizedBox(height: 4),
            pw.Text(paymentMethod ?? '—'),
            if ((paymentRef ?? '').isNotEmpty)
              pw.Text('Ref: $paymentRef', style: const pw.TextStyle(fontSize: 10)),
          ]),
        ],
      ),
    );

    pw.Widget table() {
      final headers = ['SL', 'Description', 'Qty', 'Price', 'Total'];
      final data = <List<String>>[];
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i];
        final desc = '${r['model']} | ${r['colour']} | ${r['size']}';
        data.add([
          '${i + 1}',
          desc,
          '${r['qty']}',
          NumberFormat.currency(symbol: '\$').format((r['unitPrice'] ?? 0) * 1.0),
          NumberFormat.currency(symbol: '\$').format((r['lineTotal'] ?? 0) * 1.0),
        ]);
      }

      return pw.TableHelper.fromTextArray(
        cellAlignment: pw.Alignment.centerLeft,
        headerDecoration: pw.BoxDecoration(color: blue),
        headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
        headers: headers,
        data: data,
        cellStyle: const pw.TextStyle(fontSize: 10),
        headerAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
        },
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
        },
        columnWidths: {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(5),
          2: const pw.FlexColumnWidth(2),
          3: const pw.FlexColumnWidth(2),
          4: const pw.FlexColumnWidth(2),
        },
        rowDecoration: const pw.BoxDecoration(border: pw.Border()),
      );
    }

    pw.Widget totals() => pw.Container(
      alignment: pw.Alignment.centerRight,
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        _totRow('Sub Total', subtotal),
        _totRow('Shipping', shipping),
        _totRow('Tax', tax),
        pw.SizedBox(height: 4),
        pw.Container(
          color: light,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text('Grand Total: ${NumberFormat.currency(symbol: '\$').format(grand)}',
              style: pw.TextStyle(color: blue, fontWeight: pw.FontWeight.bold)),
        ),
      ]),
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(20),
          textDirection: pw.TextDirection.ltr,
        ),
        build: (ctx) => [
          header(),
          pw.SizedBox(height: 10),
          parties(),
          pw.SizedBox(height: 12),
          table(),
          pw.SizedBox(height: 8),
          totals(),
          pw.SizedBox(height: 18),
          pw.Text('Terms & Conditions',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: blue)),
          pw.Text(
            'Please pay within 10 days of receiving the invoice. Late payments may incur interest.'
                ' Tracking number is provided to link factory Work Order and shipping updates.',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );

    return doc;
  }

  pw.Widget _totRow(String label, double value) => pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Text('$label: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.Text(NumberFormat.currency(symbol: '\$').format(value)),
    ],
  );

  Future<void> _savePdfToDevice(Uint8List bytes, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$fileName.pdf';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📄 Saved PDF to $path')));
  }

  Future<void> _sharePdf(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName.pdf';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(path)], text: 'Invoice $fileName');
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    const List<String> stepLabels = ['Buyer & Date', 'Items', 'Shipping', 'Charges'];
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: _indigoDk,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('New Invoice', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18)),
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
        onPdf: () async {
          _recomputeAll();
          final tempInvoiceNo = _makeInvoiceNo(selectedCustomerName, selectedDate, _grandTotal());
          final tracking = _trackingFromInvoiceNo(tempInvoiceNo);
          final doc = await _buildPdfDoc(
            invoiceNo: tempInvoiceNo,
            tracking: tracking,
            buyerName: selectedCustomerName,
            invDate: selectedDate,
            rows: items
                .map((e) => {
              'model': e['model'],
              'colour': e['colour'],
              'size': e['size'],
              'qty': (e['qty'] as int?) ?? 0,
              'unitPrice': (e['unitPrice'] is num) ? e['unitPrice'].toDouble() : 0.0,
              'lineTotal': (e['lineTotal'] is num) ? e['lineTotal'].toDouble() : 0.0,
            })
                .toList(),
            shipping: double.tryParse(_shippingController.text) ?? 0.0,
            tax: double.tryParse(_taxController.text) ?? 0.0,
            subtotal: _subtotal(),
            grand: _grandTotal(),
            country: _shipCountryName ?? '',
            paymentMethod: _isPaymentTaken ? _paymentMethod : null,
            paymentRef: _isPaymentTaken ? _paymentRefCtl.text.trim() : null,
          );
          final bytes = await doc.save();
          await _savePdfToDevice(bytes, tempInvoiceNo);
        },
        onShare: () async {
          _recomputeAll();
          final tempInvoiceNo = _makeInvoiceNo(selectedCustomerName, selectedDate, _grandTotal());
          final tracking = _trackingFromInvoiceNo(tempInvoiceNo);
          final doc = await _buildPdfDoc(
            invoiceNo: tempInvoiceNo,
            tracking: tracking,
            buyerName: selectedCustomerName,
            invDate: selectedDate,
            rows: items
                .map((e) => {
              'model': e['model'],
              'colour': e['colour'],
              'size': e['size'],
              'qty': (e['qty'] as int?) ?? 0,
              'unitPrice': (e['unitPrice'] is num) ? e['unitPrice'].toDouble() : 0.0,
              'lineTotal': (e['lineTotal'] is num) ? e['lineTotal'].toDouble() : 0.0,
            })
                .toList(),
            shipping: double.tryParse(_shippingController.text) ?? 0.0,
            tax: double.tryParse(_taxController.text) ?? 0.0,
            subtotal: _subtotal(),
            grand: _grandTotal(),
            country: _shipCountryName ?? '',
            paymentMethod: _isPaymentTaken ? _paymentMethod : null,
            paymentRef: _isPaymentTaken ? _paymentRefCtl.text.trim() : null,
          );
          final bytes = await doc.save();
          await _sharePdf(bytes, tempInvoiceNo);
        },
        onPrint: () async {
          _recomputeAll();
          final tempInvoiceNo = _makeInvoiceNo(selectedCustomerName, selectedDate, _grandTotal());
          final tracking = _trackingFromInvoiceNo(tempInvoiceNo);
          await Printing.layoutPdf(
            onLayout: (_) async => (await _buildPdfDoc(
              invoiceNo: tempInvoiceNo,
              tracking: tracking,
              buyerName: selectedCustomerName,
              invDate: selectedDate,
              rows: items
                  .map((e) => {
                'model': e['model'],
                'colour': e['colour'],
                'size': e['size'],
                'qty': (e['qty'] as int?) ?? 0,
                'unitPrice': (e['unitPrice'] is num) ? e['unitPrice'].toDouble() : 0.0,
                'lineTotal': (e['lineTotal'] is num) ? e['lineTotal'].toDouble() : 0.0,
              })
                  .toList(),
              shipping: double.tryParse(_shippingController.text) ?? 0.0,
              tax: double.tryParse(_taxController.text) ?? 0.0,
              subtotal: _subtotal(),
              grand: _grandTotal(),
              country: _shipCountryName ?? '',
              paymentMethod: _isPaymentTaken ? _paymentMethod : null,
              paymentRef: _isPaymentTaken ? _paymentRefCtl.text.trim() : null,
            )).save(),
          );
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            _stepStrip(stepLabels),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 120),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _onboardingCard(),
                      _sectionKeyed(
                        0,
                        icon: Icons.person_pin_circle,
                        title: 'Buyer & Date',
                        child: Column(
                          children: [
                      StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                        stream: _customersStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              height: 36,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(width: 160, child: LinearProgressIndicator(minHeight: 2)),
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return const Text('Error fetching customers.');
                          }

                          final docs = snapshot.data ?? const [];
                          if (docs.isEmpty) {
                            return const Text('No customers found.');
                          }

                          return DropdownButtonFormField<String>(
                            value: selectedCustomerId,
                            decoration: _decor('Select Buyer'),
                            items: docs.map((d) {
                              final m = d.data();
                              final name = (m['name'] ?? 'Unnamed').toString();
                              final email = (m['email'] ?? '').toString();
                              return DropdownMenuItem(
                                value: d.id,
                                child: Text(
                                  email.isEmpty ? name : '$name  •  $email',
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              final doc = docs.firstWhere((d) => d.id == v);
                              final m = doc.data();

                              setState(() {
                                selectedCustomerId = v;
                                selectedCustomerName = (m['name'] ?? '').toString();
                                selectedCustomerEmail = (m['email'] ?? '').toString();

                                // Optional prefill shipping
                                _shipCountryName ??= (m['country'] ?? '').toString().trim().isEmpty ? null : (m['country'] as String);
                                _shipCountryCode ??= (m['countryCode'] ?? '').toString().trim().isEmpty ? null : (m['countryCode'] as String);
                                if (_addr1Ctl.text.trim().isEmpty) _addr1Ctl.text = (m['addressLine'] ?? m['address'] ?? '').toString();
                                _shipCity ??= (m['city'] ?? '').toString();
                                _shipState ??= (m['state'] ?? '').toString();
                                if (_zipCtl.text.trim().isEmpty) _zipCtl.text = (m['zip'] ?? '').toString();

                                final dial = (m['phoneCountryCode'] ?? '').toString();
                                if (dial.isNotEmpty && _phoneDial.isEmpty) _phoneDial = '+$dial';
                                if (_phoneIso.isEmpty && (m['countryCode'] ?? '').toString().isNotEmpty) {
                                  _phoneIso = (m['countryCode'] as String);
                                }
                                if (_phoneNational.isEmpty) _phoneNational = (m['phone'] ?? '').toString();
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
                              final picked = await _showModernDatePicker(
                                title: 'Invoice date',
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
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
                            _statusIndex = v ?? 0;
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

                // Items
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
                          icon: const Icon(Icons.add_rounded, color: _indigo, size: 20),
                          label: Text('Add item', style: GoogleFonts.plusJakartaSans(color: _indigo, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
                // Shipping Address (NEW)
                _section(
                  icon: Icons.local_shipping_outlined,
                  title: 'Shipping Address',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CSCPicker(
                        showStates: true,
                        showCities: true,
                        layout: Layout.vertical,
                        flagState: CountryFlag.ENABLE,
                        dropdownDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFB0BEC5)),
                          color: Colors.grey[50],
                        ),
                        disabledDropdownDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFB0BEC5)),
                          color: Colors.grey[100],
                        ),
                        selectedItemStyle: const TextStyle(fontSize: 13, color: Colors.black87),
                        onCountryChanged: (country) {
                          setState(() {
                            _shipCountryName = country;
                            _shipCountryCode = null; // will infer from phone ISO
                            _shipState = null;
                            _shipCity = null;
                          });
                        },
                        onStateChanged: (state) => setState(() => _shipState = state ?? ''),
                        onCityChanged: (city) => setState(() => _shipCity = city ?? ''),
                        currentCountry:
                        (_shipCountryName?.isNotEmpty ?? false) ? _shipCountryName : null,
                        currentState: (_shipState?.isNotEmpty ?? false) ? _shipState : null,
                        currentCity: (_shipCity?.isNotEmpty ?? false) ? _shipCity : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _addr1Ctl,
                        decoration: _decor('Address Line 1 *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _addr2Ctl,
                        decoration: _decor('Address Line 2 (optional)'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _zipCtl,
                        decoration: _decor('ZIP / Postal Code *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      IntlPhoneField(
                        initialCountryCode:
                        _phoneIso.isNotEmpty ? _phoneIso : (_shipCountryCode ?? 'BD'),
                        initialValue: _phoneNational.isNotEmpty ? _phoneNational : null,
                        decoration: _decor('Phone (with country code) *'),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        onChanged: (p) {
                          setState(() {
                            _phoneIso = p.countryISOCode ?? '';
                            _phoneDial = '+${p.countryCode}';
                            _phoneNational = p.number;
                            _shipCountryCode ??= p.countryISOCode; // infer ISO for country block
                          });
                        },
                        validator: (p) {
                          if (p == null || p.number.trim().isEmpty) return 'Required';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                // Charges & Notes
                _section(
                  icon: Icons.receipt_long_rounded,
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
                        controller: _noteController,
                        maxLines: 3,
                        decoration: _decor('Notes (How invoice no. is generated is shown below)'),
                      ),
                      const SizedBox(height: 6),
                      _helpStrip(
                        icon: Icons.info_outline,
                        text:
                        'Invoice number = {buyerName}_{yyyyMMdd}_{grandTotalRounded}_{3-digit-random}. '
                            'Tracking number is auto-created from invoice no (e.g., TRK-{INVOICENO}).',
                      ),
                    ],
                  ),
                ),

                // Payment
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
                            if (_isPaymentTaken && _paymentDate == null) {
                              _paymentDate = DateTime.now();
                            }
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        title: Text('Payment taken', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
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
                                      onChanged: (v) =>
                                          setState(() => _paymentMethod = v ?? 'Cash'),
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
                                      final picked = await _showModernDatePicker(
                                        title: 'Payment date',
                                        initialDate: _paymentDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                        allowClear: true,
                                      );
                                      setState(() => _paymentDate = picked);
                                    },

                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _indigo,
                                      side: const BorderSide(color: _indigo),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Change'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _helpStrip(
                        icon: Icons.check_circle_outline,
                        text:
                        'No payment yet? No problem—leave this OFF and just create the invoice. You can add payment later.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
        ],
      ),
    ),
    );
  }

  Widget _stepStrip(List<String> labels) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: _cardBG,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: List.generate(labels.length * 2 - 1, (idx) {
          if (idx.isOdd) {
            final step = idx ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 20),
                color: step <= _currentStep ? _indigo : _border,
              ),
            );
          }
          final i = idx ~/ 2;
          final active = _currentStep == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _currentStep = i);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final ctx = _stepKeys[i].currentContext;
                  if (ctx != null) {
                    Scrollable.ensureVisible(ctx,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        alignment: 0.1);
                  }
                });
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? _indigo : _chipBg,
                      border: Border.all(
                          color: active ? _indigo : _border, width: 1.2),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : _muted),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        color: active ? _indigo : _muted),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ----- widgets -----
  Widget _onboardingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _indigo.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.tips_and_updates_outlined, color: _indigo, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Fill buyer, items, shipping & charges → Save. Use the tracking number in Work Orders to start production.',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: _fg, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpStrip({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _indigo, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _fg, height: 1.35))),
        ],
      ),
    );
  }

  Widget _itemCard(int i) {
    final itm = items[i];

    final models =
    _products.map((p) => p.data()!['model_name'] as String).toSet().toList()..sort();

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
        .where((p) =>
    p.data()!['model_name'] == itm['model'] &&
        p.data()!['colour'] == itm['colour'])
        .map((p) => p.data()!['size'] as String)
        .toSet()
        .toList()
        : <String>[];
    sizes.sort();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBG,
        borderRadius: BorderRadius.circular(_radiusCard),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: const Color(0x06000000),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                        itm['model'] = v;
                        itm['colour'] = null;
                        itm['size'] = null;
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
                        itm['size'] = null;
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
                        activeTrackColor: _indigo.withValues(alpha: 0.5),
                        thumbColor: WidgetStateProperty.resolveWith((states) =>
                            states.contains(WidgetState.selected) ? _indigo : null),
                        onChanged: (val) {
                          setState(() => itm['autoPrice'] = val);
                          _recomputeItem(i);
                        },
                      ),
                      const SizedBox(width: 6),
                      Text('Auto price', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _fg)),
                      const SizedBox(width: 4),
                      const Tooltip(
                        message:
                        'If ON, price comes from products.unit_price by Model/Colour/Size',
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
                    initialValue:
                    _money((items[i]['unitPrice'] as num?)?.toDouble() ?? 0),
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _chipBg,
                  borderRadius: BorderRadius.circular(_radius),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  'Line total ৳${_money((items[i]['lineTotal'] as num?)?.toDouble() ?? 0)}',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, fontSize: 13, color: _indigo),
                ),
              ),
            ),
          ],
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: active ? Colors.white : _indigo,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _sectionKeyed(int keyIndex, {required IconData icon, required String title, required Widget child}) {
    return KeyedSubtree(
      key: _stepKeys[keyIndex],
      child: _section(icon: icon, title: title, child: child),
    );
  }

  Widget _section({required IconData icon, required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBG,
        borderRadius: BorderRadius.circular(_radiusCard),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: const Color(0x08000000),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _indigo,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(icon, size: 20, color: _indigo),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 15, fontWeight: FontWeight.w700, color: _fg),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, {IconData? icon}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: _indigo),
            const SizedBox(width: 10),
          ],
          Text('$label: ',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600, fontSize: 13, color: _indigo)),
          Flexible(
              child: Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _fg))),
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
    required VoidCallback onPdf,
    required VoidCallback onShare,
    required VoidCallback onPrint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBG,
        border: Border(top: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Subtotal ৳${_money(subtotal)}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _muted)),
                      Text('Shipping ৳${_money(shipping)} · Tax ৳${_money(tax)}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _muted)),
                      const SizedBox(height: 2),
                      Text('Grand ৳${_money(grand)}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 16, fontWeight: FontWeight.w800, color: _indigo)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onSubmit,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: Text('Save invoice', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _bottomAction(Icons.picture_as_pdf_outlined, 'PDF', onPdf),
                const SizedBox(width: 8),
                _bottomAction(Icons.share_rounded, 'Share', onShare),
                const SizedBox(width: 8),
                _bottomAction(Icons.print_rounded, 'Print', onPrint),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: _indigo,
          side: const BorderSide(color: _border),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showAfterSaveSheet(String invoiceNo, Map<String, dynamic> payload) {
    final tracking = payload['tracking_number'];
    final shipping = (payload['shipping'] ?? const {}) as Map<String, dynamic>;
    final countryBlock = (shipping['country'] ?? const {}) as Map<String, dynamic>;
    final countryName = (countryBlock['name'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
                    const SizedBox(width: 12),
                    Text('Invoice $invoiceNo created',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 17, color: _fg)),
                  ],
                ),
                const SizedBox(height: 8),
                _helpStrip(
                  icon: Icons.local_activity_outlined,
                  text:
                  'Tracking Number: $tracking. Use this same tracking number when you go to the Work Orders section to create a work order and track factory stages.',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          // Create and share PDF from saved payload
                          final doc = await _buildPdfDoc(
                            invoiceNo: invoiceNo,
                            tracking: tracking,
                            buyerName: (payload['customerName'] ?? '') as String,
                            invDate: (payload['date'] as Timestamp).toDate(),
                            rows: List<Map<String, dynamic>>.from(payload['items'] as List),
                            shipping: (payload['shippingCost'] as num?)?.toDouble() ?? 0.0,
                            tax: (payload['tax'] as num?)?.toDouble() ?? 0.0,
                            subtotal: (payload['totalAmount'] as num?)?.toDouble() ?? 0.0,
                            grand: (payload['grandTotal'] as num?)?.toDouble() ?? 0.0,
                            country: countryName,
                            paymentMethod: payload['paymentMethod'] as String?,
                            paymentRef: payload['paymentRef'] as String?,
                          );
                          final bytes = await doc.save();
                          await _sharePdf(bytes, invoiceNo);
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('Send PDF now'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _indigo,
                          side: const BorderSide(color: _indigo),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.done),
                        label: const Text('Close'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
