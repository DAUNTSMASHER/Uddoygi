// lib/features/rnd/presentation/screens/rnd_request_tracker_screen.dart
// Cross-department read-only view: Marketing/Factory track their R&D requests
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/features/rnd/rnd_theme.dart';
import 'package:intl/intl.dart';

import 'package:uddoygi/services/local_storage_service.dart';


class RndRequestTrackerScreen extends StatefulWidget {
  const RndRequestTrackerScreen({super.key});
  @override
  State<RndRequestTrackerScreen> createState() => _RndRequestTrackerScreenState();
}

class _RndRequestTrackerScreenState extends State<RndRequestTrackerScreen> {
  String _cid = '';
  String? _email;

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    final session = await LocalStorageService.getSession();
    final current = FirebaseAuth.instance.currentUser;
    setState(() => _email = session?['email'] as String? ?? current?.email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: rndSurface,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [rndBrandDk, rndMid],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        title: const Text('R&D Project Tracker',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(
                context, '/rnd/request'),
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
            label: const Text('New Request',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _email == null
          ? const Center(child: CircularProgressIndicator(color: rndBrand))
          : _TrackerBody(email: _email!),
    );
  }
}

class _TrackerBody extends StatefulWidget {

  final String email;
  const _TrackerBody({required this.email});
  @override
  State<_TrackerBody> createState() => _TrackerBodyState();
}

class _TrackerBodyState extends State<_TrackerBody> {
  String _cid = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: DB.colSync(_cid, C.rndRequests)
          .where('requesterEmail', isEqualTo: widget.email)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: rndBrand));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.science_outlined, size: 56, color: Colors.black12),
              const SizedBox(height: 16),
              const Text('No R&D requests yet.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                      color: Colors.black38)),
              const SizedBox(height: 8),
              const Text('Submit a request to start tracking R&D progress.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black38)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/rnd/request'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New R&D Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: rndBrand, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]),
          ));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) => _TrackerCard(doc: docs[i]),
        );
      },
    );
  }
}

class _TrackerCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const _TrackerCard({required this.doc});
  @override
  State<_TrackerCard> createState() => _TrackerCardState();
}

class _TrackerCardState extends State<_TrackerCard> {
  bool _expanded = false;

  Map<String, dynamic> get _data => widget.doc.data() as Map<String, dynamic>;

  Color _statusColor(String s) {
    switch (s) {
      case 'Approved':          return const Color(0xFF16A34A);
      case 'Rejected':          return const Color(0xFFDC2626);
      case 'Submitted':         return rndAccent;
      case 'Draft':             return Colors.grey;
      case 'In Progress':       return rndBrand;
      case 'Revision Required': return const Color(0xFFEA580C);
      case 'Completed':         return rndMid;
      default:                  return Colors.grey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'Approved':          return Icons.check_circle_rounded;
      case 'Rejected':          return Icons.cancel_rounded;
      case 'Submitted':         return Icons.send_rounded;
      case 'In Progress':       return Icons.science_rounded;
      case 'Revision Required': return Icons.undo_rounded;
      case 'Completed':         return Icons.done_all_rounded;
      default:                  return Icons.hourglass_empty_rounded;
    }
  }

  List<_TimelineStep> _buildTimeline(String status) {
    const flow = [
      'Draft', 'Submitted', 'Under Review', 'Approved',
      'In Progress', 'Testing', 'Completed',
    ];
    final currentIdx = flow.indexOf(status);
    return flow.asMap().entries.map((e) {
      final idx  = e.key;
      final step = e.value;
      _StepState state;
      if (idx < currentIdx)       state = _StepState.done;
      else if (idx == currentIdx) state = _StepState.active;
      else                        state = _StepState.pending;
      return _TimelineStep(step, state);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final m      = _data;
    final status = m['status'] ?? 'Draft';
    final ts     = m['createdAt'];
    final dt     = ts is Timestamp ? ts.toDate() : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black),
        boxShadow: const [BoxShadow(color: Color(0x08000000),
            blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(children: [
        // ── Header ──
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_statusIcon(status), size: 18,
                    color: _statusColor(status)),
                const SizedBox(width: 8),
                Expanded(child: Text(m['title'] ?? '—',
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700))),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _statusColor(status).withOpacity(0.4)),
                  ),
                  child: Text(status,
                      style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(status))),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                _chip(Icons.category_rounded, m['requestType'] ?? ''),
                const SizedBox(width: 8),
                _chip(Icons.priority_high_rounded, m['priority'] ?? ''),
                if (dt != null) ...[
                  const SizedBox(width: 8),
                  _chip(Icons.calendar_today_rounded,
                      DateFormat('d MMM yyyy').format(dt)),
                ],
              ]),
            ]),
          ),
        ),

        // ── Expanded: timeline + project progress ──
        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Status timeline
              const Text('Status Timeline',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: Colors.black45)),
              const SizedBox(height: 12),
              _Timeline(steps: _buildTimeline(status)),

              // Approval note
              if ((m['approvalNote'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: Colors.amber),
                    const SizedBox(width: 6),
                    Expanded(child: Text(m['approvalNote'],
                        style: const TextStyle(fontSize: 12,
                            color: Colors.black54))),
                  ]),
                ),
              ],

              // Live project progress (if approved)
              if (status == 'Approved' || status == 'In Progress' ||
                  status == 'Testing' || status == 'Completed') ...[
                const SizedBox(height: 14),
                _ProjectProgressWidget(requestId: widget.doc.id),
              ],

              // Latest R&D update
              const SizedBox(height: 14),
              _LatestUpdate(requestId: widget.doc.id),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: rndBrand.withOpacity(0.07),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: rndBrand),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: rndBrand,
          fontWeight: FontWeight.w600)),
    ]),
  );
}

class _TimelineStep {
  final String     label;
  final _StepState state;
  const _TimelineStep(this.label, this.state);
}

enum _StepState { done, active, pending }

class _Timeline extends StatelessWidget {
  final List<_TimelineStep> steps;
  const _Timeline({required this.steps});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: steps.asMap().entries.map((e) {
          final i    = e.key;
          final step = e.value;
          final color = step.state == _StepState.done    ? rndMid
              : step.state == _StepState.active ? rndMagenta
              : Colors.black12;
          return Row(children: [
            Column(children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  step.state == _StepState.done
                      ? Icons.check_rounded : Icons.circle,
                  size: 12,
                  color: step.state == _StepState.pending
                      ? Colors.black26 : Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 60,
                child: Text(step.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: step.state == _StepState.active
                          ? FontWeight.w700 : FontWeight.w400,
                      color: step.state == _StepState.pending
                          ? Colors.black26 : Colors.black54,
                    )),
              ),
            ]),
            if (i < steps.length - 1)
              Container(
                width: 20, height: 2,
                margin: const EdgeInsets.only(bottom: 20),
                color: step.state == _StepState.done ? rndMid : Colors.black12,
              ),
          ]);
        }).toList(),
      ),
    );
  }
}

class _ProjectProgressWidget extends StatefulWidget {

  final String requestId;
  const _ProjectProgressWidget({required this.requestId});
  @override
  State<_ProjectProgressWidget> createState() => _ProjectProgressWidgetState();
}

class _ProjectProgressWidgetState extends State<_ProjectProgressWidget> {
  String _cid = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: DB.colSync(_cid, C.rndProjects)
          .where('requestId', isEqualTo: widget.requestId)
          .limit(1)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final m        = snap.data!.docs.first.data() as Map<String, dynamic>;
        final progress = (m['progress'] ?? 0) as num;
        final assignee = m['assigneeName'] ?? '';

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Project Progress',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: Colors.black45)),
          const SizedBox(height: 8),
          if (assignee.isNotEmpty)
            Text('Assigned to: $assignee',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.toDouble() / 100,
                  minHeight: 8,
                  backgroundColor: Colors.black,
                  valueColor: const AlwaysStoppedAnimation(rndAccent),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('${progress.round()}%',
                style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w700, color: rndBrand)),
          ]),
        ]);
      },
    );
  }
}

class _LatestUpdate extends StatefulWidget {

  final String requestId;
  const _LatestUpdate({required this.requestId});
  @override
  State<_LatestUpdate> createState() => _LatestUpdateState();
}

class _LatestUpdateState extends State<_LatestUpdate> {
  String _cid = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: DB.colSync(_cid, C.rndUpdates)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final m  = snap.data!.docs.first.data() as Map<String, dynamic>;
        final ts = m['createdAt'];
        final dt = ts is Timestamp ? ts.toDate() : null;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Latest R&D Update',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: Colors.black45)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
            color: rndCardTint.withOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: rndBrand.withOpacity(0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ((m['workDone'] ?? '').isNotEmpty)
                Text(m['workDone'],
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
              if (dt != null) ...[
                const SizedBox(height: 4),
                Text(DateFormat('d MMM, HH:mm').format(dt),
                    style: const TextStyle(fontSize: 10, color: Colors.black38)),
              ],
            ]),
          ),
        ]);
      },
    );
  }
}
