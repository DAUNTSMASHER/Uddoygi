// lib/features/marketing/presentation/screens/marketing_dashboard.dart

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/features/marketing/presentation/screens/sales_screen.dart';

import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/marketing/presentation/screens/products.dart';
import 'package:uddoygi/features/marketing/presentation/screens/renumeration_dashboard.dart';
import '../widgets/marketing_drawer.dart';
import 'package:uddoygi/features/common/notification.dart';
import 'package:uddoygi/features/marketing/presentation/screens/campaign_screen.dart';
import 'package:uddoygi/features/common/stock/stockhistory.dart';
import 'package:uddoygi/features/marketing/presentation/screens/all_invoices_screen.dart';
// ✅ Import the loan request screen
import 'package:uddoygi/features/marketing/presentation/screens/loan_request_screen.dart';

/// ===== Palette (blue + white only) =====
const Color _brandBlue  = Color(0xFF0D47A1); // dark
const Color _blueMid    = Color(0xFF1D5DF1); // accent
const Color _surface    = Color(0xFFF6F8FF); // near-white surface
const Color _cardBorder = Color(0x1A0D47A1); // 10% blue
const Color _shadowLite = Color(0x14000000);
// Running stages (compare in lowercase; supports both `status` and `currentStage`)
const Set<String> _runningStagesLower = {
  'submitted to factory',
  'factory update 1 (base is done)',
  'hair is ready',
  'knotting is going on',
  'putting',
  'molding',
};

String _asLower(dynamic v) => (v ?? '').toString().trim().toLowerCase();

bool _isRunningWorkOrder(Map<String, dynamic> m) {
  final s  = _asLower(m['status']);        // some docs use `status`
  final cs = _asLower(m['currentStage']);  // some docs use `currentStage`
  return _runningStagesLower.contains(s) || _runningStagesLower.contains(cs);
}

class MarketingDashboard extends StatefulWidget {
  const MarketingDashboard({Key? key}) : super(key: key);

  @override
  State<MarketingDashboard> createState() => _MarketingDashboardState();
}

class _MarketingDashboardState extends State<MarketingDashboard> {
  String? email;
  String? uid;
  String _search = '';
  int _currentTab = 0;

  final List<_DashboardItem> _allItems = const [
    _DashboardItem('Notices', Icons.notifications_active, '/marketing/notices'),
    _DashboardItem('Clients', Icons.people_alt, '/marketing/clients'),
    _DashboardItem('Sales', Icons.point_of_sale, '/marketing/sales'),
    _DashboardItem('Welfare', Icons.volunteer_activism, '/common/welfare'),
    _DashboardItem('Complaints', Icons.warning_amber, '/common/complaints'),
    _DashboardItem('Messages', Icons.message, '/common/messages'),
    _DashboardItem('Tasks', Icons.task, '/marketing/task_assignment'),
    _DashboardItem('Campaigns', Icons.campaign, ''), // manual: AdsManagerMobile
    _DashboardItem('Orders', Icons.shopping_bag, '/marketing/orders'),
    _DashboardItem('Loans', Icons.request_page, ''), // manual: LoanRequestScreen
    _DashboardItem('Products', Icons.inventory, ''), // manual: ProductsPage
    _DashboardItem('Renumeration', Icons.paid, ''),  // manual: RenumerationDashboard
    _DashboardItem('Stock Update', Icons.sync, ''),  // manual: StockHistoryScreen
  ];

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    if (!mounted) return;
    setState(() {
      email = session?['email'] as String?;
      uid   = session?['uid'] as String?;
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await LocalStorageService.clearSession();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  void _onItemTap(_DashboardItem item) {
    switch (item.title) {
      case 'Products':
        if (email != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsPage(userEmail: email!)));
        }
        return;
      case 'Renumeration':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RenumerationDashboard()));
        return;
      case 'Campaigns':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdsManagerMobile()));
        return;
      case 'Stock Update':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const StockHistoryScreen()));
        return;
      case 'Sales':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesScreen()));
        return;
      case 'Loans':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LoanRequestScreen()));
        return;
      default:
        Navigator.pushNamed(context, item.route);
    }
  }

  /// ---------- LIVE BADGES: per-tile counts from Firestore ----------
  Stream<int> _badgeStreamFor(String title) {
    final mail = email ?? FirebaseAuth.instance.currentUser?.email ?? '';
    final fs = FirebaseFirestore.instance;

    switch (title) {
      case 'Notices':
        return fs
            .collection('notifications')
            .where('to', isEqualTo: mail)
            .where('read', isEqualTo: false)
            .snapshots()
            .map((s) => s.docs.length);

      case 'Messages':
        return _unreadMessagesStream();

      case 'Sales':
        return fs
            .collection('invoices')
            .where('ownerEmail', isEqualTo: mail)
            .snapshots()
            .map((s) => s.docs.length);

      case 'Orders':
        return fs.collection('work_orders')
            .snapshots()
            .map((s) => s.docs.where((d) => _isRunningWorkOrder(d.data())).length);



      case 'Loans':
        return fs
            .collection('loans')
            .where('userEmail', isEqualTo: mail)
            .snapshots()
            .map((s) => s.docs.length);

      case 'Renumeration':
        return fs
            .collection('marketing_incentives')
            .where('userEmail', isEqualTo: mail)
            .snapshots()
            .map((s) => s.docs.length);

      case 'Clients':
        return fs.collection('customers').snapshots().map((s) => s.docs.length);

      case 'Campaigns':
        return fs.collection('campaigns').snapshots().map((s) => s.docs.length);

      case 'Welfare':
        return fs.collection('welfare').snapshots().map((s) => s.docs.length);

      case 'Complaints':
        return fs.collection('complaints').snapshots().map((s) => s.docs.length);

      case 'Products':
        return fs.collection('products').snapshots().map((s) => s.docs.length);

      case 'Tasks':
        return fs.collection('tasks').snapshots().map((s) => s.docs.length);

      default:
        return const Stream<int>.empty();
    }
  }

  /// Unread messages badge stream
  Stream<int> _unreadMessagesStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream<int>.value(0);
    final mail = user.email ?? '';
    return FirebaseFirestore.instance
        .collection('messages')
        .where('to', isEqualTo: mail)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> _unreadNotificationsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream<int>.value(0);
    final mail = user.email ?? '';
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('to', isEqualTo: mail)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _allItems
        .where((i) => i.title.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 1000 ? 6 : width >= 780 ? 5 : width >= 560 ? 4 : 3;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _brandBlue,
        foregroundColor: Colors.white,
        title: Text(
          'Welcome back, ${_niceName(email ?? FirebaseAuth.instance.currentUser?.email ?? 'Marketing')}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          StreamBuilder<int>(
            stream: _unreadNotificationsStream(),
            builder: (_, s) {
              final count = s.data ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    tooltip: 'Notifications',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationPage()),
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: _Badge(count: count, small: true),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),

      drawer: const MarketingDrawer(),

      bottomNavigationBar: _buildBottomNav(),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _OverviewHeader(userEmail: email, userUid: uid),
          const SizedBox(height: 16),

          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search…',
              prefixIcon: const Icon(Icons.search, color: _brandBlue),
              hintStyle: const TextStyle(color: _brandBlue),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _cardBorder),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            style: const TextStyle(color: _brandBlue),
          ),
          const SizedBox(height: 16),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.02,
            ),
            itemBuilder: (_, i) {
              final it = filtered[i];
              final stream = _badgeStreamFor(it.title);
              return StreamBuilder<int>(
                stream: stream,
                builder: (_, snap) {
                  final count = snap.data ?? 0;
                  return _DashTile(
                    title: it.title,
                    icon: it.icon,
                    badgeCount: count,
                    onTap: () => _onItemTap(it),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = <_NavItem>[
      _NavItem('Home', Icons.home_rounded, onTap: () => setState(() => _currentTab = 0)),
      _NavItem('Clients', Icons.people_alt_rounded, onTap: () => Navigator.pushNamed(context, '/marketing/clients')),
      _NavItem(
        'Sales',
        Icons.point_of_sale_rounded,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllInvoicesScreen())),
      ),
      _NavItem('Products', Icons.inventory_2_rounded, onTap: () {
        final mail = email ?? FirebaseAuth.instance.currentUser?.email;
        if (mail != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsPage(userEmail: mail)));
        }
      }),
      _NavItem(
        'Stock Update',
        Icons.sync,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockHistoryScreen())),
      ),
      _NavItem(
        'Notifications',
        Icons.notifications,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPage())),
        badgeStream: _unreadNotificationsStream(),
      ),
      _NavItem(
        'Messages',
        Icons.message_rounded,
        onTap: () => Navigator.pushNamed(context, '/common/messages'),
        badgeStream: _unreadMessagesStream(),
      ),
    ];

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(color: _brandBlue),
        child: Row(
          children: items.map((it) {
            final isSelected = items.indexOf(it) == _currentTab;
            final color = isSelected ? Colors.white : Colors.white70;

            final iconWidget = it.badgeStream == null
                ? Icon(it.icon, color: color)
                : StreamBuilder<int>(
              stream: it.badgeStream,
              builder: (_, s) => _BadgeIcon(
                icon: it.icon,
                color: color,
                count: s.data ?? 0,
              ),
            );

            return Expanded(
              child: InkWell(
                onTap: () {
                  setState(() => _currentTab = items.indexOf(it));
                  it.onTap();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      iconWidget,
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 14,
                        child: AutoSizeText(
                          it.label,
                          maxLines: 1,
                          minFontSize: 8,
                          stepGranularity: 0.5,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
                        ),
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

  String _niceName(String s) {
    if (!s.contains('@')) return s;
    final core = s.split('@').first;
    return core.replaceAll('.', ' ').replaceAll('_', ' ');
  }
}

/* ========================= Overview & helpers ========================= */

enum _Range { thisMonth, prevMonth, last3, last12 }
// Running stages (lowercase)


class _OverviewHeader extends StatefulWidget {
  final String? userEmail; // optional user scoping if needed
  final String? userUid;
  const _OverviewHeader({Key? key, this.userEmail, this.userUid}) : super(key: key);

  @override
  State<_OverviewHeader> createState() => _OverviewHeaderState();
}

class _OverviewHeaderState extends State<_OverviewHeader> {
  _Range _range = _Range.thisMonth;

  ({DateTime a, DateTime b}) _rangeDates(_Range r) {
    final now = DateTime.now();
    switch (r) {
      case _Range.thisMonth:
        final a = DateTime(now.year, now.month, 1);
        final b = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return (a: a, b: b);
      case _Range.prevMonth:
        final a = DateTime(now.year, now.month - 1, 1);
        final b = DateTime(now.year, now.month, 0, 23, 59, 59);
        return (a: a, b: b);
      case _Range.last3:
        final a = DateTime(now.year, now.month - 2, 1);
        final b = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return (a: a, b: b);
      case _Range.last12:
        final a = DateTime(now.year, now.month - 11, 1);
        final b = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return (a: a, b: b);
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

  // 1) Total sale (paid invoices only)
  Stream<String> _totalSales() {
    final r = _rangeDates(_range);
    return FirebaseFirestore.instance
        .collection('invoices')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .snapshots()
        .map((s) {
      num sum = 0;
      for (final d in s.docs) {
        final m = d.data();
        final status = (m['status'] ?? '').toString().toLowerCase();
        final pay = (m['payment'] is Map)
            ? Map<String, dynamic>.from(m['payment'])
            : const <String, dynamic>{};
        final paid = (pay['taken'] == true) || status.contains('payment taken');
        if (!paid) continue;

        final v = m['grandTotal'];
        if (v is num) sum += v;
      }
      return _money(sum);
    });
  }

  // 2) Total campaign (count created this period)
  Stream<String> _totalCampaigns() {
    final r = _rangeDates(_range);
    return FirebaseFirestore.instance
        .collection('campaigns')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .snapshots()
        .map((s) => '${s.docs.length}');
  }

  // 3) Pending payment = invoices whose status contains "Invoice Created"
  Stream<String> _pendingPayments() {
    final r = _rangeDates(_range);
    return FirebaseFirestore.instance
        .collection('invoices')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .snapshots()
        .map((s) {
      int count = 0;
      for (final d in s.docs) {
        final status = (d.data()['status'] ?? '').toString().toLowerCase();
        if (status.contains('invoice created')) count++;
      }
      return '$count';
    });
  }

  // 4) Running work orders = your 7 ongoing stages (case-insensitive)
  Stream<String> _workOrdersRunning() {
    final r = _rangeDates(_range);
    return FirebaseFirestore.instance
        .collection('work_orders')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('timestamp', isLessThanOrEqualTo:   Timestamp.fromDate(r.b))
        .snapshots()
        .map((s) => '${s.docs.where((d) => _isRunningWorkOrder(d.data())).length}');
  }



  // 5) Incentive amount (sum totalIncentive from marketing_incentives)
  Stream<String> _incentiveAmount() {
    final r = _rangeDates(_range);
    final me = (widget.userEmail ?? '').trim();

    return FirebaseFirestore.instance
        .collection('marketing_incentives')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .snapshots()
        .map((s) {
      num sum = 0;
      for (final d in s.docs) {
        final m = d.data() as Map<String, dynamic>;
        final isMine = me.isEmpty
            ? true
            : (m['userEmail'] == me) || (m['agentEmail'] == me) || d.id.startsWith('$me');
        if (!isMine) continue;
        final v = (m['totalIncentive'] as num?) ?? 0;
        sum += v;
      }
      return _money(sum);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_brandBlue, _blueMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: _shadowLite, blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.insights, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Overview',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            ),
            _RangeFilter(value: _range, onChanged: (r) => setState(() => _range = r)),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (ctx, c) {
            final spacing = 10.0;
            final cardW = (c.maxWidth - spacing) / 2; // two columns
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _StatCard(width: cardW, label: 'Total sale',          streamText: _totalSales()),
                _StatCard(width: cardW, label: 'Total campaign',      streamText: _totalCampaigns()),
                _StatCard(width: cardW, label: 'Pending payment',     streamText: _pendingPayments()),
                _StatCard(width: cardW, label: 'Running Work orders', streamText: _workOrdersRunning()),
                _StatCard(width: cardW, label: 'Incentive amount',    streamText: _incentiveAmount()),
                _DueLoanStatCard(
                  width: cardW,
                  label: 'Current Due loan',
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

/* ---------- Filter (dropdown) ---------- */
class _RangeFilter extends StatelessWidget {
  final _Range value;
  final ValueChanged<_Range> onChanged;
  const _RangeFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white70),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_Range>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: _brandBlue),
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: _brandBlue,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          items: const [
            DropdownMenuItem(value: _Range.thisMonth, child: Text('This month')),
            DropdownMenuItem(value: _Range.prevMonth, child: Text('Previous month')),
            DropdownMenuItem(value: _Range.last3,     child: Text('Last 3 months')),
            DropdownMenuItem(value: _Range.last12,    child: Text('One year')),
          ],
          onChanged: (r) {
            if (r != null) onChanged(r);
          },
        ),
      ),
    );
  }
}

/* ========================= Stat card ========================= */
class _StatCard extends StatelessWidget {
  final double width;
  final String label;
  final Stream<String> streamText;
  const _StatCard({required this.width, required this.label, required this.streamText, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 96,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: _shadowLite, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: _brandBlue.withOpacity(.08), shape: BoxShape.circle),
            child: const Icon(Icons.assessment, color: _brandBlue, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StreamBuilder<String>(
              stream: streamText,
              builder: (_, snap) {
                final v = snap.hasData ? snap.data! : '—';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      v,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _brandBlue,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _brandBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
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

/* ========================= Due Loan Stat Card (STABLE) ========================= */
class _DueLoanStatCard extends StatefulWidget {
  final double width;
  final String label;
  final String Function(num) money;
  final String? userEmail;
  final String? userUid;

  const _DueLoanStatCard({
    Key? key,
    required this.width,
    required this.label,
    required this.money,
    this.userEmail,
    this.userUid,
  }) : super(key: key);

  @override
  State<_DueLoanStatCard> createState() => _DueLoanStatCardState();
}

class _DueLoanStatCardState extends State<_DueLoanStatCard> {
  double? _lastStableDue; // cache to avoid flicker

  // Robust number parser: handles "৳20,000", "20,000.50", etc.
  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      final cleaned = v.replaceAll(RegExp(r'[^0-9.\-]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  static double _firstAmount(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = _asDouble(m[k]);
      if (v > 0) return v;
    }
    return 0.0;
  }

  static const List<String> _repayKeys = ['amount', 'paid', 'value', 'payAmount'];
  static const Set<String> _outstandingKeys = {
    'due', 'dueAmount', 'amountDue', 'currentDue', 'totalDue',
    'outstanding', 'outstandingAmount', 'remaining', 'remainingAmount',
    'balance', 'leftToPay', 'pendingAmount',
  };

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseFirestore.instance;

    // Prefer identifiers from parent; fall back to FirebaseAuth.
    final mail = (widget.userEmail ?? FirebaseAuth.instance.currentUser?.email ?? '').trim();
    final uid  = (widget.userUid   ?? FirebaseAuth.instance.currentUser?.uid   ?? '').trim();

    Query<Map<String, dynamic>> loansQ = fs.collection('loans');
    if (mail.isNotEmpty && uid.isNotEmpty) {
      loansQ = loansQ.where(
        Filter.or(
          Filter('userEmail', isEqualTo: mail),
          Filter('userId',   isEqualTo: uid),
        ),
      );
    } else if (mail.isNotEmpty) {
      loansQ = loansQ.where('userEmail', isEqualTo: mail);
    } else if (uid.isNotEmpty) {
      loansQ = loansQ.where('userId', isEqualTo: uid);
    } else {
      // No identity yet → show cache or placeholder
      return _DueText(
        label: widget.label,
        text: _lastStableDue != null ? widget.money(_lastStableDue!) : '—',
      );
    }

    // Single repayments query (OR when both ids exist)
    Query<Map<String, dynamic>>? repaymentsQ;
    if (mail.isNotEmpty && uid.isNotEmpty) {
      repaymentsQ = fs.collectionGroup('repayments').where(
        Filter.or(
          Filter('userEmail', isEqualTo: mail),
          Filter('userId',   isEqualTo: uid),
        ),
      );
    } else if (mail.isNotEmpty) {
      repaymentsQ = fs.collectionGroup('repayments').where('userEmail', isEqualTo: mail);
    } else if (uid.isNotEmpty) {
      repaymentsQ = fs.collectionGroup('repayments').where('userId', isEqualTo: uid);
    }

    return Container(
      width: widget.width,
      height: 96,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: _shadowLite, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: _brandBlue.withOpacity(.08), shape: BoxShape.circle),
            child: const Icon(Icons.assessment, color: _brandBlue, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: loansQ.snapshots(),
              builder: (_, loansSnap) {
                if (loansSnap.connectionState == ConnectionState.waiting) {
                  return _DueText(
                    label: widget.label,
                    text: _lastStableDue != null ? widget.money(_lastStableDue!) : '—',
                  );
                }

                double explicitSum = 0.0;
                bool foundExplicitFieldAnywhere = false;
                double principalSum = 0.0;

                if (loansSnap.hasData) {
                  for (final d in loansSnap.data!.docs) {
                    final m = d.data();

                    // Look for any explicit outstanding key; treat presence as authoritative (even if 0).
                    for (final k in _outstandingKeys) {
                      if (m.containsKey(k)) {
                        foundExplicitFieldAnywhere = true;
                        final v = _asDouble(m[k]);
                        if (v > 0) explicitSum += v;
                        break; // one key per doc is enough
                      }
                    }

                    // Track principal for fallback path
                    final status = (m['status'] ?? '').toString().toLowerCase();
                    if (status == 'approved' || status == 'disbursed' || status == 'closed') {
                      principalSum += _asDouble(m['amount']);
                    }
                  }
                }

                // If any explicit field was present on any doc, always use its sum (even if zero).
                if (foundExplicitFieldAnywhere) {
                  if (_lastStableDue != explicitSum) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _lastStableDue = explicitSum;
                    });
                  }
                  return _DueText(label: widget.label, text: widget.money(explicitSum));
                }

                // No explicit due in loans → need repayments. If we cannot query them, keep cache.
                if (repaymentsQ == null) {
                  return _DueText(
                    label: widget.label,
                    text: _lastStableDue != null ? widget.money(_lastStableDue!) : '—',
                  );
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: repaymentsQ.snapshots(),
                  builder: (_, repaySnap) {
                    if (repaySnap.connectionState == ConnectionState.waiting) {
                      return _DueText(
                        label: widget.label,
                        text: _lastStableDue != null ? widget.money(_lastStableDue!) : '—',
                      );
                    }

                    double repaid = 0.0;
                    if (repaySnap.hasData) {
                      for (final d in repaySnap.data!.docs) {
                        repaid += _firstAmount(d.data(), _repayKeys);
                      }
                    }

                    // If repayments are empty, don't snap to "total principal" — keep the last stable value.
                    if (repaid == 0.0 && _lastStableDue != null) {
                      return _DueText(label: widget.label, text: widget.money(_lastStableDue!));
                    }

                    final dueRaw = principalSum - repaid;
                    final due = dueRaw <= 0 ? 0.0 : dueRaw;

                    if (_lastStableDue != due) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _lastStableDue = due;
                      });
                    }

                    return _DueText(label: widget.label, text: widget.money(due));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}



class _DueText extends StatelessWidget {
  final String label;
  final String text;
  const _DueText({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _brandBlue,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _brandBlue,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/* ========================= Tiles & bottom nav helpers ========================= */
class _DashTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;
  const _DashTile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cardBorder),
            boxShadow: const [BoxShadow(color: _shadowLite, blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: _brandBlue, size: 28),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (ctx, c) {
                          final base = 12.0;
                          double fs = base;
                          if (title.length > 12 || c.maxWidth < 90) fs = 11;
                          if (title.length > 16 || c.maxWidth < 76) fs = 10;
                          if (title.length > 20 || c.maxWidth < 68) fs = 9;
                          return Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _brandBlue, fontSize: fs, fontWeight: FontWeight.w700),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: _Badge(count: badgeCount),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Stream<int>? badgeStream;
  _NavItem(this.label, this.icon, {required this.onTap, this.badgeStream});
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
        Icon(icon, color: color),
        if (count > 0)
          Positioned(
            right: -6,
            top: -6,
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
    final text = count > 99 ? '99+' : '$count';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 5 : 6, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: _brandBlue,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 9 : 10,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
    );
  }
}

/* ======================= (Optional reference UI kept) ======================= */

class _StableRepaidHeader extends StatelessWidget {
  final FirebaseFirestore db;
  final String name;
  final double creditLimit;
  final Color brand, brandDark, accent;
  final String Function(num) money;
  final DateTime? selectedMonth;
  final String? email;
  final String? uid;

  final double totalPrincipal;
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
    final emailStream = (email == null)
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : db.collectionGroup('repayments').where('userEmail', isEqualTo: email).snapshots();

    final uidStream = (uid == null)
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : db.collectionGroup('repayments').where('userId', isEqualTo: uid).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: emailStream,
      builder: (context, emailSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: uidStream,
          builder: (context, uidSnap) {
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
              cachedRepaidSetter(unionRepaid);
            } else {
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

class _DashboardItem {
  final String title;
  final IconData icon;
  final String route;
  const _DashboardItem(this.title, this.icon, this.route);
}
