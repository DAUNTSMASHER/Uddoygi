// lib/features/rnd/presentation/screens/rnd_projects_screen.dart
// R&D team: view and manage approved/published projects
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/features/rnd/rnd_theme.dart';
import 'package:intl/intl.dart';


class RndProjectsScreen extends StatefulWidget {
  const RndProjectsScreen({super.key});
  @override
  State<RndProjectsScreen> createState() => _RndProjectsScreenState();
}

class _RndProjectsScreenState extends State<RndProjectsScreen> {
  String _cid = '';
  String _filterStatus = 'All';
  String _filterPriority = 'All';
  String _search = '';

  static const _statuses   = ['All', 'In Progress', 'Testing', 'On Hold', 'Completed', 'Cancelled'];
  static const _priorities = ['All', 'Urgent', 'High', 'Medium', 'Low'];
  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
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
        title: const Text('R&D Projects',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(children: [
        // ── Filters ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(children: [
            TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search projects...',
                prefixIcon: const Icon(Icons.search_rounded, color: rndBrand),
                filled: true, fillColor: rndSurface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                ..._statuses.map((s) => _FilterChip(
                  label: s,
                  selected: _filterStatus == s,
                  onTap: () => setState(() => _filterStatus = s),
                )),
                const SizedBox(width: 12),
                const Text('|', style: TextStyle(color: Colors.black26)),
                const SizedBox(width: 12),
                ..._priorities.map((p) => _FilterChip(
                  label: p,
                  selected: _filterPriority == p,
                  onTap: () => setState(() => _filterPriority = p),
                  color: _priorityColor(p),
                )),
              ]),
            ),
          ]),
        ),
        // ── List ──
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: DB.colSync(_cid, C.rndProjects)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: rndBrand));
              }
              var docs = snap.data!.docs;

              // Filter
              docs = docs.where((d) {
                final m = d.data() as Map<String, dynamic>;
                final status   = m['status'] ?? '';
                final priority = m['priority'] ?? '';
                final title    = (m['title'] ?? '').toString().toLowerCase();

                if (_filterStatus   != 'All' && status   != _filterStatus)   return false;
                if (_filterPriority != 'All' && priority != _filterPriority) return false;
                if (_search.isNotEmpty && !title.contains(_search))           return false;
                return true;
              }).toList();

              if (docs.isEmpty) {
                return const Center(child: Text('No projects found.',
                    style: TextStyle(color: Colors.black38)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (_, i) => _ProjectCard(doc: docs[i]),
              );
            },
          ),
        ),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool   selected;
  final VoidCallback onTap;
  final Color? color;
  const _FilterChip({required this.label, required this.selected,
      required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? rndBrand;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : Colors.black12),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black54)),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _ProjectCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final m        = doc.data() as Map<String, dynamic>;
    final status   = m['status']   ?? 'In Progress';
    final priority = m['priority'] ?? 'Medium';
    final progress = (m['progress'] ?? 0) as num;
    final ts       = m['deadline'];
    final deadline = ts is Timestamp ? ts.toDate() : null;
    final overdue  = deadline != null && deadline.isBefore(DateTime.now())
        && status != 'Completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: overdue ? Colors.red.shade200 : Colors.black),
        boxShadow: const [BoxShadow(color: Color(0x08000000),
            blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(m['title'] ?? '—',
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w700))),
              _StatusBadge(status),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _Chip(Icons.priority_high_rounded, priority,
                  _priorityColor(priority)),
              if ((m['requestingDept'] ?? '').isNotEmpty)
                _Chip(Icons.business_rounded,
                    (m['requestingDept'] as String).toUpperCase(), rndBrand),
              if ((m['assigneeName'] ?? '').isNotEmpty)
                _Chip(Icons.person_rounded, m['assigneeName'], Colors.purple),
              if (deadline != null)
                _Chip(
                  overdue
                      ? Icons.warning_amber_rounded
                      : Icons.calendar_today_rounded,
                  DateFormat('d MMM yyyy').format(deadline),
                  overdue ? Colors.red : Colors.black45,
                ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.toDouble() / 100,
                    minHeight: 6,
                    backgroundColor: Colors.black,
                    valueColor: AlwaysStoppedAnimation(
                        status == 'Completed'
                            ? const Color(0xFF16A34A) : rndAccent),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${progress.round()}%',
                  style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w700, color: rndBrand)),
            ]),
          ]),
        ),
        // ── Action bar ──
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0x0A000000))),
          ),
          child: Row(children: [
            _ActionBtn(Icons.edit_note_rounded, 'Update', () =>
                Navigator.pushNamed(context, '/rnd/updates',
                    arguments: {'projectId': doc.id, 'projectTitle': m['title']})),
            _ActionBtn(Icons.flag_rounded, 'Milestone', () =>
                Navigator.pushNamed(context, '/rnd/milestones',
                    arguments: {'projectId': doc.id, 'projectTitle': m['title']})),
            _ActionBtn(Icons.more_horiz_rounded, 'More', () =>
                _showOptions(context, doc.id, m)),
          ]),
        ),
      ]),
    );
  }

  void _showOptions(BuildContext context, String id, Map<String, dynamic> m) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProjectOptions(docId: id, data: m),
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

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  Color get _color {
    switch (status) {
      case 'Completed':   return const Color(0xFF16A34A);
      case 'In Progress': return rndAccent;
      case 'Testing':     return rndBrand;
      case 'On Hold':     return const Color(0xFFEA580C);
      case 'Cancelled':   return const Color(0xFFDC2626);
      default:            return Colors.grey;
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
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: _color)),
  );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _Chip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color,
          fontWeight: FontWeight.w600)),
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  const _ActionBtn(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: rndBrand),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 11,
              color: rndBrand, fontWeight: FontWeight.w600)),
        ]),
      ),
    ),
  );
}

class _ProjectOptions extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _ProjectOptions({required this.docId, required this.data});
  @override
  State<_ProjectOptions> createState() => _ProjectOptionsState();
}

class _ProjectOptionsState extends State<_ProjectOptions> {
  String _cid = '';
  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }
  bool _busy = false;

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    final now = FieldValue.serverTimestamp();
    final batch = DB.firestore.batch();
    final projectRef = DB.colSync(_cid, C.rndProjects).doc(widget.docId);

    batch.update(projectRef, {'status': status, 'updatedAt': now});

    // Gap E8: Create Stock Requirements when R&D is completed
    if (status == 'Completed') {
      final reqRef = DB.colSync(_cid, 'stock_requirements').doc();
      batch.set(reqRef, {
        'projectId': widget.docId,
        'title': widget.data['title'] ?? '',
        'requestingDept': widget.data['requestingDept'] ?? 'rnd',
        'status': 'Pending Review',
        'timestamp': now,
        'bom': widget.data['bom'] ?? [], // Planned BOM items
        'notes': 'Automatically generated from R&D Project: ${widget.data['title']}',
      });

      // Also notify Factory
      final notifRef = DB.colSync(_cid, C.notifications).doc();
      batch.set(notifRef, {
        'title': 'New BOM Ready for Review',
        'body': 'R&D project "${widget.data['title']}" is completed. Please review material requirements.',
        'target': 'factory',
        'timestamp': now,
      });
    }

    await batch.commit();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.black12,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text(widget.data['title'] ?? '',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        if (_busy)
          const CircularProgressIndicator(color: rndBrand)
        else ...[
          _opt(Icons.pause_circle_rounded, 'Mark On Hold', Colors.orange,
              () => _setStatus('On Hold')),
          _opt(Icons.science_rounded, 'Mark Testing', Colors.purple,
              () => _setStatus('Testing')),
          _opt(Icons.check_circle_rounded, 'Mark Completed', Colors.green,
              () => _setStatus('Completed')),
          _opt(Icons.cancel_rounded, 'Cancel Project', Colors.red,
              () => _setStatus('Cancelled')),
        ],
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _opt(IconData icon, String label, Color color, VoidCallback onTap) =>
      ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: TextStyle(color: color,
            fontWeight: FontWeight.w600)),
        onTap: onTap,
      );
}
