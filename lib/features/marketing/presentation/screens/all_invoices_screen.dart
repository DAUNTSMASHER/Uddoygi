// lib/features/marketing/presentation/screens/all_invoices_screen.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uddoygi/services/local_storage_service.dart';

/// ------- Brand tokens -------
const Color _indigo  = Color(0xFF0D47A1);
const Color _accent  = Color(0xFF448AFF);
const Color _chipBg  = Color(0xFFEFF3FF);
const Color _surface = Color(0xFFF7F9FC);

class AllInvoicesScreen extends StatefulWidget {
  const AllInvoicesScreen({Key? key}) : super(key: key);

  @override
  State<AllInvoicesScreen> createState() => _AllInvoicesScreenState();
}

class _AllInvoicesScreenState extends State<AllInvoicesScreen> {
  String? agentEmail;
  String? agentUid;

  // UI state
  String _query = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  String _statusFilter = 'All'; // quick status filter

  @override
  void initState() {
    super.initState();
    _loadUserIdentity();
  }

  // ---------- Helpers ----------
  Future<void> _loadUserIdentity() async {
    final user = FirebaseAuth.instance.currentUser;
    String? email = user?.email;
    String? uid   = user?.uid;

    if (email == null || uid == null) {
      final session = await LocalStorageService.getSession();
      email ??= session?['email'] as String?;
      uid   ??= session?['uid'] as String?;
    }
    if (!mounted) return;
    setState(() { agentEmail = email; agentUid = uid; });
  }

  void _logFirestoreIndexLink(Object? error) {
    if (error is! FirebaseException) return;
    if (error.plugin != 'cloud_firestore') return;
    final msg = error.message ?? '';
    final match = RegExp(r'(https://console\.firebase\.google\.com[^\s"]+)').firstMatch(msg);
    if (match != null) {
      debugPrint('🔥 Firestore index required – create it here:\n${match.group(1)}');
    } else {
      debugPrint('Firestore error: $msg');
    }
  }

  String _money(num v) => v.toStringAsFixed(2);
  String _niceDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('payment taken'))     return Colors.green.shade600;
    if (s.contains('payment requested')) return Colors.orange.shade700;
    if (s.contains('invoice'))           return Colors.blueGrey.shade700;
    if (s.contains('shipped'))           return Colors.indigo.shade700;
    if (s.contains('delivered'))         return Colors.teal.shade700;
    return Colors.grey.shade700;
  }

  Widget _statusPill(String status) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 8, color: c),
        const SizedBox(width: 6),
        Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c)),
      ]),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate : DateTime(now.year + 2),
      initialDateRange: (_fromDate != null && _toDate != null)
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
      builder: (c, w) => Theme(
        data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: _indigo)),
        child: w!,
      ),
    );
    if (picked != null) {
      setState(() {
        _fromDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _toDate   = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  void _clearRange() => setState(() { _fromDate = null; _toDate = null; });

  // ---------- PDF ----------
  Future<void> _generatePdf(Map<String, dynamic> inv) async {
    final pdf = pw.Document();

    final itemsRaw = (inv['items'] as List?) ?? [];
    final items = itemsRaw.cast<Map>().map((e) => e.map((k, v) => MapEntry('$k', v))).toList();

    final shipping   = (inv['shippingCost'] as num?) ?? 0;
    final tax        = (inv['tax'] as num?) ?? 0;
    final grandTotal = (inv['grandTotal'] as num?) ?? 0;

    DateTime date;
    final ts = inv['timestamp'];
    if (inv['date'] is Timestamp) {
      date = (inv['date'] as Timestamp).toDate();
    } else if (ts is Timestamp) {
      date = ts.toDate();
    } else if (ts is DateTime) {
      date = ts;
    } else {
      date = DateTime.now();
    }

    final customer   = (inv['customerName'] ?? 'N/A').toString();
    final invoiceNo  = (inv['invoiceNo'] ?? '').toString();

    pdf.addPage(
      pw.Page(
        build: (_) => pw.Container(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Invoice #$invoiceNo', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text('Customer: $customer'),
              pw.Text('Date: ${DateFormat('yyyy-MM-dd').format(date)}'),
              pw.SizedBox(height: 14),
              pw.Table.fromTextArray(
                headers: const ['Model','Colour','Size','Qty','Unit Price','Total'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                data: items.map((it) {
                  final qty   = (it['qty'] as num?) ?? 0;
                  final unit  = (it['unitPrice'] ?? it['unit_price'] ?? 0) as num;
                  final total = (it['lineTotal'] ?? it['total'] ?? (unit * qty)) as num;
                  return [
                    it['model'] ?? '',
                    it['colour'] ?? '',
                    it['size'] ?? '',
                    qty.toString(),
                    '৳${unit.toStringAsFixed(2)}',
                    '৳${total.toStringAsFixed(2)}',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 12),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('Shipping: ৳${shipping.toStringAsFixed(2)}'),
                  pw.Text('Tax: ৳${tax.toStringAsFixed(2)}'),
                  pw.SizedBox(height: 6),
                  pw.Text('Grand Total: ৳${grandTotal.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );

    final bytes = await pdf.save();
    final dir   = await getTemporaryDirectory();
    final path  = '${dir.path}/invoice_$invoiceNo.pdf';
    File(path).writeAsBytesSync(bytes);

    final result  = await ImageGallerySaverPlus.saveFile(path);
    final success = result['isSuccess'] == true;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '✅ PDF saved to gallery' : '❌ Failed to save PDF')),
    );
  }

  // ---------- Details ----------
  void _showDetails(String docId, Map<String, dynamic> inv) {
    final itemsRaw  = (inv['items'] as List?) ?? [];
    final items = itemsRaw.cast<Map>().map((e) => e.map((k, v) => MapEntry('$k', v))).toList();
    final status = (inv['status'] ?? 'Invoice Created').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .88,
        maxChildSize: .95,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.receipt_long, color: _indigo),
                const SizedBox(width: 8),
                Text('Invoice #${inv['invoiceNo'] ?? ''}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _indigo)),
                const Spacer(),
                _statusPill(status),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _infoChip(Icons.person, inv['customerName'] ?? 'N/A'),
                _infoChip(Icons.event, _niceDate(
                  (inv['timestamp'] is Timestamp)
                      ? (inv['timestamp'] as Timestamp).toDate()
                      : (inv['date'] is Timestamp ? (inv['date'] as Timestamp).toDate() : DateTime.now()),
                )),
                _infoChip(Icons.attach_money, '৳${_money((inv['grandTotal'] as num?) ?? 0)}'),
                _infoChip(Icons.inventory_2, '${(inv['items'] as List?)?.length ?? 0} item(s)'),
              ]),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Items', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              ...items.map((it) {
                final qty   = (it['qty'] as num?) ?? 0;
                final unit  = (it['unitPrice'] ?? it['unit_price'] ?? 0) as num;
                final total = (it['lineTotal'] ?? it['total'] ?? (unit * qty)) as num;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${it['model'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Wrap(spacing: 8, children: [
                            _tinyTag('Colour: ${it['colour'] ?? '-'}'),
                            _tinyTag('Size: ${it['size'] ?? '-'}'),
                          ]),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('৳${_money(unit)} × $qty'),
                        Text('= ৳${_money(total)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ]),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Shipping: ৳${_money((inv['shippingCost'] as num?) ?? 0)}'),
                  Text('Tax: ৳${_money((inv['tax'] as num?) ?? 0)}'),
                  const SizedBox(height: 4),
                  Text('Grand Total: ৳${_money((inv['grandTotal'] as num?) ?? 0)}',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ]),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit, color: _indigo),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(foregroundColor: _indigo, side: const BorderSide(color: _indigo)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showEditInvoice(docId, inv);
                    },
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download, color: _indigo),
                    label: const Text('PDF'),
                    style: OutlinedButton.styleFrom(foregroundColor: _indigo, side: const BorderSide(color: _indigo)),
                    onPressed: () => _generatePdf(inv),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Edit (bottom sheet form) ----------
  void _showEditInvoice(String docId, Map<String, dynamic> inv) {
    final formKey = GlobalKey<FormState>();

    // Local editable copies
    String customerId     = (inv['customerId'] ?? '') as String;
    String customerName   = (inv['customerName'] ?? 'N/A') as String;
    DateTime date         = (inv['date'] is Timestamp)
        ? (inv['date'] as Timestamp).toDate()
        : (inv['timestamp'] is Timestamp ? (inv['timestamp'] as Timestamp).toDate() : DateTime.now());
    int statusIndex       = (inv['statusStep'] as int?) ?? 0;
    String statusLabel    = (inv['status'] as String?) ?? 'Invoice Created';

    double shippingCost   = ((inv['shippingCost'] as num?) ?? 0).toDouble();
    double tax            = ((inv['tax'] as num?) ?? 0).toDouble();
    String country        = (inv['country'] as String?) ?? '';
    String note           = (inv['note'] as String?) ?? '';

    // Payment
    final paymentRaw      = (inv['payment'] as Map?)?.map((k, v) => MapEntry('$k', v)) ?? {};
    bool   paymentTaken   = (paymentRaw['taken'] as bool?) ?? false;
    double paymentAmount  = ((paymentRaw['amount'] as num?) ?? 0).toDouble();
    String paymentMethod  = (paymentRaw['method'] as String?) ?? 'Cash';
    String paymentRef     = (paymentRaw['ref'] as String?) ?? '';
    DateTime? paymentDate = (paymentRaw['date'] is Timestamp) ? (paymentRaw['date'] as Timestamp).toDate() : null;

    // Items (allow editing qty & unit price)
    final List<Map<String, dynamic>> items = ((inv['items'] as List?) ?? [])
        .cast<Map>()
        .map((e) => {
      'model'    : e['model'],
      'colour'   : e['colour'],
      'size'     : e['size'],
      'qty'      : (e['qty'] as num?)?.toInt() ?? 1,
      'unitPrice': ((e['unitPrice'] ?? e['unit_price'] ?? 0) as num).toDouble(),
      'lineTotal': ((e['lineTotal'] ?? e['total'] ?? 0) as num).toDouble(),
    })
        .toList();

    double recomputeSubtotal() {
      double s = 0;
      for (final it in items) {
        final qty  = (it['qty'] as int?) ?? 1;
        final unit = (it['unitPrice'] as double?) ?? 0;
        it['lineTotal'] = unit * qty;
        s += it['lineTotal'] as double;
      }
      return s;
    }
    double grandTotal() => recomputeSubtotal() + shippingCost + tax;

    const steps = [
      'Invoice Created',
      'Payment Requested',
      'Payment Taken',
      'Submitted to Factory for Production',
      'Production In Progress',
      'Quality Check',
      'Product Received at Warehouse',
      'Address Validation of the Customer',
      'Packed & Ready',
      'Shipped to Shipping Company',
      'In Transit',
      'Delivered / Completed',
    ];
    const int kMaxEditableStepIndex = 2;

    InputDecoration deco(String label) => InputDecoration(
      isDense: true,
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .92,
        maxChildSize: .97,
        builder: (_, controller) => StatefulBuilder(
          builder: (c, setSheetState) => SingleChildScrollView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
            child: Form(
              key: formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.edit_note, color: _indigo),
                  const SizedBox(width: 8),
                  Text('Edit Invoice #${inv['invoiceNo'] ?? ''}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _indigo)),
                  const Spacer(),
                  _statusPill(statusLabel),
                ]),
                const SizedBox(height: 12),

                // Buyer + date
                _section(
                  title: 'Buyer & Date',
                  child: Column(children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: (agentEmail == null)
                          ? const Stream.empty()
                          : FirebaseFirestore.instance
                          .collection('customers')
                          .where('ownerEmail', isEqualTo: agentEmail)
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (ctx, snap) {
                        final buyers = (snap.data?.docs ?? []);
                        return DropdownButtonFormField<String>(
                          value: (customerId.isEmpty && buyers.isNotEmpty)
                              ? buyers.first.id
                              : (customerId.isNotEmpty ? customerId : null),
                          decoration: deco('Select Buyer'),
                          items: buyers
                              .map((d) => DropdownMenuItem(
                            value: d.id,
                            child: Text((d['name'] ?? 'Unnamed').toString()),
                          ))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            final name = buyers.firstWhere((d) => d.id == v)['name'];
                            setSheetState(() {
                              customerId   = v;
                              customerName = (name ?? '').toString();
                            });
                          },
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: Text('Date: ${_niceDate(date)}')),
                      TextButton(
                        child: const Text('Change', style: TextStyle(color: _indigo)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate  : DateTime(2020),
                            lastDate   : DateTime(2100),
                            builder    : (c, w) => Theme(
                              data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: _indigo)),
                              child: w!,
                            ),
                          );
                          if (picked != null) setSheetState(() => date = picked);
                        },
                      ),
                    ]),
                  ]),
                ),

                // Status
                _section(
                  title: 'Status',
                  child: DropdownButtonFormField<int>(
                    value: statusIndex,
                    decoration: deco('Step (up to Payment Taken)'),
                    items: List.generate(kMaxEditableStepIndex + 1, (i) => i)
                        .map((i) => DropdownMenuItem(value: i, child: Text(steps[i]))).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setSheetState(() {
                        statusIndex = v;
                        statusLabel = steps[v];
                        if (statusIndex >= 2) {
                          paymentTaken = true;
                          paymentDate ??= DateTime.now();
                        }
                      });
                    },
                  ),
                ),

                // Items
                _section(
                  title: 'Items (Qty & Unit Price)',
                  child: Column(children: [
                    ...List.generate(items.length, (i) {
                      final it = items[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${it['model'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Wrap(spacing: 8, children: [
                              _tinyTag('Colour: ${it['colour'] ?? '-'}'),
                              _tinyTag('Size: ${it['size'] ?? '-'}'),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: '${it['qty']}',
                                  decoration  : deco('Qty'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                    final q = int.tryParse(v) ?? 1;
                                    setSheetState(() { it['qty'] = q <= 0 ? 1 : q; });
                                  },
                                  validator: (v) => (v == null || v.isEmpty) ? 'Req' : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  initialValue: _money((it['unitPrice'] as num?) ?? 0),
                                  decoration  : deco('Unit Price'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                    setSheetState(() { it['unitPrice'] = double.tryParse(v) ?? 0.0; });
                                  },
                                  validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
                                ),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Line Total: ৳${_money(((it['unitPrice'] as double) * (it['qty'] as int)))}',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ]),
                        ),
                      );
                    }),
                  ]),
                ),

                // Charges
                _section(
                  title: 'Charges',
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _money(shippingCost),
                          decoration  : deco('Shipping Cost'),
                          keyboardType: TextInputType.number,
                          onChanged   : (v) => setSheetState(() => shippingCost = double.tryParse(v) ?? 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: _money(tax),
                          decoration  : deco('Tax'),
                          keyboardType: TextInputType.number,
                          onChanged   : (v) => setSheetState(() => tax = double.tryParse(v) ?? 0),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: country,
                      decoration  : deco('Country'),
                      onChanged   : (v) => setSheetState(() => country = v),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: note,
                      decoration  : deco('Note'),
                      maxLines    : 2,
                      onChanged   : (v) => setSheetState(() => note = v),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Builder(
                        builder: (_) {
                          final subtotal = items.fold<double>(0, (s, it) =>
                          s + ((it['unitPrice'] as double?) ?? 0) * ((it['qty'] as int?) ?? 0));
                          final grand = subtotal + shippingCost + tax;
                          return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('Subtotal: ৳${_money(subtotal)}'),
                            Text('Grand Total: ৳${_money(grand)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                          ]);
                        },
                      ),
                    ),
                  ]),
                ),

                // Payment
                _section(
                  title: 'Payment (Optional)',
                  child: Column(children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Payment Taken'),
                      value: paymentTaken,
                      onChanged: (v) => setSheetState(() {
                        paymentTaken = v ?? false;
                        if (paymentTaken && statusIndex < 2) {
                          statusIndex = 2; statusLabel = steps[2];
                        }
                        if (paymentTaken && paymentDate == null) paymentDate = DateTime.now();
                      }),
                    ),
                    AnimatedOpacity(
                      opacity: paymentTaken ? 1 : .45,
                      duration: const Duration(milliseconds: 150),
                      child: IgnorePointer(
                        ignoring: !paymentTaken,
                        child: Column(children: [
                          Row(children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: _money(paymentAmount),
                                decoration  : deco('Amount Received'),
                                keyboardType: TextInputType.number,
                                onChanged   : (v) => setSheetState(() => paymentAmount = double.tryParse(v) ?? 0),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value     : paymentMethod,
                                decoration: deco('Method'),
                                items     : const ['Cash','Bank','Card','Mobile Banking']
                                    .map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                onChanged : (v) => setSheetState(() => paymentMethod = v ?? 'Cash'),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: paymentRef,
                            decoration  : deco('Reference / Txn ID'),
                            onChanged   : (v) => setSheetState(() => paymentRef = v),
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: Text('Payment Date: ${paymentDate == null ? '-' : _niceDate(paymentDate!)}')),
                            TextButton(
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: paymentDate ?? DateTime.now(),
                                  firstDate : DateTime(2020),
                                  lastDate  : DateTime(2100),
                                  builder   : (c, w) => Theme(
                                    data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: _indigo)),
                                    child: w!,
                                  ),
                                );
                                if (d != null) setSheetState(() => paymentDate = d);
                              },
                              child: const Text('Change', style: TextStyle(color: _indigo)),
                            ),
                          ]),
                        ]),
                      ),
                    ),
                  ]),
                ),

                // Save
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon : const Icon(Icons.save),
                    label: const Text('Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape  : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      final updatedItems = items.map((it) {
                        final qty  = (it['qty'] as int?) ?? 1;
                        final unit = (it['unitPrice'] as double?) ?? 0.0;
                        return {
                          'model'    : it['model'],
                          'colour'   : it['colour'],
                          'size'     : it['size'],
                          'qty'      : qty,
                          'unitPrice': unit,
                          'lineTotal': unit * qty,
                        };
                      }).toList();

                      final subtotal = updatedItems.fold<double>(0, (s, it) => s + (it['lineTotal'] as double));
                      final grand    = subtotal + shippingCost + tax;

                      final updated = <String, dynamic>{
                        'customerId'  : customerId,
                        'customerName': customerName,
                        'date'        : Timestamp.fromDate(date),
                        'timestamp'   : Timestamp.fromDate(date),
                        'statusStep'  : statusIndex,
                        'status'      : statusLabel,
                        'items'       : updatedItems,
                        'shippingCost': shippingCost,
                        'tax'         : tax,
                        'grandTotal'  : grand,
                        'country'     : country,
                        'note'        : note,
                        'updatedAt'   : FieldValue.serverTimestamp(),
                      };

                      if (paymentTaken) {
                        updated['payment'] = {
                          'taken' : true,
                          'amount': paymentAmount,
                          'method': paymentMethod,
                          'ref'   : paymentRef,
                          'date'  : paymentDate != null
                              ? Timestamp.fromDate(paymentDate!)
                              : FieldValue.serverTimestamp(),
                        };
                      } else {
                        updated['payment'] = {'taken': false};
                      }

                      try {
                        await FirebaseFirestore.instance.collection('invoices').doc(docId).update(updated);
                        if (!mounted) return;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Invoice updated')));
                      } on FirebaseException catch (e) {
                        _logFirestoreIndexLink(e);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Failed to update: ${e.message}')));
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Failed to update: $e')));
                      }
                    },
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- UI Bits ----------
  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _chipBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: _indigo),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _tinyTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: const TextStyle(fontSize: 10, color: Colors.black87)),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 6, height: 18, decoration: BoxDecoration(color: _indigo, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: _indigo)),
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    if (agentEmail == null && agentUid == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
        backgroundColor: _surface,
      );
    }

    // 1) Stream the agent's customers (by email or uid)
    final customersRef = FirebaseFirestore.instance.collection('customers');

    Filter? customerOwnerFilter;
    if (agentEmail != null && agentUid != null) {
      customerOwnerFilter = Filter.or(
        Filter('ownerEmail', isEqualTo: agentEmail),
        Filter('ownerUid', isEqualTo: agentUid),
      );
    } else if (agentEmail != null) {
      customerOwnerFilter = Filter('ownerEmail', isEqualTo: agentEmail);
    } else {
      customerOwnerFilter = Filter('ownerUid', isEqualTo: agentUid);
    }

    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: _surface,
      body: Column(
        children: [
          _filtersBar(),
          _statusQuickFilters(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: customersRef.where(customerOwnerFilter!).snapshots(),
              builder: (ctx, custSnap) {
                if (custSnap.hasError) {
                  _logFirestoreIndexLink(custSnap.error);
                  return Center(child: Text('Couldn’t load customers.\n${custSnap.error}'));
                }
                if (custSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final myCustomerIds = custSnap.data?.docs.map((d) => d.id).toList() ?? <String>[];
                final myCustomerIdSet = myCustomerIds.toSet();

                if (myCustomerIds.isEmpty) {
                  return _emptyState();
                }

                // 2) Build invoice query
                final invoicesRef = FirebaseFirestore.instance.collection('invoices');
                Query<Map<String, dynamic>> invoiceQuery;

                if (myCustomerIds.length <= 10) {
                  // Best path: filter on server
                  invoiceQuery = invoicesRef
                      .where('customerId', whereIn: myCustomerIds)
                      .orderBy('timestamp', descending: true);
                } else {
                  // Fallback: narrow by agent ownership (to avoid loading everything),
                  // then we’ll client-filter to only our customers.
                  Filter? ownerOr;
                  if (agentEmail != null && agentUid != null) {
                    ownerOr = Filter.or(
                      Filter('ownerEmail', isEqualTo: agentEmail),
                      Filter('ownerUid', isEqualTo: agentUid),
                    );
                  } else if (agentEmail != null) {
                    ownerOr = Filter('ownerEmail', isEqualTo: agentEmail);
                  } else {
                    ownerOr = Filter('ownerUid', isEqualTo: agentUid);
                  }
                  invoiceQuery = invoicesRef.where(ownerOr!).orderBy('timestamp', descending: true);
                }

                // 3) Stream invoices
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: invoiceQuery.snapshots(),
                  builder: (ctx, invSnap) {
                    if (invSnap.hasError) {
                      _logFirestoreIndexLink(invSnap.error);
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('We couldn’t load your invoices.\n${invSnap.error}', textAlign: TextAlign.center),
                        ),
                      );
                    }
                    if (invSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Raw docs from server
                    var docs = invSnap.data?.docs ?? [];

                    // If we used the fallback path (>10 customers), filter to only our customers.
                    if (myCustomerIds.length > 10) {
                      docs = docs.where((d) => myCustomerIdSet.contains(d.data()['customerId'] as String?)).toList();
                    }

                    // Local UI filters: search, date range, status
                    final filtered = docs.where((d) {
                      final m    = d.data();
                      final invN = (m['invoiceNo'] ?? '').toString().toLowerCase();
                      final cust = (m['customerName'] ?? '').toString().toLowerCase();

                      final statusOk = _statusFilter == 'All'
                          ? true
                          : (m['status']?.toString().toLowerCase() ?? '').contains(_statusFilter.toLowerCase());

                      final queryOk = _query.isEmpty || invN.contains(_query) || cust.contains(_query);
                      if (!(statusOk && queryOk)) return false;

                      if (_fromDate == null || _toDate == null) return true;

                      DateTime dt;
                      final ts = m['timestamp'];
                      if (ts is Timestamp) {
                        dt = ts.toDate();
                      } else if (m['date'] is Timestamp) {
                        dt = (m['date'] as Timestamp).toDate();
                      } else {
                        return true;
                      }
                      return (dt.isAtSameMomentAs(_fromDate!) || dt.isAfter(_fromDate!)) &&
                          (dt.isAtSameMomentAs(_toDate!)   || dt.isBefore(_toDate!));
                    }).toList();

                    final totalAmount = filtered.fold<num>(
                      0, (sum, d) => sum + ((d.data()['grandTotal'] as num?) ?? 0),
                    );

                    if (filtered.isEmpty) return _emptyState();

                    return Column(
                      children: [
                        _statsHeader(count: filtered.length, total: totalAmount.toDouble()),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final doc = filtered[i];
                              return _invoiceCard(doc.id, doc.data());
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      foregroundColor: Colors.white,
      title: const Text('All Invoices', style: TextStyle(fontWeight: FontWeight.w800)),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_indigo, _accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  Widget _filtersBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search invoice # or customer…',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blueGrey.shade100),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: _indigo, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    (_fromDate == null || _toDate == null)
                        ? 'Filter by date range'
                        : '${_niceDate(_fromDate!)} → ${_niceDate(_toDate!)}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _indigo,
                    side: const BorderSide(color: _indigo),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _pickRange,
                ),
              ),
              const SizedBox(width: 8),
              if (_fromDate != null || _toDate != null)
                IconButton(
                  tooltip: 'Clear',
                  onPressed: _clearRange,
                  icon: const Icon(Icons.clear, color: Colors.redAccent),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusQuickFilters() {
    const options = ['All','Invoice Created','Payment Requested','Payment Taken','Shipped','Delivered'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final o in options) ...[
            ChoiceChip(
              label: Text(o, style: const TextStyle(fontWeight: FontWeight.w600)),
              selected: _statusFilter == o,
              selectedColor: _chipBg,
              onSelected: (_) => setState(() => _statusFilter = o),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.blueGrey.shade100)),
            ),
            const SizedBox(width: 8),
          ]
        ]),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.blueGrey.shade300),
            const SizedBox(height: 12),
            const Text('No invoices match your filters', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Try clearing the search or adjusting the date/status filters.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _statsHeader({required int count, required double total}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(colors: [_indigo, _accent]),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          _statBox('Invoices', '$count'),
          const SizedBox(width: 12),
          _statBox('Total Amount', '৳${_money(total)}'),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.92), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _indigo)),
          ],
        ),
      ),
    );
  }

  Widget _invoiceCard(String docId, Map<String, dynamic> inv) {
    final customer  = (inv['customerName'] ?? 'N/A').toString();
    final total     = ((inv['grandTotal'] as num?) ?? 0).toDouble();
    final tracking  = (inv['tracking_number'] ?? '').toString().trim();

    DateTime date;
    final ts = inv['timestamp'];
    if (inv['date'] is Timestamp) {
      date = (inv['date'] as Timestamp).toDate();
    } else if (ts is Timestamp) {
      date = ts.toDate();
    } else {
      date = DateTime.now();
    }

    // Detect whether a Work Order exists for this invoice:
    // Prefer tracking match when available, else fall back to invoiceId.
    final woColl   = FirebaseFirestore.instance.collection('work_orders');
    final woStream = (tracking.isNotEmpty)
        ? woColl.where('tracking_number', isEqualTo: tracking).limit(1).snapshots()
        : woColl.where('invoiceId', isEqualTo: docId).limit(1).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: woStream,
      builder: (ctx, snap) {
        final hasWO = (snap.data?.docs.isNotEmpty ?? false);

        // Visual theme toggles
        final buyerColor   = hasWO ? _indigo : Colors.deepOrange.shade800;
        final accentColor  = hasWO ? _indigo : Colors.orange.shade700;
        final borderColor  = hasWO ? Colors.blueGrey.shade100 : Colors.orange.shade200;

        // Subtle background gradient that matches the theme
        final bgGradient = hasWO
            ? LinearGradient(
          colors: [Colors.white, _chipBg.withOpacity(.55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : const LinearGradient(
          colors: [Color(0xFFFFFCF5), Color(0xFFFFF1DB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: bgGradient,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                // Left: Buyer (big) + Tracking + Date + badge
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showDetails(docId, inv),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Buyer big
                        Text(
                          customer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: buyerColor),
                        ),
                        const SizedBox(height: 4),
                        // Tracking (primary id)
                        Row(
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 16, color: tracking.isEmpty ? accentColor : Colors.black54),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                tracking.isEmpty ? 'No Tracking' : tracking,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tracking.isEmpty ? accentColor : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Secondary row: date + WO badge (NO invoice number shown)
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(_niceDate(date), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: hasWO ? Colors.green.withOpacity(.12) : accentColor.withOpacity(.15),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: hasWO ? Colors.green.withOpacity(.35) : accentColor.withOpacity(.35)),
                              ),
                              child: Text(
                                hasWO ? 'WO Submitted' : 'No Work Order',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: hasWO ? Colors.green.shade700 : accentColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Right: Total + Details button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '৳${_money(total)}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: buyerColor),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: buyerColor,
                        side: BorderSide(color: buyerColor),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showDetails(docId, inv),
                      child: const Text('Details'),
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

