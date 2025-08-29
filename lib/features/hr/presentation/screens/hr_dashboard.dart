import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carousel_slider/carousel_slider.dart';

import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/hr/presentation/widgets/hr_drawer.dart';

const Color _darkBlue = Color(0xFF003087);

// Base font sizes (scaled with .sp)
const double _fontSmall = 13.0;
const double _fontMed   = 16.0;
const double _fontLarge = 18.0;
const double _fontXL    = 20.0;

/* -------------------- Responsive font helper -------------------- */
extension ResponsiveFont on num {
  /// Screen-aware font size with user text scale respected.
  /// Tuned for ~390px devices.
  double sp(BuildContext context, {double min = 10, double max = 28}) {
    final w = MediaQuery.sizeOf(context).width;
    final screenFactor = (w / 390).clamp(0.85, 1.20);
    final userFactor   = MediaQuery.textScaleFactorOf(context).clamp(0.8, 1.4);
    final v = this * screenFactor * userFactor;
    return v.clamp(min, max).toDouble();
  }
}

/* ======================= MODEL ======================= */
class _DashboardItem {
  final String keyId; // used to store lastSeen + for keywords
  final String title;
  final IconData icon;
  final String route;
  final List<Query<Map<String, dynamic>>> queries; // “new” counters source
  const _DashboardItem({
    required this.keyId,
    required this.title,
    required this.icon,
    required this.route,
    required this.queries,
  });
}

/* ======================= SCREEN ======================= */
class HRDashboard extends StatefulWidget {
  const HRDashboard({super.key});
  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard> {
  String? uid;
  String? name;
  String? photoUrl;

  bool showSummary = true;

  // Quick actions
  late final List<_DashboardItem> items = [
    _DashboardItem(
      keyId: 'directory',
      title: 'Directory',
      icon: Icons.people,
      route: '/hr/employee_directory',
      queries: [FirebaseFirestore.instance.collection('users')],
    ),
    _DashboardItem(
      keyId: 'attendance',
      title: 'Attendance',
      icon: Icons.event_available,
      route: '/hr/attendance',
      queries: [FirebaseFirestore.instance.collection('attendance')],
    ),
    _DashboardItem(
      keyId: 'leave',
      title: 'Leave',
      icon: Icons.beach_access,
      route: '/hr/leave_management',
      queries: [FirebaseFirestore.instance.collection('leaves')],
    ),
    _DashboardItem(
      keyId: 'payroll',
      title: 'Payroll',
      icon: Icons.attach_money,
      route: '/hr/payroll_processing',
      queries: [FirebaseFirestore.instance.collection('salaries')],
    ),
    _DashboardItem(
      keyId: 'payslips',
      title: 'Payslips',
      icon: Icons.receipt_long,
      route: '/hr/payslip',
      queries: [FirebaseFirestore.instance.collection('payslips')],
    ),
    _DashboardItem(
      keyId: 'loans',
      title: 'Loans',
      icon: Icons.account_balance,
      route: '/hr/loan_approval',
      queries: [FirebaseFirestore.instance.collection('loans')],
    ),
    // Finance
    _DashboardItem(
      keyId: 'credits',
      title: 'Credits',
      icon: Icons.trending_up,
      route: '/hr/credits',
      queries: [FirebaseFirestore.instance.collection('ledger')],
    ),
    _DashboardItem(
      keyId: 'expenses',
      title: 'Expenses',
      icon: Icons.payments,
      route: '/hr/expenses',
      queries: [FirebaseFirestore.instance.collection('expenses')],
    ),
    _DashboardItem(
      keyId: 'balance',
      title: 'Balance',
      icon: Icons.account_balance_wallet,
      route: '/hr/balance_update',
      queries: [FirebaseFirestore.instance.collection('ledger')],
    ),
    // Communication / Support
    _DashboardItem(
      keyId: 'notices',
      title: 'Notices',
      icon: Icons.notifications,
      route: '/hr/notices',
      queries: [FirebaseFirestore.instance.collection('notices')],
    ),
    _DashboardItem(
      keyId: 'messages',
      title: 'Messages',
      icon: Icons.message,
      route: '/common/messages',
      queries: [FirebaseFirestore.instance.collection('messages')],
    ),
    _DashboardItem(
      keyId: 'complaints',
      title: 'Complaints',
      icon: Icons.support_agent,
      route: '/common/complaints',
      queries: [FirebaseFirestore.instance.collection('complaints')],
    ),
    // Procurement
    _DashboardItem(
      keyId: 'procurement',
      title: 'Procurement',
      icon: Icons.shopping_cart,
      route: '/hr/procurement',
      queries: [FirebaseFirestore.instance.collection('procurement_requests')],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    final current = FirebaseAuth.instance.currentUser;
    setState(() {
      uid = session?['uid'] as String? ?? current?.uid;
      name = (session?['name'] as String?) ??
          current?.displayName ??
          current?.email ??
          'HR';
      photoUrl = current?.photoURL;
    });

    // Try to enhance name/photo from users/{uid}
    if (uid != null) {
      try {
        final s = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (s.exists) {
          final d = s.data()!;
          final n = (d['fullName'] as String?)?.trim();
          final p = (d['profilePhotoUrl'] as String?)?.trim();
          setState(() {
            if (n != null && n.isNotEmpty) name = n;
            if (p != null && p.isNotEmpty) photoUrl = p;
          });
        }
      } catch (_) {}
    }
  }

  String _initialsFor(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'H';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await LocalStorageService.clearSession();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (name ?? 'HR').trim();
    final initials = _initialsFor(displayName);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _darkBlue,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty) ? NetworkImage(photoUrl!) : null,
              child: (photoUrl == null || photoUrl!.isEmpty)
                  ? Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp(context, min: 11, max: 18),
                  fontWeight: FontWeight.w700,
                ),
              )
                  : null,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Welcome, $displayName',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18.sp(context, min: 14, max: 22),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white, size: 20.sp(context, min: 18, max: 24)),
            onPressed: _logout,
          ),
        ],
      ),
      drawer: const HRDrawer(),
      body: RefreshIndicator(
        color: _darkBlue,
        onRefresh: () async {
          // Summary is fully live via streams; this is just a light UX delay.
          await Future.delayed(const Duration(milliseconds: 400));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // -------- Summary header --------
            _sectionHeader('Summary', showSummary, () {
              setState(() => showSummary = !showSummary);
            }),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: showSummary ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: const _RealtimeSummaryCarousel(),
              secondChild: const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // -------- Quick Actions --------
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: _fontXL.sp(context, min: 16, max: 26),
                fontWeight: FontWeight.w900,
                color: _darkBlue,
              ),
            ),
            const SizedBox(height: 14),

            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade50, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6)),
                ],
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.3,
                ),
                itemBuilder: (ctx, i) {
                  final it = items[i];
                  return _BadgeActionCard(
                    item: it,
                    onTap: () async {
                      await _markSectionSeen(it.keyId);
                      if (!mounted) return;
                      setState(() {}); // forces badge to update
                      await Navigator.pushNamed(context, it.route);
                      if (!mounted) return;
                      setState(() {}); // back from page
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, bool expanded, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: _fontLarge.sp(context, min: 16, max: 26),
                  fontWeight: FontWeight.w900,
                  color: _darkBlue,
                ),
              ),
            ),
            Icon(expanded ? Icons.expand_less : Icons.expand_more,
                color: _darkBlue, size: 20.sp(context, min: 18, max: 26)),
          ],
        ),
      ),
    );
  }
}

/* ======================= REALTIME SUMMARY ======================= */

class _RealtimeSummaryCarousel extends StatelessWidget {
  const _RealtimeSummaryCarousel();

  // ---------- Date helpers ----------
  String _dateId(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  ({DateTime a, DateTime b}) _today() {
    final n = DateTime.now();
    final a = DateTime(n.year, n.month, n.day);
    final b = a.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
    return (a: a, b: b);
  }

  ({DateTime a, DateTime b}) _thisWeek() {
    final now = DateTime.now();
    final a = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: DateTime.now().weekday - 1));
    final b = a.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));
    return (a: a, b: b);
  }

  ({DateTime a, DateTime b}) _thisMonth() {
    final n = DateTime.now();
    final a = DateTime(n.year, n.month, 1);
    final b = DateTime(n.year, n.month + 1, 0, 23, 59, 59);
    return (a: a, b: b);
  }

  ({DateTime a, DateTime b}) _lastMonth() {
    final n = DateTime.now();
    final p = DateTime(n.year, n.month - 1, 1);
    final a = DateTime(p.year, p.month, 1);
    final b = DateTime(p.year, p.month + 1, 0, 23, 59, 59);
    return (a: a, b: b);
  }

  // ---------- Streams ----------
  /// Sum numeric field over a date range (uses `dueDate` to match Expenses screen)
  Stream<double> _sumByDueDate({
    required DateTime a,
    required DateTime b,
  }) {
    final ref = FirebaseFirestore.instance
        .collection('expenses')
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(a))
        .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(b));
    return ref.snapshots().map((snap) {
      double s = 0;
      for (final d in snap.docs) {
        final raw = d.data()['amount'];
        if (raw is num) s += raw.toDouble();
        if (raw is String) s += double.tryParse(raw.replaceAll(',', '')) ?? 0;
      }
      return s;
    });
  }

  /// attendance count from subcollection: attendance/{yyyy-MM-dd}/records where status == X
  Stream<int> _attendanceTodayCount(String status) {
    final id = _dateId(DateTime.now());
    final ref = FirebaseFirestore.instance
        .collection('attendance')
        .doc(id)
        .collection('records')
        .where('status', isEqualTo: status);
    return ref.snapshots().map((s) => s.docs.length);
  }

  /// pending count stream for a collection (e.g., loans, procurement_requests, complaints, leaves)
  Stream<int> _pendingCount(String collection, {String field = 'status'}) {
    final ref = FirebaseFirestore.instance
        .collection(collection)
        .where(field, isEqualTo: 'pending');
    return ref.snapshots().map((s) => s.docs.length);
  }

  /// credits from ledger (credit > 0) in range
  Stream<double> _creditsRange(DateTime a, DateTime b) {
    final ref = FirebaseFirestore.instance
        .collection('ledger')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(a))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(b))
        .where('credit', isGreaterThan: 0);
    return ref.snapshots().map((s) {
      double sum = 0;
      for (final d in s.docs) {
        final v = d.data()['credit'];
        if (v is num) sum += v.toDouble();
        if (v is String) sum += double.tryParse(v.replaceAll(',', '')) ?? 0;
      }
      return sum;
    });
  }

  // ---------- format ----------
  String _money(num n) {
    final s = n.toStringAsFixed(0);
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final r = s.length - i;
      b.write(s[i]);
      if (r > 1 && r % 3 == 1) b.write(',');
    }
    return '৳${b.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    // One metric per page. Keep ≥16px bottom space (or safe area) to avoid overflow.
    const double cardHeight = 92.0;
    final double bottomSafe = MediaQuery.of(context).padding.bottom;
    final double extra = bottomSafe > 0 ? bottomSafe : 16.0;
    final double h = cardHeight + extra;

    final rToday     = _today();
    final rWeek      = _thisWeek();
    final rThisMonth = _thisMonth();
    final rLastMonth = _lastMonth();

    final pages = <Widget>[
      // EXPENSES (by dueDate)
      _LiveStatTile.money(
        title: 'Expense (Today)',
        icon: Icons.today,
        gradient: const [Color(0xFF6C63FF), Color(0xFF48BFE3)],
        stream: _sumByDueDate(a: rToday.a, b: rToday.b).map(_money),
      ),
      _LiveStatTile.money(
        title: 'Expense (Week)',
        icon: Icons.view_week,
        gradient: const [Color(0xFF4EA8DE), Color(0xFF5390D9)],
        stream: _sumByDueDate(a: rWeek.a, b: rWeek.b).map(_money),
      ),
      _LiveStatTile.money(
        title: 'Expense (Month)',
        icon: Icons.calendar_month,
        gradient: const [Color(0xFF6C63FF), Color(0xFF48BFE3)],
        stream: _sumByDueDate(a: rThisMonth.a, b: rThisMonth.b).map(_money),
      ),
      _LiveStatTile.money(
        title: 'Expense (Last Month)',
        icon: Icons.history,
        gradient: const [Color(0xFF6C63FF), Color(0xFF48BFE3)],
        stream: _sumByDueDate(a: rLastMonth.a, b: rLastMonth.b).map(_money),
      ),

      // ATTENDANCE (today) from subcollection
      _LiveStatTile.text(
        title: 'Present (Today)',
        icon: Icons.how_to_reg,
        gradient: const [Color(0xFF6C63FF), Color(0xFF48BFE3)],
        stream: _attendanceTodayCount('present').map((n) => 'P $n'),
      ),
      _LiveStatTile.text(
        title: 'Absent (Today)',
        icon: Icons.block,
        gradient: const [Color(0xFF6C63FF), Color(0xFF48BFE3)],
        stream: _attendanceTodayCount('absent').map((n) => 'A $n'),
      ),

      // PENDING
      _LiveStatTile.count(
        title: 'Pending Loans',
        icon: Icons.account_balance,
        gradient: const [Color(0xFF6C63FF), Color(0xFF48BFE3)],
        stream: _pendingCount('loans'),
      ),
      _LiveStatTile.count(
        title: 'Pending Procurement',
        icon: Icons.add_shopping_cart,
        gradient: const [Color(0xFF6C63FF), Color(0xFF48BFE3)],
        stream: _pendingCount('procurement_requests'),
      ),
      _LiveStatTile.count(
        title: 'Pending Complaints',
        icon: Icons.support_agent,
        gradient: const [Color(0xFF6C63FF), Color(0xFF48BFE3)],
        stream: _pendingCount('complaints'),
      ),
      _LiveStatTile.count(
        title: 'Leaves (Pending)',
        icon: Icons.holiday_village,
        gradient: const [Color(0xFF0091EA), Color(0xFF00B0FF)],
        stream: _pendingCount('leaves'),
      ),

      // CREDITS
      _LiveStatTile.money(
        title: 'Credits (Today)',
        icon: Icons.trending_up,
        gradient: const [Color(0xFF6C63FF), Color(0xFF48BFE3)],
        stream: _creditsRange(rToday.a, rToday.b).map(_money),
      ),
      _LiveStatTile.money(
        title: 'Credits (Month)',
        icon: Icons.show_chart,
        gradient: const [Color(0xFF6C63FF), Color(0xFF48BFE3)],
        stream: _creditsRange(rThisMonth.a, rThisMonth.b).map(_money),
      ),
    ].map((tile) => SizedBox(height: cardHeight, child: tile)).toList();

    return SizedBox(
      height: h,
      child: CarouselSlider(
        items: pages
            .map((p) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: p))
            .toList(),
        options: CarouselOptions(
          height: h,
          autoPlay: true,
          viewportFraction: 1.0,
          enlargeCenterPage: false,
          autoPlayInterval: const Duration(seconds: 4),
        ),
      ),
    );
  }
}

/* ====== Live stat card (single stream) ====== */
class _LiveStatTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final Stream<String> streamValue;

  const _LiveStatTile._({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.streamValue,
  });

  factory _LiveStatTile.money({
    required String title,
    required IconData icon,
    required List<Color> gradient,
    required Stream<String> stream,
  }) =>
      _LiveStatTile._(title: title, icon: icon, gradient: gradient, streamValue: stream);

  factory _LiveStatTile.count({
    required String title,
    required IconData icon,
    required List<Color> gradient,
    required Stream<int> stream,
  }) =>
      _LiveStatTile._(
        title: title,
        icon: icon,
        gradient: gradient,
        streamValue: stream.map((n) => n.toString()),
      );

  factory _LiveStatTile.text({
    required String title,
    required IconData icon,
    required List<Color> gradient,
    required Stream<String> stream,
  }) =>
      _LiveStatTile._(title: title, icon: icon, gradient: gradient, streamValue: stream);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            height: 40, width: 40,
            decoration: BoxDecoration(color: Colors.white.withOpacity(.2), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StreamBuilder<String>(
              stream: streamValue,
              builder: (context, snap) {
                final v = snap.hasData ? snap.data! : '—';
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
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

/* ===================== BADGED ACTION CARD ===================== */
class _BadgeActionCard extends StatefulWidget {
  final _DashboardItem item;
  final VoidCallback onTap;
  const _BadgeActionCard({required this.item, required this.onTap});

  @override
  State<_BadgeActionCard> createState() => _BadgeActionCardState();
}

class _BadgeActionCardState extends State<_BadgeActionCard> {
  int _count = 0;
  bool _pressed = false;
  final Map<int, int> _perStream = {};
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs = [];

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(covariant _BadgeActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _detach();
    _attach();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  Future<void> _attach() async {
    final lastSeen = await _getLastSeen(widget.item.keyId);
    _perStream.clear();
    for (final q in widget.item.queries) {
      final sub = q
          .where('createdAt', isGreaterThan: Timestamp.fromDate(lastSeen))
          .snapshots()
          .listen((snap) {
        _perStream[q.hashCode] = snap.docs.length;
        final total = _perStream.values.fold<int>(0, (s, n) => s + n);
        if (mounted) setState(() => _count = total);
      });
      _subs.add(sub);
    }
  }

  void _detach() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 90),
      scale: _pressed ? 0.98 : 1.0,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: Stack(
          children: [
            Material(
              color: Colors.white,
              elevation: 3,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _darkBlue.withOpacity(0.06),
                        _darkBlue.withOpacity(0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _darkBlue.withOpacity(0.08)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: _darkBlue.withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(widget.item.icon, color: _darkBlue, size: 22.sp(context, min: 18, max: 26)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.item.title,
                              style: TextStyle(
                                fontSize: _fontMed.sp(context, min: 12, max: 18),
                                fontWeight: FontWeight.w800,
                                color: _darkBlue,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_count > 0)
              Positioned(
                right: 10,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Text(
                    _count > 99 ? '99+' : '$_count',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp(context, min: 10, max: 14),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- lastSeen helpers ----------
  Future<DateTime> _getLastSeen(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt('lastSeen_$key');
    if (ms == null) {
      final seed = DateTime.now().subtract(const Duration(days: 1));
      await prefs.setInt('lastSeen_$key', seed.millisecondsSinceEpoch);
      return seed;
    }
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
}

/* ======================= lastSeen (shared) ======================= */
Future<void> _markSectionSeen(String key) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('lastSeen_$key', DateTime.now().millisecondsSinceEpoch);
}
