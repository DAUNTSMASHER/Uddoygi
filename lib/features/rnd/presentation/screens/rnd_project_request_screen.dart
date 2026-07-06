// lib/features/rnd/presentation/screens/rnd_project_request_screen.dart
// Used by: Marketing & Factory departments to submit R&D project requests
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/features/rnd/rnd_theme.dart';
import 'package:intl/intl.dart';

import 'package:uddoygi/services/local_storage_service.dart';


class RndProjectRequestScreen extends StatefulWidget {
  const RndProjectRequestScreen({super.key});
  @override
  State<RndProjectRequestScreen> createState() => _RndProjectRequestScreenState();
}

class _RndProjectRequestScreenState extends State<RndProjectRequestScreen>
    with SingleTickerProviderStateMixin {
  String _cid = '';
  late final TabController _tabs;
  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _tabs = TabController(length: 2, vsync: this);
  }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

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
        title: const Text('R&D Project Request',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'New Request'),
            Tab(text: 'My Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _NewRequestForm(),
          _MyRequestsList(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// NEW REQUEST FORM
// ─────────────────────────────────────────────────────────────
class _NewRequestForm extends StatefulWidget {
  const _NewRequestForm();
  @override
  State<_NewRequestForm> createState() => _NewRequestFormState();
}

class _NewRequestFormState extends State<_NewRequestForm> {
  String _cid = '';
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl      = TextEditingController();
  final _problemCtrl    = TextEditingController();
  final _impactCtrl     = TextEditingController();
  final _ideaCtrl       = TextEditingController();
  final _productCtrl    = TextEditingController();

  String _requestType = 'Product Development';
  String _priority    = 'Medium';
  DateTime? _targetDate;
  bool _submitting = false;

  String? _requesterName, _requesterEmail, _department;

  static const _requestTypes = [
    'Product Development', 'Material Improvement', 'Process Optimization',
    'Packaging', 'Quality Issue', 'Cost Reduction', 'Custom Buyer Requirement',
  ];
  static const _priorities = ['Low', 'Medium', 'High', 'Urgent'];

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _loadUser();
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _problemCtrl.dispose();
    _impactCtrl.dispose(); _ideaCtrl.dispose(); _productCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final session = await LocalStorageService.getSession();
    final current = FirebaseAuth.instance.currentUser;
    final uid     = session?['uid'] as String? ?? current?.uid;
    setState(() {
      _requesterEmail = session?['email'] as String? ?? current?.email;
      _department     = session?['role']  as String?;
    });
    if (uid != null) {
      try {
        final snap = await DB.colSync(_cid, C.users).doc(uid).get();
        if (snap.exists && mounted) {
          final d = snap.data()!;
          setState(() {
            _requesterName = (d['fullName'] as String?)?.trim() ?? _requesterEmail;
            _department    = (d['department'] as String?)?.toLowerCase() ?? _department;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _submit({bool draft = false}) async {
    if (!draft && !(_formKey.currentState?.validate() ?? false)) return;
    if (_targetDate == null && !draft) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a target date.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final ref = DB.colSync(_cid, C.rndRequests).doc();
      await ref.set({
        'requestId':         ref.id,
        'title':             _titleCtrl.text.trim(),
        'requestType':       _requestType,
        'problemStatement':  _problemCtrl.text.trim(),
        'businessImpact':    _impactCtrl.text.trim(),
        'proposedIdea':      _ideaCtrl.text.trim(),
        'relatedProduct':    _productCtrl.text.trim(),
        'priority':          _priority,
        'targetDate':        _targetDate != null
            ? Timestamp.fromDate(_targetDate!) : null,
        'requestingDept':    _department ?? 'unknown',
        'requesterName':     _requesterName ?? '',
        'requesterEmail':    _requesterEmail ?? '',
        'status':            draft ? 'Draft' : 'Submitted',
        'approvalHistory':   [],
        'createdAt':         FieldValue.serverTimestamp(),
        'updatedAt':         FieldValue.serverTimestamp(),
      });

      // Notify Admin/HR
      if (!draft) {
        await DB.colSync(_cid, C.notifications).add({
          'to':        'admin',
          'title':     'New R&D Request',
          'body':      '${_requesterName ?? _requesterEmail} submitted: ${_titleCtrl.text.trim()}',
          'read':      false,
          'type':      'rnd_request',
          'refId':     ref.id,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(draft ? 'Draft saved.' : 'Request submitted for approval.')));
        if (!draft) {
          _titleCtrl.clear(); _problemCtrl.clear();
          _impactCtrl.clear(); _ideaCtrl.clear(); _productCtrl.clear();
          setState(() { _targetDate = null; _priority = 'Medium'; });
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Requester info banner
          if (_requesterName != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
            color: rndCardTint,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: rndBrand.withOpacity(0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.person_rounded, size: 16, color: rndBrand),
            const SizedBox(width: 8),
            Expanded(child: Text(
                  '$_requesterName  ·  ${(_department ?? '').toUpperCase()}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: rndBrand),
                )),
              ]),
            ),

          _label('Project Title *'),
          _field(_titleCtrl, 'Brief title of the R&D request',
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null),

          _label('Request Type *'),
          _dropdown(_requestTypes, _requestType, (v) => setState(() => _requestType = v!)),

          _label('Problem Statement *'),
          _field(_problemCtrl, 'Describe the problem or need in detail',
              maxLines: 4,
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null),

          _label('Business Impact'),
          _field(_impactCtrl, 'How does this affect the business?', maxLines: 3),

          _label('Proposed Idea (optional)'),
          _field(_ideaCtrl, 'Any initial idea or approach?', maxLines: 3),

          _label('Related Product / SKU / Process'),
          _field(_productCtrl, 'e.g. SKU-1234 or Dyeing Process'),

          _label('Priority *'),
          _dropdown(_priorities, _priority, (v) => setState(() => _priority = v!),
              colors: {'Low': Colors.grey, 'Medium': rndAccent,
                  'High': const Color(0xFFEA580C), 'Urgent': rndMagenta}),

          _label('Target Date *'),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 14)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (c, child) => Theme(
                  data: Theme.of(c).copyWith(
                    colorScheme: const ColorScheme.light(primary: rndBrand)),
                  child: child!),
              );
              if (picked != null) setState(() => _targetDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 16, color: rndBrand),
                const SizedBox(width: 10),
                Text(
                  _targetDate != null
                      ? DateFormat('d MMM yyyy').format(_targetDate!)
                      : 'Select target date',
                  style: TextStyle(
                    fontSize: 14,
                    color: _targetDate != null ? Colors.black87 : Colors.black38,
                  ),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 28),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting ? null : () => _submit(draft: true),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: rndBrand),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Save Draft',
                    style: TextStyle(color: rndBrand, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _submitting ? null : () => _submit(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: rndBrand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Submit for Approval',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
        color: Colors.black54)),
  );

  Widget _field(TextEditingController ctrl, String hint,
      {int maxLines = 1, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.black12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.black12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: rndBrand, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red)),
      ),
    );
  }

  Widget _dropdown(List<String> items, String value, ValueChanged<String?> onChanged,
      {Map<String, Color>? colors}) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      items: items.map((s) => DropdownMenuItem(
        value: s,
        child: Row(children: [
          if (colors != null) Container(
            width: 8, height: 8, margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: colors[s] ?? rndBrand, shape: BoxShape.circle),
          ),
          Text(s, style: const TextStyle(fontSize: 14)),
        ]),
      )).toList(),
      decoration: InputDecoration(
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.black12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.black12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: rndBrand, width: 1.5)),
      ),
      dropdownColor: Colors.white,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MY REQUESTS LIST
// ─────────────────────────────────────────────────────────────
class _MyRequestsList extends StatefulWidget {
  const _MyRequestsList();
  @override
  State<_MyRequestsList> createState() => _MyRequestsListState();
}

class _MyRequestsListState extends State<_MyRequestsList> {
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

  Color _statusColor(String s) {
    switch (s) {
      case 'Approved':    return const Color(0xFF16A34A);
      case 'Rejected':    return const Color(0xFFDC2626);
      case 'Submitted':   return rndAccent;
      case 'Draft':       return Colors.grey;
      case 'In Progress': return rndBrand;
      default:            return const Color(0xFFEA580C);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_email == null) {
      return const Center(child: CircularProgressIndicator(color: rndBrand));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: DB.colSync(_cid, C.rndRequests)
          .where('requesterEmail', isEqualTo: _email)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: rndBrand));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('No requests yet.\nSubmit your first R&D request.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black38, fontSize: 14)),
          ));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final m = docs[i].data() as Map<String, dynamic>;
            final status = m['status'] ?? 'Draft';
            final ts = m['createdAt'];
            final dt = ts is Timestamp ? ts.toDate() : null;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black),
                boxShadow: const [BoxShadow(color: Color(0x08000000),
                    blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(m['title'] ?? '—',
                      style: const TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w700))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _statusColor(status).withOpacity(0.4)),
                    ),
                    child: Text(status,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: _statusColor(status))),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  _chip(Icons.category_rounded, m['requestType'] ?? ''),
                  const SizedBox(width: 8),
                  _chip(Icons.priority_high_rounded, m['priority'] ?? '',
                      color: _priorityColor(m['priority'] ?? '')),
                ]),
                if (dt != null) ...[
                  const SizedBox(height: 6),
                  Text(DateFormat('d MMM yyyy').format(dt),
                      style: const TextStyle(fontSize: 11, color: Colors.black38)),
                ],
                if ((m['approvalNote'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
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
              ]),
            );
          },
        );
      },
    );
  }

  Widget _chip(IconData icon, String label, {Color? color}) {
    final c = color ?? rndBrand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: c,
            fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'Urgent': return rndMagenta;
      case 'High':   return const Color(0xFFEA580C);
      case 'Low':    return Colors.grey;
      default:       return rndAccent;
    }
  }
}
