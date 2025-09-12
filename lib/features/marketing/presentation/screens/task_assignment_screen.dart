import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';

/// ===== Palette (blue bars + white labels) =====
const Color _brandBlue = Color(0xFF0D47A1); // dark blue
const Color _blueMid   = Color(0xFF1D5DF1); // accent
const Color _surface   = Color(0xFFF6F8FF); // light surface
const Color _border    = Color(0x1A0D47A1); // 10% blue
const double _barH     = 48;

/// Firestore collections (adjust names if your schema differs)
const String _USERS  = 'users';
const String _TASKS  = 'tasks';

class TaskAssignmentScreen extends StatefulWidget {
  const TaskAssignmentScreen({super.key});

  @override
  State<TaskAssignmentScreen> createState() => _TaskAssignmentScreenState();
}

class _TaskAssignmentScreenState extends State<TaskAssignmentScreen> {
  int _tab = 0;

  String get _title {
    switch (_tab) {
      case 0: return 'Dashboard';
      case 1: return 'Assign Task';
      case 2: return 'My Work';
      default: return 'Tasks';
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final mq = MediaQuery.of(context);

    return Theme(
      data: baseTheme.copyWith(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: _brandBlue,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          toolbarHeight: _barH,
          titleTextStyle: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: _brandBlue,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.w800),
          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w700),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        colorScheme: baseTheme.colorScheme.copyWith(primary: _brandBlue),
      ),
      child: MediaQuery(
        // keep UI tight even when device text size is large
        data: mq.copyWith(textScaler: const TextScaler.linear(0.92)),
        child: Scaffold(
          appBar: AppBar(title: Text(_title)),
          body: IndexedStack(
            index: _tab,
            children: const [
              _DashboardPage(),
              _AssignPage(),
              _MyWorkPage(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _tab,
            onTap: (i) => setState(() => _tab = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.space_dashboard), label: 'Dashboard'),
              BottomNavigationBarItem(icon: Icon(Icons.assignment_add), label: 'Assign'),
              BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: 'My Work'),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                DASHBOARD                                   */
/* -------------------------------------------------------------------------- */

class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  User get _me => FirebaseAuth.instance.currentUser!;

  /// 1) Total assigned (by me)
  Stream<int> _countAssignedByMe() => FirebaseFirestore.instance
      .collection(_TASKS)
      .where('assignerId', isEqualTo: _me.uid)
      .snapshots()
      .map((s) => s.docs.length);

  /// 2) Submitted by me (I am assignee and status=submitted)
  Stream<int> _countSubmittedByMe() => FirebaseFirestore.instance
      .collection(_TASKS)
      .where('assigneeId', isEqualTo: _me.uid)
      .where('status', isEqualTo: 'submitted')
      .snapshots()
      .map((s) => s.docs.length);

  /// 3) Completed by juniors (I am assigner and status=done)
  Stream<int> _countCompletedByJuniors() => FirebaseFirestore.instance
      .collection(_TASKS)
      .where('assignerId', isEqualTo: _me.uid)
      .where('status', isEqualTo: 'done')
      .snapshots()
      .map((s) => s.docs.length);

  /// 4) Rejected task (my submissions that were rejected / need changes)
  Stream<int> _countRejectedForMe() => FirebaseFirestore.instance
      .collection(_TASKS)
      .where('assigneeId', isEqualTo: _me.uid)
      .where('status', whereIn: ['changes_requested', 'rejected'])
      .snapshots()
      .map((s) => s.docs.length);

  @override
  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('EEE, MMM d').format(DateTime.now());

    // 4 tiles for the fixed 2×2 grid — with labels
    final tiles = <Widget>[
      _StatTile(
        stream: _countAssignedByMe().map((v) => '$v'),
        icon: Icons.outgoing_mail,
        showLabel: true,
        label: 'Total assigned',
      ),
      _StatTile(
        stream: _countSubmittedByMe().map((v) => '$v'),
        icon: Icons.upload_file,
        showLabel: true,
        label: 'Submitted by me',
      ),
      _StatTile(
        stream: _countCompletedByJuniors().map((v) => '$v'),
        icon: Icons.verified,
        showLabel: true,
        label: 'Completed by juniors',
      ),
      _StatTile(
        stream: _countRejectedForMe().map((v) => '$v'),
        icon: Icons.block,
        showLabel: true,
        label: 'Rejected task',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _HeaderCard(label: 'Overview', subtitle: todayStr),
        const SizedBox(height: 12),

        // Fixed 2×2 grid
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: tiles,
        ),

        const SizedBox(height: 16),
        const _RecentSection(),
      ],
    );
  }

}

class _HeaderCard extends StatelessWidget {
  final String label;
  final String? subtitle;
  const _HeaderCard({required this.label, this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_brandBlue, _blueMid]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              subtitle == null ? label : '$label • $subtitle',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14, // smaller header
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final Stream<String> stream;
  final IconData icon;
  final bool showLabel; // numbers only when false
  final String label;   // optional, unused when showLabel=false
  const _StatTile({
    required this.stream,
    required this.icon,
    this.showLabel = true,
    this.label = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: _brandBlue.withOpacity(.08),
            foregroundColor: _brandBlue,
            child: Icon(icon, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StreamBuilder<String>(
              stream: stream,
              builder: (_, snap) {
                final v = snap.data ?? '—';
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _brandBlue,
                        fontSize: 16,
                      ),
                    ),
                    if (showLabel) ...[
                      const SizedBox(height: 1),
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _brandBlue,
                          fontSize: 11,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSection extends StatelessWidget {
  const _RecentSection();
  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Recent Tasks',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(_TASKS)
            .orderBy('createdAt', descending: true)
            .limit(10)
            .snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No tasks yet.', style: TextStyle(color: _brandBlue)),
            );
          }
          return Column(
            children: docs.map((d) => _TaskCard(docId: d.id, data: d.data())).toList(),
          );
        },
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                 ASSIGN PAGE                                */
/* -------------------------------------------------------------------------- */

class _AssignPage extends StatefulWidget {
  const _AssignPage();

  @override
  State<_AssignPage> createState() => _AssignPageState();
}

class _AssignPageState extends State<_AssignPage> {
  final _form = GlobalKey<FormState>();
  final _titleCtl = TextEditingController();
  final _descCtl  = TextEditingController();
  DateTime _due   = DateTime.now().add(const Duration(days: 3));
  String _priority = 'normal';
  String? _assigneeId;

  final _me = FirebaseAuth.instance.currentUser!;

  Future<Map<String, dynamic>?> _getMeProfile() async {
    // Try doc by uid first, fallback to email lookup
    final byId = await FirebaseFirestore.instance.collection(_USERS).doc(_me.uid).get();
    if (byId.data() != null) return byId.data();
    final byEmail = await FirebaseFirestore.instance.collection(_USERS)
        .where('email', isEqualTo: _me.email).limit(1).get();
    return byEmail.docs.isNotEmpty ? byEmail.docs.first.data() : null;
  }

  Stream<List<_UserLite>> _juniorsStream() async* {
    final meProfile = await _getMeProfile();
    final myDept = (meProfile?['department'] ?? '').toString().toLowerCase();
    final myJoin = (meProfile?['joinDate'] as Timestamp?)?.toDate();

    yield* FirebaseFirestore.instance.collection(_USERS)
        .where('department', isEqualTo: myDept)
        .snapshots()
        .map((s) {
      final list = <_UserLite>[];
      for (final d in s.docs) {
        final m = d.data();
        final join = (m['joinDate'] as Timestamp?)?.toDate();
        // A “junior” is anyone who joined after me.
        final isJunior = myJoin == null || (join != null && join.isAfter(myJoin));
        if (d.id == _me.uid) continue;
        if (isJunior) {
          list.add(_UserLite(
            id: d.id,
            name: (m['fullName'] ?? m['name'] ?? m['email'] ?? 'Unknown').toString(),
          ));
        }
      }
      list.sort((a,b) => a.name.compareTo(b.name));
      return list;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _assigneeId == null) return;

    final meProfile = await _getMeProfile();
    final meName = (meProfile?['fullName'] ?? meProfile?['name'] ?? _me.email ?? 'Me').toString();
    final assigneeDoc = await FirebaseFirestore.instance.collection(_USERS).doc(_assigneeId).get();
    final assigneeName = (assigneeDoc.data()?['fullName'] ?? assigneeDoc.data()?['name'] ?? 'User').toString();

    final now = DateTime.now();
    await FirebaseFirestore.instance.collection(_TASKS).add({
      'title'      : _titleCtl.text.trim(),
      'description': _descCtl.text.trim(),
      'priority'   : _priority,
      'status'     : 'pending', // pending | doing | submitted | done | changes_requested
      'dueDate'    : Timestamp.fromDate(_due),
      'createdAt'  : Timestamp.fromDate(now),
      'updatedAt'  : Timestamp.fromDate(now),

      'assignerId'  : _me.uid,
      'assignerName': meName,
      'assigneeId'  : _assigneeId,
      'assigneeName': assigneeName,
    });

    if (mounted) {
      _titleCtl.clear();
      _descCtl.clear();
      _priority = 'normal';
      _assigneeId = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task created')),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const _SectionHeader(title: 'Create a task', subtitle: 'Assign to a junior and set a due date'),
        const SizedBox(height: 10),
        _SectionCard(
          child: Form(
            key: _form,
            child: Column(
              children: [
                StreamBuilder<List<_UserLite>>(
                  stream: _juniorsStream(),
                  builder: (_, snap) {
                    final juniors = snap.data ?? const <_UserLite>[];
                    return _DropdownField<String>(
                      label: 'Assignee *',
                      value: _assigneeId,
                      items: juniors.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))).toList(),
                      onChanged: (v) => setState(() => _assigneeId = v),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _TextField(label: 'Title *', controller: _titleCtl, validator: _req),
                const SizedBox(height: 10),
                _TextField(label: 'Description', controller: _descCtl, maxLines: 4),
                const SizedBox(height: 10),
                _DateField(
                  label: 'Due date',
                  value: _due,
                  onChanged: (d) => setState(() => _due = d),
                ),
                const SizedBox(height: 10),
                _DropdownField<String>(
                  label: 'Priority',
                  value: _priority,
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: (v) => setState(() => _priority = v ?? 'normal'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.send),
                    label: const Text('Assign Task'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _AssignedByMeList(),
      ],
    );
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
}

/* -------------------------------------------------------------------------- */
/*                                  MY WORK                                   */
/* -------------------------------------------------------------------------- */

class _MyWorkPage extends StatelessWidget {
  const _MyWorkPage();
  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const _SectionHeader(title: 'My Tasks', subtitle: 'Work assigned to you, with live updates'),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(_TASKS)
              .where('assigneeId', isEqualTo: me.uid)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const _CardLoader();
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const _EmptyState(message: 'No tasks for you (yet).');
            }
            return Column(
              children: docs.map((d) => _TaskCard(docId: d.id, data: d.data(), isMyWork: true)).toList(),
            );
          },
        ),
      ],
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                REUSABLE UI                                 */
/* -------------------------------------------------------------------------- */

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.view_agenda, color: _brandBlue, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            subtitle == null ? title : '$title • $subtitle',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: _brandBlue,
              fontSize: 14, // smaller section title
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  const _SectionCard({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[
          Text(title!, style: const TextStyle(color: _brandBlue, fontWeight: FontWeight.w800, fontSize: 14)),
          const Divider(height: 18),
        ],
        child,
      ]),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  const _DropdownField({required this.label, required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true, fillColor: _surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _border)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(isExpanded: true, value: value, items: items, onChanged: onChanged),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final String? Function(String?)? validator;
  const _TextField({required this.label, required this.controller, this.maxLines = 1, this.validator});
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller, validator: validator, maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true, fillColor: _surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _border)),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  const _DateField({required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final txt = DateFormat('MMM d, yyyy').format(value);
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          initialDate: value,
          helpText: label,
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true, fillColor: _surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _border)),
        ),
        child: Text(txt),
      ),
    );
  }
}

class _CardLoader extends StatelessWidget {
  const _CardLoader();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }
}

class _UserLite {
  final String id;
  final String name;
  const _UserLite({required this.id, required this.name});
}

/* -------------------------- Lists: Assigned by me ------------------------- */

class _AssignedByMeList extends StatelessWidget {
  const _AssignedByMeList();

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser!;
    return _SectionCard(
      title: 'Tasks I assigned',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection(_TASKS)
            .where('assignerId', isEqualTo: me.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const _CardLoader();
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Text('Nothing yet.');
          return Column(
            children: docs.map((d) => _TaskCard(docId: d.id, data: d.data(), isOwner: true)).toList(),
          );
        },
      ),
    );
  }
}

/* ------------------------------ Safe casting helpers ------------------------------ */

Map<String, dynamic> _toMap(dynamic v) {
  if (v == null) return <String, dynamic>{};
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _toListOfMap(dynamic v) {
  if (v is List) {
    return v.map((e) => _toMap(e)).toList();
  }
  return <Map<String, dynamic>>[];
}

/* ------------------------------ Task Card UI ----------------------------- */

class _TaskCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isOwner;  // I assigned it
  final bool isMyWork; // It’s assigned to me

  const _TaskCard({
    required this.docId,
    required this.data,
    this.isOwner = false,
    this.isMyWork = false,
  });

  @override
  Widget build(BuildContext context) {
    final status   = (data['status'] ?? 'pending').toString();
    final title    = (data['title'] ?? '').toString();
    final desc     = (data['description'] ?? '').toString();
    final assignee = (data['assigneeName'] ?? '').toString();
    final due      = (data['dueDate'] is Timestamp)
        ? (data['dueDate'] as Timestamp).toDate()
        : DateTime.tryParse('${data['dueDate']}');
    final dueTxt   = due != null ? DateFormat('MMM d').format(due) : '—';
    final priority = (data['priority'] ?? 'normal').toString();

    // ✅ SAFE nested structure reads (prevents _Map<dynamic, dynamic> cast crash)
    final submission = _toMap(data['submission']);
    final files      = _toListOfMap(submission['files']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0,3))],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title.isEmpty ? desc : title,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, color: _brandBlue, fontSize: 14),
              ),
            ),
            _StatusChip(status: status),
          ],
        ),
        if (desc.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Pill(icon: Icons.schedule, text: 'Due $dueTxt'),
            _Pill(icon: Icons.flag, text: 'Priority: ${priority[0].toUpperCase()}${priority.substring(1)}'),
            if (!isMyWork) _Pill(icon: Icons.person, text: assignee),
          ],
        ),

        // --- Submission preview (if any) ---
        if (submission.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          const Text('Submission', style: TextStyle(fontWeight: FontWeight.w800, color: _brandBlue)),
          if ((submission['note'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(submission['note'].toString()),
          ],
          if ((submission['link'] ?? '').toString().isNotEmpty)
            TextButton.icon(
              onPressed: () => _openUrl(context, submission['link'].toString()),
              icon: const Icon(Icons.open_in_new),
              label: Text(submission['link'].toString(), overflow: TextOverflow.ellipsis),
            ),
          if (files.isNotEmpty) _AttachmentsRow(files: files),
        ],

        const SizedBox(height: 10),
        _TaskActions(docId: docId, data: data, isOwner: isOwner, isMyWork: isMyWork),
      ]),
    );
  }

  void _openUrl(BuildContext context, String url) {
    // leave to url_launcher if you already use it, otherwise a noop here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Open: $url')),
    );
  }
}

class _AttachmentsRow extends StatelessWidget {
  final List<Map<String, dynamic>> files;
  const _AttachmentsRow({required this.files});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6, runSpacing: 6,
        children: files.map((f) {
          final name = (f['name'] ?? 'file').toString();
          return ActionChip(
            visualDensity: VisualDensity.compact,
            avatar: const Icon(Icons.insert_drive_file, size: 16),
            label: Text(name, overflow: TextOverflow.ellipsis),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Download: $name')),
              );
              // Use url_launcher to actually open: f['url']
            },
          );
        }).toList(),
      ),
    );
  }
}

class _RepliesSection extends StatelessWidget {
  final String taskId;
  const _RepliesSection({required this.taskId});

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser!;
    final ctl = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Replies', style: TextStyle(fontWeight: FontWeight.w800, color: _brandBlue)),
        const SizedBox(height: 6),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(_TASKS).doc(taskId)
              .collection('replies')
              .orderBy('createdAt')
              .snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const Text('No replies yet.');
            }
            return Column(
              children: snap.data!.docs.map((d) {
                final m = d.data();
                final who = (m['name'] ?? 'User').toString();
                final text = (m['text'] ?? '').toString();
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.chat_bubble_outline, size: 18, color: _brandBlue),
                  title: Text(who, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  subtitle: Text(text),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctl,
                decoration: const InputDecoration(
                  hintText: 'Write a reply…',
                  filled: true, fillColor: _surface,
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: () async {
                final text = ctl.text.trim();
                if (text.isEmpty) return;
                await FirebaseFirestore.instance
                    .collection(_TASKS).doc(taskId)
                    .collection('replies')
                    .add({
                  'text': text,
                  'uid': me.uid,
                  'name': me.email ?? 'User',
                  'createdAt': FieldValue.serverTimestamp(),
                });
                ctl.clear();
              },
              icon: const Icon(Icons.send, color: _brandBlue),
              tooltip: 'Send',
            ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _brandBlue.withOpacity(.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brandBlue.withOpacity(.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: _brandBlue),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: _brandBlue,
            fontWeight: FontWeight.w700,
            fontSize: 11, // smaller chip text
          ),
        ),
      ]),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bg = Colors.grey.shade200;
    Color fg = Colors.grey.shade800;
    if (s == 'doing') { bg = Colors.blue.shade50; fg = Colors.blue.shade800; }
    else if (s == 'submitted') { bg = Colors.deepPurple.shade50; fg = Colors.deepPurple.shade800; }
    else if (s == 'done') { bg = Colors.green.shade50; fg = Colors.green.shade800; }
    else if (s == 'changes_requested') { bg = Colors.orange.shade50; fg = Colors.orange.shade800; }
    else if (s == 'rejected') { bg = Colors.red.shade50; fg = Colors.red.shade800; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fg,
          fontSize: 11, // smaller chip font
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}

/* ------------------------------- Actions row ------------------------------ */

class _TaskActions extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isOwner;
  final bool isMyWork;
  const _TaskActions({required this.docId, required this.data, required this.isOwner, required this.isMyWork});

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'pending').toString();

    final buttons = <Widget>[];

    // Assignee (junior) actions
    if (isMyWork) {
      if (status == 'pending') {
        buttons.add(_Btn(text: 'Start', icon: Icons.play_arrow, onTap: () => _update({'status': 'doing'})));
      } else if (status == 'doing') {
        buttons.add(_Btn(text: 'Submit', icon: Icons.upload_file, onTap: () => _openSubmitSheet(context)));
      } else if (status == 'changes_requested') {
        buttons.add(_Btn(text: 'Re-Submit', icon: Icons.upload, onTap: () => _openSubmitSheet(context)));
      }
      if (status == 'doing' || status == 'submitted') {
        buttons.add(_Btn(text: 'Mark Done', icon: Icons.check, onTap: () => _update({'status': 'done'})));
      }
    }

    // Owner (senior) actions
    if (isOwner) {
      if (status == 'submitted') {
        buttons.add(_Btn(text: 'Approve', icon: Icons.verified, onTap: () => _update({'status': 'done'})));
        buttons.add(_Btn(text: 'Request Changes', icon: Icons.pending_actions, onTap: () => _update({'status': 'changes_requested'})));
      } else if (status == 'pending') {
        buttons.add(_Btn(text: 'Start for Assignee', icon: Icons.play_arrow, onTap: () => _update({'status': 'doing'})));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (buttons.isNotEmpty)
          Wrap(spacing: 8, runSpacing: 8, children: buttons),

        // Replies thread appears once the task is not "pending"
        if (status != 'pending') ...[
          const SizedBox(height: 10),
          _RepliesSection(taskId: docId),
        ],
      ],
    );
  }

  Future<void> _update(Map<String, dynamic> patch) async {
    patch['updatedAt'] = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance.collection(_TASKS).doc(docId).update(patch);
  }

  Future<void> _openSubmitSheet(BuildContext context) async {
    final noteCtl = TextEditingController();
    final linkCtl = TextEditingController();
    final attachments = <Map<String, dynamic>>[];

    Future<void> pickAndUpload() async {
      final picked = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (picked == null) return;

      final uid = FirebaseAuth.instance.currentUser!.uid;

      for (final f in picked.files) {
        final String fileName = f.name;
        final String objectPath = 'tasks/$docId/submissions/$uid/$fileName';

        // Guess a content-type from path/bytes (may be null)
        final String? contentType = lookupMimeType(
          f.path ?? fileName,
          headerBytes: f.bytes, // safe even if null
        );

        final ref = FirebaseStorage.instance.ref(objectPath);

        UploadTask uploadTask;
        final metadata = SettableMetadata(contentType: contentType);

        if (f.bytes != null) {
          uploadTask = ref.putData(f.bytes!, metadata);
        } else if (f.path != null) {
          uploadTask = ref.putFile(File(f.path!), metadata);
        } else {
          continue; // skip unknown source
        }

        final snap = await uploadTask.whenComplete(() {});
        final url = await snap.ref.getDownloadURL();

        attachments.add({
          'name': fileName,
          'url' : url,
          'type': contentType ?? 'application/octet-stream',
          'size': f.size,
          'ext' : f.extension, // optional, helpful for UI
          'path': objectPath,  // optional, if you ever need to delete
        });
      }
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16, right: 16, top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Submit Work', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes / What was done',
                    filled: true, fillColor: _surface, border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: linkCtl,
                  decoration: const InputDecoration(
                    labelText: 'Optional Link (Drive, Git, etc.)',
                    filled: true, fillColor: _surface, border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await pickAndUpload();
                        setSheet(() {}); // refresh list
                      },
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: const Text('Attach files'),
                    ),
                    const SizedBox(width: 8),
                    if (attachments.isNotEmpty)
                      Text('${attachments.length} file(s) attached',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6, runSpacing: 6,
                      children: attachments.map((a) => Chip(
                        label: Text(a['name'], overflow: TextOverflow.ellipsis),
                        visualDensity: VisualDensity.compact,
                      )).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Submit'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (ok == true) {
      await _update({
        'status': 'submitted',
        'submission': {
          'note': noteCtl.text.trim(),
          'link': linkCtl.text.trim(),
          'files': attachments, // << saved files
          'submittedAt': FieldValue.serverTimestamp(),
        },
      });
      // also drop a first reply so the thread has context
      final me = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance
          .collection(_TASKS).doc(docId)
          .collection('replies')
          .add({
        'text': 'Submitted: ${noteCtl.text.trim()}',
        'uid': me.uid,
        'name': me.email ?? 'User',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}

class _Btn extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  const _Btn({required this.text, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(text),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                  Helpers                                   */
/* -------------------------------------------------------------------------- */

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      alignment: Alignment.center,
      child: Text(message, style: const TextStyle(color: _brandBlue)),
    );
  }
}
