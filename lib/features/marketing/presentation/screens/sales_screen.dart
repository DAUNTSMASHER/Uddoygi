import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uddoygi/services/db.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:uddoygi/services/local_storage_service.dart';

import 'new_invoices_screen.dart';
import 'all_invoices_screen.dart';
import 'sales_report_screen.dart';
import 'order_progress_screen.dart';
import 'work_order_screen.dart';

// ── Design system: premium marketing sales ─────────────────────────────────────
const Color _bg        = Color(0xFFF0F4FF);
const Color _primary   = Color(0xFF2563EB);
const Color _primaryDk = Color(0xFF1E3A8A);
const Color _primaryLt = Color(0xFFEFF6FF);
const Color _card      = Color(0xFFFFFFFF);
const Color _border    = Color(0xFFE2E8F0);
const Color _fg        = Color(0xFF0F172A);
const Color _muted     = Color(0xFF64748B);
const Color _success   = Color(0xFF16A34A);
const Color _warning   = Color(0xFFF59E0B);
const double _radiusCard = 16.0;
const double _radiusChip = 12.0;
const double _spaceSm = 8.0;
const double _spaceMd = 12.0;
const double _spaceLg = 16.0;
const double _spaceXl = 20.0;

class _Feature {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _Feature(this.icon, this.label, this.onTap);
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_spaceLg, _spaceLg, _spaceLg, _spaceSm),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 20, color: _primary),
          const SizedBox(width: 8),
          Text(title,
              style: AppFonts.banglaBody(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _fg)),
        ],
      ),
    );
  }
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
    final current = FirebaseAuth.instance.currentUser;
    userEmail = (session?['email'] as String?)?.trim() ?? current?.email?.trim();
    if (userEmail == null || userEmail!.isEmpty) {
      userEmail = 'marketing@uddoygi.com';
    }
    String? sessionName = (session?['fullName'] as String?)?.trim();
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
    final start = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final end   = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

    var snap = await DB.colSync(_cid, C.invoices)
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
    final since    = DateTime.now().subtract(const Duration(days: 365));
    final invQuery = DB.colSync(_cid, C.invoices)
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
            style: AppFonts.banglaBody(fontWeight: FontWeight.w700, fontSize: 18)),
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(_spaceLg, _spaceLg, _spaceLg, 0),
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
              ),
              SliverToBoxAdapter(child: _SectionTitle(icon: Icons.touch_app_rounded, title: 'Quick actions')),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(_spaceLg, _spaceSm, _spaceLg, _spaceLg),
                sliver: SliverToBoxAdapter(child: _QuickActions(context)),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(_spaceLg, 0, _spaceLg, _spaceSm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('Recent transactions',
                          style: AppFonts.banglaBody(
                              fontSize: 17, fontWeight: FontWeight.w700, color: _fg)),
                      Text('Last 30 days',
                          style: AppFonts.banglaBody(fontSize: 12, color: _muted)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _TabBar(active: _activeTab, onChanged: (i) => setState(() => _activeTab = i))),
              SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
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
      _Feature(Icons.add_circle_outline_rounded, 'New Invoice', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewInvoicesScreen()))),
      _Feature(Icons.receipt_long_rounded,       'All Invoices', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllInvoicesScreen()))),
      _Feature(Icons.work_history_rounded,      'Work Orders',  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkOrderScreen()))),
      _Feature(Icons.bar_chart_rounded,         'Reports',      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReportScreen()))),
      _Feature(Icons.timeline_rounded,          'Order Progress', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderProgressScreen()))),
    ];

    final crossCount = MediaQuery.sizeOf(context).width > 600 ? 4 : 3;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: _spaceMd,
        mainAxisSpacing: _spaceMd,
        childAspectRatio: 0.95,
      ),
      itemBuilder: (_, i) {
        final f = tiles[i];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: f.onTap,
            borderRadius: BorderRadius.circular(_radiusCard),
            splashColor: _primaryDk.withValues(alpha: 0.12),
            highlightColor: _primaryDk.withValues(alpha: 0.08),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: _spaceLg, horizontal: _spaceMd),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(_radiusCard),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x08000000),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _primaryLt,
                      borderRadius: BorderRadius.circular(_radiusChip),
                      border: Border.all(color: _primary.withValues(alpha: 0.2)),
                    ),
                    child: Icon(f.icon, color: _primary, size: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(f.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.banglaBody(
                          fontSize: 13, fontWeight: FontWeight.w600, color: _fg)),
                ],
              ),
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
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(_radiusCard + 4))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(_spaceXl, 8, _spaceXl, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customer,
                style: AppFonts.banglaBody(
                    fontSize: 20, fontWeight: FontWeight.w700, color: _fg)),
            const SizedBox(height: 20),
            _KV('Status',   status.isEmpty ? '—' : status),
            _KV('Tracking', tracking.isEmpty ? '—' : tracking),
            _KV('Date',     DateFormat('dd MMM, yyyy').format(date)),
            _KV('Amount',   '৳${amt.toStringAsFixed(0)}'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const AllInvoicesScreen()));
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text('Open in All Invoices',
                    style: AppFonts.banglaBody(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_radiusChip)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(k,
              style: AppFonts.banglaBody(
                  fontSize: 13, color: _muted, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(v,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.banglaBody(
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
      padding: const EdgeInsets.all(_spaceXl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _primaryDk],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_radiusCard + 2),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Sales summary',
                  style: AppFonts.banglaBody(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              GestureDetector(
                onTap: onPickMonth,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(DateFormat.yMMMM().format(selectedMonth),
                          style: AppFonts.banglaBody(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '৳${totalSales.toStringAsFixed(0)}',
            style: AppFonts.banglaBody(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text('Total paid sales this period',
              style: AppFonts.banglaBody(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
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
                            style: AppFonts.banglaBody(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                        Text('${achievement.toStringAsFixed(0)}%',
                            style: AppFonts.banglaBody(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: achievement / 100,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            targetReached ? const Color(0xFF86EFAC) : Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _KpiChip(label: 'Target', value: salesTarget > 0 ? '৳${salesTarget.toStringAsFixed(0)}' : '—')),
              const SizedBox(width: _spaceSm),
              Expanded(child: _KpiChip(label: 'Orders', value: '$orderCount')),
              const SizedBox(width: _spaceSm),
              Expanded(child: _KpiChip(label: 'Paid', value: '$paidCount', color: const Color(0xFF86EFAC))),
              const SizedBox(width: _spaceSm),
              Expanded(child: _KpiChip(label: 'Pending', value: '$pendingCount', color: const Color(0xFFFDBA74))),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(_radiusChip),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppFonts.banglaBody(
                  color: color ?? Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.2)),
          const SizedBox(height: 4),
          Text(label,
              style: AppFonts.banglaBody(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
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
      margin: const EdgeInsets.fromLTRB(_spaceLg, _spaceMd, _spaceLg, _spaceMd),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: const Color(0x06000000),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final sel = i == active;
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(999),
                splashColor: _primary.withValues(alpha: 0.1),
                highlightColor: _primary.withValues(alpha: 0.06),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: sel ? _primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: Text(tabs[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.banglaBody(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : _muted)),
                  ),
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
        padding: const EdgeInsets.fromLTRB(_spaceLg, 0, _spaceLg, _spaceLg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: _spaceXl, vertical: 24),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(_radiusCard),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: const Color(0x06000000),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _primaryLt,
                  borderRadius: BorderRadius.circular(_radiusChip),
                ),
                child: const Icon(Icons.inbox_rounded, color: _primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text('No invoices in the last 30 days',
                    style: AppFonts.banglaBody(
                        color: _muted, fontSize: 15, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(_spaceLg, 0, _spaceLg, _spaceLg),
      child: Column(
        key: const ValueKey('invoices'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: docs.take(20).map((d) {
          final m        = d.data();
          final customer = (m['customerName'] ?? 'N/A').toString();
          final amt      = ((m['grandTotal'] as num?) ?? 0).toDouble();
          final tracking = (m['tracking_number'] ?? '').toString();
          final ts       = m['timestamp'];
          final date     = ts is Timestamp ? ts.toDate() : DateTime.now();
          final paid     = _isPaid(m);
          final color    = paid ? _success : _warning;

          return Padding(
            padding: const EdgeInsets.only(bottom: _spaceMd),
            child: Material(
              color: _card,
              borderRadius: BorderRadius.circular(_radiusCard),
              child: InkWell(
                onTap: () => onDetail(d.id, m),
                borderRadius: BorderRadius.circular(_radiusCard),
                splashColor: _primary.withValues(alpha: 0.08),
                highlightColor: _primary.withValues(alpha: 0.05),
                child: Container(
                  padding: const EdgeInsets.all(_spaceLg),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_radiusCard),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x05000000),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(_radiusChip),
                        ),
                        child: Icon(
                            paid ? Icons.check_circle_rounded : Icons.schedule_rounded,
                            color: color, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(customer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.banglaBody(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: _fg)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _StatusPill(label: paid ? 'Paid' : 'Pending', color: color),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    tracking.isEmpty
                                        ? DateFormat('dd MMM, yyyy').format(date)
                                        : tracking,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.banglaBody(
                                        fontSize: 12, color: _muted),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('৳${amt.toStringAsFixed(0)}',
                          style: AppFonts.banglaBody(
                              fontWeight: FontWeight.w800, fontSize: 15, color: _fg)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: AppFonts.banglaBody(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_spaceLg, 0, _spaceLg, _spaceLg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: _spaceXl, vertical: 24),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(_radiusCard),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: const Color(0x06000000),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _primaryLt,
                borderRadius: BorderRadius.circular(_radiusChip),
              ),
              child: const Icon(Icons.inbox_rounded, color: _primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text('No records to show',
                  style: AppFonts.banglaBody(
                      color: _muted, fontSize: 15, fontWeight: FontWeight.w500)),
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
      height: 40,
      decoration: BoxDecoration(
        color: _primaryDk,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: currentIndex,
          onTap: onTap,
          backgroundColor: _primaryDk,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white.withValues(alpha: 0.7),
          selectedLabelStyle: AppFonts.banglaBody(
              fontWeight: FontWeight.w700, fontSize: 9),
          unselectedLabelStyle: AppFonts.banglaBody(
              fontWeight: FontWeight.w500, fontSize: 9),
          iconSize: 16,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline_rounded), label: 'New'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Invoices'),
            BottomNavigationBarItem(icon: Icon(Icons.work_history_rounded), label: 'Work'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Reports'),
            BottomNavigationBarItem(icon: Icon(Icons.timeline_rounded), label: 'Progress'),
          ],
        ),
      ),
    );
  }
}
