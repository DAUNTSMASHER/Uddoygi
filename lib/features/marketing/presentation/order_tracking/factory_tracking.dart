// lib/features/marketing/presentation/order_tracking/factory_tracking.dart

import 'dart:collection';

import 'package:circle_flags/circle_flags.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

const Color _darkBlue = Color(0xFF0D47A1);
const Color _peach = Color(0xFFFF8A65);
const Color _surface = Color(0xFFF8F6F5);

/// Canonical stages (order matters, used for the path + comparisons)
const List<String> _stages = [
  'Invoice created',
  'Payment taken',
  'Submitted to factory',
  'Factory update 1 (base is done)',
  'Hair is ready',
  'Knotting is going on',
  'Putting',
  'Molding',
  'Submit to the Head office',
  'Address validation',
  'Shipped to FedEx',
  'Final tracking code',
];

String _normStage(String? s) {
  if (s == null) return '';
  final x = s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  // Common aliases
  if (x.startsWith('address validat')) return 'Address validation';
  if (x.startsWith('shipped to fedex')) return 'Shipped to FedEx';

  // Submit to (the) Head Office — allow “submit/submitted”, optional “the”
  if (RegExp(r'^(submit(ted)?)( to)?( the)? head office$').hasMatch(x)) {
    return 'Submit to the Head office';
  }

  // Exact canonical matches (case-insensitive)
  for (final st in _stages) {
    if (st.toLowerCase() == x) return st;
  }
  return s; // fallback: keep original
}

int _stageIndex(String? s) {
  final ns = _normStage(s);
  final i = _stages.indexOf(ns);
  return i < 0 ? 0 : i;
}

String _relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return DateFormat.yMMMd().add_jm().format(t);
}

String _deltaHuman(DateTime a, DateTime b) {
  final ms = a.millisecondsSinceEpoch - b.millisecondsSinceEpoch;
  final dur = Duration(milliseconds: ms < 0 ? 0 : ms);
  final d = dur.inDays;
  final h = dur.inHours % 24;
  final m = dur.inMinutes % 60;
  if (d > 0) return '${d}d ${h}h ${m}m';
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

String _truncateWords(String s, {int maxWords = 3}) {
  final parts = s.trim().split(RegExp(r'\s+'));
  if (parts.length <= maxWords) return s.trim();
  return parts.take(maxWords).join(' ');
}

String _safeUpper(String s) => s.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();

/// Country extraction bits (unchanged, kept from your version)
class _CountryInfo {
  final String name;
  final String iso2;
  const _CountryInfo(this.name, this.iso2);
}

_CountryInfo _extractCountry(Map<String, dynamic>? order, Map<String, dynamic>? invoice) {
  String _pick(List<String> keys, Map<String, dynamic>? m) {
    if (m == null) return '';
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = '$v'.trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  final codeCandidates = <String>[
    'countryCode',
    'shippingCountryCode',
    'customerCountryCode',
    'billing.countryCode',
    'shipping.countryCode',
    'address.countryCode',
    'shippingAddress.countryCode',
  ];

  final nameCandidates = <String>[
    'buyerCountry',
    'shippingCountry',
    'customerCountry',
    'country',
    'shipping.country',
    'billing.country',
    'address.country',
    'shippingAddress.country',
  ];

  String _findOne(List<String> keys, Map<String, dynamic>? m) {
    if (m == null) return '';
    for (final k in keys) {
      if (k.contains('.')) {
        final parts = k.split('.');
        dynamic cur = m;
        for (final p in parts) {
          if (cur is Map && cur[p] != null) {
            cur = cur[p];
          } else {
            cur = null;
            break;
          }
        }
        if (cur != null && '$cur'.trim().isNotEmpty) return '$cur'.trim();
      } else {
        final s = _pick([k], m);
        if (s.isNotEmpty) return s;
      }
    }
    return '';
  }

  final codeRaw = (_findOne(codeCandidates, invoice).isNotEmpty)
      ? _findOne(codeCandidates, invoice)
      : _findOne(codeCandidates, order);
  if (codeRaw.length == 2 && RegExp(r'^[A-Za-z]{2}$').hasMatch(codeRaw)) {
    final friendly = _findOne(nameCandidates, invoice).isNotEmpty
        ? _findOne(nameCandidates, invoice)
        : _findOne(nameCandidates, order);
    return _CountryInfo(friendly, codeRaw.toUpperCase());
  }

  final raw = (_findOne(nameCandidates, invoice).isNotEmpty)
      ? _findOne(nameCandidates, invoice)
      : _findOne(nameCandidates, order);

  if (raw.isEmpty) return const _CountryInfo('', 'UN');

  if (raw.length == 2 && RegExp(r'^[A-Za-z]{2}$').hasMatch(raw)) {
    return _CountryInfo(raw.toUpperCase(), raw.toUpperCase());
  }

  final name = raw.toLowerCase();
  final map = <String, String>{
    'bangladesh': 'BD',
    'india': 'IN',
    'pakistan': 'PK',
    'united states': 'US',
    'united states of america': 'US',
    'usa': 'US',
    'united kingdom': 'GB',
    'uk': 'GB',
    'england': 'GB',
    'canada': 'CA',
    'australia': 'AU',
    'germany': 'DE',
    'france': 'FR',
    'italy': 'IT',
    'spain': 'ES',
    'netherlands': 'NL',
    'japan': 'JP',
    'china': 'CN',
    'singapore': 'SG',
    'malaysia': 'MY',
    'saudi arabia': 'SA',
    'uae': 'AE',
    'united arab emirates': 'AE',
    'qatar': 'QA',
    'kuwait': 'KW',
    'brazil': 'BR',
    'argentina': 'AR',
    'chile': 'CL',
    'peru': 'PE',
    'mexico': 'MX',
    'ireland': 'IE',
    'switzerland': 'CH',
    'turkey': 'TR',
    'philippines': 'PH',
  };
  for (final entry in map.entries) {
    if (name.contains(entry.key)) {
      final friendly = raw;
      return _CountryInfo(friendly, entry.value);
    }
  }

  final up = _safeUpper(raw);
  final iso = up.isEmpty ? 'UN' : up.substring(0, up.length >= 2 ? 2 : 1).padRight(2, 'N');
  return _CountryInfo(raw, iso);
}

({String? name, String? code}) _countryHintsFromOrder(Map<String, dynamic> m) {
  String _read(String k) => (m[k] ?? '').toString().trim();
  String _readNested(List<String> path) {
    dynamic cur = m;
    for (final p in path) {
      if (cur is Map && cur[p] != null) {
        cur = cur[p];
      } else {
        return '';
      }
    }
    return '$cur'.trim();
  }

  for (final k in ['countryCode', 'shippingCountryCode', 'customerCountryCode']) {
    final v = _read(k);
    if (v.length == 2) return (name: null, code: v.toUpperCase());
  }
  for (final path in [
    ['billing', 'countryCode'],
    ['shipping', 'countryCode'],
    ['address', 'countryCode'],
    ['shippingAddress', 'countryCode'],
  ]) {
    final v = _readNested(path);
    if (v.length == 2) return (name: null, code: v.toUpperCase());
  }

  for (final k in ['buyerCountry', 'shippingCountry', 'customerCountry', 'country']) {
    final v = _read(k);
    if (v.isNotEmpty) return (name: v, code: null);
  }
  for (final path in [
    ['billing', 'country'],
    ['shipping', 'country'],
    ['address', 'country'],
    ['shippingAddress', 'country'],
  ]) {
    final v = _readNested(path);
    if (v.isNotEmpty) return (name: v, code: null);
  }
  return (name: null, code: null);
}

/// Board item model
class _BoardItem {
  _BoardItem({
    required this.workOrderNo,
    required this.trackingNo,
    required this.bbuyerName,
    required this.lastUpdated,
    required this.currentStage,
    required this.daysLeft,
    required this.itemsCount,
    this.invoiceId,
    this.orderCountryName,
    this.orderCountryCode,
  });

  final String workOrderNo;
  final String trackingNo;
  final String bbuyerName;
  final DateTime lastUpdated;
  final String currentStage;
  final int daysLeft;
  final int itemsCount;
  final String? invoiceId;
  final String? orderCountryName;
  final String? orderCountryCode;
}

/// —————————————————————————————————————————————————————
/// PAGE
/// —————————————————————————————————————————————————————
class FactoryTrackingPage extends StatelessWidget {
  const FactoryTrackingPage({Key? key}) : super(key: key);

  TextStyle get _font10 => GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: _darkBlue);
  TextStyle get _font9  => GoogleFonts.inter(fontSize: 9,  fontWeight: FontWeight.w700, color: _darkBlue);
  TextStyle get _font8  => GoogleFonts.inter(fontSize: 8,  fontWeight: FontWeight.w900, color: _darkBlue);
  TextStyle get _font6d => GoogleFonts.inter(fontSize: 6,  fontWeight: FontWeight.w700, color: Colors.grey.shade700);
  TextStyle get _font6l => GoogleFonts.inter(fontSize: 6,  fontWeight: FontWeight.w700, color: _darkBlue);

  /// Stream of ONLY my local tracking numbers (deduped by tracking_number)
  Stream<List<_BoardItem>> _myLocalTrackingBoard() {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    if (userEmail.isEmpty) return const Stream.empty();

    final q = FirebaseFirestore.instance
        .collection('work_orders')
        .where('agentEmail', isEqualTo: userEmail)
        .snapshots();

    return q.map((snap) {
      final docs = snap.docs.toList();

      final list = docs
          .map((d) => d.data())
          .where((m) => (m['tracking_number'] ?? '').toString().trim().isNotEmpty)
          .toList();

      DateTime _toDate(dynamic x) {
        if (x is Timestamp) return x.toDate();
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
      list.sort((a, b) => _toDate(b['timestamp']).compareTo(_toDate(a['timestamp'])));

      final byTrk = LinkedHashMap<String, Map<String, dynamic>>();
      for (final m in list) {
        final trk = (m['tracking_number'] ?? '').toString();
        if (!byTrk.containsKey(trk)) byTrk[trk] = m;
      }
      final finalList = byTrk.values.toList();

      int _sumItems(dynamic items) {
        if (items is List) {
          return items.fold<int>(0, (s, it) => s + ((it is Map && it['qty'] is int) ? it['qty'] as int : 0));
        }
        return 0;
      }

      int _daysLeft(dynamic finalTs) {
        final d = (finalTs is Timestamp) ? finalTs.toDate() : null;
        if (d == null) return 0;
        return d.difference(DateTime.now()).inDays;
      }

      return finalList.map((m) {
        final woNo = (m['workOrderNo'] ?? '').toString();
        final trk = (m['tracking_number'] ?? '').toString();
        final buyer = (m['buyerName'] ?? m['makerName'] ?? 'Buyer').toString();
        final last = (m['lastUpdated'] as Timestamp?)?.toDate()
            ?? (m['timestamp'] as Timestamp?)?.toDate()
            ?? DateTime.now();
        final stage = _normStage((m['currentStage'] ?? 'Submitted to factory').toString());
        final daysLeft = _daysLeft(m['finalDate']);
        final cnt = _sumItems(m['items']);
        final invoiceId = (m['invoiceId'] as String?);

        final hints = _countryHintsFromOrder(m);

        return _BoardItem(
          workOrderNo: woNo,
          trackingNo: trk,
          bbuyerName: buyer,
          lastUpdated: last,
          currentStage: stage,
          daysLeft: daysLeft,
          itemsCount: cnt,
          invoiceId: invoiceId,
          orderCountryName: hints.name,
          orderCountryCode: hints.code,
        );
      }).toList();
    });
  }

  /// All updates for a WO — ascending by createdAt (for timeline)
  Stream<List<Map<String, dynamic>>> _updatesForAsc(String woNo) {
    return FirebaseFirestore.instance
        .collection('work_order_tracking')
        .where('workOrderNo', isEqualTo: woNo)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map((e) => e.data()).toList());
  }

  Future<Map<String, dynamic>?> _invoiceMeta(String? invoiceId) async {
    if (invoiceId == null || invoiceId.isEmpty) return null;
    final d = await FirebaseFirestore.instance.collection('invoices').doc(invoiceId).get();
    return d.data();
  }

  Future<Map<String, dynamic>?> _orderMeta(String woNo) async {
    final q = await FirebaseFirestore.instance
        .collection('work_orders')
        .where('workOrderNo', isEqualTo: woNo)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return q.docs.first.data();
  }

  String _remainingLabel(int daysLeft) {
    if (daysLeft > 0) return '$daysLeft day${daysLeft == 1 ? '' : 's'} left';
    if (daysLeft == 0) return 'Due today';
    return 'Overdue ${-daysLeft}d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: Text('My Tracking Board', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: _darkBlue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<_BoardItem>>(
        stream: _myLocalTrackingBoard(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final boards = snap.data ?? const <_BoardItem>[];
          if (boards.isEmpty) {
            return Center(
              child: _card(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_shipping_outlined, color: _darkBlue),
                    const SizedBox(width: 10),
                    Text('No tracking numbers yet',
                        style: GoogleFonts.inter(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: boards.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final b = boards[i];

              final orderHint = <String, dynamic>{
                if ((b.orderCountryName ?? '').isNotEmpty) 'country': b.orderCountryName,
                if ((b.orderCountryCode ?? '').isNotEmpty) 'countryCode': b.orderCountryCode,
                if ((b.orderCountryName ?? '').isNotEmpty) 'buyerCountry': b.orderCountryName,
              };

              return FutureBuilder<Map<String, dynamic>?>(
                future: _invoiceMeta(b.invoiceId),
                builder: (c, invSnap) {
                  final invoice = invSnap.data;
                  final buyer = (invoice?['customerName'] ?? b.bbuyerName).toString();
                  final country = _extractCountry(orderHint, invoice);

                  return _TrackingBoardCard(
                    item: b,
                    buyerName: buyer,
                    country: country,
                    font10: _font10,
                    font9: _font9,
                    font8: _font8,
                    font6d: _font6d,
                    font6l: _font6l,
                    remainingLabel: _remainingLabel(b.daysLeft),
                    onTap: () async {
                      final orderMeta = await _orderMeta(b.workOrderNo);
                      if (ctx.mounted) {
                        showModalBottomSheet(
                          context: ctx,
                          isScrollControlled: true,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                          ),
                          builder: (c) => _TrackingDetailsSheet(
                            item: b,
                            orderMeta: orderMeta,
                            updatesStream: _updatesForAsc(b.workOrderNo),
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ).animate().fadeIn(duration: 300.ms, curve: Curves.easeOut);
        },
      ),
    );
  }
}

/// —————————————————————————————————————————————————————
/// SMALL BOARD CARD
/// —————————————————————————————————————————————————————
class _TrackingBoardCard extends StatelessWidget {
  const _TrackingBoardCard({
    required this.item,
    required this.buyerName,
    required this.country,
    required this.remainingLabel,
    required this.onTap,
    required this.font10,
    required this.font9,
    required this.font8,
    required this.font6d,
    required this.font6l,
  });

  final _BoardItem item;
  final String buyerName;
  final _CountryInfo country;
  final String remainingLabel;
  final VoidCallback onTap;

  final TextStyle font10;
  final TextStyle font9;
  final TextStyle font8;
  final TextStyle font6d;
  final TextStyle font6l;

  @override
  Widget build(BuildContext context) {
    final days = item.daysLeft;
    final overdue = days < 0;

    return _card(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Flag • Buyer • Country
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white,
                  child: ClipOval(
                    child: (country.iso2.length == 2)
                        ? CircleFlag(country.iso2.toUpperCase(), size: 24)
                        : Icon(Icons.public, color: _darkBlue, size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          buyerName.isEmpty ? 'Buyer' : buyerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: font10,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _truncateWords(country.name.isEmpty ? '' : country.name, maxWords: 3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: font6d,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Tracking number line
            Row(
              children: [
                Text('Tracking number: ', style: font6l),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.trackingNo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: font8,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(text: item.trackingNo));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tracking copied')),
                            );
                          }
                        },
                        child: const Icon(Icons.copy_rounded, size: 14, color: _darkBlue),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Items + Remaining
            Row(
              children: [
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: item.itemsCount),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOut,
                  builder: (_, value, __) => Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 14, color: _darkBlue),
                      const SizedBox(width: 4),
                      Text('Items: $value', style: font6l),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  builder: (_, t, __) => Opacity(
                    opacity: t,
                    child: Row(
                      children: [
                        Icon(
                          overdue ? Icons.warning_amber_rounded : Icons.schedule,
                          size: 14,
                          color: overdue ? Colors.redAccent : _darkBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          remainingLabel,
                          style: font6l.copyWith(
                            color: overdue ? Colors.redAccent : _darkBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Text(_relativeTime(item.lastUpdated), style: font6d),
              ],
            ),

            const SizedBox(height: 8),

            // Current status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _darkBlue.withOpacity(.06),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _darkBlue.withOpacity(.2)),
                  ),
                  child: Text(
                    _normStage(item.currentStage),
                    style: font9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 220.ms, curve: Curves.easeOut);
  }
}

/// —————————————————————————————————————————————————————
/// DETAILS SHEET — includes "Move to Address validation" button
/// —————————————————————————————————————————————————————
class _TrackingDetailsSheet extends StatelessWidget {
  const _TrackingDetailsSheet({
    required this.item,
    required this.orderMeta,
    required this.updatesStream,
  });

  final _BoardItem item;
  final Map<String, dynamic>? orderMeta;
  final Stream<List<Map<String, dynamic>>> updatesStream;

  /// Treat statuses that *start with* "Done" (case-insensitive) as Done.
  bool _isDoneStatus(dynamic v) {
    final s = (v ?? '').toString().trim().toLowerCase();
    return s == 'done' || s.startsWith('done');
  }

  Future<void> _markAddressValidation(BuildContext context) async {
    final db = FirebaseFirestore.instance;
    final now = FieldValue.serverTimestamp();

    // Find the work_orders doc by id or by workOrderNo
    Future<DocumentReference<Map<String, dynamic>>> _resolveWorkOrderRef() async {
      final direct = db.collection('work_orders').doc(item.workOrderNo);
      final directSnap = await direct.get();
      if (directSnap.exists) return direct;

      final q = await db
          .collection('work_orders')
          .where('workOrderNo', isEqualTo: item.workOrderNo)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) return q.docs.first.reference;

      // Fallback to direct (will fail if missing, but keeps transaction shape)
      return direct;
    }

    final woRef = await _resolveWorkOrderRef();
    final trkCol = db.collection('work_order_tracking');
    final updRef = trkCol.doc();

    await db.runTransaction((tx) async {
      tx.update(woRef, {
        'currentStage': 'Address validation',
        'status': 'Address validation',
        'lastUpdated': now,
      });
      tx.set(updRef, {
        'id': updRef.id,
        'workOrderNo': item.workOrderNo,
        'tracking_number': item.trackingNo,
        'stage': 'Address validation',
        'status': 'Done',
        'createdAt': now,
        'lastUpdated': now,
        'by': FirebaseAuth.instance.currentUser?.email,
      });
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Moved to Address validation')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = (orderMeta?['customerName'] ?? orderMeta?['buyerName'] ?? 'Customer').toString();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => SingleChildScrollView(
        controller: controller,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Heading
              Row(
                children: [
                  const Icon(Icons.qr_code_2, color: _darkBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'WO# ${item.workOrderNo} • $customer',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _darkBlue, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tracking line
              _card(
                child: Row(
                  children: [
                    Text('Tracking:', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _darkBlue)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        item.trackingNo,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _darkBlue),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy_rounded, color: _darkBlue),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: item.trackingNo));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              // ---- Quick action: show ONLY when previous step is Done ----
              // ---- Quick action: Address validation — show whenever we're at "Submit to the Head office"
              (_normStage(item.currentStage) == 'Submit to the Head office')
                  ? Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.verified_user),
                    label: const Text('Move to Address validation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _darkBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _markAddressValidation(context),
                  ),
                ),
              )
                  : const SizedBox.shrink(),


              const SizedBox(height: 16),

              // Detailed Timeline — Δ from previous stage
              Text('Detailed Timeline', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _darkBlue)),
              const SizedBox(height: 8),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: updatesStream,
                builder: (ctx, s) {
                  if (!s.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final ups = List<Map<String, dynamic>>.from(s.data!);
                  if (ups.isEmpty) {
                    return Text('No updates yet.', style: GoogleFonts.inter(color: Colors.grey.shade600));
                  }

                  // Already ascending by query; compute deltas
                  return _card(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Column(
                      children: List.generate(ups.length, (i) {
                        final u = ups[i];
                        final stage = _normStage((u['stage'] ?? '').toString());
                        final status = (u['status'] ?? '').toString().toUpperCase();
                        final when = (u['lastUpdated'] as Timestamp?)?.toDate() ??
                            (u['createdAt'] as Timestamp?)?.toDate() ??
                            DateTime.now();
                        final whenStr = DateFormat('dd MMM, HH:mm').format(when);

                        String delta = '—';
                        if (i > 0) {
                          final prevWhen =
                              (ups[i - 1]['lastUpdated'] as Timestamp?)?.toDate() ??
                                  (ups[i - 1]['createdAt'] as Timestamp?)?.toDate() ??
                                  when;
                          delta = _deltaHuman(when, prevWhen);
                        }

                        final sub = <String>[
                          if (status.isNotEmpty) status,
                          whenStr,
                          if (i > 0) 'Δ from “${_normStage((ups[i - 1]['stage'] ?? '').toString())}”: $delta',
                        ].join(' • ');

                        final isFirst = i == 0;
                        final isLast = i == ups.length - 1;
                        final highlighted = isLast;

                        return _timelineRow(
                          title: stage,
                          subtitle: sub,
                          isFirst: isFirst,
                          isLast: isLast,
                          highlighted: highlighted,
                        ).animate().fadeIn(duration: 200.ms).moveY(begin: 8, end: 0, curve: Curves.easeOut);
                      }),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // Path overview (done/current/upcoming)
              Text('Path (stages)', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _darkBlue)),
              const SizedBox(height: 8),
              _detailPath(currentStage: item.currentStage),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  // Timeline row
  Widget _timelineRow({
    required String title,
    required String subtitle,
    required bool isFirst,
    required bool isLast,
    bool highlighted = false,
  }) {
    final Color bullet = highlighted ? _peach : _darkBlue;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 26,
          child: Column(
            children: [
              if (!isFirst) Container(width: 2, height: 10, color: Colors.grey.shade300),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: bullet, width: 2),
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast) Container(width: 2, height: 26, color: Colors.grey.shade300),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: Colors.grey.shade900, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailPath({required String currentStage}) {
    final curr = _stageIndex(currentStage);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_stages.length, (i) {
          final s = _stages[i];
          final bool done = i < curr;
          final bool currFlag = i == curr;
          final Color dot = currFlag ? _peach : (done ? Colors.green.shade600 : Colors.grey.shade400);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Column(
                  children: [
                    if (i != 0) Container(width: 2, height: 8, color: Colors.grey.shade300),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: currFlag ? Colors.white : (done ? Colors.green.shade600 : Colors.white),
                        border: Border.all(color: dot, width: 2),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i != _stages.length - 1) Container(width: 2, height: 20, color: Colors.grey.shade300),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: Colors.grey.shade900,
                            fontWeight: currFlag ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (done || currFlag)
                        Icon(
                          done ? Icons.check_circle : Icons.radio_button_checked,
                          size: 16,
                          color: done ? Colors.green.shade600 : _peach,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Shared card container
Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))],
      border: Border.all(color: Colors.black12.withOpacity(.06)),
    ),
    padding: padding ?? const EdgeInsets.all(14),
    child: child,
  );
}
