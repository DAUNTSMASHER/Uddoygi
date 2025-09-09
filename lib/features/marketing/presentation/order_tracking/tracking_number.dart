// lib/features/factory/presentation/screens/tracking_number_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

const Color _darkBlue = Color(0xFF0D47A1);
const String _addressValidatedStage = 'Address validated';
const String _stageShippedFedex     = 'Shipped to FedEx agent';

class TrackingNumberPage extends StatefulWidget {
  const TrackingNumberPage({Key? key}) : super(key: key);

  @override
  State<TrackingNumberPage> createState() => _TrackingNumberPageState();
}

class _TrackingNumberPageState extends State<TrackingNumberPage> {
  String _search = '';
  bool _onlyMissing = true;

  Stream<QuerySnapshot<Map<String, dynamic>>> _validatedOrders() {
    return FirebaseFirestore.instance
        .collection('work_orders')
        .where('currentStage', isEqualTo: _addressValidatedStage)
        .orderBy('lastUpdated', descending: true)
        .snapshots();
  }

  Stream<({int total, int missing, int withTracking})> _stats() {
    return _validatedOrders().map((s) {
      final total = s.docs.length;
      final missing = s.docs.where((d) => (d.data()['trackingNo'] ?? '').toString().isEmpty).length;
      final withTracking = total - missing;
      return (total: total, missing: missing, withTracking: withTracking);
    });
  }

  Future<void> _saveTracking(
      QueryDocumentSnapshot<Map<String, dynamic>> d, {
        required String trackingNo,
      }) async {
    final now = Timestamp.now();
    final workOrderNo = (d.data()['workOrderNo'] ?? '').toString();
    final user = FirebaseAuth.instance.currentUser;
    final assignedTo = user?.email ?? user?.uid ?? '';

    final batch = FirebaseFirestore.instance.batch();

    final trackRef = FirebaseFirestore.instance.collection('work_order_tracking').doc();
    batch.set(trackRef, {
      'workOrderNo': workOrderNo,
      'stage': _stageShippedFedex,
      'notes': 'FedEx: $trackingNo',
      'assignedTo': assignedTo,
      'timeLimit': now,
      'createdAt': now,
      'lastUpdated': now,
      'trackingNo': trackingNo,
    });

    batch.update(d.reference, {
      'trackingNo': trackingNo,
      'currentStage': _stageShippedFedex,
      'lastUpdated': now,
    });

    await batch.commit();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('WO $workOrderNo moved to “$_stageShippedFedex”.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('MMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_darkBlue, Color(0xFF1D5DF1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        titleSpacing: 0,
        title: const Text('FedEx Tracking', style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Address validated • $today',
                  style: TextStyle(color: Colors.white.withOpacity(.9))),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Live stats
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: StreamBuilder<({int total, int missing, int withTracking})>(
              stream: _stats(),
              builder: (_, s) {
                final st = s.data ?? (total: 0, missing: 0, withTracking: 0);
                return Row(
                  children: [
                    Expanded(child: _StatChip(label: 'Validated', value: '${st.total}', color: Colors.teal)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatChip(label: 'Missing', value: '${st.missing}', color: Colors.orange)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatChip(label: 'With tracking', value: '${st.withTracking}', color: Colors.indigo)),
                  ],
                );
              },
            ),
          ),

          // Toolbar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search WO# / customer / tracking…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.isEmpty
                          ? null
                          : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _search = ''),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Missing only'),
                  selected: _onlyMissing,
                  onSelected: (v) => setState(() => _onlyMissing = v),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => await Future<void>.delayed(const Duration(milliseconds: 250)),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _validatedOrders(),
                builder: (ctx, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var docs = snap.data!.docs;

                  final s = _search.trim().toLowerCase();
                  if (s.isNotEmpty) {
                    docs = docs.where((d) {
                      final m = d.data();
                      final wo = (m['workOrderNo'] ?? '').toString().toLowerCase();
                      final cust = (m['customerName'] ?? '').toString().toLowerCase();
                      final trk = (m['trackingNo'] ?? '').toString().toLowerCase();
                      return wo.contains(s) || cust.contains(s) || trk.contains(s);
                    }).toList();
                  }

                  if (_onlyMissing) {
                    docs = docs.where((d) => (d.data()['trackingNo'] ?? '').toString().isEmpty).toList();
                  }

                  if (docs.isEmpty) {
                    return const Center(child: Text('Nothing to show.'));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _TrackingCard(
                      doc: docs[i],
                      onSave: _saveTracking,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* —————————————————— UI widgets —————————————————— */

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final MaterialColor color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12.withOpacity(.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withOpacity(.12), shape: BoxShape.circle),
            child: Icon(Icons.insights, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: _darkBlue)),
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({
    required this.doc,
    required this.onSave,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Future<void> Function(
      QueryDocumentSnapshot<Map<String, dynamic>>,
      {required String trackingNo}
      ) onSave;

  @override
  Widget build(BuildContext context) {
    final m = doc.data();
    final wo = (m['workOrderNo'] ?? '—').toString();
    final customer = (m['customerName'] ?? 'Customer').toString();
    final tracking = (m['trackingNo'] ?? '').toString();
    final updated = (m['lastUpdated'] as Timestamp?)?.toDate();
    final updatedStr = updated == null ? '—' : DateFormat('dd MMM, HH:mm').format(updated);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12.withOpacity(.06)),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // left accent
            Positioned.fill(
              left: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(width: 4, color: Colors.green),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // header row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'WO# $wo',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _darkBlue),
                        ),
                      ),
                      _badge('Address validated', Colors.green),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.black54),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          customer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(updatedStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // tracking row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black12.withOpacity(.08)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_shipping_outlined, color: _darkBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tracking.isEmpty ? 'No tracking number yet' : tracking,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: tracking.isEmpty ? Colors.black54 : _darkBlue,
                            ),
                          ),
                        ),
                        if (tracking.isNotEmpty) ...[
                          IconButton(
                            tooltip: 'Copy',
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: tracking));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Copied')),
                                );
                              }
                            },
                          ),
                        ],
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed: () => _promptTracking(context, initial: tracking),
                          icon: const Icon(Icons.edit),
                          label: Text(tracking.isEmpty ? 'Add' : 'Edit'),
                          style: TextButton.styleFrom(foregroundColor: _darkBlue),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Text(text, style: TextStyle(color: color.shade700, fontWeight: FontWeight.w800, fontSize: 11)),
    );
  }

  Future<void> _promptTracking(BuildContext context, {String initial = ''}) async {
    final ctl = TextEditingController(text: initial);
    final formKey = GlobalKey<FormState>();

    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${initial.isEmpty ? 'Add' : 'Edit'} FedEx Tracking', style: const TextStyle(color: _darkBlue)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. 1234 5678 9012',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _darkBlue),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, ctl.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (value == null) return;
    await onSave(doc, trackingNo: value);
  }
}
