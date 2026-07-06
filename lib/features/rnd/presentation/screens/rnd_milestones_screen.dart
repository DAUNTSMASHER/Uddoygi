// lib/features/rnd/presentation/screens/rnd_milestones_screen.dart
// R&D team: track milestones, test results, and sample iterations
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/features/rnd/rnd_theme.dart';
import 'package:intl/intl.dart';

import 'package:uddoygi/services/local_storage_service.dart';


class RndMilestonesScreen extends StatefulWidget {
  final String? projectId;
  final String? projectTitle;
  const RndMilestonesScreen({super.key, this.projectId, this.projectTitle});
  @override
  State<RndMilestonesScreen> createState() => _RndMilestonesScreenState();
}

class _RndMilestonesScreenState extends State<RndMilestonesScreen> {
  String _cid = '';
  String? _email, _name;

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _loadUser();
  }

  Future<void> _loadUser() async {
    final session = await LocalStorageService.getSession();
    final current = FirebaseAuth.instance.currentUser;
    setState(() {
      _email = session?['email'] as String? ?? current?.email;
      _name  = session?['name']  as String? ?? current?.displayName;
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
        title: Text(widget.projectTitle != null
            ? 'Milestones: ${widget.projectTitle}'
            : 'Milestones & Tests',
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            tooltip: 'Add Milestone',
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: _MilestoneList(
          projectId: widget.projectId,
          email: _email,
          name: _name),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: rndMid,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Milestone',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () => _showAddDialog(context),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddMilestoneSheet(
        projectId: widget.projectId,
        projectTitle: widget.projectTitle,
        submitterEmail: _email,
        submitterName: _name,
      ),
    );
  }
}

class _MilestoneList extends StatefulWidget {

  final String? projectId, email, name;
  const _MilestoneList({this.projectId, this.email, this.name});
  @override
  State<_MilestoneList> createState() => _MilestoneListState();
}

class _MilestoneListState extends State<_MilestoneList> {
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
    Query<Map<String, dynamic>> q = DB.colSync(_cid, C.rndMilestones)
        .orderBy('createdAt', descending: true);

    if (widget.projectId != null) {
      q = q.where('projectId', isEqualTo: widget.projectId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: rndBrand));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('No milestones yet.\nTap + to add one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black38, fontSize: 14)),
          ));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: docs.length,
          itemBuilder: (_, i) => _MilestoneCard(doc: docs[i]),
        );
      },
    );
  }
}

class _MilestoneCard extends StatefulWidget {

  final QueryDocumentSnapshot doc;
  const _MilestoneCard({required this.doc});
  @override
  State<_MilestoneCard> createState() => _MilestoneCardState();
}

class _MilestoneCardState extends State<_MilestoneCard> {
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
    final m         = widget.doc.data() as Map<String, dynamic>;
    final type      = m['type']      ?? 'Milestone';
    final status    = m['status']    ?? 'Pending';
    final ts        = m['createdAt'];
    final dt        = ts is Timestamp ? ts.toDate() : null;
    final completed = status == 'Completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: completed ? Colors.green.shade200 : Colors.black),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _typeColor(type).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_typeIcon(type), size: 16, color: _typeColor(type)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m['title'] ?? '—',
                  style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w700)),
              Text(type,
                  style: TextStyle(fontSize: 11, color: _typeColor(type),
                      fontWeight: FontWeight.w600)),
            ],
          )),
          _StatusBadge(status),
        ]),
        if ((m['description'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(m['description'],
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
        if ((m['testResult'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
            color: rndCardTint,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: rndBrand.withOpacity(0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.biotech_rounded, size: 14, color: rndBrand),
            const SizedBox(width: 6),
            Expanded(child: Text(m['testResult'],
                style: const TextStyle(fontSize: 12, color: rndBrand))),
            ]),
          ),
        ],
        const SizedBox(height: 8),
        Row(children: [
          if (dt != null)
            Text(DateFormat('d MMM yyyy').format(dt),
                style: const TextStyle(fontSize: 11, color: Colors.black38)),
          const Spacer(),
          if (!completed)
            TextButton.icon(
              onPressed: () => _markComplete(widget.doc.id),
              icon: const Icon(Icons.check_rounded, size: 14),
              label: const Text('Complete', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: rndBrand),
            ),
        ]),
      ]),
    );
  }

  Future<void> _markComplete(String id) async {
      await DB.colSync(_cid, C.rndMilestones)
          .doc(id)
          .update({
        'status':    'Completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  
    Color _typeColor(String t) {
      switch (t) {
        case 'Test Result':   return rndBrand;
        case 'Sample':        return rndAccent;
        case 'Review':        return const Color(0xFFEA580C);
        case 'Handoff':       return rndMagenta;
        default:              return rndMid;
      }
    }
  
    IconData _typeIcon(String t) {
      switch (t) {
        case 'Test Result':   return Icons.biotech_rounded;
        case 'Sample':        return Icons.science_rounded;
        case 'Review':        return Icons.rate_review_rounded;
        case 'Handoff':       return Icons.send_rounded;
        default:              return Icons.flag_rounded;
      }
    }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  Color get _color {
    switch (status) {
      case 'Completed': return const Color(0xFF16A34A);
      case 'In Review': return const Color(0xFFEA580C);
      case 'Pending':   return Colors.grey;
      default:          return rndAccent;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _color.withOpacity(0.4)),
    ),
    child: Text(status,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
            color: _color)),
  );
}

// ─────────────────────────────────────────────────────────────
// ADD MILESTONE SHEET
// ─────────────────────────────────────────────────────────────
class _AddMilestoneSheet extends StatefulWidget {
  final String? projectId, projectTitle, submitterEmail, submitterName;
  const _AddMilestoneSheet({this.projectId, this.projectTitle,
      this.submitterEmail, this.submitterName});
  @override
  State<_AddMilestoneSheet> createState() => _AddMilestoneSheetState();
}

class _AddMilestoneSheetState extends State<_AddMilestoneSheet> {
  String _cid = '';
  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }
  final _titleCtrl  = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _resultCtrl = TextEditingController();

  String _type   = 'Milestone';
  bool   _saving = false;

  static const _types = ['Milestone', 'Test Result', 'Sample', 'Review', 'Handoff'];

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose(); _resultCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title is required.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await DB.colSync(_cid, C.rndMilestones).add({
        'projectId':      widget.projectId ?? '',
        'projectTitle':   widget.projectTitle ?? '',
        'title':          _titleCtrl.text.trim(),
        'description':    _descCtrl.text.trim(),
        'testResult':     _resultCtrl.text.trim(),
        'type':           _type,
        'status':         'Pending',
        'submittedBy':    widget.submitterName ?? '',
        'submittedByEmail': widget.submitterEmail ?? '',
        'createdAt':      FieldValue.serverTimestamp(),
        'updatedAt':      FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.black12,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Add Milestone / Test Result',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),

        // Type
        DropdownButtonFormField<String>(
          value: _type,
          onChanged: (v) => setState(() => _type = v!),
          items: _types.map((t) => DropdownMenuItem(value: t,
              child: Text(t, style: const TextStyle(fontSize: 14)))).toList(),
          decoration: _inputDec('Type'),
          dropdownColor: Colors.white,
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _titleCtrl,
          decoration: _inputDec('Title *'),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _descCtrl,
          maxLines: 3,
          decoration: _inputDec('Description / Notes'),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _resultCtrl,
          maxLines: 2,
          decoration: _inputDec('Test Result / Outcome (if applicable)'),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: rndBrand,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save Milestone',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
    filled: true, fillColor: const Color(0xFFF8F8F8),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black12)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: rndBrand, width: 1.5)),
  );
}
