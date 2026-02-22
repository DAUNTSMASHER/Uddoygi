// lib/features/hr/presentation/screens/loan_approval_screen.dart
// HR-facing board to review/approve/reject/disburse employee loans.
// PER-AGENT repayments are FIFO across all loans.
// Includes PDF export (loans + repayments by date) saved to App Documents + share.
// Auto-hides agents that have zero outstanding across all repayable loans.

import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _primary   = Color(0xFF065F46); // HR deep green
const Color _primaryMd = Color(0xFF059669); // medium green
const Color _primaryLt = Color(0xFFD1FAE5); // light green tint
const Color _surface   = Color(0xFFF7F9FC); // page background
const Color _card      = Color(0xFFFFFFFF); // card background
const Color _fg        = Color(0xFF0F172A); // primary text
const Color _muted     = Color(0xFF64748B); // secondary text
const Color _border    = Color(0xFFE2E8F0); // card border
const Color _danger    = Color(0xFFDC2626);
const Color _warn      = Color(0xFFF97316);
const Color _info      = Color(0xFF2563EB);

// ── Status colours ────────────────────────────────────────────────────────────
Color _statusColor(String s) {
  switch (s) {
    case 'pending':   return _warn;
    case 'approved':  return _info;
    case 'rejected':  return _danger;
    case 'disbursed': return _primaryMd;
    case 'closed':    return _muted;
    case 'withdrawn': return _muted;
    default:          return _muted;
  }
}

IconData _statusIcon(String s) {
  switch (s) {
    case 'pending':   return Icons.hourglass_top_rounded;
    case 'approved':  return Icons.thumb_up_rounded;
    case 'rejected':  return Icons.cancel_rounded;
    case 'disbursed': return Icons.payments_rounded;
    case 'closed':    return Icons.check_circle_rounded;
    default:          return Icons.help_rounded;
  }
}

class LoanApprovalScreen extends StatefulWidget {
  const LoanApprovalScreen({super.key});
  @override
  State<LoanApprovalScreen> createState() => _LoanApprovalScreenState();
}

class _LoanApprovalScreenState extends State<LoanApprovalScreen>
    with SingleTickerProviderStateMixin {
  String _cid = '';

  final _auth  = FirebaseAuth.instance;
  final _money = NumberFormat.currency(locale: 'en_BD', symbol: '৳', decimalDigits: 0);
  final _date  = DateFormat('d MMM yyyy');

  late TabController _tabs;
  String _search    = '';
  String _statusAll = 'all';

  final ScrollController _scrollCtrl = ScrollController();
  final Map<String, num> _loanRepaidCache  = {};
  final Map<String, num> _agentRepaidCache = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Streams ───────────────────────────────────────────────────────────────
  Stream<QuerySnapshot<Map<String, dynamic>>> _stream({required bool onlyPending}) {
    Query<Map<String, dynamic>> q =
        DB.colSync(_cid, C.loans).orderBy('requestedAt', descending: true);
    if (onlyPending) q = q.where('status', isEqualTo: 'pending');
    return q.snapshots();
  }

  Stream<int> _countStatus(String status) async* {
    yield* DB.colSync(_cid, C.loans)
        .where('status', isEqualTo: status)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<num> _sumApprovedPrincipal() {
    return DB.colSync(_cid, C.loans)
        .where('status', whereIn: ['approved', 'disbursed', 'closed'])
        .snapshots()
        .map((s) => s.docs.fold<num>(
              0, (sum, d) => sum + (d.data()['amount'] as num? ?? 0)));
  }

  Stream<num> _sumAllRepaid() {
    return DB.colSync(_cid, C.loans)
        .where('status', whereIn: ['approved', 'disbursed', 'closed'])
        .snapshots()
        .asyncMap((loansSnap) async {
      num total = 0;
      for (final loan in loansSnap.docs) {
        final repSnap =
            await DB.subColSync(_cid, C.loans, loan.id, C.repayments).get();
        total += repSnap.docs
            .fold<num>(0, (s, d) => s + (d.data()['amount'] as num? ?? 0));
      }
      return total;
    });
  }

  Stream<num> _sumDisbursed() {
    return DB.colSync(_cid, C.loans)
        .where('status', whereIn: ['disbursed', 'closed'])
        .snapshots()
        .map((s) => s.docs.fold<num>(0, (sum, d) {
      final m = d.data();
              return sum +
                  ((m['disbursedAmount'] ?? m['amount']) as num? ?? 0);
    }));
  }

  Stream<num> _loanRepaidStream(String loanId) {
    return DB.colSync(_cid, C.loans)
        .doc(loanId)
        .collection('repayments')
        .snapshots()
        .map((s) =>
            s.docs.fold<num>(0, (sum, d) => sum + (d.data()['amount'] as num? ?? 0)));
  }

  Future<_AgentOutstandingTotals> _computeAgentOutstanding(String userId) async {
    final loansSnap = await DB.colSync(_cid, C.loans)
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['approved', 'disbursed'])
        .get();

    double repayablePrincipal = 0;
    double repaid = 0;

    for (final ld in loansSnap.docs) {
      final principal = (ld.data()['amount'] as num? ?? 0).toDouble();
      repayablePrincipal += principal;
      final repaysSnap = await ld.reference.collection('repayments').get();
      final thisLoanRepaid = repaysSnap.docs
          .fold<num>(0, (sum, d) => sum + (d.data()['amount'] as num? ?? 0))
          .toDouble();
      repaid += thisLoanRepaid;
    }

    final outstanding =
        (repayablePrincipal - repaid).clamp(0, double.infinity).toDouble();
    return _AgentOutstandingTotals(
      repayablePrincipal: repayablePrincipal,
      repaid: repaid,
      outstanding: outstanding,
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  Future<void> _updateStatus(String id, String status,
      {String? notes, Map<String, dynamic>? extra}) async {
    await (await DB.col(C.loans)).doc(id).set({
      'status': status,
      'notes': notes,
      'decisionAt': FieldValue.serverTimestamp(),
      'decidedBy': _auth.currentUser?.email ?? 'hr',
      ...?extra,
    }, SetOptions(merge: true));
  }

  Future<void> _approve(String id) async {
    final note = await _askNote('Approval note (optional)');
    await _updateStatus(id, 'approved', notes: note);
    _toast('Marked Approved');
  }

  Future<void> _reject(String id) async {
    final note = await _askNote('Rejection reason (optional)');
    await _updateStatus(id, 'rejected', notes: note);
    _toast('Marked Rejected');
  }

  Future<void> _disburse(String id, double defaultAmount) async {
    final res = await _askDisburse(defaultAmount);
    if (res == null) return;
    await _updateStatus(id, 'disbursed',
      notes: res.note,
      extra: {
        'disbursedAmount': res.amount,
        'disbursedAt': FieldValue.serverTimestamp(),
        'disbursedBy': _auth.currentUser?.email ?? 'hr',
        });
    _toast('Marked Disbursed');
  }

  Future<void> _repayForUser(
      {required String userId, required String? userEmail}) async {
    final res = await _askRepayment(0);
    if (res == null) return;

    double inputAmount = res.amount;
    if (inputAmount <= 0) {
      _toast('Enter valid amount');
      return;
    }

    final loansSnap = await DB.colSync(_cid, C.loans)
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['approved', 'disbursed'])
        .orderBy('requestedAt')
        .get();

    double totalOutstanding = 0;
    final List<_LoanOutstanding> buckets = [];
    for (final loanDoc in loansSnap.docs) {
      final principal = (loanDoc.data()['amount'] as num? ?? 0).toDouble();
      final repaysSnap =
          await loanDoc.reference.collection('repayments').get();
      final alreadyRepaid = repaysSnap.docs
          .fold<num>(0, (sum, d) => sum + (d.data()['amount'] as num? ?? 0));
      final outstanding =
          (principal - alreadyRepaid).clamp(0, double.infinity).toDouble();
      if (outstanding > 0) {
        buckets.add(_LoanOutstanding(loanDoc.reference, outstanding));
        totalOutstanding += outstanding;
      }
    }

    if (totalOutstanding <= 0) {
      _toast('No outstanding balance for this employee.');
      return;
    }

    if (inputAmount > totalOutstanding) {
      _toast(
          'Amount exceeds outstanding of ${_money.format(totalOutstanding)}.');
      return;
    }

    double remaining = inputAmount;
    final batch = DB.firestore.batch();
    for (final b in buckets) {
      if (remaining <= 0) break;
      final applyHere = remaining > b.outstanding ? b.outstanding : remaining;
      final repayRef = b.ref.collection('repayments').doc();
      batch.set(repayRef, {
        'amount': applyHere,
        'note': res.note ?? 'Agent-level repayment across loans',
        'addedAt': FieldValue.serverTimestamp(),
        'addedBy': _auth.currentUser?.email ?? 'hr',
        'userLevel': true,
        'userId': userId,
        'userEmail': userEmail,
      });
      remaining -= applyHere;
    }
    await batch.commit();

    _agentRepaidCache[userId] =
        ((_agentRepaidCache[userId] ?? 0) + inputAmount);

    for (final b in buckets) {
      final loanSnap = await b.ref.get();
      final principal =
          (loanSnap.data()?['amount'] as num? ?? 0).toDouble();
      final repaysSnap = await b.ref.collection('repayments').get();
      final repaid = repaysSnap.docs
          .fold<num>(0, (t, d) => t + (d.data()['amount'] as num? ?? 0));
      if (repaid >= principal) {
        await b.ref.update({'status': 'closed'});
      }
    }

    _toast('Repayment of ${_money.format(inputAmount)} recorded.');
  }

  // ── PDF export ─────────────────────────────────────────────────────────────
  Future<void> _exportAgentReport(_AgentAggregate a) async {
    try {
      final bytes = await _buildAgentReportPdf(a.userId, a.email);
      final filename =
          'Agent_${a.email ?? a.userId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final savedPath =
          await _savePdfToAppDocs(bytes: bytes, filename: filename);
      _toast('PDF saved at $savedPath');
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e, st) {
      if (kDebugMode) print('PDF error: $e\n$st');
      _toast('Failed to create PDF: $e');
    }
  }

  Future<Uint8List> _buildAgentReportPdf(
      String userId, String? userEmail) async {
    final loansSnap = await DB.colSync(_cid, C.loans)
        .where('userId', isEqualTo: userId)
        .orderBy('requestedAt')
        .get();

    final List<_LoanRow> loanRows = [];
    final List<_RepayRow> repayRows = [];

    for (final ld in loansSnap.docs) {
      final m = ld.data();
      final loanAmount = (m['amount'] as num? ?? 0).toDouble();
      final requestedAt = (m['requestedAt'] is Timestamp)
          ? (m['requestedAt'] as Timestamp).toDate()
          : null;
      final status = (m['status'] ?? 'pending') as String;
      final type = (m['type'] ?? 'Loan') as String;

      final repSnap = await ld.reference
          .collection('repayments')
          .orderBy('addedAt')
          .get();
      num repaid = 0;
      for (final r in repSnap.docs) {
        final rm = r.data();
        final amt = (rm['amount'] as num? ?? 0).toDouble();
        repaid += amt;
        final addedAt = (rm['addedAt'] is Timestamp)
            ? (rm['addedAt'] as Timestamp).toDate()
            : null;
        final note = (rm['note'] ?? '') as String? ?? '';
        repayRows.add(_RepayRow(
            date: addedAt, amount: amt, note: note, loanType: type));
      }

      loanRows.add(_LoanRow(
        type: type,
        amount: loanAmount,
        date: requestedAt,
        status: status,
          repaid: repaid.toDouble()));
    }

    repayRows.sort((a, b) =>
        (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0)));

    final doc = pw.Document(
        theme: pw.ThemeData.withFont(
            base: pw.Font.times(),
            bold: pw.Font.timesBold(),
            italic: pw.Font.timesItalic(),
            boldItalic: pw.Font.timesBoldItalic()));
    final small = pw.TextStyle(fontSize: 9);

    doc.addPage(pw.MultiPage(build: (_) => [
      pw.Text('Agent Loan Report',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(userEmail ?? userId, style: small),
          pw.SizedBox(height: 12),
      pw.Text('Loans',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table.fromTextArray(
            headers: ['Type', 'Amount', 'Requested', 'Status', 'Repaid', 'Outstanding'],
            data: loanRows.map((r) {
              final outstanding = (r.amount - r.repaid).clamp(0, double.infinity);
              return [
                r.type,
                _money.format(r.amount),
                r.date != null ? _date.format(r.date!) : '—',
                r.status,
                _money.format(r.repaid),
                _money.format(outstanding),
              ];
            }).toList(),
            cellStyle: small,
            headerStyle: small.copyWith(fontWeight: pw.FontWeight.bold),
        headerDecoration:
            const pw.BoxDecoration(color: PdfColor(0.90, 0.90, 0.90)),
            border: null,
          ),
          pw.SizedBox(height: 16),
      pw.Text('Repayments (by date)',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (repayRows.isEmpty)
            pw.Text('No repayments yet.', style: small)
          else
            pw.Table.fromTextArray(
              headers: ['Date', 'Amount', 'Loan', 'Note'],
          data: repayRows
              .map((r) => [
                r.date != null ? _date.format(r.date!) : '—',
                _money.format(r.amount),
                r.loanType,
                r.note,
                  ])
              .toList(),
              cellStyle: small,
              headerStyle: small.copyWith(fontWeight: pw.FontWeight.bold),
          headerDecoration:
              const pw.BoxDecoration(color: PdfColor(0.90, 0.90, 0.90)),
              border: null,
        ),
    ]));

    return await doc.save();
  }

  Future<String> _savePdfToAppDocs(
      {required Uint8List bytes, required String filename}) async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      }
    final dir = await getApplicationDocumentsDirectory();
    final fullPath = p.join(dir.path, filename);
    await File(fullPath).writeAsBytes(bytes, flush: true);
    return fullPath;
  }

  // ── Toast ─────────────────────────────────────────────────────────────────
  void _toast(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(s, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: _primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _initials(String? email) {
    final core = (email ?? 'U').split('@').first;
    final parts =
        core.split(RegExp(r'[\W_]+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return core[0].toUpperCase();
    return (parts.first[0] +
            (parts.length > 1 ? parts.last[0] : ''))
        .toUpperCase();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
        appBar: AppBar(
        backgroundColor: _primary,
          foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Loan Approvals',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w800, fontSize: 17)),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'All Loans'),
          ],
        ),
      ),
      body: Column(children: [
        // ── Balance card ──────────────────────────────────────────────
              Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _CompanyBalanceCard(
                  money: _money,
                  approvedPrincipalStream: _sumApprovedPrincipal(),
                  totalRepaidStream: _sumAllRepaid(),
                ),
              ),

        // ── KPI row ───────────────────────────────────────────────────
              Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Expanded(
              child: _KpiCard(
                icon: Icons.hourglass_top_rounded,
                label: 'Pending',
                color: _warn,
                stream: _countStatus('pending').map((n) => '$n'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                icon: Icons.thumb_up_rounded,
                label: 'Approved',
                color: _info,
                stream: _countStatus('approved').map((n) => '$n'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                icon: Icons.payments_rounded,
                label: 'Disbursed',
                color: _primaryMd,
                stream: _sumDisbursed().map((s) => _money.format(s)),
              ),
            ),
          ]),
        ),

        // ── Search + filter ───────────────────────────────────────────
              Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v.trim()),
                style: GoogleFonts.inter(fontSize: 14, color: _fg),
                        decoration: InputDecoration(
                  hintText: 'Search by name or email…',
                  hintStyle: GoogleFonts.inter(
                      color: _muted, fontSize: 13),
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: _muted, size: 20),
                          filled: true,
                  fillColor: _card,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: _primary, width: 1.5),
                  ),
                ),
              ),
            ),
            // Status filter (All tab only)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _tabs.index == 1
                  ? Padding(
                      padding: const EdgeInsets.only(left: 10),
                        child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                          color: _card,
                            borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                          ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _statusAll,
                            style: GoogleFonts.inter(
                                color: _fg, fontSize: 13),
                            items: const [
                              DropdownMenuItem(
                                  value: 'all',
                                  child: Text('All Status')),
                              DropdownMenuItem(
                                  value: 'pending',
                                  child: Text('Pending')),
                              DropdownMenuItem(
                                  value: 'approved',
                                  child: Text('Approved')),
                              DropdownMenuItem(
                                  value: 'rejected',
                                  child: Text('Rejected')),
                              DropdownMenuItem(
                                  value: 'disbursed',
                                  child: Text('Disbursed')),
                              DropdownMenuItem(
                                  value: 'closed',
                                  child: Text('Closed')),
                            ],
                            onChanged: (v) =>
                                setState(() => _statusAll = v ?? 'all'),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
                ),
          ]),
              ),

        // ── Tab content ───────────────────────────────────────────────
              Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _buildPendingTab(),
              _buildAllTab(),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Pending tab ───────────────────────────────────────────────────────────
  Widget _buildPendingTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream(onlyPending: true),
      builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(
              child: CircularProgressIndicator(color: _primary));
        }

        final filtered = snap.data!.docs.where((d) {
          final m = d.data();
          if ((m['status'] ?? '') != 'pending') return false;
          final q = _search.toLowerCase();
          if (q.isEmpty) return true;
          return (m['userEmail'] ?? '').toString().toLowerCase().contains(q) ||
              (m['userId'] ?? '').toString().toLowerCase().contains(q) ||
              (m['type'] ?? '').toString().toLowerCase().contains(q);
                        }).toList();

                        if (filtered.isEmpty) {
          return _EmptyState(
            icon: Icons.inbox_rounded,
            title: 'No pending loans',
            subtitle: 'All loan requests have been reviewed.',
                          );
                        }

                        return ListView.separated(
                          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final doc = filtered[i];
                            final m = doc.data();
            final amount = (m['amount'] as num? ?? 0).toDouble();
            final months = (m['durationMonths'] as num? ?? 0).toInt();
            final status = (m['status'] ?? 'pending') as String;
            final email = (m['userEmail'] ?? '') as String?;
            final userId = (m['userId'] ?? '') as String?;
            final type = (m['type'] ?? 'Loan') as String;
                            final purpose = (m['purpose'] ?? '') as String? ?? '';
                            final created = (m['requestedAt'] is Timestamp)
                                ? (m['requestedAt'] as Timestamp).toDate()
                                : null;

                            return _LoanCard(
                              loanId: doc.id,
                              money: _money,
              date: _date,
              type: type,
              amount: amount,
              durationMonths: months,
                              purpose: purpose,
                              status: status,
              email: email,
                              userId: userId ?? '',
              createdAt: created,
              initials: _initials(email),
                              onApprove: status == 'pending' ? () => _approve(doc.id) : null,
              onReject: (status == 'pending' || status == 'approved')
                  ? () => _reject(doc.id)
                  : null,
              onDisburse: (status == 'pending' || status == 'approved')
                  ? () => _disburse(doc.id, amount)
                  : null,
                              onRepayAgent: (userId != null && userId.isNotEmpty)
                                  ? () => _repayForUser(userId: userId, userEmail: email)
                                  : null,
                              repaidStream: _loanRepaidStream(doc.id),
                              initialRepaid: _loanRepaidCache[doc.id],
                              onRepaidChanged: (v) => _loanRepaidCache[doc.id] = v,
                            );
                          },
                        );
      },
    );
  }

  // ── All tab ───────────────────────────────────────────────────────────────
  Widget _buildAllTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream(onlyPending: false),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: _primary));
        }

        final filtered = snap.data!.docs.where((d) {
          final m = d.data();
          final st = (m['status'] ?? '').toString();
          final q = _search.toLowerCase();
                          final passStatus = _statusAll == 'all' || st == _statusAll;
          final passSearch = q.isEmpty ||
              (m['userEmail'] ?? '').toString().toLowerCase().contains(q) ||
              (m['userId'] ?? '').toString().toLowerCase().contains(q);
                          return passStatus && passSearch;
                        }).toList();

                        if (filtered.isEmpty) {
          return _EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No results',
            subtitle: 'Try adjusting your search or filter.',
          );
        }

        // Group by agent
                        final Map<String, _AgentAggregate> byAgent = {};
                        for (final d in filtered) {
                          final m = d.data();
                          final userId = (m['userId'] ?? '').toString();
          final email = (m['userEmail'] ?? '') as String?;
          final amt = (m['amount'] as num? ?? 0).toDouble();
                          final status = (m['status'] ?? '') as String;
                          final key = userId.isNotEmpty ? userId : (email ?? '');
          byAgent.putIfAbsent(
              key, () => _AgentAggregate(userId: userId, email: email));
                          final agg = byAgent[key]!;
          agg.totalPrincipal += amt;
                          if (status == 'approved' || status == 'disbursed') {
            agg.repayablePrincipal += amt;
                          }
                          agg.loanIds.add(d.id);
                          agg.loanCount += 1;
                        }

                        final agents = byAgent.values.toList()
          ..sort((a, b) => b.totalPrincipal.compareTo(a.totalPrincipal));

                        return ListView.separated(
                          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: agents.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final a = agents[i];
                            return _AgentRowCard(
                              email: a.email ?? a.userId,
                              initials: _initials(a.email),
                              loanCount: a.loanCount,
                              totalPrincipal: a.totalPrincipal,
                              money: _money,
                              userId: a.userId,
                              userEmail: a.email,
              onRepayAgent: () =>
                  _repayForUser(userId: a.userId, userEmail: a.email),
              onViewLoans: () =>
                  _showAgentLoansDialog(a.userId, a.email),
                              onPrint: () => _exportAgentReport(a),
                              outstandingFuture: _computeAgentOutstanding(a.userId),
                              autoHideWhenCleared: true,
                            );
                          },
                        );
      },
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────
  Future<String?> _askNote(String title) async {
    String note = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w800, fontSize: 16)),
        content: TextField(
              onChanged: (v) => note = v,
              maxLines: 3,
          style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Write a note…',
            hintStyle: GoogleFonts.inter(color: _muted),
                filled: true,
            fillColor: _surface,
                border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: _primary, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text('Skip',
                  style: GoogleFonts.inter(color: _muted))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(
                ctx, note.trim().isEmpty ? null : note.trim()),
            child: Text('Save', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  Future<_DisburseFormResult?> _askDisburse(double defaultAmount) async {
    String amountText = defaultAmount.toStringAsFixed(0);
    String note = '';
    return showDialog<_DisburseFormResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: _primaryLt,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.payments_rounded,
                color: _primary, size: 20),
          ),
          const SizedBox(width: 10),
          Text('Disburse Loan',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _DialogField(
            label: 'Amount (BDT)',
                initialValue: amountText,
                keyboardType: TextInputType.number,
                onChanged: (v) => amountText = v,
              ),
              const SizedBox(height: 10),
          _DialogField(
            label: 'Note (optional)',
                onChanged: (v) => note = v,
                maxLines: 2,
          ),
        ]),
          actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: _muted))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
              onPressed: () {
              final amt =
                  double.tryParse(amountText.trim().replaceAll(',', '')) ??
                      0;
                if (amt <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Enter valid amount')));
                  return;
                }
              Navigator.pop(ctx,
                  _DisburseFormResult(amt, note.trim().isEmpty ? null : note.trim()));
              },
            child: Text('Disburse', style: GoogleFonts.inter()),
            ),
          ],
      ),
    );
  }

  Future<_RepayFormResult?> _askRepayment(double suggested) async {
    String amountText =
        suggested > 0 ? suggested.toStringAsFixed(0) : '';
    String note = '';
    return showDialog<_RepayFormResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: _primaryLt,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.account_balance_wallet_rounded,
                color: _primary, size: 20),
          ),
          const SizedBox(width: 10),
          Text('Record Repayment',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _DialogField(
            label: 'Amount (BDT)',
                initialValue: amountText,
                keyboardType: TextInputType.number,
                onChanged: (v) => amountText = v,
              ),
              const SizedBox(height: 10),
          _DialogField(
            label: 'Note (optional)',
                onChanged: (v) => note = v,
                maxLines: 2,
          ),
        ]),
          actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: _muted))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
              onPressed: () {
              final amt =
                  double.tryParse(amountText.trim().replaceAll(',', ''));
              if (amt == null || !amt.isFinite || amt <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Enter a valid amount')));
                  return;
                }
              Navigator.pop(ctx,
                  _RepayFormResult(amt, note.trim().isEmpty ? null : note.trim()));
            },
            child: Text('Save', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  Future<void> _showAgentLoansDialog(
      String userId, String? userEmail) async {
    final q = (await DB.col(C.loans))
        .where('userId', isEqualTo: userId)
        .orderBy('requestedAt', descending: true);

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
            decoration: const BoxDecoration(
              color: _primary,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Expanded(
                child: Text(userEmail ?? userId,
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(ctx),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: q.snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) {
                    return const SizedBox(
                        height: 80,
                        child: Center(
                            child: CircularProgressIndicator(
                                color: _primary)));
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                    return Text('No loans for this agent.',
                        style: GoogleFonts.inter(color: _muted));
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                    children: docs
                        .map((d) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 8),
                              child: _AgentLoanTile(
                      money: _money,
                      date: _date,
                      data: d.data(),
                    ),
                            ))
                        .toList(),
              );
            },
          ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPANY BALANCE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _CompanyBalanceCard extends StatelessWidget {
  final NumberFormat money;
  final Stream<num> approvedPrincipalStream;
  final Stream<num> totalRepaidStream;

  const _CompanyBalanceCard({
    required this.money,
    required this.approvedPrincipalStream,
    required this.totalRepaidStream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<num>(
      stream: approvedPrincipalStream,
      builder: (_, principalSnap) {
        final totalLoan = (principalSnap.data ?? 0).toDouble().clamp(0, double.infinity);
        return StreamBuilder<num>(
          stream: totalRepaidStream,
          builder: (_, repaidSnap) {
            final repaid = (repaidSnap.data ?? 0).toDouble().clamp(0, double.infinity);
            final due = (totalLoan - repaid).clamp(0, double.infinity);
            final progress =
                totalLoan > 0 ? (repaid / totalLoan).clamp(0.0, 1.0) : 0.0;

    return Container(
              padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
                  colors: [_primary, _primaryMd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: _primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.account_balance_rounded,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text('Company Loan Portfolio',
                        style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3)),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: _BalanceStat(
                        label: 'Total Issued',
                        value: money.format(totalLoan),
                        icon: Icons.receipt_long_rounded,
                      ),
                    ),
                    Container(
                        width: 1, height: 40, color: Colors.white24),
                    Expanded(
                      child: _BalanceStat(
                        label: 'Repaid',
                        value: money.format(repaid),
                        icon: Icons.check_circle_outline_rounded,
                      ),
                    ),
                    Container(
                        width: 1, height: 40, color: Colors.white24),
                    Expanded(
                      child: _BalanceStat(
                        label: 'Outstanding',
                        value: money.format(due),
                        icon: Icons.pending_actions_rounded,
                        highlight: due > 0,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${(progress * 100).round()}% repaid',
                      style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ],
              ),
              );
            },
          );
        },
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final bool highlight;
  const _BalanceStat({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(children: [
          Icon(icon,
              color: highlight ? const Color(0xFFFCD34D) : Colors.white70,
              size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.inter(
                  color: highlight ? const Color(0xFFFCD34D) : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(
                  color: Colors.white60, fontSize: 10),
              textAlign: TextAlign.center),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI CARD
// ─────────────────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Stream<String> stream;
  const _KpiCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.stream});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
        color: _card,
          borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000),
              blurRadius: 6,
              offset: Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StreamBuilder<String>(
            stream: stream,
            builder: (_, snap) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
          children: [
                Text(snap.data ?? '—',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: _fg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 10, color: _muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOAN CARD (pending tab)
// ─────────────────────────────────────────────────────────────────────────────
class _LoanCard extends StatelessWidget {
  final String loanId;
  final NumberFormat money;
  final DateFormat date;
  final String type, status, userId, initials;
  final String? email, purpose;
  final double amount;
  final int durationMonths;
  final DateTime? createdAt;
  final VoidCallback? onApprove, onReject, onDisburse, onRepayAgent;
  final Stream<num> repaidStream;
  final num? initialRepaid;
  final void Function(num)? onRepaidChanged;

  const _LoanCard({
    super.key,
    required this.loanId,
    required this.money,
    required this.date,
    required this.type,
    required this.status,
    required this.userId,
    required this.initials,
    required this.amount,
    required this.durationMonths,
    required this.repaidStream,
    this.email,
    this.purpose,
    this.createdAt,
    this.onApprove,
    this.onReject,
    this.onDisburse,
    this.onRepayAgent,
    this.initialRepaid,
    this.onRepaidChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(status);
    final si = _statusIcon(status);

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x07000000),
              blurRadius: 8,
              offset: Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header strip ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
            color: sc.withValues(alpha: 0.06),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border(
                bottom: BorderSide(color: sc.withValues(alpha: 0.15))),
          ),
          child: Row(children: [
            // Avatar
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(initials,
                  style: GoogleFonts.inter(
                      color: _primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(email ?? userId,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _fg),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                      '$type  •  ${durationMonths}m'
                      '${createdAt != null ? '  •  ${date.format(createdAt!)}' : ''}',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: _muted),
                    ),
                  ]),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: sc.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sc.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(si, size: 12, color: sc),
                const SizedBox(width: 4),
                Text(status.toUpperCase(),
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: sc)),
              ]),
            ),
          ]),
        ),

        // ── Body ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Amount + progress
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Loan Amount',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: _muted,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(money.format(amount),
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _fg)),
              ]),
            ]),

                  const SizedBox(height: 10),

            // Repayment progress
                  StreamBuilder<num>(
                    stream: repaidStream,
                    initialData: initialRepaid,
              builder: (_, snap) {
                final repaid =
                    (snap.data ?? initialRepaid ?? 0).toDouble();
                      onRepaidChanged?.call(repaid);
                final outstanding =
                    (amount - repaid).clamp(0, double.infinity);
                final pct = amount > 0
                    ? (repaid / amount).clamp(0.0, 1.0)
                    : 0.0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  Row(children: [
                    Expanded(
                      child: _StatPill(
                          label: 'Repaid',
                          value: money.format(repaid),
                          color: _primaryMd),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatPill(
                          label: 'Outstanding',
                          value: money.format(outstanding),
                          color: outstanding > 0 ? _warn : _primaryMd),
                    ),
                    if (outstanding == 0) ...[
                      const SizedBox(width: 8),
                                Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                          color: _primaryLt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Cleared ✓',
                            style: GoogleFonts.inter(
                                color: _primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 8),
                          ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                      backgroundColor: _primaryLt,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          _primaryMd),
                    ),
                  ),
                ]);
              },
            ),

            if (purpose != null && purpose!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Icon(Icons.notes_rounded,
                      size: 14, color: _muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(purpose!,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _muted,
                            height: 1.4),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
            ],

                  const SizedBox(height: 12),

            // Action buttons
                  _ActionBar(
                    onApprove: onApprove,
                    onReject: onReject,
                    onDisburse: onDisburse,
                    onRepayAgent: onRepayAgent,
                  ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AGENT ROW CARD (all tab)
// ─────────────────────────────────────────────────────────────────────────────
class _AgentRowCard extends StatelessWidget {
  final String email, initials, userId;
  final String? userEmail;
  final int loanCount;
  final double totalPrincipal;
  final NumberFormat money;
  final VoidCallback onRepayAgent, onViewLoans, onPrint;
  final Future<_AgentOutstandingTotals> outstandingFuture;
  final bool autoHideWhenCleared;

  const _AgentRowCard({
    super.key,
    required this.email,
    required this.initials,
    required this.loanCount,
    required this.totalPrincipal,
    required this.money,
    required this.userId,
    required this.userEmail,
    required this.onRepayAgent,
    required this.onViewLoans,
    required this.onPrint,
    required this.outstandingFuture,
    this.autoHideWhenCleared = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AgentOutstandingTotals>(
      future: outstandingFuture,
      builder: (_, snap) {
        if (!snap.hasData) {
          return Container(
            height: 72,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: const Center(
                child: LinearProgressIndicator(
                    color: _primary, minHeight: 2)),
          );
        }

        final totals = snap.data!;
        final repaid =
            totals.repaid.clamp(0, double.infinity).toDouble();
        final outstanding =
            totals.outstanding.clamp(0, double.infinity).toDouble();
        final repayable =
            totals.repayablePrincipal.clamp(0, double.infinity).toDouble();

        if (autoHideWhenCleared && outstanding == 0) {
          return const SizedBox.shrink();
        }

        final pct = repayable > 0
            ? (repaid / repayable).clamp(0.0, 1.0)
            : 0.0;

        return Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x07000000),
                  blurRadius: 8,
                  offset: Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Header
                  Container(
              padding:
                  const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: _border)),
              ),
              child: Row(children: [
                    Container(
                  width: 40, height: 40,
                      decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(initials,
                      style: GoogleFonts.inter(
                          color: _primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(email,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _fg),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                        '$loanCount loan${loanCount == 1 ? '' : 's'}  •  Total: ${money.format(repayable)}',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: _muted)),
                  ]),
                ),
              ]),
            ),

            // Stats + progress
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                    child: _StatPill(
                        label: 'Repaid',
                        value: money.format(repaid),
                        color: _primaryMd),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatPill(
                        label: 'Outstanding',
                        value: money.format(outstanding),
                        color: outstanding > 0 ? _warn : _primaryMd),
                  ),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: _primaryLt,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(_primaryMd),
                  ),
                ),
                const SizedBox(height: 12),

                // Action buttons
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (outstanding > 0)
                    _ActionButton(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Repay',
                      color: _primary,
                      onTap: onRepayAgent,
                    ),
                  _ActionButton(
                    icon: Icons.list_alt_rounded,
                    label: 'View Loans',
                    color: _info,
                    outlined: true,
                    onTap: onViewLoans,
                  ),
                  _ActionButton(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'Export PDF',
                    color: _muted,
                    outlined: true,
                    onTap: onPrint,
                  ),
                ]),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION BAR (pending loan card)
// ─────────────────────────────────────────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  final VoidCallback? onApprove, onReject, onDisburse, onRepayAgent;
  const _ActionBar(
      {this.onApprove, this.onReject, this.onDisburse, this.onRepayAgent});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      if (onApprove != null)
        _ActionButton(
            icon: Icons.check_circle_rounded,
            label: 'Approve',
            color: _primaryMd,
            onTap: onApprove!),
      if (onReject != null)
        _ActionButton(
            icon: Icons.cancel_rounded,
            label: 'Reject',
            color: _danger,
            outlined: true,
            onTap: onReject!),
      if (onDisburse != null)
        _ActionButton(
            icon: Icons.payments_rounded,
            label: 'Disburse',
            color: _info,
            outlined: true,
            onTap: onDisburse!),
      if (onRepayAgent != null)
        _ActionButton(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Repay',
            color: _primary,
            outlined: true,
            onTap: onRepayAgent!),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AGENT LOAN TILE (inside dialog)
// ─────────────────────────────────────────────────────────────────────────────
class _AgentLoanTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final NumberFormat money;
  final DateFormat date;

  const _AgentLoanTile({
    super.key,
    required this.data,
    required this.money,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final amount = (data['amount'] as num? ?? 0).toDouble();
    final type = (data['type'] ?? 'Loan') as String;
    final status = (data['status'] ?? 'pending') as String;
    final created = (data['requestedAt'] is Timestamp)
        ? (data['requestedAt'] as Timestamp).toDate()
        : null;
    final sc = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text('$type  •  ${money.format(amount)}',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _fg)),
            if (created != null)
              Text(date.format(created),
                  style: GoogleFonts.inter(
                      fontSize: 11, color: _muted)),
          ]),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: sc.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(status.toUpperCase(),
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: sc)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10, color: _muted,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(label,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label,
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w700, fontSize: 12)),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  final String label;
  final String? initialValue;
  final TextInputType? keyboardType;
  final void Function(String)? onChanged;
  final int maxLines;
  const _DialogField({
    required this.label,
    this.initialValue,
    this.keyboardType,
    this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _fg)),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: initialValue,
            keyboardType: keyboardType,
            maxLines: maxLines,
            onChanged: onChanged,
            style: GoogleFonts.inter(fontSize: 14, color: _fg),
            decoration: InputDecoration(
              filled: true,
              fillColor: _surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: _primary, width: 1.5)),
            ),
          ),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _EmptyState(
      {required this.icon,
      required this.title,
      required this.subtitle});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _primaryLt,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: _primary, size: 32),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _fg)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13, color: _muted)),
          ]),
        ),
      );
}

/* ── Models ──────────────────────────────────────────────────────────────── */

class _DisburseFormResult {
  final double amount;
  final String? note;
  _DisburseFormResult(this.amount, this.note);
}

class _RepayFormResult {
  final double amount;
  final String? note;
  _RepayFormResult(this.amount, this.note);
}

class _LoanOutstanding {
  final DocumentReference<Map<String, dynamic>> ref;
  final double outstanding;
  _LoanOutstanding(this.ref, this.outstanding);
}

class _LoanRow {
  final String type, status;
  final double amount, repaid;
  final DateTime? date;
  _LoanRow(
      {required this.type,
      required this.amount,
      required this.date,
      required this.status,
      required this.repaid});
}

class _RepayRow {
  final DateTime? date;
  final double amount;
  final String note, loanType;
  _RepayRow(
      {required this.date,
      required this.amount,
      required this.note,
      required this.loanType});
}

class _AgentAggregate {
  final String userId;
  final String? email;
  int loanCount = 0;
  double totalPrincipal = 0;
  double repayablePrincipal = 0;
  final List<String> loanIds = [];
  _AgentAggregate({required this.userId, required this.email});
}

class _AgentOutstandingTotals {
  final double repayablePrincipal, repaid, outstanding;
  _AgentOutstandingTotals(
      {required this.repayablePrincipal,
    required this.repaid,
      required this.outstanding});
}
