// lib/features/rnd/presentation/screens/rnd_approval_screen.dart
// Used by: Admin & HR to review, approve, reject, or return R&D requests
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/features/rnd/rnd_theme.dart';
import 'package:intl/intl.dart';

import 'package:uddoygi/services/local_storage_service.dart';


class RndApprovalScreen extends StatefulWidget {
  const RndApprovalScreen({super.key});
  @override
  State<RndApprovalScreen> createState() => _RndApprovalScreenState();
}

class _RndApprovalScreenState extends State<RndApprovalScreen>
    with SingleTickerProviderStateMixin {
  String _cid = '';
  late final TabController _tabs;
  String? _approverName, _approverEmail;

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _tabs = TabController(length: 3, vsync: this);
    _loadApprover();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadApprover() async {
    final session = await LocalStorageService.getSession();
    final current = FirebaseAuth.instance.currentUser;
    setState(() {
      _approverEmail = session?['email'] as String? ?? current?.email;
      _approverName  = session?['name']  as String? ?? current?.displayName;
    });
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
        title: const Text('R&D Approval',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _RequestList(status: 'Submitted',
              approverName: _approverName, approverEmail: _approverEmail),
          _RequestList(status: 'Approved',
              approverName: _approverName, approverEmail: _approverEmail,
              readOnly: true),
          _RequestList(status: 'Rejected',
              approverName: _approverName, approverEmail: _approverEmail,
              readOnly: true),
        ],
      ),
    );
  }
}

class _RequestList extends StatefulWidget {

  final String  status;
  final String? approverName, approverEmail;
  final bool    readOnly;

  const _RequestList({
    required this.status,
    this.approverName,
    this.approverEmail,
    this.readOnly = false,
  });
  @override
  State<_RequestList> createState() => _RequestListState();
}

class _RequestListState extends State<_RequestList> {
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
          .where('status', isEqualTo: widget.status)
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
            child: Text('No ${widget.status} requests.',
                style: const TextStyle(color: Colors.black38, fontSize: 14)),
          ));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) => _RequestCard(
            doc: docs[i],
            approverName:  widget.approverName,
            approverEmail: widget.approverEmail,
            readOnly: widget.readOnly,
          ),
        );
      },
    );
  }
}

class _RequestCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final String? approverName, approverEmail;
  final bool readOnly;
  const _RequestCard({required this.doc, this.approverName,
      this.approverEmail, this.readOnly = false});
  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  String _cid = '';
  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }
  bool _expanded = false;
  bool _busy     = false;

  final _noteCtrl     = TextEditingController();
  final _assignCtrl   = TextEditingController();
  DateTime? _deadline;

  @override
  void dispose() { _noteCtrl.dispose(); _assignCtrl.dispose(); super.dispose(); }

  Map<String, dynamic> get _data => widget.doc.data() as Map<String, dynamic>;

  Future<void> _act(String action) async {
    if (action == 'Approved' && _assignCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter an R&D assignee.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final db  = DB.firestore;
      final ref = DB.colSync(_cid, C.rndRequests).doc(widget.doc.id);
      final now = FieldValue.serverTimestamp();

      final historyEntry = {
        'action':    action,
        'by':        widget.approverName ?? widget.approverEmail ?? 'Admin',
        'byEmail':   widget.approverEmail ?? '',
        'note':      _noteCtrl.text.trim(),
        'timestamp': Timestamp.now(),
      };

      await ref.update({
        'status':         action,
        'approvalNote':   _noteCtrl.text.trim(),
        'approvedBy':     widget.approverName ?? widget.approverEmail,
        'approvedByEmail':widget.approverEmail,
        'approvedAt':     now,
        'assignedTo':     _assignCtrl.text.trim(),
        'deadline':       _deadline != null ? Timestamp.fromDate(_deadline!) : null,
        'updatedAt':      now,
        'approvalHistory': FieldValue.arrayUnion([historyEntry]),
      });

      // If approved → create an rnd_project document
      if (action == 'Approved') {
        await DB.colSync(_cid, C.rndProjects).add({
          'requestId':      widget.doc.id,
          'title':          _data['title'] ?? '',
          'description':    _data['problemStatement'] ?? '',
          'objectives':     _data['proposedIdea'] ?? '',
          'requestType':    _data['requestType'] ?? '',
          'priority':       _data['priority'] ?? 'Medium',
          'status':         'In Progress',
          'progress':       0,
          'assigneeName':   _assignCtrl.text.trim(),
          'assigneeEmail':  '',
          'requestingDept': _data['requestingDept'] ?? '',
          'requesterName':  _data['requesterName'] ?? '',
          'requesterEmail': _data['requesterEmail'] ?? '',
          'deadline':       _deadline != null ? Timestamp.fromDate(_deadline!) : null,
          'createdAt':      now,
          'updatedAt':      now,
          'createdBy':      widget.approverEmail ?? '',
        });
      }

      // Notify requester
      final requesterEmail = _data['requesterEmail'] ?? '';
      if (requesterEmail.isNotEmpty) {
        await DB.colSync(_cid, C.notifications).add({
          'to':        requesterEmail,
          'title':     'R&D Request $action',
          'body':      'Your request "${_data['title']}" has been $action.',
          'read':      false,
          'type':      'rnd_approval',
          'refId':     widget.doc.id,
          'timestamp': now,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Request $action successfully.')));
        setState(() => _expanded = false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'Urgent': return rndMagenta;
      case 'High':   return const Color(0xFFEA580C);
      case 'Low':    return Colors.grey;
      default:       return rndAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m        = _data;
    final ts       = m['createdAt'];
    final dt       = ts is Timestamp ? ts.toDate() : null;
    final priority = m['priority'] ?? 'Medium';

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
        // ── Header row ──
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(m['title'] ?? '—',
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w700))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _priorityColor(priority).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(priority,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: _priorityColor(priority))),
                ),
                const SizedBox(width: 6),
                Icon(_expanded
                    ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: Colors.black38),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                _chip(Icons.business_rounded,
                    (m['requestingDept'] ?? '').toUpperCase()),
                _chip(Icons.person_rounded, m['requesterName'] ?? ''),
                if (dt != null)
                  _chip(Icons.calendar_today_rounded,
                      DateFormat('d MMM yyyy').format(dt)),
              ]),
            ]),
          ),
        ),

        // ── Expanded detail + actions ──
        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _detail('Request Type', m['requestType'] ?? ''),
              _detail('Problem Statement', m['problemStatement'] ?? ''),
              if ((m['businessImpact'] ?? '').isNotEmpty)
                _detail('Business Impact', m['businessImpact']),
              if ((m['proposedIdea'] ?? '').isNotEmpty)
                _detail('Proposed Idea', m['proposedIdea']),

              if (!widget.readOnly) ...[
                const SizedBox(height: 16),
                const Text('Approval Note',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: Colors.black54)),
                const SizedBox(height: 6),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: _inputDec('Add a note (optional)'),
                ),
                const SizedBox(height: 12),
                const Text('Assign to R&D Member',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: Colors.black54)),
                const SizedBox(height: 6),
                TextField(
                  controller: _assignCtrl,
                  decoration: _inputDec('R&D lead / member name'),
                ),
                const SizedBox(height: 12),
                const Text('Set Deadline',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: Colors.black54)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 14)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(
                          colorScheme: const ColorScheme.light(primary: rndBrand)),
                        child: child!),
                    );
                    if (picked != null) setState(() => _deadline = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 16, color: rndBrand),
                      const SizedBox(width: 8),
                      Text(
                        _deadline != null
                            ? DateFormat('d MMM yyyy').format(_deadline!)
                            : 'Select deadline',
                        style: TextStyle(fontSize: 13,
                            color: _deadline != null
                                ? Colors.black87 : Colors.black38),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                if (_busy)
                  const Center(child: CircularProgressIndicator(color: rndBrand))
                else
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _act('Revision Required'),
                        icon: const Icon(Icons.undo_rounded, size: 16),
                        label: const Text('Return'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _act('Rejected'),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _act('Approved'),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: rndMid,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ]),
              ],
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: Colors.black38)),
      const SizedBox(height: 3),
      Text(value, style: const TextStyle(fontSize: 13, color: Colors.black87)),
    ]),
  );

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

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
    filled: true, fillColor: const Color(0xFFF8F8F8),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black12)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: rndBrand, width: 1.5)),
  );
}
