import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color _brand     = Color(0xFF2A0A4B);
const Color _brandMid  = Color(0xFF4B2AC4);
const Color _bg        = Color(0xFFF8F7FC);
const Color _border    = Color(0xFFE8E4F0);

class LoanRequestScreen extends StatefulWidget {
  const LoanRequestScreen({super.key});
  @override
  State<LoanRequestScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanRequestScreen>
    with SingleTickerProviderStateMixin {
  String _cid = '';
  final _auth = FirebaseAuth.instance;
  late final TabController _tab;
  final _fmt = NumberFormat.currency(locale: 'en_BD', symbol: '৳', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Streams ────────────────────────────────────────────────
  Stream<QuerySnapshot<Map<String, dynamic>>> _myLoans() {
    if (_cid.isEmpty) return const Stream.empty();
    final uid = _auth.currentUser?.uid ?? '_';
    return DB.colSync(_cid, C.loans)
        .where('userId', isEqualTo: uid)
        .orderBy('requestedAt', descending: true)
        .snapshots();
  }

  // ── Actions ────────────────────────────────────────────────
  Future<void> _submit({
    required String type,
    required double amount,
    required int months,
    required String purpose,
  }) async {
    final user = _auth.currentUser;
    if (user == null || _cid.isEmpty) return;
    await DB.colSync(_cid, C.loans).add({
      'userId':         user.uid,
      'userEmail':      user.email,
      'amount':         amount,
      'purpose':        purpose,
      'durationMonths': months,
      'type':           type,
      'status':         'pending',
      'requestedAt':    FieldValue.serverTimestamp(),
      'createdAt':      FieldValue.serverTimestamp(),
      'createdBy':      user.email ?? 'user',
      'decisionAt':     null,
      'closedAt':       null,
      'notes':          null,
      'currency':       'BDT',
    });
  }

  Future<void> _withdraw(String docId) async {
    await DB.colSync(_cid, C.loans).doc(docId).set({
      'status':     'withdrawn',
      'decisionAt': FieldValue.serverTimestamp(),
      'notes':      'Withdrawn by user',
    }, SetOptions(merge: true));
  }

  // ── Money helper ───────────────────────────────────────────
  String _m(num n) => _fmt.format(n);

  // ── Status helpers ─────────────────────────────────────────
  static Color _statusColor(String s) {
    switch (s) {
      case 'pending':   return Colors.orange;
      case 'approved':  return Colors.blue;
      case 'disbursed': return const Color(0xFF22C55E);
      case 'rejected':  return Colors.red;
      case 'withdrawn': return Colors.grey;
      case 'closed':    return Colors.teal;
      default:          return Colors.black54;
    }
  }

  static String _statusLabel(String s) {
    const m = {
      'pending':   'Pending',
      'approved':  'Approved',
      'disbursed': 'Disbursed',
      'rejected':  'Rejected',
      'withdrawn': 'Withdrawn',
      'closed':    'Closed',
    };
    return m[s] ?? s;
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Loans', style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [Tab(text: 'My Loans'), Tab(text: 'Apply')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_buildMyLoansTab(), _buildApplyTab()],
      ),
    );
  }

  // ── Tab 1: My Loans ────────────────────────────────────────
  Widget _buildMyLoansTab() {
    if (_cid.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _brand));
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _myLoans(),
      builder: (_, snap) {
        if (snap.hasError) {
          return Center(
            child: Text('Failed to load loans',
                style: TextStyle(color: Colors.red.shade400)));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: _brand));
        }

        final docs = snap.data!.docs;

        // Compute summary from disbursed/approved loans
        double disbursed = 0;
        int pending = 0;
        for (final d in docs) {
          final m  = d.data();
          final st = (m['status'] ?? '') as String;
          if (st == 'disbursed' || st == 'approved') {
            disbursed += (m['amount'] as num? ?? 0).toDouble();
          }
          if (st == 'pending') pending++;
        }

        return CustomScrollView(
          slivers: [
            // Summary header
            SliverToBoxAdapter(
              child: _SummaryCard(
                disbursed: disbursed,
                pending: pending,
                money: _m,
                cid: _cid,
                uid: _auth.currentUser?.uid,
                email: _auth.currentUser?.email,
              ),
            ),

            if (docs.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 48, color: Colors.black26),
                    SizedBox(height: 12),
                    Text('No loan records yet.',
                        style: TextStyle(color: Colors.black45,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                sliver: SliverList.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d  = docs[i];
                    final m  = d.data();
                    final st = (m['status'] ?? 'pending') as String;
                    final amt = (m['amount'] as num? ?? 0).toDouble();
                    final type = (m['type'] ?? 'Loan') as String;
                    final months = (m['durationMonths'] as num? ?? 0).toInt();
                    final purpose = (m['purpose'] ?? '') as String;
                    final ra = m['requestedAt'];
                    final requestedAt = ra is Timestamp ? ra.toDate() : null;

                    return _LoanTile(
                      type: type,
                      amount: amt,
                      months: months,
                      purpose: purpose,
                      status: st,
                      requestedAt: requestedAt,
                      money: _m,
                      canWithdraw: st == 'pending',
                      onWithdraw: () => _withdraw(d.id),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Tab 2: Apply ───────────────────────────────────────────
  Widget _buildApplyTab() {
    const types = [
      ('Personal',  Icons.person_outline),
      ('Medical',   Icons.local_hospital_outlined),
      ('Education', Icons.school_outlined),
      ('Business',  Icons.business_outlined),
      ('Advance',   Icons.payments_outlined),
      ('Other',     Icons.more_horiz),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _brand.withOpacity(.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _brand.withOpacity(.15)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, color: _brand.withOpacity(.7), size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Select a loan type to apply. Your request will be reviewed by HR.',
                style: TextStyle(fontSize: 13, color: _brand,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Loan type grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: types.map((t) => _TypeCard(
            label: t.$1,
            icon: t.$2,
            onTap: () => _openSheet(type: t.$1),
          )).toList(),
        ),
      ],
    );
  }

  // ── Apply bottom sheet ─────────────────────────────────────
  Future<void> _openSheet({required String type}) async {
    final amtCtl  = TextEditingController();
    final mnCtl   = TextEditingController();
    final purCtl  = TextEditingController();

    // Capture the parent ScaffoldMessenger before entering the sheet so we
    // can safely show a snackbar after the sheet is dismissed.
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) {
        // All mutable state lives inside a dedicated StatefulWidget so that
        // setState / Navigator.pop never touch a disposed BuildContext.
        return _LoanApplySheet(
          initialType: type,
          amtCtl: amtCtl,
          mnCtl: mnCtl,
          purCtl: purCtl,
          messenger: messenger,
          onSubmit: (selType, amt, mn, purpose) async {
            await _submit(
              type: selType,
              amount: amt,
              months: mn,
              purpose: purpose,
            );
          },
        );
      },
    );

    amtCtl.dispose();
    mnCtl.dispose();
    purCtl.dispose();
  }
}

// ── Summary card ──────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final double disbursed;
  final int pending;
  final String Function(num) money;
  final String cid;
  final String? uid;
  final String? email;

  const _SummaryCard({
    required this.disbursed,
    required this.pending,
    required this.money,
    required this.cid,
    required this.uid,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    // Stream total repaid — scoped to this company's loans for this user only.
    // Queries data/{cid}/loans where userId == uid, then sums each loan's repayments subcollection.
    final repaidStream = (uid == null || cid.isEmpty)
        ? Stream.value(0.0)
        : DB.colSync(cid, C.loans)
            .where('userId', isEqualTo: uid)
            .where('status', whereIn: ['approved', 'disbursed', 'closed'])
            .snapshots()
            .asyncMap((loansSnap) async {
              double total = 0.0;
              for (final loan in loansSnap.docs) {
                final repSnap = await DB.subColSync(cid, C.loans, loan.id, C.repayments).get();
                total += repSnap.docs.fold(
                    0.0, (s, d) => s + (d.data()['amount'] as num? ?? 0).toDouble());
              }
              return total;
            });

    return StreamBuilder<double>(
      stream: repaidStream,
      builder: (_, snap) {
        final repaid = snap.data ?? 0.0;
        final outstanding = (disbursed - repaid).clamp(0.0, double.infinity);

        return Container(
          margin: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_brand, _brandMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Loan Summary',
                style: TextStyle(color: Colors.white70, fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Stat('Disbursed', money(disbursed))),
              Expanded(child: _Stat('Repaid', money(repaid))),
              Expanded(child: _Stat('Outstanding', money(outstanding),
                  highlight: outstanding > 0)),
            ]),
            if (pending > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(.2),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.orange.withOpacity(.4)),
                ),
                child: Text('$pending request${pending > 1 ? 's' : ''} pending review',
                    style: const TextStyle(color: Colors.orange,
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _Stat(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value,
          style: TextStyle(
              color: highlight ? const Color(0xFFFFC857) : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15)),
      const SizedBox(height: 2),
      Text(label,
          style: const TextStyle(color: Colors.white60, fontSize: 11)),
    ]);
  }
}

// ── Loan tile ─────────────────────────────────────────────────
class _LoanTile extends StatelessWidget {
  final String type, status, purpose;
  final double amount;
  final int months;
  final DateTime? requestedAt;
  final String Function(num) money;
  final bool canWithdraw;
  final VoidCallback onWithdraw;

  const _LoanTile({
    required this.type,
    required this.amount,
    required this.months,
    required this.purpose,
    required this.status,
    required this.requestedAt,
    required this.money,
    required this.canWithdraw,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    final c = _LoanScreenState._statusColor(status);
    final label = _LoanScreenState._statusLabel(status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top row: type + status
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _brand.withOpacity(.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet_outlined,
                  color: _brand, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(type,
                  style: const TextStyle(fontWeight: FontWeight.w800,
                      fontSize: 15, color: _brand)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: c.withOpacity(.1),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: c.withOpacity(.3)),
              ),
              child: Text(label,
                  style: TextStyle(color: c, fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ]),

          const SizedBox(height: 10),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 10),

          // Amount + duration row
          Row(children: [
            _InfoPill(Icons.payments_outlined, money(amount)),
            const SizedBox(width: 8),
            _InfoPill(Icons.schedule_outlined, '${months}m'),
            if (requestedAt != null) ...[
              const SizedBox(width: 8),
              _InfoPill(Icons.calendar_today_outlined,
                  DateFormat('d MMM yyyy').format(requestedAt!)),
            ],
          ]),

          // Purpose
          if (purpose.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(purpose,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],

          // Withdraw button
          if (canWithdraw) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onWithdraw,
                icon: const Icon(Icons.undo_outlined, size: 16),
                label: const Text('Withdraw Request'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade400,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoPill(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.grey.shade500),
      const SizedBox(width: 4),
      Text(text,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600,
              fontWeight: FontWeight.w600)),
    ]);
  }
}

// ── Type card (apply tab) ─────────────────────────────────────
class _TypeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _TypeCard({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _brand.withOpacity(.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: _brand, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13, color: _brand),
                  overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.chevron_right, color: _brand, size: 18),
          ]),
        ),
      ),
    );
  }
}

// ── Sheet field wrapper ───────────────────────────────────────
class _SheetField extends StatelessWidget {
  final Widget child;
  final String label;
  const _SheetField({required this.child, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        child,
      ]),
    );
  }
}

// ── Loan apply sheet (self-contained StatefulWidget) ──────────
// Keeping this as its own widget avoids the _dependents.isEmpty assertion
// that occurs when StatefulBuilder's setState is called after the sheet's
// BuildContext has been disposed (i.e. after Navigator.pop).
class _LoanApplySheet extends StatefulWidget {
  final String initialType;
  final TextEditingController amtCtl, mnCtl, purCtl;
  final ScaffoldMessengerState messenger;
  final Future<void> Function(String type, double amt, int mn, String purpose) onSubmit;

  const _LoanApplySheet({
    required this.initialType,
    required this.amtCtl,
    required this.mnCtl,
    required this.purCtl,
    required this.messenger,
    required this.onSubmit,
  });

  @override
  State<_LoanApplySheet> createState() => _LoanApplySheetState();
}

class _LoanApplySheetState extends State<_LoanApplySheet> {
  late String _selType;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selType = widget.initialType;
  }

  Future<void> _handleSubmit() async {
    final amt = double.tryParse(widget.amtCtl.text.trim()) ?? 0;
    final mn  = int.tryParse(widget.mnCtl.text.trim()) ?? 0;

    if (amt <= 0 || mn <= 0) {
      widget.messenger.showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid amount and duration.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (mounted) setState(() => _loading = true);

    bool success = false;
    try {
      await widget.onSubmit(_selType, amt, mn, widget.purCtl.text.trim());
      success = true;
    } catch (_) {
      success = false;
    }

    // Dismiss the sheet first — before touching any parent context.
    if (mounted) Navigator.pop(context);

    // Now safely show feedback on the parent scaffold.
    if (success) {
      widget.messenger.showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your loan request has been submitted and is now under review.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      widget.messenger.showSnackBar(
        SnackBar(
          content: const Text(
              'Something went wrong. Please try again in a moment.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: bottomInset + 24,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title row
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _brand.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet_outlined,
                  color: _brand, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('New Loan Request',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                      color: _brand)),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
          const SizedBox(height: 16),

          // Loan type — plain DropdownButton (no Form/InheritedWidget dependency)
          _SheetField(
            label: 'Loan Type',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selType,
                isExpanded: true,
                dropdownColor: Colors.white,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                    fontSize: 14),
                items: ['Personal', 'Medical', 'Education', 'Business', 'Advance', 'Other']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v != null && mounted) setState(() => _selType = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          _SheetField(
            label: 'Amount (৳)',
            child: TextField(
              controller: widget.amtCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration.collapsed(hintText: 'e.g. 50000'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),

          _SheetField(
            label: 'Duration (months)',
            child: TextField(
              controller: widget.mnCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration.collapsed(hintText: 'e.g. 12'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),

          _SheetField(
            label: 'Purpose (optional)',
            child: TextField(
              controller: widget.purCtl,
              maxLines: 2,
              decoration: const InputDecoration.collapsed(
                  hintText: 'Briefly explain the purpose'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loading ? null : _handleSubmit,
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Request',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15,
                          color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}
