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

const Color _indigo = Color(0xFF0D47A1);
const Color _accent = Color(0xFF448AFF);
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
  String _agentName = '';

  // Buyer
  String? selectedCustomerId;
  String selectedCustomerName = '';

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

  // Pipeline (limit to Payment Taken)
  static const List<String> kFullSteps = [
    'Invoice Created', // 0
    'Payment Requested', // 1
    'Payment Taken', // 2 (max editable here)
    'Submitted to Factory for Production', // 3
    'Production In Progress', // 4
    'Quality Check', // 5
    'Product Received at Warehouse', // 6
    'Address Validation of the Customer', // 7
    'Packed & Ready', // 8
    'Shipped to Shipping Company', // 9
    'In Transit', // 10
    'Delivered / Completed', // 11
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
    _loadAgent();
    _loadProducts();
    _addItem();
  }

  @override
  void dispose() {
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
      final udoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      _agentName = (udoc.data()?['fullName'] as String?) ?? (user?.displayName ?? '');
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadProducts() async {
    final snapshot = await FirebaseFirestore.instance.collection('products').orderBy('model_name').get();
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
      await FirebaseFirestore.instance.collection('invoices').doc(invoiceNo).set(payload);
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
    final doc = pw.Document();

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
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 110),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _onboardingCard(),

                // Buyer & Date
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
                              return DropdownMenuItem(
                                  value: d.id, child: Text(name, style: const TextStyle(fontSize: 13)));
                            }).toList(),
                            onChanged: (v) {
                              final name = docs.firstWhere((d) => d.id == v)['name'];
                              setState(() {
                                selectedCustomerId = v;
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

                // Status
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
                          icon: const Icon(Icons.add, color: _indigo),
                          label: const Text('Add Item', style: TextStyle(color: _indigo)),
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
    );
  }

  // ----- widgets -----
  Widget _onboardingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _indigo.withOpacity(.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: _indigo),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 12),
                children: const [
                  TextSpan(
                      text: 'How this works:\n',
                      style: TextStyle(fontWeight: FontWeight.w800, color: _indigo)),
                  TextSpan(
                      text:
                      '1) Fill buyer, items, charges and (optionally) payment → Save to create the invoice with an auto tracking number.\n'),
                  TextSpan(text: '2) To start production, go to the '),
                  TextSpan(text: 'Work Orders', style: TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(
                      text:
                      ' section and create a work order using the same tracking number.\n'),
                  TextSpan(
                      text:
                      '3) Use the buttons at the bottom to Save PDF, Share/Send, or Print—just like the sample layout.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpStrip({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: _indigo, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11))),
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
    required VoidCallback onPdf,
    required VoidCallback onShare,
    required VoidCallback onPrint,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, -2))],
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
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
                        const SizedBox(height: 2),
                        Text('Grand: ৳${_money(grand)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: _indigo)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onSubmit,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Save PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _indigo,
                      side: const BorderSide(color: _indigo),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _indigo,
                      side: const BorderSide(color: _indigo),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPrint,
                    icon: const Icon(Icons.print),
                    label: const Text('Print'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _indigo,
                      side: const BorderSide(color: _indigo),
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
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text('Invoice $invoiceNo created',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
