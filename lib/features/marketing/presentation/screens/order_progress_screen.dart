// lib/features/marketing/presentation/screens/order_progress_screen.dart
// Agent-scoped, realtime order progress with summary board, filters, and rich details.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/local_storage_service.dart';

class OrderProgressScreen extends StatefulWidget {
  const OrderProgressScreen({super.key});

  @override
  State<OrderProgressScreen> createState() => _OrderProgressScreenState();
}

class _OrderProgressScreenState extends State<OrderProgressScreen> {
  Map<String, dynamic>? _session;
  String _search = '';
  String _statusFilter = 'all';
  bool _sortDesc = true;

  // Palette (aligned with your dashboards)
  static const Color _brandTeal  = Color(0xFF001863);
  static const Color _indigoCard = Color(0xFF0B2D9F);
  static const Color _surface    = Color(0xFFF4FBFB);
  static const Color _boardDark  = Color(0xFF0330AE);

  final List<String> _statusOptions = const [
    'all', 'pending', 'processing', 'factory', 'qc', 'packed', 'shipped', 'delivered', 'cancelled'
  ];

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final s = await LocalStorageService.getSession();
    if (!mounted) return;
    setState(() => _session = s);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _ordersStream() {
    if (_session == null || _session!['email'] == null) {
      // empty stream until session arrives
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('invoices')
        .where('agentEmail', isEqualTo: _session!['email'])
        .orderBy('timestamp', descending: true);

    if (_statusFilter != 'all') {
      q = q.where('status', isEqualTo: _statusFilter);
    }
    return q.snapshots();
  }

  String _fmtDate(dynamic ts) {
    if (ts is Timestamp) return DateFormat('yyyy-MM-dd').format(ts.toDate());
    if (ts is DateTime)  return DateFormat('yyyy-MM-dd').format(ts);
    return '—';
  }

  DateTime _toDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _bdt(num? n) {
    if (n == null) return '৳0';
    final s = n.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0];
    final frac = parts[1];
    final b = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      final r = intPart.length - i;
      b.write(intPart[i]);
      if (r > 1 && r % 3 == 1) b.write(',');
    }
    return '৳${b.toString()}.$frac';
  }

  int _pieces(Map<String, dynamic> data) {
    final items = (data['items'] as List?) ?? const [];
    int sum = 0;
    for (final it in items) {
      final q = (it is Map && it['qty'] is num) ? (it['qty'] as num).toInt() : 0;
      sum += q;
    }
    return sum;
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'delivered': return Colors.green;
      case 'shipped':   return Colors.blue;
      case 'packed':    return Colors.teal;
      case 'qc':        return Colors.deepPurple;
      case 'factory':   return Colors.indigo;
      case 'processing':return Colors.orange;
      case 'pending':   return Colors.amber;
      case 'cancelled': return Colors.red;
      default:          return Colors.grey;
    }
  }

  Widget _statusChip(String status) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.withOpacity(.35)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 11),
      ),
    );
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return true;
    bool has(Object? v) => v != null && v.toString().toLowerCase().contains(q);
    return has(data['customerName']) ||
        has(data['country']) ||
        has(data['note']) ||
        has(data['status']) ||
        has(data['invoiceNo']) ||
        has(data['docId']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('My Order Progress', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: _brandTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _sortDesc ? 'Newest first' : 'Oldest first',
            icon: const Icon(Icons.sort),
            onPressed: () => setState(() => _sortDesc = !_sortDesc),
          ),
          PopupMenuButton<String>(
            tooltip: 'Filter status',
            icon: const Icon(Icons.filter_alt),
            onSelected: (v) => setState(() => _statusFilter = v),
            itemBuilder: (context) => _statusOptions
                .map((e) => PopupMenuItem(value: e, child: Text(e.toUpperCase())))
                .toList(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search by customer, country, note, status…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _session == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _ordersStream(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // From stream
          final docs = snap.data!.docs;

          // Summary counts by status (before search)
          final counts = <String, int>{
            'pending': 0, 'processing': 0, 'factory': 0, 'qc': 0, 'packed': 0,
            'shipped': 0, 'delivered': 0, 'cancelled': 0
          };
          for (final d in docs) {
            final st = (d.data()['status'] ?? 'pending').toString().toLowerCase();
            if (counts.containsKey(st)) counts[st] = counts[st]! + 1;
          }

          // Apply search + sort
          final filtered = docs.where((d) {
            final m = d.data();
            m['docId'] = d.id;
            return _matchesSearch(m);
          }).toList()
            ..sort((a, b) {
              final A = _toDate(a.data()['timestamp']);
              final B = _toDate(b.data()['timestamp']);
              return _sortDesc ? B.compareTo(A) : A.compareTo(B);
            });

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: filtered.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                // Overview board on top
                return Column(
                  children: [
                    _overviewBoard(total: docs.length, counts: counts),
                    const SizedBox(height: 14),
                    _quickChips(), // quick status chips row
                    const SizedBox(height: 12),
                  ],
                );
              }

              final doc  = filtered[i - 1];
              final data = doc.data();
              final date = _toDate(data['timestamp']);
              final status = (data['status'] ?? 'pending').toString();
              final name = (data['customerName'] ?? 'Unknown').toString();
              final country = (data['country'] ?? '').toString();
              final grand = (data['grandTotal'] is num) ? (data['grandTotal'] as num) : null;
              final pcs = _pieces(data);
              final invoiceNo = (data['invoiceNo'] ?? doc.id).toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black12),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailsScreen(orderId: doc.id, data: data),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Gradient header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                          gradient: LinearGradient(
                            colors: [_indigoCard, Color(0xFF1D5DF1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ),
                            _statusChip(status),
                          ],
                        ),
                      ),

                      // Body
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _metaChip(Icons.tag, 'Invoice: $invoiceNo'),
                                if (country.isNotEmpty) _metaChip(Icons.public, country),
                                _metaChip(Icons.inventory, 'Pieces: $pcs'),
                                _metaChip(Icons.payments, _bdt(grand)),
                                _metaChip(Icons.schedule, _fmtDate(date)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _overviewBoard({required int total, required Map<String, int> counts}) {
    // Dark board with 2xN stats
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(color: _boardDark, borderRadius: BorderRadius.circular(20)),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final cardW = (w - 12) / 2;
        Widget tile(String label, String value, IconData icon) => SizedBox(
          width: cardW,
          child: _squareStat(label, value, icon),
        );

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            tile('Total Orders', '$total', Icons.list_alt),
            tile('Pending', '${counts['pending']}', Icons.timelapse),
            tile('Processing', '${counts['processing']}', Icons.settings_suggest),
            tile('Factory', '${counts['factory']}', Icons.factory),
            tile('QC', '${counts['qc']}', Icons.fact_check),
            tile('Packed', '${counts['packed']}', Icons.inventory_2),
            tile('Shipped', '${counts['shipped']}', Icons.local_shipping),
            tile('Delivered', '${counts['delivered']}', Icons.verified),
            tile('Cancelled', '${counts['cancelled']}', Icons.cancel),
          ],
        );
      }),
    );
  }

  Widget _squareStat(String label, String value, IconData icon) {
    return Container(
      height: 100,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: Colors.black.withOpacity(.85), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _statusOptions.map((s) {
        final sel = _statusFilter == s;
        return InkWell(
          onTap: () => setState(() => _statusFilter = s),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? Colors.black.withOpacity(.15) : Colors.black.withOpacity(.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              s.toUpperCase(),
              style: TextStyle(
                color: sel ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black87),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/* ======================= Details Screen ======================= */

class OrderDetailsScreen extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;

  const OrderDetailsScreen({super.key, required this.orderId, required this.data});

  String _fmtDate(dynamic ts) {
    if (ts is Timestamp) return DateFormat('yyyy-MM-dd').format(ts.toDate());
    if (ts is DateTime)  return DateFormat('yyyy-MM-dd').format(ts);
    return '—';
  }

  DateTime _toDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _bdt(num? n) {
    if (n == null) return '৳0';
    final s = n.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0];
    final frac = parts[1];
    final b = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      final r = intPart.length - i;
      b.write(intPart[i]);
      if (r > 1 && r % 3 == 1) b.write(',');
    }
    return '৳${b.toString()}.$frac';
  }

  int _pieces() {
    final items = (data['items'] as List?) ?? const [];
    int sum = 0;
    for (final it in items) {
      final q = (it is Map && it['qty'] is num) ? (it['qty'] as num).toInt() : 0;
      sum += q;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final items = (data['items'] as List?) ?? const [];
    final date  = data['timestamp'];
    final status= (data['status'] ?? 'Unknown').toString();
    final country = (data['country'] ?? 'Not specified').toString();
    final note    = (data['note'] ?? '').toString();
    final grand   = (data['grandTotal'] is num) ? (data['grandTotal'] as num) : null;
    final ship    = (data['shippingCost'] is num) ? (data['shippingCost'] as num) : null;
    final tax     = (data['tax'] is num) ? (data['tax'] as num) : null;
    final invoiceNo = (data['invoiceNo'] ?? orderId).toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF4FBFB),
      appBar: AppBar(
        title: const Text('Order Details', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFF001863),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Top panel
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF0B2D9F), Color(0xFF1D5DF1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('Invoice', invoiceNo, white: true, bold: true),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _chip(Icons.schedule, _fmtDate(date), white: true),
                    _chip(Icons.public, country, white: true),
                    _chip(Icons.inventory, 'Pieces: ${_pieces()}', white: true),
                    _chip(Icons.payments, _bdt(grand), white: true),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          _kv('Customer', (data['customerName'] ?? 'N/A').toString()),
          _kv('Status', status, color: _statusColor(status), bold: true),
          if (note.isNotEmpty) _kv('Note', note),

          const SizedBox(height: 16),
          const Text('Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF001863))),
          const SizedBox(height: 8),

          // Items list
          ...items.map((it) {
            final m = (it is Map) ? it : <String, dynamic>{};
            final model = (m['model'] ?? '').toString();
            final color = (m['color'] ?? '').toString();
            final size  = (m['size']  ?? '').toString();
            final qty   = (m['qty'] is num) ? (m['qty'] as num).toInt() : 0;
            final total = (m['total'] is num) ? (m['total'] as num) : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black12),
              ),
              child: ListTile(
                title: Text(
                  model.isEmpty ? 'Item' : model,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('Color: ${color.isEmpty ? '-' : color}  •  Size: ${size.isEmpty ? '-' : size}  •  Qty: $qty'),
                trailing: Text(_bdt(total), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            );
          }),

          const Divider(height: 28, color: Color(0xFF001863)),

          // Totals
          _kv('Shipping Cost', _bdt(ship)),
          _kv('Tax', _bdt(tax)),
          _kv('Grand Total', _bdt(grand), bold: true, color: Colors.green.shade700),

          const SizedBox(height: 18),

          // Optional tracking history
          _trackingHistory(data),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false, Color? color, bool white = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$k: ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: white ? Colors.white : Colors.black87,
              )),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: white ? Colors.white : (color ?? Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text, {bool white = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: white ? Colors.white.withOpacity(.18) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: white ? Colors.white30 : Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: white ? Colors.white : Colors.black87),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: white ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trackingHistory(Map<String, dynamic> data) {
    final history = (data['trackingHistory'] as List?) ?? const [];
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: const Text(
          'No tracking updates yet. You will see factory/QC/packing/shipping events here if available.',
          style: TextStyle(fontSize: 12),
        ),
      );
    }

    // Sort by time desc (supports Timestamp/DateTime/string)
    final sorted = [...history]..sort((a, b) {
      DateTime A = DateTime.fromMillisecondsSinceEpoch(0);
      DateTime B = DateTime.fromMillisecondsSinceEpoch(0);
      if (a is Map) A = _toDate(a['at']);
      if (b is Map) B = _toDate(b['at']);
      return B.compareTo(A);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tracking History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF001863))),
        const SizedBox(height: 8),
        ...sorted.map((e) {
          final m = (e is Map) ? e : <String, dynamic>{};
          final st = (m['status'] ?? '').toString();
          final note = (m['note'] ?? '').toString();
          final at = _fmtDate(m['at']);
          final icon = _trackingIcon(st);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _statusColor(st).withOpacity(.12),
                child: Icon(icon, color: _statusColor(st)),
              ),
              title: Text(st.isEmpty ? 'Update' : st.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(note.isEmpty ? at : '$note\n$at'),
              isThreeLine: note.isNotEmpty,
            ),
          );
        }),
      ],
    );
  }

  IconData _trackingIcon(String s) {
    switch (s.toLowerCase()) {
      case 'factory':    return Icons.factory;
      case 'qc':         return Icons.fact_check;
      case 'packed':     return Icons.inventory_2;
      case 'shipped':    return Icons.local_shipping;
      case 'delivered':  return Icons.verified;
      case 'processing': return Icons.settings_suggest;
      case 'pending':    return Icons.timelapse;
      case 'cancelled':  return Icons.cancel;
      default:           return Icons.timeline;
    }
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'delivered': return Colors.green;
      case 'shipped':   return Colors.blue;
      case 'packed':    return Colors.teal;
      case 'qc':        return Colors.deepPurple;
      case 'factory':   return Colors.indigo;
      case 'processing':return Colors.orange;
      case 'pending':   return Colors.amber;
      case 'cancelled': return Colors.red;
      default:          return Colors.grey;
    }
  }
}
