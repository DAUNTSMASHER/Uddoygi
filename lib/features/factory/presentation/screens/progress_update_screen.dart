// lib/features/factory/presentation/screens/progress_update_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color _darkBlue = Color(0xFF40062D);
const Color _ink = Color(0xFF500B49);
const Color _surface = Color(0xFFF6F8FB);
const Color _doneGreen = Color(0xFF1B5E20); // dark green for completed cards

class ProgressUpdateScreen extends StatefulWidget {
  const ProgressUpdateScreen({Key? key}) : super(key: key);

  @override
  State<ProgressUpdateScreen> createState() => _ProgressUpdateScreenState();
}
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    this.subtitle,
  }) : super(key: key);

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Stack(
        children: [
          // Corner watermark icon (subtle, doesn’t fight the number)
          Positioned(
            right: 10,
            top: 10,
            child: Icon(icon, size: 22, color: accent.withOpacity(0.22)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label — keep tiny per your 6–8sp guidance
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: .2,
                  ),
                ),
                const SizedBox(height: 6),
                // Value — slightly larger for contrast
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
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

  /// Factory pipeline stages (forward-only, terminal = Submit to the Head office)
  static const List<String> _stages = <String>[
    'Submitted to factory',
    'Factory update 1 (base is done)',
    'Hair is ready',
    'Knotting is going on',
    'Putting',
    'Molding',
    'Submit to the Head office', // terminal
  ];

  int _stageIndex(String? name) {
    if (name == null) return -1;
    final i = _stages.indexOf(name);
    return i < 0 ? -1 : i;
  }

  bool _isTerminal(String? stage) => stage == _stages.last;

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
    final currentStage = (orderData['currentStage'] as String?) ?? _stages.first;
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

    // Log to tracking collection
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

    final isTerminalMove = _selectedNextStage == _stages.last;

    // Update the work_order doc
    batch.update(orderRef, {
      'currentStage': _selectedNextStage,
      'currentStageIndex': nextIdx,
      'lastUpdated': now,
      if (isTerminalMove) ...{
        // Mark final completion
        'completed': true,
        'completedAt': now,
        // Handoff/global next stage (as requested earlier)
        'nextStage': 'Address Validation of the Customer',
      }
    });

    await batch.commit();

    if (!mounted) return;
    setState(() {
      _selectedNextStage = null;
      _notesCtl.clear();
      _assignedCtl.clear();
      _timeLimit = DateTime.now().add(const Duration(days: 1));
      _orderDocFuture =
          FirebaseFirestore.instance.collection('work_orders').doc(_selectedOrderDocId!).get();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isTerminalMove
              ? '🎉 Work order submitted to Head Office. Progress 100%. Next step: Address Validation of the Customer.'
              : 'Stage updated to "${_stages[nextIdx]}".',
        ),
        backgroundColor: isTerminalMove ? Colors.green.shade700 : null,
      ),
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
      foregroundColor: Colors.white,
      backgroundColor: Colors.red,
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
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stageChipsScrollable(String currentStage, {bool completed = false}) {
    final currIdx = _stageIndex(currentStage);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_stages.length, (i) {
          final s = _stages[i];
          final isDone = i < currIdx || (completed && i <= currIdx);
          final isCurr = i == currIdx;
          final Color bg = completed
              ? _doneGreen
              : (isCurr
              ? _darkBlue
              : (isDone
              ? Colors.green.shade600
              : Colors.grey.shade300));
          final Color fg = (completed || isCurr || isDone) ? Colors.white : Colors.black87;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  s,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: 12),
                ),
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

  Widget _progressBar(String currentStage, {required bool completed}) {
    final idx = _stageIndex(currentStage);
    final progress = completed
        ? 1.0
        : (idx < 0 ? 0.0 : ((idx + 1) / _stages.length).clamp(0.0, 1.0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.shade300,
            color: completed ? _doneGreen : _darkBlue,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Progress: ${(progress * 100).toStringAsFixed(0)}%',
          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ——————————— Dashboard ———————————

  String _formatAvg(Duration? d) {
    if (d == null || d.inSeconds <= 0) return '—';
    if (d.inDays >= 1) return '${d.inDays}d';
    if (d.inHours >= 1) return '${d.inHours}h';
    return '${d.inMinutes}m';
  }

  Duration? _averageCompletionDuration(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final completed = docs.where((d) => (d.data()['completed'] == true) || _isTerminal(d.data()['currentStage'] as String?)).toList();
    if (completed.isEmpty) return null;

    int count = 0;
    int totalMs = 0;
    for (final d in completed) {
      final data = d.data();
      final completedAt = data['completedAt'] is Timestamp ? (data['completedAt'] as Timestamp).toDate() : null;
      if (completedAt == null) continue;

      // Try to find a start timestamp
      final DateTime? startedAt =
      (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate()
          : (data['timestamp']  is Timestamp) ? (data['timestamp']  as Timestamp).toDate()
          : (data['orderDate']  is Timestamp) ? (data['orderDate']  as Timestamp).toDate()
          : null;

      if (startedAt == null) continue;
      final ms = completedAt.millisecondsSinceEpoch - startedAt.millisecondsSinceEpoch;
      if (ms > 0) {
        totalMs += ms;
        count++;
      }
    }
    if (count == 0) return null;
    return Duration(milliseconds: (totalMs / count).round());
  }

  Widget _dashboard(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final total = docs.length;
    final completed = docs.where((d) =>
    (d.data()['completed'] == true) ||
        _isTerminal(d.data()['currentStage'] as String?)).length;
    final running = total - completed;
    final avg = _averageCompletionDuration(docs);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          // ↓ More compact cards; tweak 1.6–2.2 to taste per device width
          childAspectRatio: 1.9,
        ),
        children: [
          _MetricCard(
            title: 'Total orders',
            value: '$total',
            icon: Icons.all_inbox,
            accent: _darkBlue,
          ),
          _MetricCard(
            title: 'Completed',
            value: '$completed',
            icon: Icons.verified,
            accent: Colors.green.shade700,
          ),
          _MetricCard(
            title: 'Running',
            value: '$running',
            icon: Icons.play_circle_fill,
            accent: Colors.orange.shade700,
          ),
          _MetricCard(
            title: 'Avg. complete time',
            value: _formatAvg(avg),
            icon: Icons.timer,
            accent: Colors.purple.shade700,
          ),
        ],
      ),
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
            padding: const EdgeInsets.only(bottom: 16),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: docs.length + 1, // +1 for the dashboard on top
            itemBuilder: (ctx, i) {
              if (i == 0) {
                // Dashboard at top
                return _dashboard(docs);
              }

              final doc = docs[i - 1];
              final data = doc.data();

              final no = data['workOrderNo'] as String? ?? '—';
              final stage = (data['currentStage'] as String?) ?? _stages.first;
              final when = (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now();
              final tracking = (data['tracking_number'] as String?) ?? '—';
              final agent = (data['agentName'] as String?)
                  ?? (data['agentEmail'] as String?)
                  ?? '—';
              final buyer = (data['buyerName'] as String?)
                  ?? (data['customerName'] as String?)
                  ?? '—';

              final bool isCompleted = (data['completed'] == true) || _isTerminal(stage);

              // Small label text (6–8sp)
              final tsLabelStyle = TextStyle(fontSize: 7, color: isCompleted ? Colors.white70 : Colors.grey.shade700, fontWeight: FontWeight.w600);
              final titleStyle   = TextStyle(fontSize: 8, color: isCompleted ? Colors.white : _darkBlue, fontWeight: FontWeight.w800);
              final infoStyle    = TextStyle(fontSize: 7, color: isCompleted ? Colors.white : Colors.black87, fontWeight: FontWeight.w700);

              return Material(
                color: isCompleted ? _doneGreen : Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() {
                    _selectedOrderNo = no;
                    _selectedOrderDocId = doc.id;
                    _orderDocFuture = FirebaseFirestore.instance.collection('work_orders').doc(doc.id).get();
                  }),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isCompleted ? _doneGreen : Colors.grey.shade200, width: 1),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: (isCompleted ? Colors.white : _darkBlue).withOpacity(.12),
                          child: Icon(Icons.assignment, color: isCompleted ? Colors.white : _darkBlue, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top line: Order & Tracking (8sp)
                              Text('Order $no  •  TRK $tracking',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                              const SizedBox(height: 4),
                              // Stage + time (6–7sp)
                              Text(
                                '${DateFormat.yMMMd().add_jm().format(when)}  •  $stage',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tsLabelStyle,
                              ),
                              const SizedBox(height: 4),
                              // Agent + Buyer (6–7sp)
                              Text('Agent: $agent  •  Buyer: $buyer',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: infoStyle),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: isCompleted ? Colors.white : _darkBlue, size: 16),
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
        final currentStage = orderData['currentStage'] as String? ?? _stages.first;
        final currIdx = _stageIndex(currentStage);

        final bool isCompleted = (orderData['completed'] == true) || _isTerminal(currentStage);
        final DateTime? completedAt =
        (orderData['completedAt'] is Timestamp) ? (orderData['completedAt'] as Timestamp).toDate() : null;

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
                            _progressBar(currentStage, completed: isCompleted), // 100% if terminal/completed
                            const SizedBox(height: 10),
                            _stageChipsScrollable(currentStage, completed: isCompleted),
                          ],
                        ),
                      ),

                      // If completed — show green completion card
                      if (isCompleted)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Card(
                            color: _doneGreen,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.green.shade100, width: 1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.emoji_events, color: Colors.white),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Work order submitted to Head Office!',
                                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          completedAt == null
                                              ? 'Finished: time not recorded.'
                                              : 'Finished on ${DateFormat.yMMMd().add_jm().format(completedAt)}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          '🎉 Great job! Next system stage: “Address Validation of the Customer”.',
                                          style: TextStyle(fontSize: 12, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                      // Form card (only when NOT completed)
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
                                        .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s, overflow: TextOverflow.ellipsis),
                                    ))
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
                                          const Text('Deadline:', style: TextStyle(fontWeight: FontWeight.w700)),
                                          const SizedBox(width: 4),
                                          Text(DateFormat.yMMMd().format(_timeLimit),
                                              style: const TextStyle(fontWeight: FontWeight.w600)),
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
                                  final Color leftBar = idx <= _stageIndex(currentStage) ? _darkBlue : Colors.grey.shade400;

                                  return Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border(left: BorderSide(color: leftBar, width: 4)),
                                      color: Colors.white,
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      title: const SizedBox(),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Keep these compact but readable
                                          Text(stage,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w800, color: _darkBlue, fontSize: 12)),
                                          const SizedBox(height: 4),
                                          if (assigned.isNotEmpty)
                                            Text('Assigned to: $assigned',
                                                maxLines: 1, overflow: TextOverflow.ellipsis),
                                          if (notes.isNotEmpty)
                                            Text('Notes: $notes',
                                                maxLines: 3, overflow: TextOverflow.ellipsis),
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
