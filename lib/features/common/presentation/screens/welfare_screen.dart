// lib/features/common/presentation/screens/welfare_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/features/common/welfare_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uddoygi/services/local_storage_service.dart';

// ─────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────


// Collection names are now resolved via DB.colSync(cid, C.welfareSchemes) etc.

String _fmtDate(dynamic v) {
  if (v == null) return '';
  DateTime? dt;
  if (v is Timestamp) dt = v.toDate();
  if (v is String) dt = DateTime.tryParse(v);
  if (dt == null) return '';
  return DateFormat('dd MMM yyyy').format(dt);
}

// ─────────────────────────────────────────────
// EMPLOYEE WELFARE SCREEN
// ─────────────────────────────────────────────
class WelfareScreen extends StatefulWidget {
  const WelfareScreen({super.key});

  @override
  State<WelfareScreen> createState() => _WelfareScreenState();
}

enum _Tab { schemes, myRequests }

class _WelfareScreenState extends State<WelfareScreen>
    with SingleTickerProviderStateMixin {
  String _cid = '';
  late final TabController _tab;

  String _userEmail  = '';
  String _userUid    = '';
  String _userName   = '';
  String _department = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _tab = TabController(length: 2, vsync: this);
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
      _userEmail  = (s?['email']      as String?) ?? '';
      _userUid    = (s?['uid']        as String?) ?? '';
      _userName   = (s?['name']       as String?) ?? _userEmail;
      _department = (s?['department'] as String?) ?? '';
    });
  }

  // ── Apply for a welfare scheme ──
  void _showApplyDialog(DocumentSnapshot scheme) {
    final m = scheme.data() as Map<String, dynamic>;
    final schemeTitle = m['title'] ?? 'Welfare Scheme';
    final maxAmount = (m['amount'] as num?)?.toDouble() ?? 0;

    final reasonC = TextEditingController();
    final amtC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: WC.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Text(
          'Apply for Welfare',
          style: GoogleFonts.ubuntu(fontWeight: FontWeight.w900, color: WC.text),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: WC.p2.withOpacity(.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: WC.p2.withOpacity(.2)),
                ),
                child: Text(schemeTitle,
                    style: GoogleFonts.ubuntu(fontWeight: FontWeight.w900, color: WC.p2)),
              ),
              const SizedBox(height: 12),
              _Field(
                controller: reasonC,
                label: 'Reason / Purpose',
                hint: 'Explain why you need this support',
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              _Field(
                controller: amtC,
                label: maxAmount > 0
                    ? 'Requested Amount (৳)  Max: ${NumberFormat.decimalPattern('en_BD').format(maxAmount.round())}'
                    : 'Requested Amount (৳)',
                hint: '0',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
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
            onPressed: () async {
              final reason = reasonC.text.trim();
              if (reason.isEmpty) return;
              final requestedAmount = double.tryParse(amtC.text.trim()) ?? 0;

              // Check if already applied for this scheme (company-scoped)
              final existing = await DB.colSync(_cid, C.welfareRequests)
                  .where('employeeEmail', isEqualTo: _userEmail)
                  .where('schemeId', isEqualTo: scheme.id)
                  .where('status', whereIn: ['Pending HR', 'Pending Admin', 'Approved'])
                  .get();

              if (existing.docs.isNotEmpty) {
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('You already have an active request for this scheme.',
                        style: GoogleFonts.ubuntu(fontWeight: FontWeight.w700)),
                    backgroundColor: WC.amber,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
                return;
              }

              await DB.colSync(_cid, C.welfareRequests).add({
                'schemeId':        scheme.id,
                'schemeTitle':     schemeTitle,
                'employeeEmail':   _userEmail,
                'employeeUid':     _userUid,
                'employeeName':    _userName,
                'department':      _department,
                'reason':          reason,
                'requestedAmount': requestedAmount,
                'status':          'Pending HR',
                'submittedAt':     FieldValue.serverTimestamp(),
                'hrNote':          '',
                'adminNote':       '',
              });

              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Request submitted successfully!',
                      style: GoogleFonts.ubuntu(fontWeight: FontWeight.w700)),
                  backgroundColor: WC.green,
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            child: Text('Submit Request',
                style: GoogleFonts.ubuntu(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WC.bg,
      appBar: AppBar(
        elevation: 0,
        title: Text('Welfare Schemes',
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
          tabs: const [
            Tab(text: 'Available Schemes'),
            Tab(text: 'My Requests'),
          ],
        ),
      ),
      body: _cid.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _AvailableSchemesTab(cid: _cid, onApply: _showApplyDialog),
                _MyRequestsTab(cid: _cid, userEmail: _userEmail),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────
// TAB 1 — AVAILABLE SCHEMES
// ─────────────────────────────────────────────
class _AvailableSchemesTab extends StatelessWidget {
  final String cid;
  final void Function(DocumentSnapshot) onApply;
  const _AvailableSchemesTab({required this.cid, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: DB.colSync(cid, C.welfareSchemes)
          .where('active', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _Shimmer();
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _Empty(
            icon: Icons.volunteer_activism_rounded,
            message: 'No welfare schemes available at the moment.\nCheck back later.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          itemCount: docs.length,
          itemBuilder: (_, i) => _SchemeCard(
            doc: docs[i],
            onApply: onApply,
          ).animate().fadeIn(duration: 200.ms).slideY(begin: .04),
        );
      },
    );
  }
}

class _SchemeCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final void Function(DocumentSnapshot) onApply;
  const _SchemeCard({required this.doc, required this.onApply});

  Color _catColor(String cat) {
    switch (cat) {
      case 'Medical': return WC.red;
      case 'Education': return WC.cyan;
      case 'Housing': return WC.amber;
      case 'Emergency': return Colors.orange;
      default: return WC.p3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m           = doc.data() as Map<String, dynamic>;
    final title       = m['title']       ?? 'Untitled';
    final desc        = m['description'] ?? '';
    final eligibility = m['eligibility'] ?? '';
    final amount      = (m['amount'] as num?)?.toDouble() ?? 0;
    final category    = m['category']    ?? 'Other';
    final publishedBy = m['publishedBy'] ?? '';
    final date        = _fmtDate(m['timestamp']);
    final catColor    = _catColor(category);

    // Show "NEW" badge if published within the last 48 hours
    final ts = m['timestamp'];
    final isNew = ts is Timestamp &&
        DateTime.now().difference(ts.toDate()).inHours < 48;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: WC.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isNew ? WC.p2.withOpacity(.4) : WC.border, width: isNew ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header gradient
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              gradient: LinearGradient(
                colors: [WC.p1.withOpacity(.92), WC.p2.withOpacity(.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(.25),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: catColor.withOpacity(.5)),
                  ),
                  child: Text(category,
                      style: GoogleFonts.ubuntu(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ubuntu(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15)),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc,
                    style: GoogleFonts.ubuntu(color: WC.text, fontWeight: FontWeight.w600, fontSize: 13)),
                if (eligibility.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: WC.green.withOpacity(.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: WC.green.withOpacity(.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 14, color: WC.green),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Eligibility: $eligibility',
                              style: GoogleFonts.ubuntu(fontSize: 12, fontWeight: FontWeight.w700, color: WC.text)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (amount > 0) ...[
                      _InfoChip(
                        label: 'Up to ৳ ${NumberFormat.decimalPattern('en_BD').format(amount.round())}',
                        icon: Icons.payments_rounded,
                        color: WC.green,
                      ),
                      const SizedBox(width: 8),
                    ],
                    _InfoChip(label: publishedBy, icon: Icons.admin_panel_settings_rounded, color: WC.p2),
                    const Spacer(),
                    Text(date, style: GoogleFonts.ubuntu(fontSize: 11, fontWeight: FontWeight.w700, color: WC.text2)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: WC.p2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: Text('Apply for this Scheme',
                        style: GoogleFonts.ubuntu(fontWeight: FontWeight.w900)),
                    onPressed: () => onApply(doc),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TAB 2 — MY REQUESTS
// ─────────────────────────────────────────────
class _MyRequestsTab extends StatelessWidget {
  final String cid;
  final String userEmail;
  const _MyRequestsTab({required this.cid, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    if (userEmail.isEmpty) {
      return const _Empty(icon: Icons.person_off_rounded, message: 'Could not load your profile.');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: DB.colSync(cid, C.welfareRequests)
          .where('employeeEmail', isEqualTo: userEmail)
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const _Shimmer();
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _Empty(
            icon: Icons.inbox_rounded,
            message: 'You haven\'t submitted any welfare requests yet.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          itemCount: docs.length,
          itemBuilder: (_, i) => _MyRequestCard(doc: docs[i])
              .animate()
              .fadeIn(duration: 200.ms)
              .slideY(begin: .04),
        );
      },
    );
  }
}

class _MyRequestCard extends StatelessWidget {
  final DocumentSnapshot doc;
  const _MyRequestCard({required this.doc});

  Color _statusColor(String s) {
    switch (s) {
      case 'Approved': return WC.green;
      case 'Rejected': return WC.red;
      case 'Declined': return WC.red;
      case 'Pending Admin': return WC.amber;
      default: return WC.cyan;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'Approved': return Icons.check_circle_rounded;
      case 'Rejected': return Icons.cancel_rounded;
      case 'Declined': return Icons.cancel_rounded;
      case 'Pending Admin': return Icons.pending_rounded;
      default: return Icons.hourglass_top_rounded;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'Pending HR': return 'Awaiting HR Review';
      case 'Pending Admin': return 'Awaiting Admin Approval';
      case 'Approved': return 'Approved';
      case 'Rejected': return 'Rejected by Admin';
      case 'Declined': return 'Declined by HR';
      default: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = doc.data() as Map<String, dynamic>;
    final schemeTitle = m['schemeTitle'] ?? 'Welfare Request';
    final reason = m['reason'] ?? '';
    final amount = (m['requestedAmount'] as num?)?.toDouble() ?? 0;
    final status = m['status'] ?? 'Pending HR';
    final submittedAt = _fmtDate(m['submittedAt']);
    final hrNote = m['hrNote'] ?? '';
    final adminNote = m['adminNote'] ?? '';
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: WC.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(.3), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge + scheme title
            Row(
              children: [
                Expanded(
                  child: Text(schemeTitle,
                      style: GoogleFonts.ubuntu(fontWeight: FontWeight.w900, color: WC.p2, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withOpacity(.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status), size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(_statusLabel(status),
                          style: GoogleFonts.ubuntu(fontSize: 10, fontWeight: FontWeight.w900, color: statusColor)),
                    ],
                  ),
                ),
              ],
            ),

            // Progress stepper
            const SizedBox(height: 12),
            _StatusStepper(status: status),
            const SizedBox(height: 12),

            if (reason.isNotEmpty)
              Text(reason,
                  style: GoogleFonts.ubuntu(fontSize: 12, fontWeight: FontWeight.w600, color: WC.text),
                  maxLines: 3, overflow: TextOverflow.ellipsis),

            const SizedBox(height: 8),
            Row(
              children: [
                if (amount > 0) ...[
                  _InfoChip(
                    label: '৳ ${NumberFormat.decimalPattern('en_BD').format(amount.round())}',
                    icon: Icons.payments_rounded,
                    color: WC.green,
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                Text(submittedAt,
                    style: GoogleFonts.ubuntu(fontSize: 11, fontWeight: FontWeight.w700, color: WC.text2)),
              ],
            ),

            if (hrNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              _NoteBox(label: 'HR Note', note: hrNote, color: WC.cyan),
            ],
            if (adminNote.isNotEmpty) ...[
              const SizedBox(height: 6),
              _NoteBox(label: 'Admin Note', note: adminNote, color: WC.red),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STATUS STEPPER
// ─────────────────────────────────────────────
class _StatusStepper extends StatelessWidget {
  final String status;
  const _StatusStepper({required this.status});

  @override
  Widget build(BuildContext context) {
    final steps = ['Submitted', 'HR Review', 'Admin Decision'];
    int activeStep;
    bool rejected = false;

    switch (status) {
      case 'Pending HR':
        activeStep = 0;
        break;
      case 'Pending Admin':
        activeStep = 1;
        break;
      case 'Approved':
        activeStep = 2;
        break;
      case 'Rejected':
        activeStep = 2;
        rejected = true;
        break;
      case 'Declined':
        activeStep = 1;
        rejected = true;
        break;
      default:
        activeStep = 0;
    }

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final stepIdx = i ~/ 2;
          final filled = stepIdx < activeStep;
          return Expanded(
            child: Container(
              height: 2,
              color: filled ? WC.p2 : WC.border,
            ),
          );
        }
        final stepIdx = i ~/ 2;
        final done = stepIdx < activeStep;
        final current = stepIdx == activeStep;
        final isRejected = current && rejected;
        final color = isRejected ? WC.red : (done || current ? WC.p2 : WC.border);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 22, width: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? WC.p2 : (current ? (isRejected ? WC.red : WC.p2) : Colors.transparent),
                border: Border.all(color: color, width: 2),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                  : (current && isRejected
                      ? const Icon(Icons.close_rounded, size: 12, color: Colors.white)
                      : (current
                          ? Container(
                              margin: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                            )
                          : null)),
            ),
            const SizedBox(height: 4),
            Text(steps[stepIdx],
                style: GoogleFonts.ubuntu(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: (done || current) ? WC.text : WC.text2,
                )),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.ubuntu(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notes_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.ubuntu(fontSize: 12, fontWeight: FontWeight.w700, color: WC.text),
                children: [
                  TextSpan(text: '$label: ', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                  TextSpan(text: note),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputType keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
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
        hintStyle: GoogleFonts.ubuntu(color: WC.text2.withOpacity(.6), fontWeight: FontWeight.w600),
        filled: true,
        fillColor: WC.bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: WC.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: WC.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: WC.p2, width: 1.5),
        ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: WC.border),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.ubuntu(fontWeight: FontWeight.w700, color: WC.text2)),
        ],
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer();

  @override
  Widget build(BuildContext context) {
    Widget box({double h = 120}) => Container(
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
        child: Column(
          children: [
            box(), const SizedBox(height: 12),
            box(), const SizedBox(height: 12),
            box(h: 100),
          ],
        ),
      ),
    );
  }
}
