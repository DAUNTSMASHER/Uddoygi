import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'payment_slip_screen.dart';

const Color _indigo = Color(0xFF2563EB);
const Color _indigoDk = Color(0xFF1E3A8A);
const Color _chipBg = Color(0xFFEFF6FF);
const Color _surface = Color(0xFFF8FAFC);
const Color _border = Color(0xFFE2E8F0);
const Color _fg = Color(0xFF0F172A);
const Color _muted = Color(0xFF64748B);
const double _radius = 12.0;
const double _radiusCard = 16.0;

class AllInvoicesScreen extends StatefulWidget {
  const AllInvoicesScreen({Key? key}) : super(key: key);

  @override
  State<AllInvoicesScreen> createState() => _AllInvoicesScreenState();
}

class _AllInvoicesScreenState extends State<AllInvoicesScreen> {
  String _cid = '';
  String? agentEmail;
  String? agentUid;

  String _query = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _loadUserIdentity();
  }

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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters;
  }

  String _emojiFlag(String? iso) {
    if (iso == null || iso.length != 2) return '🌐';
    final code = iso.toUpperCase();
    const int base = 0x1F1E6; // regional indicator 'A'
    return String.fromCharCodes(code.codeUnits.map((c) => base + (c - 65)));
  }

  Map<String, dynamic> _toMap(Object? v) {
    if (v is Map) {
      // coerce keys to String to satisfy Map<String, dynamic>
      return v.map((k, val) => MapEntry(k.toString(), val));
    }
    return const <String, dynamic>{};
  }

  String _countryLabelShort(Map<String, dynamic> inv) {
    final shipping = _toMap(inv['shipping']);
    final country  = _toMap(shipping['country']);
    final name = (country['name'] ?? inv['country'] ?? '').toString().trim();
    final code = (country['code'] ?? inv['countryCode'] ?? '').toString().trim();

    final words = name.isEmpty ? <String>[] : name.split(RegExp(r'\s+'));
    final short = words.take(3).join(' '); // up to three words
    final flag  = _emojiFlag(code.isEmpty ? null : code);

    return [flag, if (short.isNotEmpty) short].join(' ').trim();
  }

  int _totalQtyFromItems(List? itemsRaw) {
    final items = (itemsRaw ?? const []).cast<Map>();
    int sum = 0;
    for (final it in items) {
      sum += ((it['qty'] as num?)?.toInt() ?? 0);
    }
    return sum;
  }

  Widget _customerAvatar(String? customerId, String fallbackName) {
    if (customerId == null || customerId.isEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: _indigo.withValues(alpha: 0.12),
        child: Text(_initials(fallbackName), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: _indigo)),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: DB.colSync(_cid, C.customers).doc(customerId).snapshots(),
      builder: (ctx, snap) {
        final data = snap.data?.data();
        final url  = (data?['photoUrl'] ?? data?['image'] ?? '').toString();
        final name = (data?['name'] ?? fallbackName).toString();
        if (url.isNotEmpty) {
          return CircleAvatar(radius: 22, backgroundImage: NetworkImage(url));
        }
        return CircleAvatar(
          radius: 22,
          backgroundColor: _indigo.withValues(alpha: 0.12),
          child: Text(_initials(name), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: _indigo)),
        );
      },
    );
  }

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
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 8, color: c),
        const SizedBox(width: 6),
        Text(status, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
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

  Future<void> _generatePdf(Map<String, dynamic> inv) async {
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: pw.Font.times(), bold: pw.Font.timesBold(), italic: pw.Font.timesItalic(), boldItalic: pw.Font.timesBoldItalic()));

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

  void _showDetails(String docId, Map<String, dynamic> inv) {
    final itemsRaw = (inv['items'] as List?) ?? [];
    final items = itemsRaw
        .cast<Map>()
        .map((e) => e.map((k, v) => MapEntry('$k', v)))
        .toList();

    final status = (inv['status'] ?? 'Invoice Created').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_radiusCard + 2)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .88,
        maxChildSize: .95,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _chipBg, borderRadius: BorderRadius.circular(_radius), border: Border.all(color: _border)),
                    child: const Icon(Icons.receipt_long_rounded, color: _indigo, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Invoice #${inv['invoiceNo'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: _fg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              _statusPill(status),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _infoChip(Icons.person, inv['customerName'] ?? 'N/A'),
                  _infoChip(
                    Icons.event,
                    _niceDate(
                      (inv['timestamp'] is Timestamp)
                          ? (inv['timestamp'] as Timestamp).toDate()
                          : (inv['date'] is Timestamp
                          ? (inv['date'] as Timestamp).toDate()
                          : DateTime.now()),
                    ),
                  ),
                  _infoChip(Icons.attach_money,
                      '৳${_money((inv['grandTotal'] as num?) ?? 0)}'),
                  _infoChip(Icons.inventory_2,
                      '${(inv['items'] as List?)?.length ?? 0} item(s)'),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              Text('Items', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15, color: _fg)),
              const SizedBox(height: 6),
              ...items.map((it) {
                final qty = (it['qty'] as num?) ?? 0;
                final unit = (it['unitPrice'] ?? it['unit_price'] ?? 0) as num;
                final total =
                (it['lineTotal'] ?? it['total'] ?? (unit * qty)) as num;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(_radius),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${it['model'] ?? ''}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: _fg)),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 8,
                              children: [
                                _tinyTag('Colour: ${it['colour'] ?? '-'}'),
                                _tinyTag('Size: ${it['size'] ?? '-'}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('৳${_money(unit)} × $qty'),
                          Text('= ৳${_money(total)}',
                              style:
                              const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Shipping: ৳${_money((inv['shippingCost'] as num?) ?? 0)}'),
                    Text('Tax: ৳${_money((inv['tax'] as num?) ?? 0)}'),
                    const SizedBox(height: 4),
                    Text(
                      'Grand Total: ৳${_money((inv['grandTotal'] as num?) ?? 0)}',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: _indigo),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              _buildSlipStatusBanner(docId, inv),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit, color: _indigo),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _indigo,
                        side: const BorderSide(color: _indigo),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showEditInvoice(docId, inv);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.download, color: _indigo),
                      label: const Text('PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _indigo,
                        side: const BorderSide(color: _indigo),
                      ),
                      onPressed: () => _generatePdf(inv),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildAddSlipButton(context, docId, inv),
            ],
          ),
        ),
      ),
    );
  }

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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_radiusCard + 2)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .92,
        maxChildSize: .97,
        builder: (_, controller) => StatefulBuilder(
          builder: (c, setSheetState) => SingleChildScrollView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(16, 16, 16,
                MediaQuery.of(context).viewInsets.bottom + 24),
            child: Form(
              key: formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: _chipBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
                    child: const Icon(Icons.edit_note_rounded, color: _indigo, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Edit Invoice #${inv['invoiceNo'] ?? ''}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700, color: _fg)),
                  ),
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
                          : DB.colSync(_cid, C.customers)
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
                            Text('Grand Total: ৳${_money(grand)}',
                                style: const TextStyle(fontWeight: FontWeight.w900)),
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
                        await DB.colSync(_cid, C.invoices).doc(docId).update(updated);
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

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: _indigo),
        const SizedBox(width: 6),
        Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: _fg)),
      ]),
    );
  }

  Widget _tinyTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: _surface, border: Border.all(color: _border), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _muted)),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radiusCard),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: _indigo, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: _indigo)),
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (agentEmail == null && agentUid == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
        backgroundColor: _surface,
      );
    }

    final invoicesRef = DB.colSync(_cid, C.invoices);

    Filter ownerFilter;
    if (agentEmail != null && agentUid != null) {
      ownerFilter = Filter.or(
        Filter('ownerEmail', isEqualTo: agentEmail),
        Filter('ownerUid', isEqualTo: agentUid),
      );
    } else if (agentEmail != null) {
      ownerFilter = Filter('ownerEmail', isEqualTo: agentEmail);
    } else {
      ownerFilter = Filter('ownerUid', isEqualTo: agentUid);
    }

    final query = invoicesRef
        .where(ownerFilter)
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: _surface,
      body: Column(
        children: [
          _filtersBar(),
          _statusQuickFilters(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
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

                var docs = invSnap.data?.docs ?? [];

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

                final paidOnly = filtered.where((d) {
                  final m = d.data();
                  final pay = m['payment'];
                  final takenFlag = (pay is Map && pay['taken'] == true);
                  final takenByStatus =
                  (m['status']?.toString().toLowerCase() ?? '').contains('payment taken');
                  return takenFlag || takenByStatus;
                }).toList();

                final totalPaidAmount = paidOnly.fold<num>(
                  0, (sum, d) => sum + ((d.data()['grandTotal'] as num?) ?? 0),
                );

                final pendingAmount = filtered.fold<num>(0, (sum, d) {
                  final m      = d.data();
                  final slip   = (m['slipStatus'] as String?) ?? '';
                  final pay    = m['payment'];
                  final taken  = (pay is Map && pay['taken'] == true) ||
                      (m['status']?.toString().toLowerCase() ?? '').contains('payment taken');
                  if (taken || slip == 'verified') return sum;
                  return sum + ((m['grandTotal'] as num?) ?? 0);
                });

                if (filtered.isEmpty) return _emptyState();

                return Column(
                  children: [
                    _statsHeader(
                      count: paidOnly.length,
                      total: totalPaidAmount.toDouble(),
                      pending: pendingAmount.toDouble(),
                    ),
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
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: _indigoDk,
      foregroundColor: Colors.white,
      title: Text('All Invoices', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18)),
    );
  }

  Widget _filtersBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search invoice or customer',
              hintStyle: GoogleFonts.plusJakartaSans(color: _muted, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, color: _muted, size: 22),
              filled: true,
              fillColor: _surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(_radius), borderSide: const BorderSide(color: _border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_radius), borderSide: const BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_radius), borderSide: const BorderSide(color: _indigo, width: 1.5)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(
                    (_fromDate == null || _toDate == null)
                        ? 'Date range'
                        : '${_niceDate(_fromDate!)} – ${_niceDate(_toDate!)}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _indigo,
                    side: const BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
                  ),
                  onPressed: _pickRange,
                ),
              ),
              if (_fromDate != null || _toDate != null) ...[
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: _chipBg, foregroundColor: _indigo),
                  onPressed: _clearRange,
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  tooltip: 'Clear date',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusQuickFilters() {
    const options = ['All', 'Invoice Created', 'Payment Requested', 'Payment Taken', 'Shipped', 'Delivered'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: _border))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final o in options) ...[
            FilterChip(
              label: Text(o, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
              selected: _statusFilter == o,
              selectedColor: _indigo.withValues(alpha: 0.12),
              checkmarkColor: _indigo,
              labelStyle: TextStyle(color: _statusFilter == o ? _indigo : _fg),
              side: BorderSide(color: _statusFilter == o ? _indigo : _border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              onSelected: (_) => setState(() => _statusFilter = o),
            ),
            const SizedBox(width: 8),
          ],
        ]),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _chipBg,
                borderRadius: BorderRadius.circular(_radiusCard),
                border: Border.all(color: _border),
              ),
              child: Icon(Icons.receipt_long_rounded, size: 56, color: _muted),
            ),
            const SizedBox(height: 20),
            Text('No invoices match your filters', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: _fg)),
            const SizedBox(height: 8),
            Text('Clear search or adjust date and status filters.',
                textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _muted)),
          ],
        ),
      ),
    );
  }

  Widget _statsHeader({required int count, required double total, double pending = 0}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radiusCard),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: _indigo.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          _statBox('Paid', '$count'),
          Container(width: 1, height: 36, color: _border),
          _statBox('Received', '৳${_money(total)}'),
          Container(width: 1, height: 36, color: _border),
          _statBox('Pending', '৳${_money(pending)}', warn: pending > 0),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, {bool warn = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800,
                  color: warn ? Colors.orange.shade700 : _indigo)),
        ],
      ),
    );
  }

  Widget _buildSlipStatusBanner(String docId, Map<String, dynamic> inv) {
    final slipStatus    = (inv['slipStatus'] as String?) ?? '';
    final slipSubmitted = (inv['slipSubmitted'] as bool?) ?? false;
    final total         = ((inv['grandTotal'] as num?) ?? 0).toDouble();
    final payment       = inv['payment'];
    final paid          = (payment is Map && payment['taken'] == true)
        ? ((payment['amount'] as num?)?.toDouble() ?? total)
        : 0.0;
    final pending = total - paid;

    if (slipStatus == 'verified') {
      return _bannerTile(Icons.verified_rounded, 'Payment Verified by HR',
          'This payment has been confirmed. Invoice marked as Payment Taken.',
          Colors.green.shade600);
    }
    if (slipStatus == 'rejected') {
      return _bannerTile(Icons.cancel_rounded, 'Slip Rejected by HR',
          'Your slip was rejected. Please upload a new valid payment slip.',
          Colors.red.shade600);
    }
    if (slipSubmitted || slipStatus == 'pending_hr') {
      return _bannerTile(Icons.hourglass_top_rounded, 'Slip Pending HR Approval',
          'Your payment slip has been submitted and is awaiting HR verification.',
          Colors.orange.shade700);
    }
    if (pending > 0) {
      return _bannerTile(Icons.pending_actions_rounded,
          'Payment Pending: ৳${_money(pending)}',
          'No verified payment slip found. Upload a slip to confirm payment.',
          Colors.blueGrey.shade600);
    }
    return const SizedBox.shrink();
  }

  Widget _bannerTile(IconData icon, String title, String sub, Color color) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 2),
                Text(sub, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _muted)),
              ],
            ),
          ),
        ]),
      );

  Widget _buildAddSlipButton(BuildContext ctx, String docId, Map<String, dynamic> inv) {
    final slipStatus   = (inv['slipStatus'] as String?) ?? '';
    final paymentTaken = ((inv['payment'] is Map &&
        (inv['payment'] as Map)['taken'] == true) ||
        (inv['status']?.toString().toLowerCase() ?? '').contains('payment taken'));

    if (paymentTaken && slipStatus == 'verified') return const SizedBox.shrink();

    final total = ((inv['grandTotal'] as num?) ?? 0).toDouble();
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.upload_file_rounded, size: 18),
        label: Text(slipStatus == 'rejected'
            ? 'Re-submit Payment Slip'
            : 'Upload Payment Slip'),
        onPressed: () {
          Navigator.of(ctx).pop();
          Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => PaymentSlipScreen(
              invoiceId:    docId,
              invoiceNo:    (inv['invoiceNo'] ?? '').toString(),
              invoiceTotal: total,
            )),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _indigo,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _slipBadge(Map<String, dynamic> inv) {
    final slipStatus    = (inv['slipStatus'] as String?) ?? '';
    final slipSubmitted = (inv['slipSubmitted'] as bool?) ?? false;

    if (slipStatus == 'verified') {
      return _miniPill(Icons.verified_rounded, 'Slip Verified', Colors.green.shade600);
    }
    if (slipStatus == 'rejected') {
      return _miniPill(Icons.cancel_rounded, 'Slip Rejected', Colors.red.shade600);
    }
    if (slipSubmitted || slipStatus == 'pending_hr') {
      return _miniPill(Icons.hourglass_top_rounded, 'Slip Pending HR', Colors.orange.shade700);
    }
    // Show pending payment amount
    final total   = ((inv['grandTotal'] as num?) ?? 0).toDouble();
    final payment = inv['payment'];
    final paid    = (payment is Map && payment['taken'] == true)
        ? ((payment['amount'] as num?)?.toDouble() ?? total)
        : 0.0;
    final pending = total - paid;
    if (pending > 0) {
      return _miniPill(Icons.pending_actions_rounded,
          'Pending ৳${_money(pending)}', Colors.blueGrey.shade600);
    }
    return const SizedBox.shrink();
  }

  Widget _miniPill(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    ]),
  );

  Widget _invoiceCard(String docId, Map<String, dynamic> inv) {
    final customer   = (inv['customerName'] ?? 'N/A').toString();
    final total      = ((inv['grandTotal'] as num?) ?? 0).toDouble();
    final tracking   = (inv['tracking_number'] ?? '').toString().trim();
    final status     = (inv['status'] ?? 'Invoice Created').toString();
    final customerId = (inv['customerId'] ?? '').toString();

    // date
    DateTime date;
    final ts = inv['timestamp'];
    if (inv['date'] is Timestamp) {
      date = (inv['date'] as Timestamp).toDate();
    } else if (ts is Timestamp) {
      date = ts.toDate();
    } else {
      date = DateTime.now();
    }

    // quantities
    final totalQty = _totalQtyFromItems(inv['items'] as List?);

    // right-top country label (emoji flag + up to 3 words)
    final countrySmall = _countryLabelShort(inv);

    // slip status
    final slipStatus    = (inv['slipStatus'] as String?) ?? '';
    final slipSubmitted = (inv['slipSubmitted'] as bool?) ?? false;
    final paymentTaken  = (inv['payment'] is Map &&
        (inv['payment'] as Map)['taken'] == true) ||
        status.toLowerCase().contains('payment taken');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radiusCard),
        border: Border.all(
          color: slipStatus == 'verified' ? const Color(0xFF16A34A) : _border,
          width: slipStatus == 'verified' ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_radiusCard),
          onTap: () => _showDetails(docId, inv),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final bool compact = constraints.maxWidth < 360;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _customerAvatar(customerId, customer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: compact ? 14 : 16,
                                  fontWeight: FontWeight.w700,
                                  color: _fg,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.local_shipping_outlined, size: 16, color: _muted),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      tracking.isEmpty ? 'No tracking' : tracking,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: _muted),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('Qty: $totalQty', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _muted)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                countrySmall.isEmpty ? '🌐' : countrySmall,
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: _muted),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '৳${_money(total)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: compact ? 15 : 17,
                                  fontWeight: FontWeight.w800,
                                  color: _indigo,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Divider(height: 1, color: _border),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 6, children: [_statusPill(status), _slipBadge(inv)]),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(_niceDate(date), style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _muted)),
                        const Spacer(),
                        if (!paymentTaken && slipStatus != 'verified')
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => PaymentSlipScreen(
                                invoiceId: docId,
                                invoiceNo: (inv['invoiceNo'] ?? '').toString(),
                                invoiceTotal: total,
                              )),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _indigo,
                                borderRadius: BorderRadius.circular(_radius),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.upload_file_rounded, size: 14, color: Colors.white),
                                const SizedBox(width: 5),
                                Text('Add Slip', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                              ]),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
