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
  String? _selectedOrder;

  // Form controllers & state
  final _notesCtl    = TextEditingController();
  final _assignedCtl = TextEditingController();
  String _status     = 'running';
  DateTime _timeLimit= DateTime.now().add(const Duration(days: 1));
  String? _selectedStage;

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

  /// Stream of accepted work‑orders
  Stream<QuerySnapshot<Map<String, dynamic>>> get _acceptedOrdersStream {
    return FirebaseFirestore.instance
        .collection('work_orders')
        .where('status', isEqualTo: 'Accepted')
        .orderBy('lastUpdated', descending: true)
        .snapshots();
  }

  /// Stream of all updates for the selected order
  Stream<QuerySnapshot<Map<String, dynamic>>> get _trackingStream {
    return FirebaseFirestore.instance
        .collection('work_order_tracking')
        .where('workOrderNo', isEqualTo: _selectedOrder)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _addUpdate() async {
    if (_selectedStage == null || _selectedOrder == null) return;
    final now = Timestamp.now();
    await FirebaseFirestore.instance
        .collection('work_order_tracking')
        .add({
      'workOrderNo': _selectedOrder,
      'stage'      : _selectedStage,
      'status'     : _status,
      'notes'      : _notesCtl.text.trim(),
      'assignedTo' : _assignedCtl.text.trim(),
      'timeLimit'  : Timestamp.fromDate(_timeLimit),
      'createdAt'  : now,
      'lastUpdated': now,
    });
    setState(() {
      _selectedStage = null;
      _status        = 'running';
      _notesCtl.clear();
      _assignedCtl.clear();
      _timeLimit     = DateTime.now().add(const Duration(days: 1));
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
          _selectedOrder == null
              ? 'Select Work‑Order'
              : 'Updates: $_selectedOrder',
        ),
        backgroundColor: _darkBlue,
        leading: _selectedOrder != null
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _selectedOrder = null),
        )
            : null,
      ),

      // ────────────────
      // 1) LIST ACCEPTED
      // ────────────────
      body: _selectedOrder == null
          ? StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _acceptedOrdersStream,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty)
            return const Center(child: Text('No accepted work‑orders.'));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final order = docs[i].data();
              final no     = order['workOrderNo'] as String? ?? '—';
              final invId  = order['invoiceId']   as String?;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  // ─ top‐left: agent email from invoice
                  title: FutureBuilder<DocumentSnapshot<Map<String,dynamic>>>(
                    future: invId != null
                        ? FirebaseFirestore.instance
                        .collection('invoices')
                        .doc(invId)
                        .get()
                        : Future.value(null),
                    builder: (ctx, invSnap) {
                      if (invSnap.connectionState == ConnectionState.waiting)
                        return const Text(
                          '…',
                          style: TextStyle(
                            fontSize: 12,
                            color: _darkBlue,
                          ),
                        );
                      final inv  = invSnap.data?.data();
                      final email = inv?['agentEmail'] as String? ?? 'unknown';
                      return Text(
                        email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _darkBlue,
                        ),
                      );
                    },
                  ),

                  // ─ bottom‐left: small work‑order number
                  subtitle: Text(
                    no,
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.black87,
                    ),
                  ),

                  // ─ right: latest stage + status
                  trailing: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance
                        .collection('work_order_tracking')
                        .where('workOrderNo', isEqualTo: no)
                        .orderBy('createdAt', descending: true)
                        .limit(1)
                        .get(),
                    builder: (ctx, updSnap) {
                      if (updSnap.connectionState == ConnectionState.waiting)
                        return const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );

                      final updDocs = updSnap.data?.docs ?? [];
                      if (updDocs.isEmpty)
                        return const Text(
                          'No updates',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        );

                      final data   = updDocs.first.data();
                      final stage  = data['stage']  as String? ?? '-';
                      final status = (data['status'] as String? ?? '').toUpperCase();
                      final color  = status == 'RUNNING'
                          ? Colors.orange
                          : Colors.green;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(stage,  style: const TextStyle(fontSize: 10)),
                          Text(status, style: TextStyle(fontSize: 10, color: color)),
                        ],
                      );
                    },
                  ),

                  onTap: () => setState(() => _selectedOrder = no),
                ),
              );
            },
          );
        },
      )

      // ────────────────────────────────────────
      // 2) FORM + HISTORY FOR SELECTED ORDER
      // ────────────────────────────────────────
          : Column(
        children: [
          // ─ Add New Update Form ────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedStage,
                      hint: const Text('Select Stage'),
                      items: _stages
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedStage = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Running'),
                            value: 'running',
                            groupValue: _status,
                            onChanged: (v) => setState(() => _status = v!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Completed'),
                            value: 'completed',
                            groupValue: _status,
                            onChanged: (v) => setState(() => _status = v!),
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _assignedCtl,
                      decoration: const InputDecoration(
                        labelText: 'Assign To (email/ID)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesCtl,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Deadline: ${DateFormat.yMMMd().format(_timeLimit)}'),
                        const Spacer(),
                        TextButton(
                          onPressed: _pickTimeLimit,
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _darkBlue),
                        onPressed: _addUpdate,
                        child: const Text('Save Update'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─ Existing Updates ────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _trackingStream,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty)
                  return const Center(child: Text('No updates yet.'));
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final d        = docs[i].data();
                    final stage    = d['stage']      as String;
                    final status   = (d['status']    as String).toUpperCase();
                    final notes    = d['notes']      as String?  ?? '';
                    final assigned = d['assignedTo'] as String?  ?? '';
                    final tlTs     = d['timeLimit']  as Timestamp?;
                    final tl       = tlTs != null
                        ? DateFormat.yMMMd().format(tlTs.toDate())
                        : '-';
                    final updTs    = d['lastUpdated'] as Timestamp?;
                    final updatedAt= updTs != null
                        ? DateFormat.yMMMd().add_jm().format(updTs.toDate())
                        : '-';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      elevation: 1,
                      child: ListTile(
                        title: Text(
                          '$stage • $status',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _darkBlue),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (assigned.isNotEmpty)
                              Text('Assigned to: $assigned'),
                            if (notes.isNotEmpty)
                              Text('Notes: $notes'),
                            Text('Deadline: $tl'),
                            Text(
                              'Updated: $updatedAt',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
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
      ),
    );
  }
}
