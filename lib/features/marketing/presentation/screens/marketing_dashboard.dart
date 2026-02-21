import 'package:uddoygi/features/common/salary_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/features/marketing/presentation/screens/sales_screen.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/marketing/presentation/screens/products.dart';
import 'package:uddoygi/features/marketing/presentation/screens/renumeration_dashboard.dart';
import '../widgets/marketing_drawer.dart';
import 'package:uddoygi/features/common/notification.dart';
import 'package:uddoygi/features/marketing/presentation/screens/campaign_screen.dart';
import 'package:uddoygi/features/common/stock/stockhistory.dart';
import 'package:uddoygi/features/marketing/presentation/screens/all_invoices_screen.dart';
import 'package:uddoygi/features/factory/presentation/screens/loan_request_screen.dart';

// ── Palette — Blue & White only ───────────────────────────────────────────────
const Color _bg        = Color(0xFFF0F4FF);
const Color _primary   = Color(0xFF2563EB);
const Color _primaryDk = Color(0xFF1E3A8A);
const Color _primaryLt = Color(0xFFEFF6FF);
const Color _card      = Color(0xFFFFFFFF);
const Color _border    = Color(0x1A2563EB);
const Color _fg        = Color(0xFF0F172A);
const Color _muted     = Color(0xFF94A3B8);
const Color _badgeRed  = Color(0xFFDC2626);

const Set<String> _runningStages = {
  'submitted to factory',
  'factory update 1 (base is done)',
  'hair is ready',
  'knotting is going on',
  'putting',
  'molding',
};

bool _isRunning(Map<String, dynamic> m) {
  final s  = (m['status']       ?? '').toString().trim().toLowerCase();
  final cs = (m['currentStage'] ?? '').toString().trim().toLowerCase();
  return _runningStages.contains(s) || _runningStages.contains(cs);
}

class MarketingDashboard extends StatefulWidget {
  const MarketingDashboard({super.key});

  @override
  State<MarketingDashboard> createState() => _MarketingDashboardState();
}

class _MarketingDashboardState extends State<MarketingDashboard> {
  String _cid = '';
  String? email;
  String? uid;
  String? name;
  String? photoUrl;
  String _search = '';
  int _currentTab = 0;

  Stream<int> _notifStream = Stream.value(0);
  Stream<int> _msgStream   = Stream.value(0);

  final List<_DashItem> _allItems = const [
    _DashItem('Notices',     Icons.notifications_active_rounded, '/marketing/notices'),
    _DashItem('Clients',     Icons.people_alt_rounded,           '/marketing/clients'),
    _DashItem('Sales',       Icons.point_of_sale_rounded,        ''),
    _DashItem('Welfare',     Icons.volunteer_activism_rounded,   '/common/welfare'),
    _DashItem('Complaints',  Icons.report_problem_rounded,       '/common/complaints'),
    _DashItem('Messages',    Icons.chat_bubble_outline_rounded,  '/common/messages'),
    _DashItem('Tasks',       Icons.task_alt_rounded,             '/marketing/task_assignment'),
    _DashItem('Campaigns',   Icons.campaign_rounded,             ''),
    _DashItem('Orders',      Icons.shopping_bag_rounded,         '/marketing/orders'),
    _DashItem('Loans',       Icons.account_balance_rounded,      ''),
    _DashItem('Products',    Icons.inventory_2_rounded,          ''),
    _DashItem('Renumeration',Icons.paid_rounded,                 ''),
    _DashItem('Stock',       Icons.sync_alt_rounded,             ''),
    _DashItem('Salary',      Icons.account_balance_wallet_rounded, ''),
    _DashItem('R&D Request', Icons.science_rounded,              '/rnd/request'),
    _DashItem('Attendance',  Icons.event_available_rounded,      '/marketing/attendance'),
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = await LocalStorageService.getSavedCompanyId();
    if (!mounted) return;
    setState(() {
      _cid = id ?? '';
      if (_cid.isNotEmpty) {
        _notifStream = _unreadNotifStream();
        _msgStream   = _unreadMsgStream();
      }
    });
    await _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    final current = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    setState(() {
      email    = session?['email'] as String? ?? current?.email;
      uid      = session?['uid']   as String? ?? current?.uid;
      name     = (session?['name'] as String?) ?? current?.displayName ?? current?.email ?? 'Marketing';
      photoUrl = current?.photoURL;
    });
    if (uid != null && _cid.isNotEmpty) {
      try {
        final s = await DB.colSync(_cid, C.users).doc(uid).get();
        if (s.exists && mounted) {
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

  String _niceName(String s) {
    if (!s.contains('@')) return s;
    return s.split('@').first.replaceAll('.', ' ').replaceAll('_', ' ');
  }

  Future<void> _logout() async {
    await LocalStorageService.performLogout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  void _onTap(_DashItem item) {
    switch (item.title) {
      case 'Salary':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SalaryScreen()));
        return;
      case 'Products':
        if (email != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsPage(userEmail: email!)));
        return;
      case 'Renumeration':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RenumerationDashboard()));
        return;
      case 'Campaigns':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdsManagerMobile()));
        return;
      case 'Stock':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const StockHistoryScreen()));
        return;
      case 'Sales':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesScreen()));
        return;
      case 'Loans':
        Navigator.push(context, MaterialPageRoute(builder: (_) => LoanRequestScreen()));
        return;
      default:
        Navigator.pushNamed(context, item.route);
    }
  }

  Stream<int> _badgeFor(String title) {
    final mail = email ?? FirebaseAuth.instance.currentUser?.email ?? '';
    switch (title) {
      case 'Notices':
        return DB.colSync(_cid, C.notifications)
            .where('to', isEqualTo: mail).where('read', isEqualTo: false)
            .snapshots().map((s) => s.docs.length);
      case 'Messages':
        return _unreadMsgStream();
      case 'Sales':
        return DB.colSync(_cid, C.invoices)
            .where('ownerEmail', isEqualTo: mail)
            .snapshots().map((s) => s.docs.length);
      case 'Orders':
        return DB.colSync(_cid, C.workOrders)
            .snapshots().map((s) => s.docs.where((d) => _isRunning(d.data())).length);
      case 'Loans':
        return DB.colSync(_cid, C.loans)
            .where('userEmail', isEqualTo: mail)
            .snapshots().map((s) => s.docs.length);
      case 'Renumeration':
        return DB.colSync(_cid, C.marketingIncentives)
            .where('userEmail', isEqualTo: mail)
            .snapshots().map((s) => s.docs.length);
      case 'Clients':
        return DB.colSync(_cid, C.customers).snapshots().map((s) => s.docs.length);
      case 'Campaigns':
        return DB.colSync(_cid, C.campaigns)
            .where('status', isEqualTo: 'active')
            .snapshots().map((s) => s.docs.length);
      case 'Welfare':
        return DB.colSync(_cid, C.welfare).snapshots().map((s) => s.docs.length);
      case 'Complaints':
        return DB.colSync(_cid, C.complaints).snapshots().map((s) => s.docs.length);
      case 'Products':
        return DB.colSync(_cid, C.products).snapshots().map((s) => s.docs.length);
      case 'Tasks':
        return DB.colSync(_cid, C.tasks).snapshots().map((s) => s.docs.length);
      default:
        return const Stream<int>.empty();
    }
  }

  Stream<int> _unreadMsgStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _cid.isEmpty) return Stream.value(0);
    return DB.colSync(_cid, C.messages)
        .where('to', isEqualTo: user.email ?? '')
        .where('read', isEqualTo: false)
        .snapshots().map((s) => s.docs.length);
  }

  Stream<int> _unreadNotifStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _cid.isEmpty) return Stream.value(0);
    return DB.colSync(_cid, C.notifications)
        .where('to', isEqualTo: user.email ?? '')
        .where('read', isEqualTo: false)
        .snapshots().map((s) => s.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _allItems
        .where((i) => i.title.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    final width = MediaQuery.sizeOf(context).width;
    final cols  = width >= 1000 ? 6 : width >= 780 ? 5 : width >= 560 ? 4 : 3;
    final displayName = _niceName(name ?? email ?? 'Marketing');

    return Scaffold(
      backgroundColor: _bg,
      drawer: const MarketingDrawer(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primaryDk,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            _Avatar(name: displayName, photoUrl: photoUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hi, $displayName',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
        actions: [
          StreamBuilder<int>(
            stream: _notifStream,
            builder: (_, s) => _AppBarBadge(
              icon: Icons.notifications_outlined,
              count: s.data ?? 0,
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const NotificationPage())),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Sign out',
            onPressed: _logout,
          ),
        ],
      ),

      bottomNavigationBar: _BottomBar(
        currentTab: _currentTab,
        msgStream: _msgStream,
        onTabChanged: (i) => setState(() => _currentTab = i),
        onClients: () => Navigator.pushNamed(context, '/marketing/clients'),
        onSales: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AllInvoicesScreen())),
        onMessages: () => Navigator.pushNamed(context, '/common/messages'),
      ),

      body: CustomScrollView(
        slivers: [
          // ── Hero overview card ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _OverviewHeader(userEmail: email, userUid: uid),
            ),
          ),

          // ── Section label + search ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 4, height: 18,
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Quick Actions',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _fg)),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                      boxShadow: const [
                        BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: GoogleFonts.inter(fontSize: 14, color: _fg),
                      decoration: InputDecoration(
                        hintText: 'Search features…',
                        hintStyle: GoogleFonts.inter(color: _muted, fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Feature grid ─────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final it = filtered[i];
                  return StreamBuilder<int>(
                    stream: _badgeFor(it.title),
                    builder: (_, snap) => _DashTile(
                      title: it.title,
                      icon: it.icon,
                      badge: snap.data ?? 0,
                      onTap: () => _onTap(it),
                    ),
                  );
                },
                childCount: filtered.length,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overview header ───────────────────────────────────────────────────────────
enum _Range { thisMonth, prevMonth, last3, last12 }

class _OverviewHeader extends StatefulWidget {
  final String? userEmail;
  final String? userUid;
  const _OverviewHeader({this.userEmail, this.userUid});

  @override
  State<_OverviewHeader> createState() => _OverviewHeaderState();
}

class _OverviewHeaderState extends State<_OverviewHeader> {
  String _cid = '';
  _Range _range = _Range.thisMonth;

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId()
        .then((id) { if (mounted) setState(() => _cid = id ?? ''); });
  }

  ({DateTime a, DateTime b}) _dates(_Range r) {
    final now = DateTime.now();
    switch (r) {
      case _Range.thisMonth:
        return (a: DateTime(now.year, now.month, 1),
                b: DateTime(now.year, now.month + 1, 0, 23, 59, 59));
      case _Range.prevMonth:
        return (a: DateTime(now.year, now.month - 1, 1),
                b: DateTime(now.year, now.month, 0, 23, 59, 59));
      case _Range.last3:
        return (a: DateTime(now.year, now.month - 2, 1),
                b: DateTime(now.year, now.month + 1, 0, 23, 59, 59));
      case _Range.last12:
        return (a: DateTime(now.year, now.month - 11, 1),
                b: DateTime(now.year, now.month + 1, 0, 23, 59, 59));
    }
  }

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

  Stream<String> _totalSales() {
    final r  = _dates(_range);
    final me = (widget.userEmail ?? FirebaseAuth.instance.currentUser?.email ?? '').trim();
    Query<Map<String, dynamic>> q = DB.colSync(_cid, C.invoices)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(r.b));
    if (me.isNotEmpty) q = q.where('agentEmail', isEqualTo: me);
    return q.snapshots().map((s) {
      num sum = 0;
      for (final d in s.docs) {
        final m      = d.data();
        final status = (m['status'] ?? '').toString().toLowerCase();
        final pay    = (m['payment'] is Map) ? Map<String, dynamic>.from(m['payment']) : const <String, dynamic>{};
        final paid   = (pay['taken'] == true) || status.contains('payment taken') || status.contains('paid');
        if (!paid) continue;
        final v = m['grandTotal'];
        if (v is num) sum += v;
      }
      return _money(sum);
    });
  }

  Stream<String> _totalCampaigns() {
    final r = _dates(_range);
    return DB.colSync(_cid, C.campaigns)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .snapshots().map((s) => s.docs.length.toString());
  }

  Stream<String> _pendingPayments() {
    final r = _dates(_range);
    return DB.colSync(_cid, C.invoices)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .snapshots().map((s) {
      int count = 0;
      for (final d in s.docs) {
        final status = (d.data()['status'] ?? '').toString().toLowerCase();
        if (status.contains('invoice created')) count++;
      }
      return '$count';
    });
  }

  Stream<String> _runningOrders() {
    final r = _dates(_range);
    return DB.colSync(_cid, C.workOrders)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .snapshots()
        .map((s) => '${s.docs.where((d) => _isRunning(d.data())).length}');
  }

  Stream<String> _incentiveAmount() {
    final r  = _dates(_range);
    final me = (widget.userEmail ?? '').trim();
    return DB.colSync(_cid, C.marketingIncentives)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .snapshots().map((s) {
      num sum = 0;
      for (final d in s.docs) {
        final m     = d.data();
        final mine  = me.isEmpty
            ? true
            : (m['userEmail'] == me) || (m['agentEmail'] == me) || d.id.startsWith(me);
        if (!mine) continue;
        sum += (m['totalIncentive'] as num?) ?? 0;
      }
      return _money(sum);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _primaryDk],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: _primary.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Overview',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
              _RangeDropdown(value: _range, onChanged: (r) => setState(() => _range = r)),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (_, c) {
            final w = (c.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatCard(width: w, label: 'Total Sales',      icon: Icons.payments_rounded,       stream: _totalSales()),
                _StatCard(width: w, label: 'Campaigns',        icon: Icons.campaign_rounded,        stream: _totalCampaigns()),
                _StatCard(width: w, label: 'Pending Payments', icon: Icons.pending_actions_rounded, stream: _pendingPayments()),
                _StatCard(width: w, label: 'Running Orders',   icon: Icons.work_history_rounded,    stream: _runningOrders()),
                _StatCard(width: w, label: 'Incentives',       icon: Icons.star_rounded,            stream: _incentiveAmount()),
                _DueLoanCard(
                  width: w,
                  money: _money,
                  userEmail: widget.userEmail,
                  userUid: widget.userUid,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Range dropdown ────────────────────────────────────────────────────────────
class _RangeDropdown extends StatelessWidget {
  final _Range value;
  final ValueChanged<_Range> onChanged;
  const _RangeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white30),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_Range>(
          value: value,
          isDense: true,
          dropdownColor: _primaryDk,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
          items: const [
            DropdownMenuItem(value: _Range.thisMonth, child: Text('This month')),
            DropdownMenuItem(value: _Range.prevMonth, child: Text('Prev month')),
            DropdownMenuItem(value: _Range.last3,     child: Text('Last 3 months')),
            DropdownMenuItem(value: _Range.last12,    child: Text('One year')),
          ],
          onChanged: (r) { if (r != null) onChanged(r); },
        ),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final double width;
  final String label;
  final IconData icon;
  final Stream<String> stream;

  const _StatCard({
    required this.width,
    required this.label,
    required this.icon,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _primaryLt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StreamBuilder<String>(
              stream: stream,
              builder: (_, snap) {
                final loading = snap.connectionState == ConnectionState.waiting && !snap.hasData;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    loading
                        ? SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: _primary.withValues(alpha: 0.5)),
                          )
                        : Text(
                            snap.data ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                color: _fg,
                                fontWeight: FontWeight.w800,
                                fontSize: 18),
                          ),
                    const SizedBox(height: 2),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            color: _muted, fontSize: 11, fontWeight: FontWeight.w500)),
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

// ── Due loan card ─────────────────────────────────────────────────────────────
class _DueLoanCard extends StatefulWidget {
  final double width;
  final String Function(num) money;
  final String? userEmail;
  final String? userUid;

  const _DueLoanCard({
    required this.width,
    required this.money,
    this.userEmail,
    this.userUid,
  });

  @override
  State<_DueLoanCard> createState() => _DueLoanCardState();
}

class _DueLoanCardState extends State<_DueLoanCard> {
  String _cid = '';
  double? _cached;

  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0.0;
    return 0.0;
  }

  static double _firstAmt(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = _num(m[k]);
      if (v > 0) return v;
    }
    return 0.0;
  }

  static const _repayKeys = ['amount', 'paid', 'value', 'payAmount'];
  static const _dueKeys   = {
    'due', 'dueAmount', 'amountDue', 'currentDue', 'totalDue',
    'outstanding', 'outstandingAmount', 'remaining', 'remainingAmount',
    'balance', 'leftToPay', 'pendingAmount',
  };

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId()
        .then((id) { if (mounted) setState(() => _cid = id ?? ''); });
  }

  @override
  Widget build(BuildContext context) {
    final mail = (widget.userEmail ?? FirebaseAuth.instance.currentUser?.email ?? '').trim();
    final uid  = (widget.userUid   ?? FirebaseAuth.instance.currentUser?.uid   ?? '').trim();

    Query<Map<String, dynamic>> loansQ = DB.colSync(_cid, C.loans);
    if (mail.isNotEmpty && uid.isNotEmpty) {
      loansQ = loansQ.where(Filter.or(
        Filter('userEmail', isEqualTo: mail),
        Filter('userId',    isEqualTo: uid),
      ));
    } else if (mail.isNotEmpty) {
      loansQ = loansQ.where('userEmail', isEqualTo: mail);
    } else if (uid.isNotEmpty) {
      loansQ = loansQ.where('userId', isEqualTo: uid);
    } else {
      return _dueLoanCard(_cached != null ? widget.money(_cached!) : '—');
    }

    Query<Map<String, dynamic>>? repayQ;
    if (mail.isNotEmpty && uid.isNotEmpty) {
      repayQ = DB.firestore.collectionGroup('repayments').where(Filter.or(
        Filter('userEmail', isEqualTo: mail),
        Filter('userId',    isEqualTo: uid),
      ));
    } else if (mail.isNotEmpty) {
      repayQ = DB.firestore.collectionGroup('repayments').where('userEmail', isEqualTo: mail);
    } else if (uid.isNotEmpty) {
      repayQ = DB.firestore.collectionGroup('repayments').where('userId', isEqualTo: uid);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: loansQ.snapshots(),
      builder: (_, loansSnap) {
        if (loansSnap.connectionState == ConnectionState.waiting) {
          return _dueLoanCard(_cached != null ? widget.money(_cached!) : '—');
        }

        double explicitSum = 0;
        bool hasExplicit   = false;
        double principal   = 0;

        for (final d in loansSnap.data?.docs ?? []) {
          final m = d.data();
          for (final k in _dueKeys) {
            if (m.containsKey(k)) {
              hasExplicit = true;
              final v = _num(m[k]);
              if (v > 0) explicitSum += v;
              break;
            }
          }
          final status = (m['status'] ?? '').toString().toLowerCase();
          if (['approved', 'disbursed', 'closed'].contains(status)) {
            principal += _num(m['amount']);
          }
        }

        if (hasExplicit) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _cached = explicitSum;
          });
          return _dueLoanCard(widget.money(explicitSum));
        }

        if (repayQ == null) return _dueLoanCard(_cached != null ? widget.money(_cached!) : '—');

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: repayQ.snapshots(),
          builder: (_, repaySnap) {
            if (repaySnap.connectionState == ConnectionState.waiting) {
              return _dueLoanCard(_cached != null ? widget.money(_cached!) : '—');
            }
            double repaid = 0;
            for (final d in repaySnap.data?.docs ?? []) {
              repaid += _firstAmt(d.data(), _repayKeys);
            }
            if (repaid == 0 && _cached != null) return _dueLoanCard(widget.money(_cached!));
            final due = (principal - repaid).clamp(0.0, double.infinity);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _cached = due;
            });
            return _dueLoanCard(widget.money(due));
          },
        );
      },
    );
  }

  Widget _dueLoanCard(String text) {
    return Container(
      width: widget.width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.account_balance_rounded, color: _primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        color: _fg, fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 2),
                Text('Due Loan',
                    style: GoogleFonts.inter(
                        color: _muted, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard tile ────────────────────────────────────────────────────────────
class _DashTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final int badge;
  final VoidCallback onTap;

  const _DashTile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: _primary.withValues(alpha: 0.06),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Stack(
            children: [
              // Blue top stripe
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _primaryLt,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(icon, color: _primary, size: 20),
                      ),
                      const SizedBox(height: 7),
                      LayoutBuilder(builder: (_, c) {
                        double fs = 11.5;
                        if (title.length > 12 || c.maxWidth < 90) fs = 10.5;
                        if (title.length > 16 || c.maxWidth < 76) fs = 9.5;
                        return Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              color: _fg,
                              fontSize: fs,
                              fontWeight: FontWeight.w600),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              if (badge > 0)
                Positioned(
                  right: 8, top: 8,
                  child: _Badge(count: badge, small: true),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom navigation bar — 4 items only ─────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int currentTab;
  final Stream<int> msgStream;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onClients;
  final VoidCallback onSales;
  final VoidCallback onMessages;

  const _BottomBar({
    required this.currentTab,
    required this.msgStream,
    required this.onTabChanged,
    required this.onClients,
    required this.onSales,
    required this.onMessages,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_NavItem>[
      _NavItem('Home',     Icons.home_rounded,          onTap: () => onTabChanged(0)),
      _NavItem('Clients',  Icons.people_alt_rounded,    onTap: onClients),
      _NavItem('Sales',    Icons.point_of_sale_rounded, onTap: onSales),
      _NavItem('Messages', Icons.chat_bubble_rounded,   onTap: onMessages, badge: msgStream),
    ];

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: _primaryDk,
          border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
        ),
        child: Row(
          children: items.asMap().entries.map((e) {
            final idx      = e.key;
            final it       = e.value;
            final selected = idx == currentTab;
            final color    = selected ? Colors.white : Colors.white54;

            final iconWidget = it.badge == null
                ? Icon(it.icon, color: color, size: 22)
                : StreamBuilder<int>(
                    stream: it.badge,
                    builder: (_, s) => _BadgeIcon(
                        icon: it.icon, color: color, count: s.data ?? 0),
                  );

            return Expanded(
              child: InkWell(
                onTap: () {
                  onTabChanged(idx);
                  it.onTap();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected)
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(child: iconWidget),
                        )
                      else
                        iconWidget,
                      const SizedBox(height: 4),
                      Text(
                        it.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: color,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  const _Avatar({required this.name, this.photoUrl});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'M';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.white24,
      backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty) ? NetworkImage(photoUrl!) : null,
      child: (photoUrl == null || photoUrl!.isEmpty)
          ? Text(_initials,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))
          : null,
    );
  }
}

class _AppBarBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback onTap;
  const _AppBarBadge({required this.icon, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(icon: Icon(icon, size: 22), onPressed: onTap),
        if (count > 0)
          Positioned(
            right: 8, top: 8,
            child: _Badge(count: count, small: true),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  final bool small;
  const _Badge({required this.count, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 4 : 6, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: _badgeRed,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
            color: Colors.white,
            fontSize: small ? 9 : 10,
            fontWeight: FontWeight.w800,
            height: 1.0),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  const _BadgeIcon({required this.icon, required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color, size: 22),
        if (count > 0)
          Positioned(
            right: -5, top: -5,
            child: _Badge(count: count, small: true),
          ),
      ],
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Stream<int>? badge;
  _NavItem(this.label, this.icon, {required this.onTap, this.badge});
}

class _DashItem {
  final String title;
  final IconData icon;
  final String route;
  const _DashItem(this.title, this.icon, this.route);
}
