import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/local_storage_service.dart';

import 'new_invoices_screen.dart';
import 'all_invoices_screen.dart';
import 'sales_report_screen.dart';
import 'order_progress_screen.dart';
import 'work_order_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _bg      = Color(0xFFF7F9FC);
const Color _primary = Color(0xFF2563EB);
const Color _primaryDk = Color(0xFF1E3A8A);
const Color _card    = Color(0xFFFFFFFF);
const Color _border  = Color(0x14000000);
const Color _fg      = Color(0xFF0F172A);
const Color _muted   = Color(0xFF94A3B8);
const Color _success = Color(0xFF16A34A);
const Color _warning = Color(0xFFF97316);

class _Feature {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _Feature(this.icon, this.label, this.onTap);
}

class SalesScreen extends StatefulWidget {
  const SalesScreen({Key? key}) : super(key: key);

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  String _cid = '';
  String? userEmail;
  String? userFullName;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _curDocSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _curQuerySub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _prevQuerySub;

  double? _currentMonthTarget;
  double? _previousMonthTarget;

  double salesTarget   = 0;
  int    orderCount    = 0;
  double totalSales    = 0;
  bool   targetReached = false;

  DateTime selectedMonth = DateTime.now();
  int _activeTab = 0;
  int _bottomIdx = 0;

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
    _loadSession();
  }

  @override
  void dispose() {
    _curDocSub?.cancel();
    _curQuerySub?.cancel();
    _prevQuerySub?.cancel();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    if (session == null || !mounted) return;
    userEmail = (session['email'] as String?)?.trim();
    String? sessionName = (session['fullName'] as String?)?.trim();
    String? fetchedName;
    if (userEmail != null && userEmail!.isNotEmpty) {
      final u = await DB.colSync(_cid, C.users)
          .where('email', isEqualTo: userEmail).limit(1).get();
      if (u.docs.isNotEmpty) {
        final m = u.docs.first.data();
        fetchedName = (m['fullName'] ?? m['name'] ?? m['displayName'] ?? '').toString().trim();
      }
    }
    userFullName = (sessionName?.isNotEmpty == true ? sessionName : fetchedName)?.trim();
    if ((userFullName == null || userFullName!.isEmpty) && (userEmail?.isNotEmpty ?? false)) {
      userFullName = userEmail!.split('@').first;
    }
    _attachTargetListeners();
    await _calculateSales();
    if (mounted) setState(() {});
  }

  String _periodLabel(DateTime dt) => DateFormat('MMMM yyyy').format(dt);
  String _periodKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

  double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '')) ?? 0.0;
  }

  String _normalize(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  double? _readTarget(Map<String, dynamic>? m) {
    if (m == null) return null;
    final emailLower = (userEmail ?? '').toLowerCase();
    final nameLower  = _normalize(userFullName ?? '');
    final localLower = (userEmail ?? '').split('@').first.toLowerCase();

    final idxEmail = (m['targetsIndexEmail'] as Map?)
        ?.map((k, v) => MapEntry(k.toString().toLowerCase(), v));
    if (idxEmail != null && emailLower.isNotEmpty && idxEmail[emailLower] != null) {
      final v = _asDouble(idxEmail[emailLower]);
      if (v > 0) return v;
    }

    final idxLower = (m['targetsIndexLower'] as Map?)
        ?.map((k, v) => MapEntry(k.toString().toLowerCase(), v));
    if (idxLower != null) {
      if (nameLower.isNotEmpty && idxLower[nameLower] != null) {
        final v = _asDouble(idxLower[nameLower]);
        if (v > 0) return v;
      }
      if (localLower.isNotEmpty && idxLower[localLower] != null) {
        final v = _asDouble(idxLower[localLower]);
        if (v > 0) return v;
      }
    }

    final list = (m['salesTargets'] as List?) ?? const [];
    for (final e in list) {
      final em  = (e?['email'] ?? '').toString().toLowerCase();
      final nm  = _normalize((e?['name'] ?? '').toString());
      final mx  = _asDouble(e?['maxTarget']);
      final ft  = _asDouble(e?['finalTarget']);
      final eff = ft > 0 ? ft : mx;
      final byEmail = emailLower.isNotEmpty && em.isNotEmpty && em == emailLower;
      final byName  = nm.isNotEmpty && (nm == nameLower || nm == localLower);
      if ((byEmail || byName) && eff > 0) return eff;
    }
    return null;
  }

  void _updateTarget() {
    final next = _currentMonthTarget ?? _previousMonthTarget ?? salesTarget;
    setState(() {
      salesTarget  = next;
      targetReached = salesTarget > 0 && totalSales >= salesTarget;
    });
  }

  void _attachTargetListeners() {
    _curDocSub?.cancel();
    _curQuerySub?.cancel();
    _prevQuerySub?.cancel();

    final curKey     = _periodKey(selectedMonth);
    final prevKey    = _periodKey(DateTime(selectedMonth.year, selectedMonth.month - 1));
    final curPeriod  = _periodLabel(selectedMonth);
    final prevPeriod = _periodLabel(DateTime(selectedMonth.year, selectedMonth.month - 1));

    _curDocSub = DB.colSync(_cid, C.budgets).doc(curKey).snapshots().listen((doc) {
      if (doc.exists) {
        _currentMonthTarget = _readTarget(doc.data());
        _updateTarget();
      }
    });

    _curQuerySub = DB.colSync(_cid, C.budgets)
        .where('period', isEqualTo: curPeriod).limit(1).snapshots().listen((qs) {
      if (qs.docs.isNotEmpty) {
        _currentMonthTarget = _readTarget(qs.docs.first.data());
        _updateTarget();
      }
    });

    _prevQuerySub = DB.colSync(_cid, C.budgets)
        .where('period', isEqualTo: prevPeriod).limit(1).snapshots().listen((qs) {
      if (qs.docs.isNotEmpty) {
        _previousMonthTarget = _readTarget(qs.docs.first.data());
        _updateTarget();
      }
    });
  }

  Future<void> _calculateSales() async {
    if (userEmail == null) return;
    final start = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final end   = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

    final snap = await DB.colSync(_cid, C.invoices)
        .where('agentEmail', isEqualTo: userEmail)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    double paid = 0;
    int count   = 0;

    bool isPaid(Map<String, dynamic> m) {
      final flag   = (m['payment'] is Map) && ((m['payment']['taken'] as bool?) ?? false);
      final status = (m['status'] ?? '').toString().toLowerCase();
      return flag || status.contains('payment taken') || status.contains('paid');
    }

    for (final doc in snap.docs) {
      final m = doc.data();
      if (isPaid(m)) {
        paid  += (m['grandTotal'] as num? ?? 0).toDouble();
        count += 1;
      }
    }

    if (!mounted) return;
    setState(() {
      totalSales    = paid;
      orderCount    = count;
      targetReached = salesTarget > 0 && totalSales >= salesTarget;
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2025, 1),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      builder: (c, w) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: w!,
      ),
    );
    if (picked != null && picked != selectedMonth) {
      setState(() => selectedMonth = picked);
      _attachTargetListeners();
      await _calculateSales();
    }
  }

  bool _isPaid(Map<String, dynamic> m) {
    final flag   = (m['payment'] is Map) && ((m['payment']['taken'] as bool?) ?? false);
    final status = (m['status'] ?? '').toString().toLowerCase();
    return flag || status.contains('paid') || status.contains('payment taken');
  }

  @override
  Widget build(BuildContext context) {
    if (userEmail == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final since    = DateTime.now().subtract(const Duration(days: 30));
    final invQuery = DB.colSync(_cid, C.invoices)
        .where('agentEmail', isEqualTo: userEmail)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('timestamp', descending: true);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primaryDk,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Sales',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
        centerTitle: true,
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: invQuery.snapshots(),
        builder: (ctx, snap) {
          final docs = snap.data?.docs ?? [];
          final totalInv = docs.length;
          final paidCount = docs.where((d) => _isPaid(d.data())).length;
          final pendingCount = totalInv - paidCount;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeroCard(
                  totalSales: totalSales,
                  salesTarget: salesTarget,
                  orderCount: orderCount,
                  targetReached: targetReached,
                  selectedMonth: selectedMonth,
                  totalInv: totalInv,
                  paidCount: paidCount,
                  pendingCount: pendingCount,
                  onPickMonth: _pickMonth,
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(child: _QuickActions(context)),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent transactions',
                          style: GoogleFonts.inter(
                              fontSize: 16, fontWeight: FontWeight.w700, color: _fg)),
                      Text('Last 30 days',
                          style: GoogleFonts.inter(fontSize: 12, color: _muted)),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(child: _TabBar(active: _activeTab, onChanged: (i) => setState(() => _activeTab = i))),

              SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: _activeTab == 0 ? _InvoiceList(docs: docs, onDetail: _showDetail) : _EmptyTab(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),

      bottomNavigationBar: _BottomNav(
        currentIndex: _bottomIdx,
        onTap: (i) {
          setState(() => _bottomIdx = i);
          switch (i) {
            case 0: Navigator.push(context, MaterialPageRoute(builder: (_) => const NewInvoicesScreen())); break;
            case 1: Navigator.push(context, MaterialPageRoute(builder: (_) => const AllInvoicesScreen())); break;
            case 2: Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkOrderScreen())); break;
            case 3: Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReportScreen())); break;
            case 4: Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderProgressScreen())); break;
          }
        },
      ),
    );
  }

  Widget _QuickActions(BuildContext context) {
    final tiles = [
      _Feature(Icons.description_rounded,  'New Invoice',  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewInvoicesScreen()))),
      _Feature(Icons.list_alt_rounded,     'All Invoices', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllInvoicesScreen()))),
      _Feature(Icons.work_history_rounded, 'Work Orders',  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkOrderScreen()))),
      _Feature(Icons.bar_chart_rounded,    'Reports',      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReportScreen()))),
      _Feature(Icons.timeline_rounded,     'Progress',     () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderProgressScreen()))),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: .9,
      ),
      itemBuilder: (_, i) {
        final f = tiles[i];
        return GestureDetector(
          onTap: f.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(f.icon, color: _primary, size: 20),
                ),
                const SizedBox(height: 6),
                Text(f.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w600, color: _fg)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDetail(String id, Map<String, dynamic> m) {
    final customer = (m['customerName'] ?? 'N/A').toString();
    final amt      = ((m['grandTotal'] as num?) ?? 0).toDouble();
    final tracking = (m['tracking_number'] ?? '').toString();
    final status   = (m['status'] ?? '').toString();
    final ts       = m['timestamp'];
    final date     = ts is Timestamp ? ts.toDate() : DateTime.now();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customer,
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w700, color: _fg)),
            const SizedBox(height: 12),
            _KV('Status',   status.isEmpty ? '—' : status),
            _KV('Tracking', tracking.isEmpty ? '—' : tracking),
            _KV('Date',     DateFormat('dd MMM, yyyy').format(date)),
            _KV('Amount',   '৳${amt.toStringAsFixed(0)}'),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const AllInvoicesScreen())),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text('Open Invoice',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _KV(String k, String v) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(k,
              style: GoogleFonts.inter(fontSize: 12, color: _muted, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: _fg)),
        ),
      ],
    ),
  );
}

// ── Hero card ─────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final double totalSales;
  final double salesTarget;
  final int orderCount;
  final bool targetReached;
  final DateTime selectedMonth;
  final int totalInv;
  final int paidCount;
  final int pendingCount;
  final VoidCallback onPickMonth;

  const _HeroCard({
    required this.totalSales,
    required this.salesTarget,
    required this.orderCount,
    required this.targetReached,
    required this.selectedMonth,
    required this.totalInv,
    required this.paidCount,
    required this.pendingCount,
    required this.onPickMonth,
  });

  @override
  Widget build(BuildContext context) {
    final achievement = salesTarget <= 0
        ? 0.0
        : (totalSales / salesTarget * 100).clamp(0.0, 100.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _primaryDk],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: _primary.withOpacity(.25),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month picker row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sales Summary',
                  style: GoogleFonts.inter(
                      color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
              GestureDetector(
                onTap: onPickMonth,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text(DateFormat.yMMMM().format(selectedMonth),
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Big sales number
          Text(
            '৳${totalSales.toStringAsFixed(0)}',
            style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                height: 1),
          ),
          Text('Total paid sales',
              style: GoogleFonts.inter(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 14),

          // Progress bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Target progress',
                            style: GoogleFonts.inter(
                                color: Colors.white70, fontSize: 11)),
                        Text('${achievement.toStringAsFixed(0)}%',
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: achievement / 100,
                        minHeight: 6,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            targetReached ? Colors.greenAccent.shade400 : Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // KPI row
          Row(
            children: [
              _KpiChip(label: 'Target',  value: salesTarget > 0 ? '৳${salesTarget.toStringAsFixed(0)}' : '—'),
              const SizedBox(width: 8),
              _KpiChip(label: 'Orders',  value: '$orderCount'),
              const SizedBox(width: 8),
              _KpiChip(label: 'Paid',    value: '$paidCount', color: Colors.greenAccent.shade400),
              const SizedBox(width: 8),
              _KpiChip(label: 'Pending', value: '$pendingCount', color: Colors.orange.shade300),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _KpiChip({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.inter(
                    color: color ?? Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1)),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.inter(
                    color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onChanged;
  const _TabBar({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const tabs = ['All Invoices', 'Expenses', 'Income'];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final sel = i == active;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? _primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(tabs[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : _muted)),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Invoice list ──────────────────────────────────────────────────────────────
class _InvoiceList extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final void Function(String, Map<String, dynamic>) onDetail;
  const _InvoiceList({required this.docs, required this.onDetail});

  bool _isPaid(Map<String, dynamic> m) {
    final flag   = (m['payment'] is Map) && ((m['payment']['taken'] as bool?) ?? false);
    final status = (m['status'] ?? '').toString().toLowerCase();
    return flag || status.contains('paid') || status.contains('payment taken');
  }

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.inbox_rounded, color: _primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('No invoices in the last 30 days',
                    style: GoogleFonts.inter(color: _muted, fontSize: 14)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      key: const ValueKey('invoices'),
      children: docs.take(20).map((d) {
        final m        = d.data();
        final customer = (m['customerName'] ?? 'N/A').toString();
        final amt      = ((m['grandTotal'] as num?) ?? 0).toDouble();
        final tracking = (m['tracking_number'] ?? '').toString();
        final status   = (m['status'] ?? '').toString();
        final ts       = m['timestamp'];
        final date     = ts is Timestamp ? ts.toDate() : DateTime.now();
        final paid     = _isPaid(m);
        final color    = paid ? _success : _warning;

        return GestureDetector(
          onTap: () => onDetail(d.id, m),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                      paid ? Icons.check_circle_rounded : Icons.schedule_rounded,
                      color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700, fontSize: 14, color: _fg)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _StatusPill(
                              label: paid ? 'Paid' : 'Pending', color: color),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              tracking.isEmpty
                                  ? DateFormat('dd MMM, yyyy').format(date)
                                  : tracking,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 12, color: _muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('৳${amt.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800, fontSize: 14, color: _fg)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.3)),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _primary.withOpacity(.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inbox_rounded, color: _primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('No records to show',
                  style: GoogleFonts.inter(color: _muted, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom nav ────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _primaryDk,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: currentIndex,
          onTap: onTap,
          backgroundColor: _primaryDk,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white60,
          selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 10),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 10),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.description_rounded),  label: 'New'),
            BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded),     label: 'Invoices'),
            BottomNavigationBarItem(icon: Icon(Icons.work_history_rounded), label: 'Work'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded),    label: 'Reports'),
            BottomNavigationBarItem(icon: Icon(Icons.timeline_rounded),     label: 'Progress'),
          ],
        ),
      ),
    );
  }
}
