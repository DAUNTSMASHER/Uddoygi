// lib/features/rnd/presentation/screens/rnd_daily_update_screen.dart
// R&D team: submit and view daily progress reports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/features/rnd/rnd_theme.dart';
import 'package:intl/intl.dart';

import 'package:uddoygi/services/local_storage_service.dart';


class RndDailyUpdateScreen extends StatefulWidget {
  final String? projectId;
  final String? projectTitle;
  const RndDailyUpdateScreen({super.key, this.projectId, this.projectTitle});
  @override
  State<RndDailyUpdateScreen> createState() => _RndDailyUpdateScreenState();
}

class _RndDailyUpdateScreenState extends State<RndDailyUpdateScreen>
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
        title: Text(widget.projectTitle != null
            ? 'Update: ${widget.projectTitle}'
            : 'Daily Updates',
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Submit Update'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _SubmitForm(
              projectId: widget.projectId,
              projectTitle: widget.projectTitle),
          _UpdateHistory(projectId: widget.projectId),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SUBMIT FORM
// ─────────────────────────────────────────────────────────────
class _SubmitForm extends StatefulWidget {
  final String? projectId, projectTitle;
  const _SubmitForm({this.projectId, this.projectTitle});
  @override
  State<_SubmitForm> createState() => _SubmitFormState();
}

class _SubmitFormState extends State<_SubmitForm> {
  String _cid = '';
  final _formKey = GlobalKey<FormState>();

  final _workDoneCtrl    = TextEditingController();
  final _testCtrl        = TextEditingController();
  final _findingsCtrl    = TextEditingController();
  final _materialsCtrl   = TextEditingController();
  final _blockersCtrl    = TextEditingController();
  final _supportCtrl     = TextEditingController();
  final _nextPlanCtrl    = TextEditingController();

  double  _progress = 0;
  bool    _submitting = false;
  String? _selectedProjectId, _selectedProjectTitle;
  String? _submitterName, _submitterEmail;

  List<Map<String, dynamic>> _projects = [];

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _selectedProjectId    = widget.projectId;
    _selectedProjectTitle = widget.projectTitle;
    _loadUser();
    _loadProjects();
  }

  @override
  void dispose() {
    _workDoneCtrl.dispose(); _testCtrl.dispose(); _findingsCtrl.dispose();
    _materialsCtrl.dispose(); _blockersCtrl.dispose();
    _supportCtrl.dispose(); _nextPlanCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final session = await LocalStorageService.getSession();
    final current = FirebaseAuth.instance.currentUser;
    final uid     = session?['uid'] as String? ?? current?.uid;
    setState(() {
      _submitterEmail = session?['email'] as String? ?? current?.email;
      _submitterName  = session?['name']  as String? ?? current?.displayName;
    });
    if (uid != null) {
      try {
        final snap = await DB.colSync(_cid, C.users).doc(uid).get();
        if (snap.exists && mounted) {
          final d = snap.data()!;
          setState(() {
            _submitterName = (d['fullName'] as String?)?.trim() ?? _submitterName;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadProjects() async {
    try {
      final snap = await DB.colSync(_cid, C.rndProjects)
          .where('status', whereIn: ['In Progress', 'Testing'])
          .get();
      if (mounted) {
        setState(() {
          _projects = snap.docs.map((d) {
            final m = d.data();
            return {'id': d.id, 'title': m['title'] ?? '—'};
          }).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _submit({bool draft = false}) async {
    if (!draft && !(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a project.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await DB.colSync(_cid, C.rndUpdates).add({
        'projectId':        _selectedProjectId,
        'projectTitle':     _selectedProjectTitle ?? '',
        'date':             DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'progress':         _progress.round(),
        'workDone':         _workDoneCtrl.text.trim(),
        'testPerformed':    _testCtrl.text.trim(),
        'findings':         _findingsCtrl.text.trim(),
        'materialsUsed':    _materialsCtrl.text.trim(),
        'blockers':         _blockersCtrl.text.trim(),
        'supportNeeded':    _supportCtrl.text.trim(),
        'nextPlan':         _nextPlanCtrl.text.trim(),
        'submittedBy':      _submitterName ?? '',
        'submittedByEmail': _submitterEmail ?? '',
        'status':           draft ? 'Draft' : 'Submitted',
        'createdAt':        FieldValue.serverTimestamp(),
        'updatedAt':        FieldValue.serverTimestamp(),
      });

      // Update project progress
      if (!draft && _progress > 0) {
        await DB.colSync(_cid, C.rndProjects).doc(_selectedProjectId).update({
          'progress':  _progress.round(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(draft ? 'Draft saved.' : 'Update submitted!')));
        if (!draft) {
          _workDoneCtrl.clear(); _testCtrl.clear(); _findingsCtrl.clear();
          _materialsCtrl.clear(); _blockersCtrl.clear();
          _supportCtrl.clear(); _nextPlanCtrl.clear();
          setState(() => _progress = 0);
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
          // Submitter info
          if (_submitterName != null)
            _InfoBanner(_submitterName!, _submitterEmail ?? ''),

          // Project selector
          _label('Project *'),
          widget.projectId != null
              ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
            color: rndCardTint,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: rndBrand.withOpacity(0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.science_rounded, size: 16, color: rndBrand),
            const SizedBox(width: 8),
            Text(widget.projectTitle ?? '',
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600, color: rndBrand)),
                  ]),
                )
              : DropdownButtonFormField<String>(
                  value: _selectedProjectId,
                  hint: const Text('Select project',
                      style: TextStyle(fontSize: 13)),
                  onChanged: (v) {
                    setState(() {
                      _selectedProjectId = v;
                      _selectedProjectTitle = _projects
                          .firstWhere((p) => p['id'] == v,
                              orElse: () => {'title': ''})['title'];
                    });
                  },
                  items: _projects.map((p) => DropdownMenuItem(
                    value: p['id'] as String,
                    child: Text(p['title'] as String,
                        style: const TextStyle(fontSize: 13)),
                  )).toList(),
                  decoration: _inputDec(''),
                  validator: (v) => v == null ? 'Required' : null,
                ),

          // Progress slider
          _label('Progress (${_progress.round()}%)'),
          Slider(
            value: _progress,
            min: 0, max: 100, divisions: 20,
            activeColor: rndBrand,
            label: '${_progress.round()}%',
            onChanged: (v) => setState(() => _progress = v),
          ),

          _label('Work Done Today *'),
          _field(_workDoneCtrl, 'Describe what was accomplished today',
              maxLines: 4,
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null),

          _label('Test / Trial Performed'),
          _field(_testCtrl, 'Any experiments or tests run today', maxLines: 3),

          _label('Findings / Observations'),
          _field(_findingsCtrl, 'Key findings, data, or observations', maxLines: 3),

          _label('Materials Used'),
          _field(_materialsCtrl, 'List materials, chemicals, or resources used'),

          _label('Issues / Blockers'),
          _field(_blockersCtrl, 'Any blockers or problems encountered', maxLines: 2),

          _label('Support Needed'),
          _field(_supportCtrl, 'What support do you need from other teams?'),

          _label("Next Plan / Tomorrow's Work"),
          _field(_nextPlanCtrl, 'What is planned for the next session?', maxLines: 3),

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
                onPressed: _submitting ? null : _submit,
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
                    : const Text('Submit Update',
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
      decoration: _inputDec(hint),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
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
  );
}

class _InfoBanner extends StatelessWidget {
  final String name, email;
  const _InfoBanner(this.name, this.email);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: rndCardTint,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: rndBrand.withOpacity(0.25)),
    ),
    child: Row(children: [
      const Icon(Icons.person_rounded, size: 16, color: rndBrand),
      const SizedBox(width: 8),
      Expanded(child: Text('$name  ·  $email',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: rndBrand))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────
// UPDATE HISTORY
// ─────────────────────────────────────────────────────────────
class _UpdateHistory extends StatefulWidget {

  final String? projectId;
  const _UpdateHistory({this.projectId});
  @override
  State<_UpdateHistory> createState() => _UpdateHistoryState();
}

class _UpdateHistoryState extends State<_UpdateHistory> {
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
    Query<Map<String, dynamic>> q = DB.colSync(_cid, C.rndUpdates)
        .orderBy('createdAt', descending: true)
        .limit(30);

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
          return const Center(child: Text('No updates yet.',
              style: TextStyle(color: Colors.black38)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final m  = docs[i].data() as Map<String, dynamic>;
            final ts = m['createdAt'];
            final dt = ts is Timestamp ? ts.toDate() : null;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(m['projectTitle'] ?? '—',
                      style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w700))),
                  if (dt != null)
                    Text(DateFormat('d MMM, HH:mm').format(dt),
                        style: const TextStyle(fontSize: 11,
                            color: Colors.black38)),
                ]),
                const SizedBox(height: 4),
                Text('By ${m['submittedBy'] ?? '—'}',
                    style: const TextStyle(fontSize: 11, color: Colors.black38)),
                if ((m['workDone'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _UpdateRow(Icons.check_circle_outline_rounded,
                      'Work Done', m['workDone']),
                ],
                if ((m['findings'] ?? '').isNotEmpty)
                  _UpdateRow(Icons.biotech_rounded,
                      'Findings', m['findings']),
                if ((m['blockers'] ?? '').isNotEmpty)
                  _UpdateRow(Icons.warning_amber_rounded,
                      'Blockers', m['blockers'], color: Colors.orange),
                if ((m['nextPlan'] ?? '').isNotEmpty)
                  _UpdateRow(Icons.arrow_forward_rounded,
                      'Next Plan', m['nextPlan']),
                if ((m['progress'] ?? 0) > 0) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('Progress: ',
                        style: TextStyle(fontSize: 11, color: Colors.black45)),
                    Text('${m['progress']}%',
                        style: const TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w700, color: rndBrand)),
                  ]),
                ],
              ]),
            );
          },
        );
      },
    );
  }
}

class _UpdateRow extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  final Color    color;
  const _UpdateRow(this.icon, this.label, this.value,
      {this.color = rndBrand});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 6),
      Expanded(child: RichText(text: TextSpan(
        style: const TextStyle(fontSize: 12, color: Colors.black87),
        children: [
          TextSpan(text: '$label: ',
              style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          TextSpan(text: value),
        ],
      ))),
    ]),
  );
}
