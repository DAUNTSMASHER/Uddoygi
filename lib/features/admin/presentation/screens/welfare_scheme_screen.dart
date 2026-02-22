// lib/features/admin/presentation/screens/welfare_scheme_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/features/common/welfare_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uddoygi/services/local_storage_service.dart';

String _fmtDate(dynamic v) {
  if (v == null) return '';
  DateTime? dt;
  if (v is Timestamp) dt = v.toDate();
  if (v is String) dt = DateTime.tryParse(v);
  if (dt == null) return '';
  return DateFormat('dd MMM yyyy').format(dt);
}

// ─────────────────────────────────────────────
// ADMIN WELFARE SCREEN
// ─────────────────────────────────────────────
class WelfareSchemeScreen extends StatefulWidget {
  const WelfareSchemeScreen({super.key});
  @override
  State<WelfareSchemeScreen> createState() => _WelfareSchemeScreenState();
}

class _WelfareSchemeScreenState extends State<WelfareSchemeScreen>
    with SingleTickerProviderStateMixin {
  String _cid = '';
  late final TabController _tab;
  String _adminName  = 'Admin';
  String _adminEmail = '';
  String _filter     = 'All';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _loadSession();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final s = await LocalStorageService.getSession();
    if (!mounted) return;
    setState(() {
      _adminEmail = (s?['email'] as String?) ?? '';
      _adminName  = (s?['name']  as String?) ?? _adminEmail;
    });
  }

  // ── Fan-out: write a notification doc for every user in the company ──
  Future<void> _notifyAllUsers({
    required String schemeId,
    required String schemeTitle,
    required String category,
  }) async {
    if (_cid.isEmpty) return;
    try {
      final usersSnap = await DB.colSync(_cid, C.users).get();
      final batch = DB.firestore.batch();
      for (final u in usersSnap.docs) {
        final email = (u.data()['email'] ?? u.data()['officeEmail'] ?? '') as String;
        if (email.isEmpty) continue;
        final ref = DB.colSync(_cid, C.notifications).doc();
        batch.set(ref, {
          'to':        email,
          'toUserId':  u.id,
          'type':      'welfare_scheme',
          'title':     '🎁 New Welfare Scheme',
          'body':      '$schemeTitle ($category) is now available. Tap to apply.',
          'schemeId':  schemeId,
          'read':      false,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Welfare notification fan-out failed: $e');
    }
  }

  // ── Publish / Edit dialog ──
  void _showPublishDialog({DocumentSnapshot? existing}) {
    final titleC = TextEditingController(text: existing?.get('title') ?? '');
    final descC  = TextEditingController(text: existing?.get('description') ?? '');
    final eligC  = TextEditingController(text: existing?.get('eligibility') ?? '');
    final amtC   = TextEditingController(
        text: existing != null ? (existing.get('amount') ?? '').toString() : '');
    String category = existing?.get('category') ?? 'Medical';
    bool   notify   = existing == null; // default ON for new schemes
    final categories = ['Medical', 'Education', 'Housing', 'Emergency', 'Other'];
    bool   saving    = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: WC.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding:   const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Text(
            existing == null ? 'Publish Welfare Scheme' : 'Edit Scheme',
            style: GoogleFonts.ubuntu(fontWeight: FontWeight.w900, color: WC.text),
          ),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 4),
              _Field(controller: titleC, label: 'Scheme Title',
                  hint: 'e.g. Medical Support Fund'),
              const SizedBox(height: 10),
              _Field(controller: descC, label: 'Description',
                  hint: 'Details about the scheme', maxLines: 3),
              const SizedBox(height: 10),
              _Field(controller: eligC, label: 'Eligibility',
                  hint: 'Who can apply?'),
              const SizedBox(height: 10),
              _Field(controller: amtC, label: 'Max Amount (৳)', hint: '0',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: category,
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: GoogleFonts.ubuntu(color: WC.text2, fontWeight: FontWeight.w700),
                  filled: true, fillColor: WC.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: WC.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: WC.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: categories.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c, style: GoogleFonts.ubuntu(fontWeight: FontWeight.w700)),
                )).toList(),
                onChanged: (v) => setSt(() => category = v ?? category),
              ),

              // ── Notify toggle (new schemes only) ──
              if (existing == null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: WC.p2.withOpacity(.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: WC.p2.withOpacity(.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.notifications_active_rounded,
                        size: 18, color: WC.p2),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Notify all employees',
                          style: GoogleFonts.ubuntu(
                              fontWeight: FontWeight.w800, color: WC.text, fontSize: 13)),
                    ),
                    Switch(
                      value: notify,
                      activeColor: WC.p2,
                      onChanged: (v) => setSt(() => notify = v),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.ubuntu(fontWeight: FontWeight.w700, color: WC.text2)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: WC.p2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: saving ? null : () async {
                final title = titleC.text.trim();
                final desc  = descC.text.trim();
                if (title.isEmpty || desc.isEmpty) return;
                setSt(() => saving = true);

                final data = {
                  'title':            title,
                  'description':      desc,
                  'eligibility':      eligC.text.trim(),
                  'amount':           double.tryParse(amtC.text.trim()) ?? 0,
                  'category':         category,
                  'publishedBy':      _adminName,
                  'publishedByEmail': _adminEmail,
                  'active':           true,
                  'timestamp':        FieldValue.serverTimestamp(),
                  'createdAt':        FieldValue.serverTimestamp(),
                };

                String schemeId;
                if (existing == null) {
                  // Use company-scoped collection
                  final ref = await DB.colSync(_cid, C.welfareSchemes).add(data);
                  schemeId = ref.id;
                  // Fan-out notification to all company users
                  if (notify) {
                    await _notifyAllUsers(
                      schemeId: schemeId,
                      schemeTitle: title,
                      category: category,
                    );
                  }
                } else {
                  await existing.reference.update(data);
                  schemeId = existing.id;
                }

                setSt(() => saving = false);
                if (ctx.mounted) Navigator.pop(ctx);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                      existing == null
                          ? notify
                              ? 'Scheme published and employees notified!'
                              : 'Scheme published.'
                          : 'Scheme updated.',
                      style: GoogleFonts.ubuntu(fontWeight: FontWeight.w700),
                    ),
                    backgroundColor: WC.green,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              child: saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(existing == null ? 'Publish' : 'Update',
                      style: GoogleFonts.ubuntu(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleScheme(DocumentSnapshot doc) async {
    final current = doc.get('active') as bool? ?? true;
    await doc.reference.update({'active': !current});
  }

  Future<void> _deleteScheme(DocumentSnapshot doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Scheme?',
            style: GoogleFonts.ubuntu(fontWeight: FontWeight.w900)),
        content: Text('This will permanently remove the scheme.',
            style: GoogleFonts.ubuntu(color: WC.text2, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.ubuntu(fontWeight: FontWeight.w700, color: WC.text2))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: WC.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.ubuntu(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (ok == true) await doc.reference.delete();
  }

  Future<void> _adminDecision(DocumentSnapshot doc, String decision) async {
    String note = '';
    if (decision == 'Rejected') {
      final noteC = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Rejection Reason',
              style: GoogleFonts.ubuntu(fontWeight: FontWeight.w900)),
          content: _Field(controller: noteC, label: 'Reason',
              hint: 'Optional note for the employee', maxLines: 2),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style: GoogleFonts.ubuntu(fontWeight: FontWeight.w700, color: WC.text2))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: WC.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () { note = noteC.text.trim(); Navigator.pop(ctx, true); },
              child: Text('Reject', style: GoogleFonts.ubuntu(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    await doc.reference.update({
      'status':           decision,
      'adminNote':        note,
      'adminDecisionBy':  _adminName,
      'adminDecisionAt':  FieldValue.serverTimestamp(),
    });

    // Notify the employee of the decision
    final m = doc.data() as Map<String, dynamic>;
    final empEmail  = (m['employeeEmail'] ?? '') as String;
    final empUid    = (m['employeeUid']   ?? '') as String;
    final schemeTtl = (m['schemeTitle']   ?? 'Welfare Request') as String;
    if (empEmail.isNotEmpty && _cid.isNotEmpty) {
      try {
        await DB.colSync(_cid, C.notifications).add({
          'to':        empEmail,
          'toUserId':  empUid,
          'type':      'welfare_decision',
          'title':     decision == 'Approved'
              ? '✅ Welfare Request Approved'
              : '❌ Welfare Request Rejected',
          'body':      decision == 'Approved'
              ? 'Your request for "$schemeTtl" has been approved.'
              : 'Your request for "$schemeTtl" was rejected. ${note.isNotEmpty ? "Reason: $note" : ""}',
          'read':      false,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Request $decision',
            style: GoogleFonts.ubuntu(fontWeight: FontWeight.w700)),
        backgroundColor: decision == 'Approved' ? WC.green : WC.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WC.bg,
      appBar: AppBar(
        elevation: 0,
        title: Text('Welfare Management',
            style: GoogleFonts.ubuntu(fontWeight: FontWeight.w900, color: Colors.white)),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [WC.p1, WC.p2, WC.p3],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.ubuntu(fontWeight: FontWeight.w900, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.ubuntu(fontWeight: FontWeight.w700, fontSize: 13),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [Tab(text: 'Schemes'), Tab(text: 'Requests')],
        ),
        actions: [
          IconButton(
            tooltip: 'Publish new scheme',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () {
              HapticFeedback.lightImpact();
              _showPublishDialog();
            },
          ),
        ],
      ),
      body: _cid.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _SchemesTab(
                  cid: _cid,
                  onEdit: (doc) => _showPublishDialog(existing: doc),
                  onToggle: _toggleScheme,
                  onDelete: _deleteScheme,
                ),
                _RequestsTab(
                  cid: _cid,
                  filter: _filter,
                  onFilterChanged: (v) => setState(() => _filter = v),
                  onDecision: _adminDecision,
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────
// TAB 1 — SCHEMES
// ─────────────────────────────────────────────
class _SchemesTab extends StatelessWidget {
  final String cid;
  final void Function(DocumentSnapshot) onEdit;
  final void Function(DocumentSnapshot) onToggle;
  final void Function(DocumentSnapshot) onDelete;
  const _SchemesTab({
    required this.cid,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: DB.colSync(cid, C.welfareSchemes)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _Shimmer();
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _Empty(
            icon: Icons.volunteer_activism_rounded,
            message: 'No welfare schemes published yet.\nTap + to publish one.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          itemCount: docs.length,
          itemBuilder: (_, i) => _SchemeCard(
            doc: docs[i],
            onEdit: onEdit,
            onToggle: onToggle,
            onDelete: onDelete,
          ).animate().fadeIn(duration: 200.ms).slideY(begin: .04),
        );
      },
    );
  }
}

class _SchemeCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final void Function(DocumentSnapshot) onEdit;
  final void Function(DocumentSnapshot) onToggle;
  final void Function(DocumentSnapshot) onDelete;
  const _SchemeCard({
    required this.doc, required this.onEdit,
    required this.onToggle, required this.onDelete,
  });

  Color _catColor(String cat) {
    switch (cat) {
      case 'Medical':   return WC.red;
      case 'Education': return WC.cyan;
      case 'Housing':   return WC.amber;
      case 'Emergency': return Colors.orange;
      default:          return WC.p3;
    }
  }

  bool _isNew(dynamic ts) {
    if (ts == null) return false;
    final dt = ts is Timestamp ? ts.toDate() : null;
    if (dt == null) return false;
    return DateTime.now().difference(dt).inHours < 48;
  }

  @override
  Widget build(BuildContext context) {
    final m           = doc.data() as Map<String, dynamic>;
    final title       = m['title']       ?? 'Untitled';
    final desc        = m['description'] ?? '';
    final eligibility = m['eligibility'] ?? '';
    final amount      = (m['amount'] as num?)?.toDouble() ?? 0;
    final category    = m['category']    ?? 'Other';
    final active      = m['active']      as bool? ?? true;
    final publishedBy = m['publishedBy'] ?? '';
    final date        = _fmtDate(m['timestamp']);
    final catColor    = _catColor(category);
    final isNew       = _isNew(m['timestamp']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: WC.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: active ? WC.border : WC.border.withOpacity(.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04),
            blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            gradient: LinearGradient(
              colors: [WC.p1.withOpacity(.92), WC.p2.withOpacity(.85)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: catColor.withOpacity(.2),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: catColor.withOpacity(.4)),
              ),
              child: Text(category,
                  style: GoogleFonts.ubuntu(
                      fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
            const SizedBox(width: 8),
            if (isNew)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.shade400,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('NEW',
                    style: GoogleFonts.ubuntu(
                        fontSize: 9, fontWeight: FontWeight.w900,
                        color: Colors.white, letterSpacing: .5)),
              ),
            Expanded(
              child: Text(title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.ubuntu(
                      fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15)),
            ),
            if (!active)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Inactive',
                    style: GoogleFonts.ubuntu(
                        fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white70)),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (v) {
                if (v == 'edit')   onEdit(doc);
                if (v == 'toggle') onToggle(doc);
                if (v == 'delete') onDelete(doc);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit',
                    child: _PopItem(icon: Icons.edit_rounded, label: 'Edit')),
                PopupMenuItem(value: 'toggle',
                    child: _PopItem(
                      icon: active ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      label: active ? 'Deactivate' : 'Activate',
                    )),
                PopupMenuItem(value: 'delete',
                    child: _PopItem(icon: Icons.delete_rounded,
                        label: 'Delete', color: WC.red)),
              ],
            ),
          ]),
        ),

        // Body
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(desc,
                style: GoogleFonts.ubuntu(
                    color: WC.text, fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 3, overflow: TextOverflow.ellipsis),
            if (eligibility.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.check_circle_outline_rounded, size: 14, color: WC.text2),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('Eligibility: $eligibility',
                      style: GoogleFonts.ubuntu(
                          fontSize: 12, fontWeight: FontWeight.w700, color: WC.text2),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
            const SizedBox(height: 10),
            Row(children: [
              if (amount > 0) ...[
                _InfoChip(
                  label: '৳ ${NumberFormat.decimalPattern('en_BD').format(amount.round())}',
                  icon: Icons.payments_rounded, color: WC.green,
                ),
                const SizedBox(width: 8),
              ],
              _InfoChip(label: 'By $publishedBy',
                  icon: Icons.person_rounded, color: WC.p2),
              const Spacer(),
              Text(date,
                  style: GoogleFonts.ubuntu(
                      fontSize: 11, fontWeight: FontWeight.w700, color: WC.text2)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// TAB 2 — REQUESTS (admin view)
// ─────────────────────────────────────────────
class _RequestsTab extends StatelessWidget {
  final String cid;
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final Future<void> Function(DocumentSnapshot, String) onDecision;
  const _RequestsTab({
    required this.cid,
    required this.filter,
    required this.onFilterChanged,
    required this.onDecision,
  });

  static const _filters = ['All', 'Pending HR', 'Pending Admin', 'Approved', 'Rejected'];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: WC.card,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((f) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f,
                    style: GoogleFonts.ubuntu(fontWeight: FontWeight.w800, fontSize: 12)),
                selected: filter == f,
                onSelected: (_) => onFilterChanged(f),
                selectedColor: WC.p2,
                checkmarkColor: Colors.white,
                labelStyle: GoogleFonts.ubuntu(
                  fontWeight: FontWeight.w800, fontSize: 12,
                  color: filter == f ? Colors.white : WC.text2,
                ),
                backgroundColor: WC.bg,
                side: BorderSide(color: filter == f ? WC.p2 : WC.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
            )).toList(),
          ),
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: DB.colSync(cid, C.welfareRequests)
              .orderBy('submittedAt', descending: true)
              .snapshots(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const _Shimmer();
            var docs = snap.data?.docs ?? [];
            if (filter != 'All') {
              docs = docs.where((d) {
                final status = (d.data() as Map)['status'] ?? '';
                return status == filter;
              }).toList();
            }
            if (docs.isEmpty) {
              return _Empty(
                icon: Icons.inbox_rounded,
                message: filter == 'All'
                    ? 'No welfare requests yet.'
                    : 'No "$filter" requests.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              itemCount: docs.length,
              itemBuilder: (_, i) => _RequestCard(
                doc: docs[i],
                onDecision: onDecision,
                isAdmin: true,
              ).animate().fadeIn(duration: 200.ms).slideY(begin: .04),
            );
          },
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
// REQUEST CARD
// ─────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final Future<void> Function(DocumentSnapshot, String) onDecision;
  final bool isAdmin;
  const _RequestCard({
    required this.doc, required this.onDecision, required this.isAdmin,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'Approved':      return WC.green;
      case 'Rejected':      return WC.red;
      case 'Declined':      return WC.red;
      case 'Pending Admin': return WC.amber;
      default:              return WC.cyan;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'Approved':      return Icons.check_circle_rounded;
      case 'Rejected':      return Icons.cancel_rounded;
      case 'Declined':      return Icons.cancel_rounded;
      case 'Pending Admin': return Icons.pending_rounded;
      default:              return Icons.hourglass_top_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m            = doc.data() as Map<String, dynamic>;
    final employeeName = m['employeeName']    ?? 'Unknown';
    final employeeEmail= m['employeeEmail']   ?? '';
    final department   = m['department']      ?? '';
    final schemeTitle  = m['schemeTitle']     ?? 'Welfare Request';
    final reason       = m['reason']          ?? '';
    final amount       = (m['requestedAmount'] as num?)?.toDouble() ?? 0;
    final status       = m['status']          ?? 'Pending HR';
    final submittedAt  = _fmtDate(m['submittedAt']);
    final hrNote       = m['hrNote']          ?? '';
    final adminNote    = m['adminNote']       ?? '';
    final statusColor  = _statusColor(status);
    final canAdminAct  = isAdmin  && status == 'Pending Admin';
    final canHrAct     = !isAdmin && status == 'Pending HR';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: WC.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WC.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03),
            blurRadius: 12, offset: const Offset(0, 5))],
      ),
            child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _Avatar(name: employeeName),
            const SizedBox(width: 10),
                      Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(employeeName,
                    style: GoogleFonts.ubuntu(
                        fontWeight: FontWeight.w900, color: WC.text),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('$department  ·  $employeeEmail',
                    style: GoogleFonts.ubuntu(
                        fontSize: 11, fontWeight: FontWeight.w700, color: WC.text2),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: statusColor.withOpacity(.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_statusIcon(status), size: 12, color: statusColor),
                const SizedBox(width: 4),
                Text(status,
                    style: GoogleFonts.ubuntu(
                        fontSize: 11, fontWeight: FontWeight.w900, color: statusColor)),
              ]),
            ),
          ]),

          const SizedBox(height: 10),
          const Divider(height: 1, color: WC.border),
          const SizedBox(height: 10),

          Text(schemeTitle,
              style: GoogleFonts.ubuntu(
                  fontWeight: FontWeight.w900, color: WC.p2, fontSize: 13)),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(reason,
                style: GoogleFonts.ubuntu(
                    fontSize: 12, fontWeight: FontWeight.w600, color: WC.text),
                maxLines: 3, overflow: TextOverflow.ellipsis),
          ],

          const SizedBox(height: 10),
          Row(children: [
            if (amount > 0) ...[
              _InfoChip(
                label: '৳ ${NumberFormat.decimalPattern('en_BD').format(amount.round())}',
                icon: Icons.payments_rounded, color: WC.green,
              ),
              const SizedBox(width: 8),
            ],
            const Spacer(),
            Text(submittedAt,
                style: GoogleFonts.ubuntu(
                    fontSize: 11, fontWeight: FontWeight.w700, color: WC.text2)),
          ]),

          if (hrNote.isNotEmpty) ...[
                  const SizedBox(height: 8),
            _NoteBox(label: 'HR Note', note: hrNote, color: WC.cyan),
          ],
          if (adminNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            _NoteBox(label: 'Admin Note', note: adminNote, color: WC.red),
          ],

          if (canAdminAct || canHrAct) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WC.red,
                    side: const BorderSide(color: WC.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: Text(isAdmin ? 'Reject' : 'Decline',
                      style: GoogleFonts.ubuntu(fontWeight: FontWeight.w900, fontSize: 13)),
                  onPressed: () => onDecision(doc, isAdmin ? 'Rejected' : 'Declined'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isAdmin ? WC.green : WC.p2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: Icon(isAdmin ? Icons.check_rounded : Icons.verified_rounded,
                      size: 16),
                  label: Text(isAdmin ? 'Approve' : 'Verify & Forward',
                      style: GoogleFonts.ubuntu(fontWeight: FontWeight.w900, fontSize: 13)),
                  onPressed: () =>
                      onDecision(doc, isAdmin ? 'Approved' : 'Pending Admin'),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ─────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  String get _initials {
    final p = name.trim().split(RegExp(r'\s+'));
    final a = p.isNotEmpty && p.first.isNotEmpty ? p.first[0] : 'U';
    final b = p.length > 1 && p[1].isNotEmpty ? p[1][0] : '';
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40, width: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [WC.p1, WC.p2, WC.p3],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(_initials,
          style: GoogleFonts.ubuntu(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _InfoChip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.ubuntu(
                fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

class _NoteBox extends StatelessWidget {
  final String label;
  final String note;
  final Color color;
  const _NoteBox({required this.label, required this.note, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.notes_rounded, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.ubuntu(
                  fontSize: 12, fontWeight: FontWeight.w700, color: WC.text),
              children: [
                TextSpan(text: '$label: ',
                    style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                TextSpan(text: note),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _PopItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _PopItem({required this.icon, required this.label, this.color = WC.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Text(label, style: GoogleFonts.ubuntu(fontWeight: FontWeight.w800, color: color)),
    ]);
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputType keyboardType;
  const _Field({
    required this.controller, required this.label, required this.hint,
    this.maxLines = 1, this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.ubuntu(fontWeight: FontWeight.w700, color: WC.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.ubuntu(color: WC.text2, fontWeight: FontWeight.w700),
        hintStyle: GoogleFonts.ubuntu(
            color: WC.text2.withOpacity(.6), fontWeight: FontWeight.w600),
        filled: true, fillColor: WC.bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: WC.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: WC.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: WC.p2, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String message;
  const _Empty({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 52, color: WC.border),
        const SizedBox(height: 12),
        Text(message,
            textAlign: TextAlign.center,
            style: GoogleFonts.ubuntu(fontWeight: FontWeight.w700, color: WC.text2)),
      ]),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer();

  @override
  Widget build(BuildContext context) {
    Widget box({double h = 100}) => Container(
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WC.border),
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(children: [
          box(h: 120), const SizedBox(height: 12),
          box(h: 120), const SizedBox(height: 12),
          box(h: 100),
        ]),
      ),
    );
  }
}
