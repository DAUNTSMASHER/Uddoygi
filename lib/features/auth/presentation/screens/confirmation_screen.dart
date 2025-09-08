// lib/features/factory/presentation/screens/confirmation_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color _darkBlue = Color(0xFF0D47A1);
const Color _panel = Color(0xFFF7F8FB);

class ConfirmationScreen extends StatefulWidget {
  const ConfirmationScreen({Key? key}) : super(key: key);

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  String? _token;
  bool _ready = false;
  bool _working = false;

  DocumentSnapshot<Map<String, dynamic>>? _validationSnap;
  DocumentSnapshot<Map<String, dynamic>>? _orderSnap;
  DocumentSnapshot<Map<String, dynamic>>? _invoiceSnap;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      // Anonymous sign-in so public visitors can confirm
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (_) {}

    // Resolve token from URL (supports /address-confirm?token=..., hash routes, or /address-confirm/<token>)
    String? token;
    final base = Uri.base;

    // query param
    token = base.queryParameters['token'];

    // hash router e.g. /#/address-confirm?token=...
    if (token == null && base.fragment.isNotEmpty) {
      final frag = base.fragment;
      final qIdx = frag.indexOf('?');
      if (qIdx != -1 && qIdx + 1 < frag.length) {
        final qp = Uri.splitQueryString(frag.substring(qIdx + 1));
        token = qp['token'];
      }
    }

    // path segment e.g. /address-confirm/<token>
    if (token == null) {
      final segs = base.pathSegments;
      final i = segs.indexOf('address-confirm');
      if (i != -1 && i + 1 < segs.length) token = segs[i + 1];
    }

    setState(() {
      _token = token;
      _ready = true;
    });

    if (token != null) {
      await _load(token);
    }
  }

  Future<void> _load(String token) async {
    try {
      final vSnap =
      await FirebaseFirestore.instance.collection('address_validations').doc(token).get();
      _validationSnap = vSnap;

      // 1) Find the work order
      String? orderId = vSnap.data()?['workOrderId'] as String?;
      if (orderId == null) {
        final q = await FirebaseFirestore.instance
            .collection('work_orders')
            .where('addressValidation.token', isEqualTo: token)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          orderId = q.docs.first.id;
        }
      }

      if (orderId != null) {
        _orderSnap =
        await FirebaseFirestore.instance.collection('work_orders').doc(orderId).get();
      }

      // 2) Try to resolve invoice by common fields
      Map<String, dynamic> order = _orderSnap?.data() ?? {};
      String? invoiceId = _pickString(order, [
        'invoiceId',
        'invoice_id',
        'invoiceRef',
        'invoice.ref',
      ]);
      String? invoiceNo = _pickString(order, [
        'invoiceNo',
        'invoice_no',
        'invoice.number',
        'invoiceNumber',
      ]);
      final workOrderNo = _pickString(order, ['workOrderNo', 'orderNo']);

      // Fetch invoice by ID first
      DocumentSnapshot<Map<String, dynamic>>? invoiceSnap;
      if (invoiceId != null && invoiceId.isNotEmpty) {
        final doc =
        await FirebaseFirestore.instance.collection('invoices').doc(invoiceId).get();
        if (doc.exists) invoiceSnap = doc;
      }

      // Else by invoice number
      if (invoiceSnap == null && invoiceNo != null && invoiceNo.isNotEmpty) {
        final q = await FirebaseFirestore.instance
            .collection('invoices')
            .where('invoiceNo', isEqualTo: invoiceNo)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) invoiceSnap = q.docs.first;
      }

      // Else by work order number linkage (if your schema stores it on invoices)
      if (invoiceSnap == null && workOrderNo != null && workOrderNo.isNotEmpty) {
        final q = await FirebaseFirestore.instance
            .collection('invoices')
            .where('workOrderNo', isEqualTo: workOrderNo)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) invoiceSnap = q.docs.first;
      }

      _invoiceSnap = invoiceSnap;

      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load: $e')));
    }
  }

  Future<void> _confirm() async {
    if (_token == null) return;
    final token = _token!;
    if (_working) return;

    try {
      setState(() => _working = true);
      final now = Timestamp.now();

      final batch = FirebaseFirestore.instance.batch();

      // 1) address_validations/{token}
      final vRef = FirebaseFirestore.instance.collection('address_validations').doc(token);
      batch.update(vRef, {
        'status': 'confirmed',
        'confirmedAt': now,
      });

      // 2) Mirror into work order (so internal list sees it instantly)
      String? workOrderId = _validationSnap?.data()?['workOrderId'] as String?;
      workOrderId ??= _orderSnap?.id;
      if (workOrderId != null) {
        final oRef = FirebaseFirestore.instance.collection('work_orders').doc(workOrderId);
        batch.update(oRef, {
          'addressValidation.status': 'confirmed',
          'addressValidation.confirmedAt': now,
          'lastUpdated': now,
        });
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you! Your address has been confirmed.')),
      );

      // Reload snapshots so UI reflects the confirmed state
      await _load(token);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not confirm: $e')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_token == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirm Address'), backgroundColor: _darkBlue),
        body: const Center(child: Text('Invalid confirmation link.')),
      );
    }

    final vExists = _validationSnap?.exists ?? false;
    final vData = _validationSnap?.data();
    final status = (vData?['status'] as String?) ?? 'pending';
    final confirmed = status == 'confirmed';

    // Prefer invoice data; fallback to order
    final invoice = _invoiceSnap?.data() ?? {};
    final order = _orderSnap?.data() ?? {};

    final workOrderNo =
        _pickString(order, ['workOrderNo', 'orderNo']) ?? _pickString(invoice, ['workOrderNo']) ?? '—';
    final invoiceNo =
        _pickString(invoice, ['invoiceNo', 'invoice_no', 'invoiceNumber']) ?? '—';

    final buyerName = _pickString(invoice, [
      'buyerName',
      'customerName',
      'partyName',
      'billing.name',
      'customer.name',
    ]) ??
        _pickString(order, [
          'buyerName',
          'customerName',
          'clientName',
          'name',
        ]) ??
        '—';

    final addr = _extractAddress(invoice).isNotEmpty
        ? _extractAddress(invoice)
        : _extractAddress(order);

    return Scaffold(
      backgroundColor: _panel,
      appBar: AppBar(title: const Text('Confirm Address'), backgroundColor: _darkBlue),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: vExists
                  ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.verified_user, color: _darkBlue, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Please confirm your shipping address',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _darkBlue,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Order summary
                  _InfoRow(label: 'Work Order No', value: workOrderNo),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Invoice No', value: invoiceNo),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Buyer', value: buyerName),
                  const SizedBox(height: 8),
                  if (addr.isNotEmpty) _AddressBox(title: 'Shipping Address', addressLines: addr),
                  if (addr.isNotEmpty) const SizedBox(height: 12),

                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: (confirmed ? Colors.green : Colors.orange).withOpacity(.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (confirmed ? Colors.green : Colors.orange).withOpacity(.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          confirmed ? Icons.verified : Icons.hourglass_bottom,
                          color: confirmed ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color:
                            confirmed ? Colors.green.shade700 : Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Action
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmed ? Colors.grey : Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: (confirmed || _working) ? null : _confirm,
                      child: _working
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Text(confirmed
                          ? 'Already Confirmed'
                          : 'It’s OK — Confirm Address'),
                    ),
                  ),

                  // Small helper note
                  const SizedBox(height: 8),
                  const Text(
                    'By confirming, you agree that the above shipping address is correct.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              )
                  : const Center(
                child: Text('This confirmation link is invalid or expired.'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Utility to read nested keys like "billing.name"
  String? _pickString(Map<String, dynamic> source, List<String> keys) {
    for (final k in keys) {
      final val = _readPath(source, k);
      if (val is String && val.trim().isNotEmpty) return val.trim();
    }
    return null;
  }

  Object? _readPath(Map<String, dynamic> map, String dotted) {
    if (!dotted.contains('.')) return map[dotted];
    Object? cur = map;
    for (final seg in dotted.split('.')) {
      if (cur is Map && cur.containsKey(seg)) {
        cur = cur[seg];
      } else {
        return null;
      }
    }
    return cur;
  }

  /// Collect human-friendly address lines from typical schemas.
  List<String> _extractAddress(Map<String, dynamic> obj) {
    // Try shipping first, else billing
    final Map<String, dynamic> shipping =
        (obj['shipping'] as Map?)?.cast<String, dynamic>() ??
            (obj['shippingAddress'] as Map?)?.cast<String, dynamic>() ??
            (obj['address'] as Map?)?.cast<String, dynamic>() ??
            {};
    final Map<String, dynamic> billing =
        (obj['billing'] as Map?)?.cast<String, dynamic>() ??
            (obj['billingAddress'] as Map?)?.cast<String, dynamic>() ??
            {};

    List<String> build(Map<String, dynamic> a) {
      final lines = <String>[];
      String? s(Object? v) => (v is String && v.trim().isNotEmpty) ? v.trim() : null;

      final line1 = s(a['addressLine1'] ?? a['line1'] ?? a['street'] ?? a['road']);
      final line2 = s(a['addressLine2'] ?? a['line2'] ?? a['area'] ?? a['block']);
      final city = s(a['city'] ?? a['town']);
      final state = s(a['state'] ?? a['province'] ?? a['region']);
      final zip = s(a['zip'] ?? a['postalCode'] ?? a['postcode']);
      final country = s(a['country'] ?? a['countryCode']);

      if (line1 != null) lines.add(line1);
      if (line2 != null) lines.add(line2);

      final cityStateZip = [
        if (city != null) city,
        if (state != null) state,
        if (zip != null) zip,
      ].join(', ');
      if (cityStateZip.trim().isNotEmpty) lines.add(cityStateZip);

      if (country != null) lines.add(country);
      return lines;
    }

    final ship = build(shipping);
    if (ship.isNotEmpty) return ship;

    final bill = build(billing);
    if (bill.isNotEmpty) return bill;

    // Flat string fallback
    final flat = _pickString(obj, ['shippingAddressString', 'addressString', 'fullAddress']);
    return flat != null ? [flat] : <String>[];
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: _darkBlue)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressBox extends StatelessWidget {
  const _AddressBox({required this.addressLines, this.title = 'Shipping Address'});

  final List<String> addressLines;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_outlined, color: _darkBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: _darkBlue)),
                const SizedBox(height: 6),
                for (final line in addressLines) Text(line, style: const TextStyle(height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
