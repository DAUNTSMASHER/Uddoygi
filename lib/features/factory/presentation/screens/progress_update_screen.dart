// lib/features/factory/presentation/screens/progress_update_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color _darkBlue = Color(0xFF0D47A1);
const Color _ink = Color(0xFF1D5DF1);
const Color _surface = Color(0xFFF6F8FB);

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

  int _stageIndex(String? name) {
    if (name == null) return -1;
    final i = _stages.indexOf(name);
    return i < 0 ? -1 : i;
  }

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
    if (_selectedNextStage == null || _selectedOrderNo == null || _selectedOrderDocId == null) return;

    // Validate forward-only move
    final orderRef = FirebaseFirestore.instance.collection('work_orders').doc(_selectedOrderDocId);
    final orderSnap = await orderRef.get();
    final orderData = orderSnap.data() ?? {};
    final currentStage = (orderData['currentStage'] as String?) ?? 'Submitted to factory';
    final currIdx = _stageIndex(currentStage);
    final nextIdx = _stageIndex(_selectedNextStage);

    if (nextIdx <= currIdx) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You cannot move backward or repeat the same stage.'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    final now = Timestamp.now();
    final batch = FirebaseFirestore.instance.batch();

    final trackingRef = FirebaseFirestore.instance.collection('work_order_tracking').doc();
    batch.set(trackingRef, {
      'workOrderNo': _selectedOrderNo,
      'stage': _selectedNextStage,
      'stageIndex': nextIdx,
      'notes': _notesCtl.text.trim(),
      'assignedTo': _assignedCtl.text.trim(),
      'timeLimit': Timestamp.fromDate(_timeLimit),
      'createdAt': now,
      'lastUpdated': now,
    });

    batch.update(orderRef, {
      'currentStage': _selectedNextStage,
      'currentStageIndex': nextIdx,
      'lastUpdated': now,
    });

    await batch.commit();

    if (!mounted) return;
    setState(() {
      _selectedNextStage = null;
      _notesCtl.clear();
      _assignedCtl.clear();
      _timeLimit = DateTime.now().add(const Duration(days: 1));
      _orderDocFuture = FirebaseFirestore.instance.collection('work_orders').doc(_selectedOrderDocId!).get();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Stage updated to "${_stages[nextIdx]}".'), backgroundColor: Colors.green.shade700),
    );
  }

  Future<void> _pickTimeLimit() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _timeLimit,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select deadline',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: _darkBlue),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _timeLimit = picked);
  }

  @override
  void dispose() {
    _notesCtl.dispose();
    _assignedCtl.dispose();
    super.dispose();
  }

  // ——————————— UI helpers ———————————

  PreferredSizeWidget _appBar() {
    return AppBar(
      title: Text(_selectedOrderNo == null ? 'Factory Progress' : 'Order $_selectedOrderNo'),
      centerTitle: true,
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
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_darkBlue, _ink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String text, {IconData icon = Icons.inbox}) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: Colors.grey.shade500),
              const SizedBox(height: 10),
              Text(text,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stageChipsScrollable(String currentStage) {
    final currIdx = _stageIndex(currentStage);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_stages.length, (i) {
          final s = _stages[i];
          final isDone = i < currIdx;
          final isCurr = i == currIdx;
          final Color bg = isCurr
              ? _darkBlue
              : (isDone ? Colors.green.shade600 : Colors.grey.shade300);
          final Color fg = isCurr || isDone ? Colors.white : Colors.black87;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(s, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 12)),
              ),
              avatar: Icon(isDone ? Icons.check_circle : (isCurr ? Icons.timelapse : Icons.circle_outlined),
                  color: fg, size: 16),
              backgroundColor: bg,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }),
      ),
    );
  }

  Widget _progressBar(String currentStage) {
    final idx = _stageIndex(currentStage);
    final progress = idx < 0 ? 0.0 : ((idx + 1) / _stages.length).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.shade300,
            color: _darkBlue,
          ),
        ),
        const SizedBox(height: 6),
        Text('Progress: ${(progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ——————————— Accepted Orders ———————————

  Widget _ordersList() {
    return Container(
      color: _surface,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _acceptedOrdersStream,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return _emptyState('No accepted work-orders yet.');
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final data = doc.data();
              final no = data['workOrderNo'] as String? ?? '—';
              final stage = (data['currentStage'] as String?) ?? 'Submitted to factory';
              final when = (data['lastUpdated'] as Timestamp?)?.toDate();
              final subtitle = '${DateFormat.yMMMd().add_jm().format(when ?? DateTime.now())} • $stage';

              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() {
                    _selectedOrderNo = no;
                    _selectedOrderDocId = doc.id;
                    _orderDocFuture =
                        FirebaseFirestore.instance.collection('work_orders').doc(doc.id).get();
                  }),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(backgroundColor: _darkBlue.withOpacity(.1), child: const Icon(Icons.assignment, color: _darkBlue)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Order $no',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _darkBlue)),
                            const SizedBox(height: 2),
                            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          ]),
                        ),
                        const Icon(Icons.chevron_right, color: _darkBlue),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ——————————— Order Detail (scrollable, overflow-safe) ———————————

  Widget _orderDetail() {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _orderDocFuture,
      builder: (ctx, orderSnap) {
        if (orderSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orderData = orderSnap.data?.data() ?? {};
        final currentStage = orderData['currentStage'] as String? ?? 'Submitted to factory';
        final currIdx = _stageIndex(currentStage);

        // Forward-only options
        final List<String> forwardStages =
        (currIdx >= 0 && currIdx < _stages.length - 1) ? _stages.sublist(currIdx + 1) : const <String>[];

        return Container(
          color: _surface,
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Whole page scrolls together to avoid nested scroll overflows
                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header (progress + chips)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          boxShadow: [BoxShadow(color: Color(0x11000000), blurRadius: 8, offset: Offset(0, 2))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _progressBar(currentStage),
                            const SizedBox(height: 10),
                            _stageChipsScrollable(currentStage),
                          ],
                        ),
                      ),

                      // Form card
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Card(
                          color: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200, width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Update Stage',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.grey.shade900)),
                                const SizedBox(height: 10),

                                TextFormField(
                                  initialValue: currentStage,
                                  decoration: const InputDecoration(
                                    labelText: 'Current Stage',
                                    prefixIcon: Icon(Icons.flag),
                                    border: OutlineInputBorder(),
                                  ),
                                  readOnly: true,
                                ),
                                const SizedBox(height: 12),

                                DropdownButtonFormField<String>(
                                  value: _selectedNextStage,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Next Stage (forward only)',
                                    prefixIcon: Icon(Icons.trending_up),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: forwardStages
                                      .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: (v) => setState(() => _selectedNextStage = v),
                                ),
                                const SizedBox(height: 12),

                                TextField(
                                  controller: _assignedCtl,
                                  decoration: const InputDecoration(
                                    labelText: 'Assign To (email/ID)',
                                    prefixIcon: Icon(Icons.person_add_alt_1),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                TextField(
                                  controller: _notesCtl,
                                  decoration: const InputDecoration(
                                    labelText: 'Notes',
                                    prefixIcon: Icon(Icons.notes),
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.event, color: _darkBlue, size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Deadline: ${DateFormat.yMMMd().format(_timeLimit)}',
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: _pickTimeLimit,
                                      icon: const Icon(Icons.edit_calendar),
                                      label: const Text('Change'),
                                      style: TextButton.styleFrom(foregroundColor: _darkBlue),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _darkBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: (_selectedNextStage == null) ? null : _addUpdate,
                                    icon: const Icon(Icons.save),
                                    label: const Text('Save Update'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // History (renders into the same scroll)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200, width: 1),
                          ),
                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _trackingStream,
                            builder: (ctx, histSnap) {
                              if (histSnap.connectionState == ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final docs = histSnap.data?.docs ?? [];
                              if (docs.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: _emptyState('No updates yet.', icon: Icons.history),
                                );
                              }

                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(12),
                                itemCount: docs.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 6),
                                itemBuilder: (ctx, i) {
                                  final d = docs[i].data();
                                  final stage = d['stage'] as String? ?? '-';
                                  final notes = d['notes'] as String? ?? '';
                                  final assigned = d['assignedTo'] as String? ?? '';
                                  final tlTs = d['timeLimit'] as Timestamp?;
                                  final tl = tlTs != null ? DateFormat.yMMMd().format(tlTs.toDate()) : '-';
                                  final updTs = d['lastUpdated'] as Timestamp?;
                                  final updatedAt =
                                  updTs != null ? DateFormat.yMMMd().add_jm().format(updTs.toDate()) : '-';

                                  final idx = _stageIndex(stage);
                                  final Color leftBar = idx <= _stageIndex(currentStage)
                                      ? _darkBlue
                                      : Colors.grey.shade400;

                                  return Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border(left: BorderSide(color: leftBar, width: 4)),
                                      color: Colors.white,
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      title: Text(
                                        stage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w800, color: _darkBlue),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          if (assigned.isNotEmpty)
                                            Text('Assigned to: $assigned', maxLines: 1, overflow: TextOverflow.ellipsis),
                                          if (notes.isNotEmpty)
                                            Text('Notes: $notes', maxLines: 3, overflow: TextOverflow.ellipsis),
                                          Text('Deadline: $tl'),
                                          Text('Updated: $updatedAt',
                                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                      trailing: Icon(
                                        idx <= _stageIndex(currentStage) ? Icons.verified : Icons.schedule,
                                        color: idx <= _stageIndex(currentStage) ? Colors.green : Colors.grey,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(),
      body: _selectedOrderNo == null ? _ordersList() : _orderDetail(),
    );
  }
}
