// loan_request_screen.dart
// Real-time loan request + history UI with month filter & STABLE totals.
// Firestore collections:
//   - loans                         (fields: userId, userEmail, amount, status, requestedAt, decisionAt, closedAt, ...)
//   - loans/{loanId}/repayments     (fields: amount, userEmail, userId, paidAt | timestamp | createdAt | date)
//
// Header Sums (respect month filter):
// - Total  = sum(amount) for loans with status in {approved, disbursed, closed}   // ✅ includes CLOSED
// - Repaid = sum(amount) of repayments for this user (union of email + uid, de-duplicated)
// - Due    = max(0, Total - Repaid)
//
// Stability improvements:
// - Only commit new “Repaid” when at least one repayment stream has real data and no errors.
// - Never overwrite the cache with zero because a stream is late/empty/errored.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LoanRequestScreen extends StatefulWidget {
  const LoanRequestScreen({super.key});
  @override
  State<LoanRequestScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanRequestScreen>
    with SingleTickerProviderStateMixin {
  static const _brand = Color(0xFF6F3DFF); // primary purple
  static const _brandDark = Color(0xFF4B2AC4);
  static const _brandLight = Color(0xFFBFA8FF);
  static const _accent = Color(0xFFFFC857); // warm yellow CTA

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  late final TabController _tab;

  final _bdt = NumberFormat.currency(locale: 'en_BD', symbol: '৳');
  final double _creditLimit = 300000; // tweak with your policy

  // Month filter: null = All time, otherwise first day of month.
  DateTime? _selectedMonth;

  // Caches to reduce flicker when streams are (re)loading
  double _cachedTotal = 0;
  double _cachedRepaid = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ------------------- Firestore helpers -------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _userLoansStream() {
    final uid = _auth.currentUser?.uid ?? '_';
    return _db
        .collection('loans')
        .where('userId', isEqualTo: uid)
        .orderBy('requestedAt', descending: true)
        .snapshots();
  }

  Future<void> _submitLoan({
    required String type,
    required double amount,
    required int durationMonths,
    required String purpose,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db.collection('loans').add({
      'userId': user.uid,
      'userEmail': user.email,
      'amount': amount,
      'purpose': purpose,
      'durationMonths': durationMonths,
      'type': type, // "Advance/Personal/…"
      'status': 'pending', // pending/approved/rejected/disbursed/withdrawn/closed
      'requestedAt': FieldValue.serverTimestamp(),
      'decisionAt': null,
      'closedAt': null,
      'notes': null,
      'currency': 'BDT',
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.email ?? 'user',
    });
  }

  Future<void> _withdraw(String docId) async {
    await _db.collection('loans').doc(docId).set({
      'status': 'withdrawn',
      'decisionAt': FieldValue.serverTimestamp(),
      'notes': 'Request withdrawn by user',
    }, SetOptions(merge: true));
  }

  // ------------------- Date helpers -------------------
  DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _monthEndExclusive(DateTime d) => DateTime(d.year, d.month + 1, 1);

  bool _isInSelectedMonth(DateTime? when) {
    if (_selectedMonth == null || when == null) return true; // All time or missing timestamp
    final s = _monthStart(_selectedMonth!);
    final e = _monthEndExclusive(_selectedMonth!);
    return (when.isAtSameMomentAs(s) || when.isAfter(s)) && when.isBefore(e);
  }

  // Prefer closedAt → decisionAt → requestedAt for month grouping.
  DateTime? _loanEffectiveWhen(Map<String, dynamic> m) {
    final v = m['closedAt'] ?? m['decisionAt'] ?? m['requestedAt'];
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  // Convert repayment timestamp
  DateTime? _repaymentWhen(Map<String, dynamic> m) {
    final dynamic v = m['paidAt'] ?? m['timestamp'] ?? m['createdAt'] ?? m['date'];
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  // ------------------- UI helpers -------------------
  String _money(num n) => _bdt.format(n);

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'disbursed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'withdrawn':
        return Colors.grey;
      case 'closed':
        return Colors.black87;
      default:
        return Colors.black54;
    }
  }

  // Quick templates
  List<_LoanTemplate> get _templates => const [
    _LoanTemplate('Student Loan', 0.5, 1000, 10000, 'Education'),
    _LoanTemplate('Personal Loan', 2.5, 10000, 100000, 'Personal'),
    _LoanTemplate('Business Loan', 4.0, 10000, 250000, 'Business'),
    _LoanTemplate('House Loan', 4.5, 100000, 500000, 'Personal'),
    _LoanTemplate('Customize Loan', 0.5, 1000, 500000, 'Other'),
  ];

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final name = (user?.displayName ?? user?.email ?? 'User').split('@').first;
    final email = user?.email;
    final uid = user?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F4FF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        title: const Text('Loans', style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Column(
            children: [
              // Month Filter Row
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: _MonthFilterBar(
                  brand: _brand,
                  accent: _accent,
                  selectedMonth: _selectedMonth,
                  onPick: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedMonth ?? DateTime(now.year, now.month, 1),
                      firstDate: DateTime(now.year - 5, 1, 1),
                      lastDate: DateTime(now.year + 1, 12, 31),
                      helpText: 'Select any date inside the month',
                    );
                    if (picked != null) {
                      setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1));
                    }
                  },
                  onClear: () => setState(() => _selectedMonth = null),
                ),
              ),
              // Tabs
              TabBar(
                controller: _tab,
                indicatorColor: _accent,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'My Loans'),
                  Tab(text: 'Request'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _userLoansStream(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Could not load loans. Please check your connection.',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            );
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allLoans = snap.data?.docs ?? [];

          // Filter by month using effective date, and compute stats.
          double totalPrincipal = 0; // ✅ includes approved + disbursed + closed
          int pending = 0, approved = 0, disbursed = 0, rejected = 0, withdrawn = 0, closed = 0;

          final filteredLoans = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          for (final d in allLoans) {
            final m = d.data();
            final st = (m['status'] ?? 'pending') as String;

            final effectiveAt = _loanEffectiveWhen(m);
            if (!_isInSelectedMonth(effectiveAt)) continue;

            filteredLoans.add(d);

            final amt = (m['amount'] ?? 0).toDouble();
            switch (st) {
              case 'pending':
                pending++;
                break;
              case 'approved':
                approved++;
                totalPrincipal += amt; // count
                break;
              case 'disbursed':
                disbursed++;
                totalPrincipal += amt; // count
                break;
              case 'rejected':
                rejected++;
                break;
              case 'withdrawn':
                withdrawn++;
                break;
              case 'closed':
                closed++;
                totalPrincipal += amt; // ✅ count closed too
                break;
            }
          }

          // Cache total to reduce visible flicker when repayments stream reloads
          _cachedTotal = totalPrincipal;

          return TabBarView(
            controller: _tab,
            children: [
              // ================= TAB 1: MY LOANS =================
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _StableRepaidHeader(
                      db: _db,
                      name: name,
                      creditLimit: _creditLimit,
                      brand: _brand,
                      brandDark: _brandDark,
                      accent: _accent,
                      money: _money,
                      selectedMonth: _selectedMonth,
                      email: email,
                      uid: uid,
                      totalPrincipal: totalPrincipal,
                      cachedTotalGetter: () => _cachedTotal,
                      cachedRepaidGetter: () => _cachedRepaid,
                      cachedRepaidSetter: (v) => _cachedRepaid = v,
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _CountersRow(
                        pending: pending,
                        approved: approved,
                        disbursed: disbursed,
                        rejected: rejected,
                        withdrawn: withdrawn,
                        closed: closed,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        _selectedMonth == null
                            ? 'Recent (All time)'
                            : 'Recent (${DateFormat('MMM yyyy').format(_selectedMonth!)})',
                        style: TextStyle(
                          color: _brandDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  if (filteredLoans.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No loan records for this period.')),
                    )
                  else
                    SliverList.separated(
                      itemCount: filteredLoans.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final doc = filteredLoans[i];
                        final m = doc.data();

                        DateTime? requestedAt;
                        final ra = m['requestedAt'];
                        if (ra is Timestamp) requestedAt = ra.toDate();

                        return _LoanCard(
                          title: m['type'] ?? 'Loan',
                          amount: (m['amount'] ?? 0).toDouble(),
                          duration: (m['durationMonths'] ?? 0) as int,
                          status: (m['status'] ?? 'pending') as String,
                          requestedAt: requestedAt,
                          onWithdraw: (m['status'] == 'pending') ? () => _withdraw(doc.id) : null,
                          money: _money,
                          statusColor: _statusColor,
                          brand: _brand,
                        );
                      },
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),

              // ================= TAB 2: REQUEST =================
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _RequestHeader(brand: _brand, light: _brandLight),
                  const SizedBox(height: 16),
                  ..._templates.map(
                        (t) => _TemplateTile(
                      t: t,
                      money: _money,
                      onApply: () => _openRequestSheet(template: t),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accent,
        foregroundColor: Colors.black87,
        icon: const Icon(Icons.add),
        label: const Text('Request Loan'),
        onPressed: () => _openRequestSheet(),
      ),
    );
  }

  // ------------------- Request sheet -------------------
  Future<void> _openRequestSheet({_LoanTemplate? template}) async {
    final typeCtrl = ValueNotifier<String>(template?.kind ?? 'Personal');
    final amountCtrl =
    TextEditingController(text: template != null ? template.min.toInt().toString() : '');
    final monthsCtrl = TextEditingController(text: template != null ? '12' : '');
    final purposeCtrl =
    TextEditingController(text: template?.kind == 'Education' ? 'Tuition & fees' : '');

    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  height: 4,
                  width: 42,
                  decoration:
                  BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('New Loan Request',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 10),
              _DropdownField(
                label: 'Type',
                value: typeCtrl.value,
                items: const ['Advance', 'Personal', 'Medical', 'Education', 'Business', 'Other'],
                onChanged: (v) => typeCtrl.value = v!,
              ),
              const SizedBox(height: 10),
              _TextField(controller: amountCtrl, label: 'Amount (BDT)', keyboard: TextInputType.number),
              const SizedBox(height: 10),
              _TextField(controller: monthsCtrl, label: 'Duration (months)', keyboard: TextInputType.number),
              const SizedBox(height: 10),
              _TextField(controller: purposeCtrl, label: 'Purpose', maxLines: 2),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Submit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    final mn = int.tryParse(monthsCtrl.text.trim()) ?? 0;
                    if (amt <= 0 || mn <= 0) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter a valid amount and duration')),
                        );
                      }
                      return;
                    }
                    await _submitLoan(
                      type: typeCtrl.value,
                      amount: amt,
                      durationMonths: mn,
                      purpose: purposeCtrl.text.trim(),
                    );
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Loan request submitted')));
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    amountCtrl.dispose();
    monthsCtrl.dispose();
    purposeCtrl.dispose();
  }
}

/* ======================= Stable Repaid Header (union of email+uid) ======================= */

class _StableRepaidHeader extends StatelessWidget {
  final FirebaseFirestore db;
  final String name;
  final double creditLimit;
  final Color brand, brandDark, accent;
  final String Function(num) money;
  final DateTime? selectedMonth;
  final String? email;
  final String? uid;

  final double totalPrincipal; // computed from loans (approved+disbursed+closed, month-filtered)
  final double Function() cachedTotalGetter;
  final double Function() cachedRepaidGetter;
  final void Function(double) cachedRepaidSetter;

  const _StableRepaidHeader({
    required this.db,
    required this.name,
    required this.creditLimit,
    required this.brand,
    required this.brandDark,
    required this.accent,
    required this.money,
    required this.selectedMonth,
    required this.email,
    required this.uid,
    required this.totalPrincipal,
    required this.cachedTotalGetter,
    required this.cachedRepaidGetter,
    required this.cachedRepaidSetter,
  });

  DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _monthEndExclusive(DateTime d) => DateTime(d.year, d.month + 1, 1);
  bool _isInSelectedMonth(DateTime? when) {
    if (selectedMonth == null || when == null) return true;
    final s = _monthStart(selectedMonth!);
    final e = _monthEndExclusive(selectedMonth!);
    return (when.isAtSameMomentAs(s) || when.isAfter(s)) && when.isBefore(e);
  }

  DateTime? _repaymentWhen(Map<String, dynamic> m) {
    final dynamic v = m['paidAt'] ?? m['timestamp'] ?? m['createdAt'] ?? m['date'];
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Primary stream by email (if we have one)
    final emailStream = (email == null)
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : db.collectionGroup('repayments').where('userEmail', isEqualTo: email).snapshots();

    // Legacy stream by uid (if we have one)
    final uidStream = (uid == null)
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : db.collectionGroup('repayments').where('userId', isEqualTo: uid).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: emailStream,
      builder: (context, emailSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: uidStream,
          builder: (context, uidSnap) {
            // If either stream errored, DO NOT blow away the cache—keep last stable value.
            if (emailSnap.hasError || uidSnap.hasError) {
              final total = totalPrincipal != 0 ? totalPrincipal : cachedTotalGetter();
              final repaid = cachedRepaidGetter();
              final double due = (total - repaid) < 0 ? 0 : (total - repaid);
              final progress = (creditLimit <= 0) ? 0.0 : (due / creditLimit).clamp(0.0, 1.0);
              return _HeaderCard(
                name: name,
                total: total,
                repaid: repaid,
                due: due,
                limit: creditLimit,
                progress: progress,
                brand: brand,
                brandDark: brandDark,
                accent: accent,
                money: money,
              );
            }

            // Only recompute when at least one snapshot has real data.
            final hasAnyData = (emailSnap.hasData && emailSnap.data != null) ||
                (uidSnap.hasData && uidSnap.data != null);

            double unionRepaid;
            if (hasAnyData) {
              final seen = <String>{};
              double sum = 0;

              if (emailSnap.hasData && emailSnap.data != null) {
                for (final d in emailSnap.data!.docs) {
                  final m = d.data();
                  final dt = _repaymentWhen(m);
                  if (!_isInSelectedMonth(dt)) continue;
                  final path = d.reference.path;
                  if (seen.add(path)) sum += (m['amount'] as num? ?? 0).toDouble();
                }
              }
              if (uidSnap.hasData && uidSnap.data != null) {
                for (final d in uidSnap.data!.docs) {
                  final m = d.data();
                  final dt = _repaymentWhen(m);
                  if (!_isInSelectedMonth(dt)) continue;
                  final path = d.reference.path;
                  if (seen.add(path)) sum += (m['amount'] as num? ?? 0).toDouble();
                }
              }

              unionRepaid = sum;
              cachedRepaidSetter(unionRepaid); // update stable cache ONLY when we had data
            } else {
              // Neither has emitted data yet → keep last stable value
              unionRepaid = cachedRepaidGetter();
            }

            final total = totalPrincipal != 0 ? totalPrincipal : cachedTotalGetter();
            final double due = (total - unionRepaid) < 0 ? 0 : (total - unionRepaid);
            final progress = (creditLimit <= 0) ? 0.0 : (due / creditLimit).clamp(0.0, 1.0);

            return _HeaderCard(
              name: name,
              total: total,
              repaid: unionRepaid,
              due: due,
              limit: creditLimit,
              progress: progress,
              brand: brand,
              brandDark: brandDark,
              accent: accent,
              money: money,
            );
          },
        );
      },
    );
  }
}

/* ======================= Helper Widgets ======================= */

class _MonthFilterBar extends StatelessWidget {
  final Color brand, accent;
  final DateTime? selectedMonth;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _MonthFilterBar({
    required this.brand,
    required this.accent,
    required this.selectedMonth,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final label = selectedMonth == null
        ? 'All time'
        : DateFormat('MMMM yyyy').format(selectedMonth!);
    return Row(
      children: [
        const SizedBox(width: 4),
        Icon(Icons.calendar_month, color: Colors.white.withOpacity(.95)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(.25)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPick,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (selectedMonth != null)
          IconButton(
            tooltip: 'Clear',
            onPressed: onClear,
            icon: const Icon(Icons.clear, color: Colors.white),
          ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String name;
  final double total;
  final double repaid;
  final double due;
  final double limit;
  final double progress;
  final Color brand, brandDark, accent;
  final String Function(num) money;

  const _HeaderCard({
    required this.name,
    required this.total,
    required this.repaid,
    required this.due,
    required this.limit,
    required this.progress,
    required this.brand,
    required this.brandDark,
    required this.accent,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, num value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(money(value),
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [brand, brandDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x30000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hi, $name', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 10,
                children: [
                  stat('Total Loan', total),
                  stat('Repaid', repaid),
                  stat('Due', due),
                ],
              ),
              const SizedBox(height: 8),
              Text('Limit: ${money(limit)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
                Text('${(progress * 100).round()}%',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountersRow extends StatelessWidget {
  final int pending, approved, disbursed, rejected, withdrawn, closed;
  const _CountersRow({
    required this.pending,
    required this.approved,
    required this.disbursed,
    required this.rejected,
    required this.withdrawn,
    required this.closed,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, int n, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w800)),
        const SizedBox(width: 6),
        Text('$n', style: TextStyle(color: c, fontWeight: FontWeight.w700)),
      ]),
    );

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        chip('Pending', pending, Colors.orange),
        chip('Approved', approved, Colors.blue),
        chip('Disbursed', disbursed, Colors.green),
        chip('Rejected', rejected, Colors.red),
        chip('Withdrawn', withdrawn, Colors.grey),
        chip('Closed', closed, Colors.black87),
      ],
    );
  }
}

class _LoanCard extends StatelessWidget {
  final String title;
  final double amount;
  final int duration;
  final String status;
  final DateTime? requestedAt;
  final VoidCallback? onWithdraw;
  final String Function(num) money;
  final Color Function(String) statusColor;
  final Color brand;

  const _LoanCard({
    required this.title,
    required this.amount,
    required this.duration,
    required this.status,
    required this.requestedAt,
    required this.onWithdraw,
    required this.money,
    required this.statusColor,
    required this.brand,
  });

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: brand.withOpacity(.1), shape: BoxShape.circle),
            child: const Icon(Icons.request_page, color: Color(0xFF6F3DFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.withOpacity(.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.withOpacity(.35)),
                  ),
                  child: Text(status.toUpperCase(),
                      style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 11)),
                ),
              ]),
              const SizedBox(height: 6),
              Text('${money(amount)} • ${duration}m', style: const TextStyle(color: Colors.black54)),
              if (requestedAt != null)
                Text('Requested: ${DateFormat('d MMM, yyyy').format(requestedAt!)}',
                    style: const TextStyle(color: Colors.black45, fontSize: 12)),
            ]),
          ),
          if (onWithdraw != null) const SizedBox(width: 8),
          if (onWithdraw != null)
            TextButton(onPressed: onWithdraw, child: const Text('Withdraw')),
        ],
      ),
    );
  }
}

class _RequestHeader extends StatelessWidget {
  final Color brand, light;
  const _RequestHeader({required this.brand, required this.light});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [brand, light], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x30000000), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Row(
        children: const [
          Icon(Icons.savings, color: Colors.white, size: 34),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Choose a loan that fits your needs. You’ll get updates as your request progresses.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final _LoanTemplate t;
  final String Function(num) money;
  final VoidCallback onApply;

  const _TemplateTile({required this.t, required this.money, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: Color(0x146F3DFF), shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_wallet, color: Color(0xFF6F3DFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 2),
              Text('${money(t.min)} – ${money(t.max)} • ${t.rate.toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.black54)),
            ]),
          ),
          TextButton(onPressed: onApply, child: const Text('Apply')),
        ],
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboard;
  final int maxLines;

  const _TextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboard,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

/* ======================= Models ======================= */

class _LoanTemplate {
  final String title;
  final double rate; // display only
  final double min;
  final double max;
  final String kind; // maps to your `type` field

  const _LoanTemplate(this.title, this.rate, this.min, this.max, this.kind);
}
