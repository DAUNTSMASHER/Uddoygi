// lib/features/hr/presentation/screens/loan_approval_screen.dart
// HR-facing board to review/approve/reject/disburse employee loans.
// Clean dark board, neon chips, Firestore realtime.
// PER-AGENT repayments are FIFO across all loans.
// Includes PDF export (loans + repayments by date) saved to App Documents + share.
// Auto-hides agents that have zero outstanding across all repayable loans.

import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// PDF + Share + Storage
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

class LoanApprovalScreen extends StatefulWidget {
  const LoanApprovalScreen({super.key});
  @override
  State<LoanApprovalScreen> createState() => _LoanApprovalScreenState();
}

class _LoanApprovalScreenState extends State<LoanApprovalScreen> {
  // Palette
  static const Color _board        = Color(0xFF80839A);
  static const Color _ink          = Color(0xFF173A9F);
  static const Color _lime         = Color(0xFFF1FF60);
  static const Color _purplePastel = Color(0xFFCDB9FF);
  static const Color _cyanPastel   = Color(0xFF9DEBFF);
  static const Color _accent       = Color(0xFFFFC857);

  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _money = NumberFormat.currency(locale: 'en_BD', symbol: '৳', decimalDigits: 0);
  final _date  = DateFormat('d MMM, yyyy');

  int    _tabIndex = 0; // 0: Pending, 1: All
  String _search    = '';
  String _statusAll = 'all';

  // Scrollbar needs a controller
  final ScrollController _scrollCtrl = ScrollController();

  // warm caches to avoid “jump” on first snapshot
  final Map<String, num> _loanRepaidCache  = {}; // loanId -> repaid
  final Map<String, num> _agentRepaidCache = {}; // userId -> repaid (best-effort)

  // ───────────────────────── Streams ─────────────────────────
  Stream<QuerySnapshot<Map<String, dynamic>>> _stream({required bool onlyPending}) {
    Query<Map<String, dynamic>> q = _db.collection('loans').orderBy('requestedAt', descending: true);
    if (onlyPending) q = q.where('status', isEqualTo: 'pending');
    return q.snapshots();
  }

  Stream<int> _countStatus(String status) {
    return _db.collection('loans').where('status', isEqualTo: status).snapshots().map((s) => s.docs.length);
  }

  /// Company “Total” = sum of principal for loans with status approved or disbursed.
  Stream<num> _sumApprovedPrincipal() {
    return _db
        .collection('loans')
        .where('status', whereIn: ['approved', 'disbursed', 'closed'])
        .snapshots()
        .map((s) => s.docs.fold<num>(
      0,
          (sum, d) => sum + (d.data()['amount'] as num? ?? 0),
    ));
  }

  /// Company “Repaid” = sum of all repayments (historically okay).
  Stream<num> _sumAllRepaid() {
    return _db.collectionGroup('repayments').snapshots()
        .map((s) => s.docs.fold<num>(0, (sum, d) => sum + (d.data()['amount'] as num? ?? 0)));
  }

  Stream<num> _sumDisbursed() {
    return _db
        .collection('loans')
        .where('status', whereIn: ['disbursed', 'closed'])
        .snapshots()
        .map((s) => s.docs.fold<num>(0, (sum, d) {
      final m = d.data();
      return sum + ((m['disbursedAmount'] ?? m['amount']) as num? ?? 0);
    }));
  }


  Stream<num> _loanRepaidStream(String loanId) {
    return _db
        .collection('loans').doc(loanId)
        .collection('repayments')
        .snapshots()
        .map((s) => s.docs.fold<num>(0, (sum, d) => sum + (d.data()['amount'] as num? ?? 0)));
  }

  // ───────────────────────── Derived totals (per agent) ─────────────────────────
  /// Accurate, backward-compatible outstanding computed from each approved/disbursed loan’s own repayments.
  Future<_AgentOutstandingTotals> _computeAgentOutstanding(String userId) async {
    final loansSnap = await _db
        .collection('loans')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['approved', 'disbursed']) // ← only approved + disbursed
        .get();

    double repayablePrincipal = 0;
    double repaid = 0;

    for (final ld in loansSnap.docs) {
      final principal = (ld.data()['amount'] as num? ?? 0).toDouble();
      repayablePrincipal += principal;

      final repaysSnap = await ld.reference.collection('repayments').get();
      final thisLoanRepaid = repaysSnap.docs.fold<num>(0, (sum, d) => sum + (d.data()['amount'] as num? ?? 0)).toDouble();
      repaid += thisLoanRepaid;
    }

    final outstanding = (repayablePrincipal - repaid).clamp(0, double.infinity).toDouble();
    return _AgentOutstandingTotals(
      repayablePrincipal: repayablePrincipal,
      repaid: repaid,
      outstanding: outstanding,
    );
  }

  // ───────────────────────── Actions ─────────────────────────
  Future<void> _updateStatus(
      String id,
      String status, {
        String? notes,
        Map<String, dynamic>? extra,
      }) async {
    await _db.collection('loans').doc(id).set({
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
    await _updateStatus(
      id,
      'disbursed',
      notes: res.note,
      extra: {
        'disbursedAmount': res.amount,
        'disbursedAt': FieldValue.serverTimestamp(),
        'disbursedBy': _auth.currentUser?.email ?? 'hr',
      },
    );
    _toast('Marked Disbursed');
  }

  // PER-AGENT repayment: apply one amount across ALL loans (FIFO)
  Future<void> _repayForUser({
    required String userId,
    required String? userEmail,
  }) async {
    final res = await _askRepayment(0);
    if (res == null) return;

    double inputAmount = res.amount;
    if (inputAmount <= 0) {
      _toast('Enter valid amount');
      return;
    }

    // Load repayable loans (approved/disbursed), oldest first
    final loansSnap = await _db
        .collection('loans')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['approved', 'disbursed'])
        .orderBy('requestedAt')
        .get();

    // Compute outstanding across repayable loans
    double totalOutstanding = 0;
    final List<_LoanOutstanding> buckets = [];
    for (final loanDoc in loansSnap.docs) {
      final principal = (loanDoc.data()['amount'] as num? ?? 0).toDouble();

      final repaysSnap = await loanDoc.reference.collection('repayments').get();
      final alreadyRepaid = repaysSnap.docs.fold<num>(0, (sum, d) => sum + (d.data()['amount'] as num? ?? 0));

      final outstanding = (principal - alreadyRepaid).clamp(0, double.infinity).toDouble();
      if (outstanding > 0) {
        buckets.add(_LoanOutstanding(loanDoc.reference, outstanding));
        totalOutstanding += outstanding;
      }
    }

    if (totalOutstanding <= 0) {
      _toast('No outstanding balance for this employee.');
      return;
    }

    // Cap the amount to the outstanding
    // Validate against outstanding (reject if over)
    if (inputAmount > totalOutstanding) {
      _toast('Amount exceeds outstanding of ${_money.format(totalOutstanding)}. Enter a value \u2264 outstanding.');
      return;
    }

// Use the user-entered amount (now guaranteed valid)
    final double applyAmount = inputAmount;


    // Apply FIFO
    double remaining = applyAmount;
    final batch = _db.batch();
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
        'userId': userId,       // ✅ always store for new repayments
        'userEmail': userEmail, // ✅ always store for new repayments
      });

      remaining -= applyHere;
    }
    await batch.commit();

    // update local cache to avoid visual delay until stream refresh
    _agentRepaidCache[userId] = ((_agentRepaidCache[userId] ?? 0) + applyAmount);

    // Close loans that are fully paid now
    for (final b in buckets) {
      final loanSnap = await b.ref.get();
      final principal = (loanSnap.data()?['amount'] as num? ?? 0).toDouble();
      final repaysSnap = await b.ref.collection('repayments').get();
      final repaid = repaysSnap.docs.fold<num>(0, (t, d) => t + (d.data()['amount'] as num? ?? 0));
      if (repaid >= principal) {
        await b.ref.update({'status': 'closed'});
      }
    }

    _toast('Repayment of ${_money.format(applyAmount)} recorded for ${userEmail ?? userId}');
  }

  // ────────────────────── PDF export ──────────────────────
  Future<void> _exportAgentReport(_AgentAggregate a) async {
    try {
      final bytes = await _buildAgentReportPdf(a.userId, a.email);
      final filename = 'Agent_${a.email ?? a.userId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final savedPath = await _savePdfToAppDocs(bytes: bytes, filename: filename);
      _toast('PDF saved at $savedPath');
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('PDF error: $e\n$st');
      }
      _toast('Failed to create PDF: $e');
    }
  }

  Future<Uint8List> _buildAgentReportPdf(String userId, String? userEmail) async {
    // Fetch loans
    final loansSnap = await _db
        .collection('loans')
        .where('userId', isEqualTo: userId)
        .orderBy('requestedAt')
        .get();

    // Build rows
    final List<_LoanRow> loanRows = [];
    final List<_RepayRow> repayRows = [];

    for (final ld in loansSnap.docs) {
      final m = ld.data();
      final loanAmount = (m['amount'] as num? ?? 0).toDouble();
      final requestedAt = (m['requestedAt'] is Timestamp) ? (m['requestedAt'] as Timestamp).toDate() : null;
      final status = (m['status'] ?? 'pending') as String;
      final type   = (m['type'] ?? 'Loan') as String;

      final repSnap = await ld.reference.collection('repayments').orderBy('addedAt').get();
      num repaid = 0;
      for (final r in repSnap.docs) {
        final rm = r.data();
        final amt = (rm['amount'] as num? ?? 0).toDouble();
        repaid += amt;
        final addedAt = (rm['addedAt'] is Timestamp) ? (rm['addedAt'] as Timestamp).toDate() : null;
        final note = (rm['note'] ?? '') as String? ?? '';
        repayRows.add(_RepayRow(
          date: addedAt,
          amount: amt,
          note: note,
          loanType: type,
        ));
      }

      loanRows.add(_LoanRow(
        type: type,
        amount: loanAmount,
        date: requestedAt,
        status: status,
        repaid: repaid.toDouble(),
      ));
    }

    repayRows.sort((a, b) => (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0)));

    final doc = pw.Document();
    final small = pw.TextStyle(fontSize: 9);

    doc.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Text('Agent Loan Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(userEmail ?? userId, style: small),
          pw.SizedBox(height: 12),

          pw.Text('Loans', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
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
            headerDecoration: const pw.BoxDecoration(color: PdfColor(0.90, 0.90, 0.90)),
            border: null,
          ),

          pw.SizedBox(height: 16),
          pw.Text('Repayments (by date / installment)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (repayRows.isEmpty)
            pw.Text('No repayments yet.', style: small)
          else
            pw.Table.fromTextArray(
              headers: ['Date', 'Amount', 'Loan', 'Note'],
              data: repayRows.map((r) => [
                r.date != null ? _date.format(r.date!) : '—',
                _money.format(r.amount),
                r.loanType,
                r.note,
              ]).toList(),
              cellStyle: small,
              headerStyle: small.copyWith(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColor(0.90, 0.90, 0.90)),
              border: null,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
              },
            ),
        ],
      ),
    );

    return await doc.save();
  }

  /// Safer save path: App Documents (works on Android 10/11/12+ without special permissions).
  Future<String> _savePdfToAppDocs({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted && !status.isLimited) {
        // proceed anyway; app docs works without it
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final fullPath = p.join(dir.path, filename);
    final file = File(fullPath);
    await file.writeAsBytes(bytes, flush: true);
    return fullPath;
  }

  // ────────────────────── UI helpers ──────────────────────
  void _toast(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':   return const Color(0xFFFFB020);
      case 'approved':  return const Color(0xFF5AB2FF);
      case 'rejected':  return const Color(0xFFFF5A7A);
      case 'disbursed': return const Color(0xFF65D38B);
      case 'closed':    return Colors.grey;
      case 'withdrawn': return Colors.grey;
      default:          return Colors.white70;
    }
  }

  String _initials(String? email) {
    final core = (email ?? 'U').split('@').first;
    final parts = core.split(RegExp(r'[\W_]+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return core[0].toUpperCase();
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  // ───────────────────────── Build ─────────────────────────
  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    // Safe text scaling (no deprecated APIs)
    final rawFactor = MediaQuery.textScaleFactorOf(context);
    final clampedFactor = rawFactor.clamp(1.0, 1.2);
    final textScaler = TextScaler.linear(clampedFactor);

    final topKpis = SizedBox(
      height: 80,
      child: ScrollConfiguration(
        behavior: const _NoGlowBehavior(),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _ChipKpi(
              color: _lime,
              icon: Icons.timer_outlined,
              label: 'Pending',
              stream: _countStatus('pending').map((n) => '$n'),
            ),
            const SizedBox(width: 10),
            _ChipKpi(
              color: _purplePastel,
              icon: Icons.task_alt_outlined,
              label: 'Approved',
              stream: _countStatus('approved').map((n) => '$n'),
            ),
            const SizedBox(width: 10),
            _ChipKpi(
              color: _cyanPastel,
              icon: Icons.payments_outlined,
              label: 'Disbursed',
              stream: _sumDisbursed().map((s) => _money.format(s)),
            ),
          ],
        ),
      ),
    );

    return MediaQuery(
      data: media.copyWith(textScaler: textScaler),
      child: Scaffold(
        backgroundColor: _board,
        appBar: AppBar(
          backgroundColor: _board,
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text('Loan Approvals', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),

              // Company balance — exactly three: Total (approved+disbursed), Repaid, Due
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _CompanyBalanceCard(
                  money: _money,
                  approvedPrincipalStream: _sumApprovedPrincipal(),
                  totalRepaidStream: _sumAllRepaid(),
                ),
              ),
              const SizedBox(height: 12),

              // KPI chips
              topKpis,

              // Segmented
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: _ink.withOpacity(.9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    children: [
                      _Segment(
                        text: 'Pending',
                        selected: _tabIndex == 0,
                        onTap: () => setState(() => _tabIndex = 0),
                      ),
                      _Segment(
                        text: 'All',
                        selected: _tabIndex == 1,
                        onTap: () => setState(() => _tabIndex = 1),
                      ),
                    ],
                  ),
                ),
              ),

              // Search & (All) status filter
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v.trim()),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _tabIndex == 1 ? 'Search agent email / id' : 'Search email / id / type',
                          hintStyle: const TextStyle(color: Colors.white60),
                          prefixIcon: const Icon(Icons.search, color: Colors.white70),
                          filled: true,
                          fillColor: _ink.withOpacity(.9),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    if (_tabIndex == 1) ...[
                      const SizedBox(width: 10),
                      DropdownButtonHideUnderline(
                        child: Container(
                          decoration: BoxDecoration(
                            color: _ink.withOpacity(.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: DropdownButton<String>(
                            value: _statusAll,
                            dropdownColor: _ink,
                            iconEnabledColor: Colors.white70,
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 'pending', child: Text('Pending', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 'approved', child: Text('Approved', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 'rejected', child: Text('Rejected', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 'disbursed', child: Text('Disbursed', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 'withdrawn', child: Text('Withdrawn', style: TextStyle(color: Colors.white))),
                              DropdownMenuItem(value: 'closed', child: Text('Closed', style: TextStyle(color: Colors.white))),
                            ],
                            onChanged: (v) => setState(() => _statusAll = v ?? 'all'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 6),
              Expanded(
                child: Scrollbar(
                  controller: _scrollCtrl,
                  thumbVisibility: true,
                  thickness: 4,
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _stream(onlyPending: _tabIndex == 0),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snap.hasData) {
                        return const Center(
                          child: Text('No data available.', style: TextStyle(color: Colors.white60)),
                        );
                      }

                      final allDocs = snap.data!.docs;

                      if (_tabIndex == 0) {
                        // ── Pending tab: per-loan cards ──
                        final filtered = allDocs.where((d) {
                          final m   = d.data();
                          final st  = (m['status'] ?? '').toString();
                          if (st != 'pending') return false;
                          final em  = (m['userEmail'] ?? '').toString().toLowerCase();
                          final uid = (m['userId'] ?? '').toString().toLowerCase();
                          final ty  = (m['type'] ?? '').toString().toLowerCase();
                          final q   = _search.toLowerCase();
                          final passSearch = q.isEmpty || em.contains(q) || uid.contains(q) || ty.contains(q);
                          return passSearch;
                        }).toList();

                        if (filtered.isEmpty) {
                          return const Center(
                            child: Text('No loans match your filters.', style: TextStyle(color: Colors.white60)),
                          );
                        }

                        return ListView.separated(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final doc = filtered[i];
                            final m = doc.data();
                            final amount  = (m['amount'] as num? ?? 0).toDouble();
                            final months  = (m['durationMonths'] as num? ?? 0).toInt();
                            final status  = (m['status'] ?? 'pending') as String;
                            final email   = (m['userEmail'] ?? '') as String?;
                            final userId  = (m['userId'] ?? '') as String?;
                            final type    = (m['type'] ?? 'Loan') as String;
                            final purpose = (m['purpose'] ?? '') as String? ?? '';
                            final created = (m['requestedAt'] is Timestamp)
                                ? (m['requestedAt'] as Timestamp).toDate()
                                : null;

                            return _LoanCard(
                              loanId: doc.id,
                              money: _money,
                              title: '$type • ${_money.format(amount)}',
                              subtitle: '${email ?? '—'}  •  ${months}m${created != null ? '  •  ${_date.format(created)}' : ''}',
                              purpose: purpose,
                              status: status,
                              statusColor: _statusColor(status),
                              initials: _initials(email),
                              principal: amount,
                              userId: userId ?? '',
                              userEmail: email,
                              onApprove: status == 'pending' ? () => _approve(doc.id) : null,
                              onReject: (status == 'pending' || status == 'approved') ? () => _reject(doc.id) : null,
                              onDisburse: (status == 'pending' || status == 'approved') ? () => _disburse(doc.id, amount) : null,
                              onRepayAgent: (userId != null && userId.isNotEmpty)
                                  ? () => _repayForUser(userId: userId, userEmail: email)
                                  : null,

                              repaidStream: _loanRepaidStream(doc.id),
                              initialRepaid: _loanRepaidCache[doc.id],
                              onRepaidChanged: (v) => _loanRepaidCache[doc.id] = v,
                            );
                          },
                        );
                      } else {
                        // ── All tab: group by agent ──
                        final filtered = allDocs.where((d) {
                          final m   = d.data();
                          final st  = (m['status'] ?? '').toString();
                          final em  = (m['userEmail'] ?? '').toString().toLowerCase();
                          final uid = (m['userId'] ?? '').toString().toLowerCase();
                          final q   = _search.toLowerCase();
                          final passStatus = _statusAll == 'all' || st == _statusAll;
                          final passSearch = q.isEmpty || em.contains(q) || uid.contains(q);
                          return passStatus && passSearch;
                        }).toList();

                        if (filtered.isEmpty) {
                          return const Center(
                            child: Text('No agents match your filters.', style: TextStyle(color: Colors.white60)),
                          );
                        }

                        // Build agent aggregates (principal + counts)
                        final Map<String, _AgentAggregate> byAgent = {};
                        for (final d in filtered) {
                          final m = d.data();
                          final userId = (m['userId'] ?? '').toString();
                          final email  = (m['userEmail'] ?? '') as String?;
                          final amt    = (m['amount'] as num? ?? 0).toDouble();
                          final status = (m['status'] ?? '') as String;
                          final key = userId.isNotEmpty ? userId : (email ?? '');
                          byAgent.putIfAbsent(key, () => _AgentAggregate(userId: userId, email: email));
                          final agg = byAgent[key]!;
                          agg.totalPrincipal += amt; // display purpose
                          if (status == 'approved' || status == 'disbursed') {
                            agg.repayablePrincipal += amt; // only approved + disbursed
                          }
                          agg.loanIds.add(d.id);
                          agg.loanCount += 1;
                        }

                        final agents = byAgent.values.toList()
                          ..sort((a, b) => (b.totalPrincipal.compareTo(a.totalPrincipal)));

                        return ListView.separated(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
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
                              onRepayAgent: () => _repayForUser(userId: a.userId, userEmail: a.email),
                              onViewLoans: () => _showAgentLoansDialog(a.userId, a.email),
                              onPrint: () => _exportAgentReport(a),

                              // accurate totals from only approved/disbursed loans
                              outstandingFuture: _computeAgentOutstanding(a.userId),

                              // 👉 auto-hide if fully cleared
                              autoHideWhenCleared: true,
                            );
                          },
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────── Dialogs ───────────────────────
  Future<String?> _askNote(String title) async {
    String note = '';
    return showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        scrollable: true,
        backgroundColor: _ink,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (v) => note = v,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Write a note…',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.black.withOpacity(.25),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(null), child: const Text('Skip')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.black87),
            onPressed: () => Navigator.of(dialogCtx).pop(note.trim().isEmpty ? null : note.trim()),
            child: const Text('Save'),
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
      builder: (dialogCtx) {
        return AlertDialog(
          scrollable: true,
          backgroundColor: _ink,
          title: const Text('Disburse Loan', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: amountText,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onChanged: (v) => amountText = v,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Amount (BDT)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true, fillColor: Colors.black.withOpacity(.25),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: '',
                onChanged: (v) => note = v,
                maxLines: 2,
                textInputAction: TextInputAction.done,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true, fillColor: Colors.black.withOpacity(.25),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.black87),
              onPressed: () {
                final raw = amountText.trim().replaceAll(',', '');
                final amt = double.tryParse(raw) ?? 0;
                if (amt <= 0) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(const SnackBar(content: Text('Enter valid amount')));
                  return;
                }
                Navigator.of(dialogCtx).pop(_DisburseFormResult(amt, note.trim().isEmpty ? null : note.trim()));
              },
              child: const Text('Disburse'),
            ),
          ],
        );
      },
    );
  }

  Future<_RepayFormResult?> _askRepayment(double suggested) async {
    String amountText = suggested > 0 ? suggested.toStringAsFixed(0) : '';
    String note = '';
    return showDialog<_RepayFormResult>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          scrollable: true,
          backgroundColor: _ink,
          title: const Text('Record Agent Repayment', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: amountText,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onChanged: (v) => amountText = v,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Amount (BDT)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true, fillColor: Colors.black.withOpacity(.25),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: '',
                onChanged: (v) => note = v,
                maxLines: 2,
                textInputAction: TextInputAction.done,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true, fillColor: Colors.black.withOpacity(.25),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.black87),
              onPressed: () {
                final raw = amountText.trim().replaceAll(',', '');
                final amt = double.tryParse(raw);

                if (amt == null || !amt.isFinite) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(const SnackBar(content: Text('Enter a valid number')));
                  return;
                }
                if (amt <= 0) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(const SnackBar(content: Text('Amount must be greater than 0')));
                  return;
                }

                Navigator.of(dialogCtx).pop(_RepayFormResult(amt, note.trim().isEmpty ? null : note.trim()));
              },

              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────── Agent loans popup ───────────────────────
  Future<void> _showAgentLoansDialog(String userId, String? userEmail) async {
    final q = _db.collection('loans').where('userId', isEqualTo: userId).orderBy('requestedAt', descending: true);

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: _ink,
          scrollable: true,
          title: Text(userEmail ?? userId, style: const TextStyle(color: Colors.white)),
          content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: q.snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Text('No loans for this agent.', style: TextStyle(color: Colors.white70));
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final d in docs) ...[
                    _AgentLoanTile(
                      money: _money,
                      statusColor: _statusColor,
                      date: _date,
                      data: d.data(),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Close')),
          ],
        );
      },
    );
  }
}

/* ========================= Widgets ========================= */

class _Segment extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _Segment({required this.text, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? Colors.black : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: text,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(.35)),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onDisburse;
  final VoidCallback? onRepayAgent; // per-agent only
  const _ActionBar({this.onApprove, this.onReject, this.onDisburse, this.onRepayAgent});

  Widget _btn(IconData ic, String txt, {VoidCallback? onTap, Color? bg, Color? fg}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140),
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(ic, size: 18),
          label: Text(txt, overflow: TextOverflow.ellipsis),
          style: ElevatedButton.styleFrom(
            backgroundColor: bg ?? Colors.white12,
            foregroundColor: fg ?? Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final raw = <Widget>[
      if (onApprove != null) _btn(Icons.check_circle, 'Approve', onTap: onApprove, bg: Colors.white, fg: Colors.black87),
      if (onReject != null)  _btn(Icons.close_rounded, 'Reject',  onTap: onReject,  bg: const Color(0xFF36212A)),
      if (onDisburse != null) _btn(Icons.payments, 'Disburse', onTap: onDisburse, bg: const Color(0xFF1E2D23)),
      if (onRepayAgent != null) _btn(Icons.account_balance_wallet_outlined, 'Repay Agent', onTap: onRepayAgent, bg: const Color(0xFF10381E)),
    ];

    return Wrap(spacing: 8, runSpacing: 8, children: raw);
  }
}

class _ChipKpi extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final Stream<String> stream;
  const _ChipKpi({required this.color, required this.icon, required this.label, required this.stream});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: Colors.black.withOpacity(.85), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StreamBuilder<String>(
              stream: stream,
              builder: (_, snap) {
                final v = snap.data ?? '—';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
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

// ───────────────── Company Loan Balance (Total = Repaid + Due) ─────────────────
class _CompanyBalanceCard extends StatelessWidget {
  final NumberFormat money;
  final Stream<num> approvedPrincipalStream; // "Total Loan" principal
  final Stream<num> totalRepaidStream;       // "Repaid Amount"
  const _CompanyBalanceCard({
    required this.money,
    required this.approvedPrincipalStream,
    required this.totalRepaidStream,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x33111111), Color(0x22333333)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.all(14),
      child: StreamBuilder<num>(
        stream: approvedPrincipalStream,
        builder: (context, principalSnap) {
          final totalLoanRaw = (principalSnap.data ?? 0);
          final totalLoan = totalLoanRaw < 0 ? 0 : totalLoanRaw; // safety

          return StreamBuilder<num>(
            stream: totalRepaidStream,
            builder: (context, repaidSnap) {
              final repaidRaw = (repaidSnap.data ?? 0);
              final repaid = repaidRaw < 0 ? 0 : repaidRaw; // safety

              // Identity: Due = max(0, Total - Repaid)
              final due = (totalLoan - repaid) < 0 ? 0 : (totalLoan - repaid);

              // Progress is for visuals only; keep it in [0,1]
              final progress = totalLoan > 0
                  ? (repaid / totalLoan).clamp(0, 1).toDouble()
                  : 0.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Company Loan Balance',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _miniStat('Total Loan',    money.format(totalLoan)),
                      _miniStat('Repaid Amount', money.format(repaid)),
                      _miniStat('Due Amount',    money.format(due)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF65D38B)),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final String loanId;
  final NumberFormat money;
  final String title;
  final String subtitle;
  final String purpose;
  final String status;
  final Color statusColor;
  final String initials;
  final double principal;
  final String userId;
  final String? userEmail;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onDisburse;
  final VoidCallback? onRepayAgent;

  // stable real-time sums
  final Stream<num> repaidStream;
  final num? initialRepaid;
  final void Function(num)? onRepaidChanged;

  const _LoanCard({
    super.key,
    required this.loanId,
    required this.money,
    required this.title,
    required this.subtitle,
    required this.purpose,
    required this.status,
    required this.statusColor,
    required this.initials,
    required this.principal,
    required this.userId,
    required this.userEmail,
    this.onApprove,
    this.onReject,
    this.onDisburse,
    this.onRepayAgent,
    required this.repaidStream,
    this.initialRepaid,
    this.onRepaidChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x1FFFFFFF), Color(0x00000000)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0E2B8F), Color(0xFF0B1F6A)]),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(initials, maxLines: 1, overflow: TextOverflow.fade, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top: title + status
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 160),
                        child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                      _StatusPill(text: status.toUpperCase(), color: statusColor),
                    ],
                  ),

                  const SizedBox(height: 6),
                  Text(subtitle, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),

                  if (purpose.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(purpose, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],

                  const SizedBox(height: 10),

                  // Per-loan live summary — stable with initialRepaid
                  StreamBuilder<num>(
                    stream: repaidStream,
                    initialData: initialRepaid,
                    builder: (context, snap) {
                      final repaid = (snap.data ?? initialRepaid ?? 0).toDouble();
                      onRepaidChanged?.call(repaid);
                      final outstanding = (principal - repaid).clamp(0, double.infinity);
                      final pct = principal > 0 ? (repaid / principal).clamp(0, 1).toDouble() : 0.0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _pill('Repaid', money.format(repaid)),
                              _pill('Outstanding', money.format(outstanding)),
                              if (outstanding == 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.green.withOpacity(.35)),
                                  ),
                                  child: const Text('All Cleared', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 12)),
                                ),
                              if (onRepayAgent != null && outstanding > 0)
                                TextButton.icon(
                                  onPressed: onRepayAgent,
                                  icon: const Icon(Icons.account_balance_wallet_outlined, size: 18, color: Colors.white),
                                  label: const Text('Repay Agent', style: TextStyle(color: Colors.white)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF65D38B)),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 12),
                  _ActionBar(
                    onApprove: onApprove,
                    onReject: onReject,
                    onDisburse: onDisburse,
                    onRepayAgent: onRepayAgent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

class _AgentRowCard extends StatelessWidget {
  final String email;
  final String initials;
  final int loanCount;
  final double totalPrincipal;     // sum of ALL loans (display only)
  final NumberFormat money;
  final String userId;
  final String? userEmail;
  final VoidCallback onRepayAgent;
  final VoidCallback onViewLoans;
  final VoidCallback onPrint;

  // accurate outstanding (sum(approved+disbursed principal) - sum(repayments on those loans))
  final Future<_AgentOutstandingTotals> outstandingFuture;

  // auto hide switch
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x1FFFFFFF), Color(0x00000000)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: const SizedBox(height: 48, child: Center(child: LinearProgressIndicator(minHeight: 3))),
          );
        }

        final totals = snap.data!;
        final repaid = totals.repaid < 0 ? 0 : totals.repaid; // extra safety
        final outstanding = totals.outstanding < 0 ? 0 : totals.outstanding;
        final repayablePrincipal = totals.repayablePrincipal < 0 ? 0 : totals.repayablePrincipal;

        // 👉 auto-hide if fully cleared
        if (autoHideWhenCleared && outstanding == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x1FFFFFFF), Color(0x00000000)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row (email + count)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 160),
                    child: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
                    child: Text('$loanCount loan${loanCount == 1 ? '' : 's'}', style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Totals line — exactly Total (approved+disbursed), Repaid, Due
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _miniPill('Total', money.format(repayablePrincipal)),
                  _miniPill('Repaid', money.format(repaid)),
                  _miniPill('Due', money.format(outstanding)),
                  if (outstanding == 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.withOpacity(.35)),
                      ),
                      child: const Text('No loan left', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 12)),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // Buttons
              if (outstanding > 0)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 140),
                      child: ElevatedButton.icon(
                        onPressed: onRepayAgent,
                        icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                        label: const Text('Repay Agent'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10381E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 140),
                      child: OutlinedButton.icon(
                        onPressed: onViewLoans,
                        icon: const Icon(Icons.list_alt, size: 18),
                        label: const Text('View Loans'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 120),
                      child: OutlinedButton.icon(
                        onPressed: onPrint,
                        icon: const Icon(Icons.print, size: 18),
                        label: const Text('Save PDF'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: onPrint,
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('Save PDF (history)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

class _AgentLoanTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final NumberFormat money;
  final Color Function(String) statusColor;
  final DateFormat date;

  const _AgentLoanTile({
    super.key,
    required this.data,
    required this.money,
    required this.statusColor,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final amount  = (data['amount'] as num? ?? 0).toDouble();
    final type    = (data['type'] ?? 'Loan') as String;
    final status  = (data['status'] ?? 'pending') as String;
    final created = (data['requestedAt'] is Timestamp) ? (data['requestedAt'] as Timestamp).toDate() : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0x22000000), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 6,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 160),
            child: Text(
              '$type • ${money.format(amount)}${created != null ? ' • ${date.format(created)}' : ''}',
              maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white),
            ),
          ),
          _StatusPill(text: status.toUpperCase(), color: statusColor(status)),
        ],
      ),
    );
  }
}

/* ========================= Models & helpers ========================= */

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
  final String type;
  final double amount;
  final DateTime? date;
  final String status;
  final double repaid;
  _LoanRow({required this.type, required this.amount, required this.date, required this.status, required this.repaid});
}

class _RepayRow {
  final DateTime? date;
  final double amount;
  final String note;
  final String loanType;
  _RepayRow({required this.date, required this.amount, required this.note, required this.loanType});
}

class _AgentAggregate {
  final String userId;
  final String? email;
  int loanCount = 0;
  double totalPrincipal = 0;      // all loans (display)
  double repayablePrincipal = 0;  // approved + disbursed only (for due)
  final List<String> loanIds = [];
  _AgentAggregate({required this.userId, required this.email});
}

/// Accurate derived totals for an agent.
class _AgentOutstandingTotals {
  final double repayablePrincipal; // approved + disbursed
  final double repaid;
  final double outstanding;
  _AgentOutstandingTotals({
    required this.repayablePrincipal,
    required this.repaid,
    required this.outstanding,
  });
}

/// Remove overscroll glow in horizontal KPI list
class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}
