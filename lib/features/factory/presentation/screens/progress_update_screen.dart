// lib/features/factory/presentation/screens/progress_update_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class ProgressUpdateScreen extends StatefulWidget {
  const ProgressUpdateScreen({Key? key}) : super(key: key);

  @override
  State<ProgressUpdateScreen> createState() => _ProgressUpdateScreenState();
}

class _ProgressUpdateScreenState extends State<ProgressUpdateScreen> {
  String? _selectedOrderNo;
  String? _selectedOrderDocId;
  Future<DocumentSnapshot<Map<String, dynamic>>>? _orderDocFuture;

  // Form controllers & state
  final _notesCtl = TextEditingController();
  final _assignedCtl = TextEditingController();
  DateTime _timeLimit = DateTime.now().add(const Duration(days: 1));
  String? _selectedNextStage;

  static const List<String> _stages = [
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

  Stream<QuerySnapshot<Map<String, dynamic>>> get _acceptedOrdersStream =>
      FirebaseFirestore.instance
          .collection('work_orders')
          .where('status', isEqualTo: 'Accepted')
          .orderBy('lastUpdated', descending: true)
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _trackingStream {
    if (_selectedOrderNo == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('work_order_tracking')
        .where('workOrderNo', isEqualTo: _selectedOrderNo)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _addUpdate() async {
    if (_selectedNextStage == null ||
        _selectedOrderNo == null ||
        _selectedOrderDocId == null) return;

    final now = Timestamp.now();
    final batch = FirebaseFirestore.instance.batch();

    // 1) Add to tracking history
    final trackingRef = FirebaseFirestore.instance
        .collection('work_order_tracking')
        .doc();
    batch.set(trackingRef, {
      'workOrderNo': _selectedOrderNo,
      'stage': _selectedNextStage,
      'notes': _notesCtl.text.trim(),
      'assignedTo': _assignedCtl.text.trim(),
      'timeLimit': Timestamp.fromDate(_timeLimit),
      'createdAt': now,
      'lastUpdated': now,
    });

    // 2) Update the work_orders doc with currentStage & lastUpdated
    final orderRef = FirebaseFirestore.instance
        .collection('work_orders')
        .doc(_selectedOrderDocId);
    batch.update(orderRef, {
      'currentStage': _selectedNextStage,
      'lastUpdated': now,
    });

    await batch.commit();

    // Reset form & reload order
    setState(() {
      _selectedNextStage = null;
      _notesCtl.clear();
      _assignedCtl.clear();
      _timeLimit = DateTime.now().add(const Duration(days: 1));
      _orderDocFuture = FirebaseFirestore.instance
          .collection('work_orders')
          .doc(_selectedOrderDocId!)
          .get();
    });
  }

  Future<void> _pickTimeLimit() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _timeLimit,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _timeLimit = picked);
  }

  @override
  void dispose() {
    _notesCtl.dispose();
    _assignedCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedOrderNo == null
              ? 'Select Work‑Order'
              : 'Updates: $_selectedOrderNo',
        ),
        backgroundColor: _darkBlue,
        leading: _selectedOrderNo != null
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _selectedOrderNo = null;
            _selectedOrderDocId = null;
            _orderDocFuture = null;
          }),
        )
            : null,
      ),
      body: _selectedOrderNo == null
      // 1) List of accepted work‑orders
          ? StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _acceptedOrdersStream,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No accepted work‑orders.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final no = doc.data()['workOrderNo'] as String? ?? '—';
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text('Order $no',
                      style: const TextStyle(
                          fontSize: 14, color: _darkBlue)),
                  subtitle: Text(no,
                      style: const TextStyle(
                          fontSize: 10, color: Colors.black54)),
                  onTap: () => setState(() {
                    _selectedOrderNo = no;
                    _selectedOrderDocId = doc.id;
                    _orderDocFuture = FirebaseFirestore.instance
                        .collection('work_orders')
                        .doc(doc.id)
                        .get();
                  }),
                ),
              );
            },
          );
        },
      )

      // 2) Form + history for selected order
          : FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _orderDocFuture,
        builder: (ctx, orderSnap) {
          if (orderSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Determine current & next stages
          final orderData = orderSnap.data?.data() ?? {};
          final currentStage = orderData['currentStage']
          as String? ??
              'Submitted to factory'; // default initial
          // Next state options: stages #5–#9 (indices 4–8)
          final nextStages = _stages.sublist(4, 9);

          return Column(
            children: [
              // — New Update Form —
              Padding(
                padding: const EdgeInsets.all(12),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current State (read‑only)
                        TextFormField(
                          initialValue: currentStage,
                          decoration: const InputDecoration(
                            labelText: 'Current State',
                            border: OutlineInputBorder(),
                          ),
                          readOnly: true,
                        ),
                        const SizedBox(height: 12),

                        // Next State (select from #5–#9)
                        DropdownButtonFormField<String>(
                          value: _selectedNextStage,
                          decoration: const InputDecoration(
                            labelText: 'Next State',
                            border: OutlineInputBorder(),
                          ),
                          items: nextStages
                              .map((s) => DropdownMenuItem(
                              value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedNextStage = v),
                        ),
                        const SizedBox(height: 12),

                        // Assign To
                        TextField(
                          controller: _assignedCtl,
                          decoration: const InputDecoration(
                            labelText: 'Assign To (email/ID)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Notes
                        TextField(
                          controller: _notesCtl,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),

                        // Deadline picker
                        Row(
                          children: [
                            Text(
                              'Deadline: ${DateFormat.yMMMd().format(_timeLimit)}',
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _pickTimeLimit,
                              child: const Text('Change'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Save button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: _darkBlue),
                            onPressed: _selectedNextStage == null
                                ? null
                                : _addUpdate,
                            child: const Text('Save Update'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // — Update History —
              Expanded(
                child: StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: _trackingStream,
                  builder: (ctx, histSnap) {
                    if (histSnap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    final docs = histSnap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                          child: Text('No updates yet.'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: docs.length,
                      itemBuilder: (ctx, i) {
                        final d = docs[i].data();
                        final stage = d['stage'] as String;
                        final notes = d['notes'] as String? ?? '';
                        final assigned =
                            d['assignedTo'] as String? ?? '';
                        final tlTs = d['timeLimit'] as Timestamp?;
                        final tl = tlTs != null
                            ? DateFormat.yMMMd()
                            .format(tlTs.toDate())
                            : '-';
                        final updTs =
                        d['lastUpdated'] as Timestamp?;
                        final updatedAt = updTs != null
                            ? DateFormat.yMMMd()
                            .add_jm()
                            .format(updTs.toDate())
                            : '-';
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(6)),
                          elevation: 1,
                          child: ListTile(
                            title: Text(
                              stage,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _darkBlue),
                            ),
                            subtitle: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                if (assigned.isNotEmpty)
                                  Text('Assigned to: $assigned'),
                                if (notes.isNotEmpty)
                                  Text('Notes: $notes'),
                                Text('Deadline: $tl'),
                                Text(
                                  'Updated: $updatedAt',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
