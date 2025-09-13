// lib/features/marketing/presentation/screens/marketing_dashboard.dart
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/marketing/presentation/screens/products.dart';
import 'package:uddoygi/features/marketing/presentation/screens/renumeration_dashboard.dart';
import '../widgets/marketing_drawer.dart';
import 'package:uddoygi/features/common/notification.dart';
import 'package:uddoygi/features/marketing/presentation/screens/campaign_screen.dart';

// ✅ NEW: import the Stock History screen/class
import 'package:uddoygi/features/common/stock/stockhistory.dart';

/// ===== Palette (blue + white only) =====
const Color _brandBlue   = Color(0xFF0D47A1); // dark
const Color _blueMid     = Color(0xFF1D5DF1); // accent
const Color _surface     = Color(0xFFF6F8FF); // near-white surface
const Color _cardBorder  = Color(0x1A0D47A1); // 10% blue
const Color _shadowLite  = Color(0x14000000);

class MarketingDashboard extends StatefulWidget {
  const MarketingDashboard({Key? key}) : super(key: key);

  @override
  State<MarketingDashboard> createState() => _MarketingDashboardState();
}

class _MarketingDashboardState extends State<MarketingDashboard> {
  String? email;
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
    _DashboardItem('Campaigns', Icons.campaign, '/marketing/campaign'),
    _DashboardItem('Orders', Icons.shopping_bag, '/marketing/orders'),
    _DashboardItem('Loans', Icons.request_page, '/marketing/loan_request'),
    _DashboardItem('Products', Icons.inventory, ''),           // manual route
    _DashboardItem('Renumeration', Icons.paid, ''),            // manual route
    // ✅ NEW dashboard section
    _DashboardItem('Stock Update', Icons.sync, ''),            // manual route
  ];

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    if (session != null && mounted) {
      setState(() => email = session['email'] as String?);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await LocalStorageService.clearSession();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  void _onItemTap(_DashboardItem item) {
    if (item.title == 'Products') {
      if (email != null) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => ProductsPage(userEmail: email!)));
      }
      return;
    }
    if (item.title == 'Renumeration') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const RenumerationDashboard()));
      return;
    }
    if (item.title == 'Campaigns') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const AdsManagerMobile()));
      return;
    }
    // ✅ NEW: route Stock Update tile to StockHistoryScreen
    if (item.title == 'Stock Update') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StockHistoryScreen()),
      );
      return;
    }

    Navigator.pushNamed(context, item.route);
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
        .where('to', isEqualTo: mail)          // adjust to your schema
        .where('read', isEqualTo: false)       // adjust to your schema
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
          'Welcome back, ${_niceName(email ?? 'Marketing')}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationPage()),
            ),
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
          _OverviewHeader(userEmail: email),
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
              final isMessages = it.title == 'Messages';
              return StreamBuilder<int>(
                stream: isMessages ? _unreadMessagesStream() : const Stream<int>.empty(),
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
      _NavItem('Sales', Icons.point_of_sale_rounded, onTap: () => Navigator.pushNamed(context, '/marketing/sales')),
      _NavItem('Products', Icons.inventory_2_rounded, onTap: () {
        final mail = email;
        if (mail != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsPage(userEmail: mail)));
        }
      }),
      // ✅ NEW: Bottom-nav shortcut to Stock History
      _NavItem(
        'Stock Update',
        Icons.sync,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StockHistoryScreen()),
        ),
      ),
      _NavItem(
        'Notifications',
        Icons.notifications,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPage())),
        badgeStream: _unreadNotificationsStream(),
      ),
      _NavItem('Messages', Icons.message_rounded, onTap: () => Navigator.pushNamed(context, '/common/messages'),
          badgeStream: _unreadMessagesStream()),
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

/* ========================= Overview, stat cards & helpers remain unchanged ========================= */

enum _Range { thisMonth, prevMonth, last3, last12 }

// ... (rest of your file stays exactly the same below here) ...
// I didn’t modify _OverviewHeader, _StatCard, _DashTile, _NavItem, _BadgeIcon, _Badge, etc.

/* ========================= Overview (blue header + white stat cards, 2x3 + filter) ========================= */



class _OverviewHeader extends StatefulWidget {
  final String? userEmail; // optional user scoping if needed
  const _OverviewHeader({Key? key, this.userEmail}) : super(key: key);

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

  /* ---------- Streams for stats (adjust collection/field names if needed) ---------- */

  // 1) Total sale (sum grandTotal from invoices)
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
        final v = d.data()['grandTotal'];
        if (v is num) sum += v;
      }
      return _money(sum);
    });
  }

  // 2) Total campaign (invoice count — keep same meaning as before)
  Stream<String> _totalCampaigns() {
    final r = _rangeDates(_range);
    return FirebaseFirestore.instance
        .collection('invoices')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .snapshots()
        .map((s) => '${s.docs.length}');
  }

  // 3) Pending payment (count invoices by status)
  Stream<String> _pendingPayments() {
    final r = _rangeDates(_range);
    return FirebaseFirestore.instance
        .collection('invoices')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .where('status', whereIn: ['pending', 'unpaid', 'processing'])
        .snapshots()
        .map((s) => '${s.docs.length}');
  }

  // 4) Work orders running (count work_orders with active statuses)
  //    Tweak the whereIn list to match your exact statuses.
  Stream<String> _workOrdersRunning() {
    final r = _rangeDates(_range);
    return FirebaseFirestore.instance
        .collection('work_orders')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .where('status', whereIn: ['Pending', 'Processing', 'In Progress', 'In Production'])
        .snapshots()
        .map((s) => '${s.docs.length}');
  }

  // 5) Incentive amount (sum of amounts from renumerations/incentives)
  //    Change the collection name if yours is different.
  static const String _INCENTIVE_COLLECTION = 'renumerations'; // or 'incentives'
  Stream<String> _incentiveAmount() {
    final r = _rangeDates(_range);
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection(_INCENTIVE_COLLECTION)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(r.b));
    // Optional: scope by user
    if ((widget.userEmail ?? '').isNotEmpty) {
      // adjust field if your doc uses 'agentEmail' or 'userEmail'
      q = q.where('agentEmail', isEqualTo: widget.userEmail);
    }
    return q.snapshots().map((s) {
      num sum = 0;
      for (final d in s.docs) {
        final v = d.data()['amount'];
        if (v is num) sum += v;
      }
      return _money(sum);
    });
  }

  // 6) Total loans (sum amount from loans)
  Stream<String> _loansTotal() {
    final r = _rangeDates(_range);
    return FirebaseFirestore.instance
        .collection('loans')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .snapshots()
        .map((s) {
      num sum = 0;
      for (final d in s.docs) {
        final v = d.data()['amount'];
        if (v is num) sum += v;
      }
      return _money(sum);
    });
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

  @override
  Widget build(BuildContext context) {
    // header
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
          // Title + Filter
          Row(
            children: [
              const Icon(Icons.insights, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Overview',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              _RangeFilter(
                value: _range,
                onChanged: (r) => setState(() => _range = r),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2×3 grid of stat cards (fixed two columns)
          LayoutBuilder(builder: (ctx, c) {
            final w = c.maxWidth;
            final spacing = 10.0;
            final cardW = (w - spacing) / 2; // two columns
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _StatCard(width: cardW, label: 'Total sale',       streamText: _totalSales()),
                _StatCard(width: cardW, label: 'Total campaign',   streamText: _totalCampaigns()),
                _StatCard(width: cardW, label: 'Pending payment',  streamText: _pendingPayments()),
                _StatCard(width: cardW, label: 'Running Work orders', streamText: _workOrdersRunning()),
                _StatCard(width: cardW, label: 'Incentive amount', streamText: _incentiveAmount()),
                _StatCard(width: cardW, label: 'Total loans',      streamText: _loansTotal()),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/* ---------- Filter chip row (blue & white only) ---------- */

/* ---------- Filter as a dropdown (blue & white only) ---------- */

class _RangeFilter extends StatelessWidget {
  final _Range value;
  final ValueChanged<_Range> onChanged;
  const _RangeFilter({required this.value, required this.onChanged});

  String _label(_Range r) {
    switch (r) {
      case _Range.thisMonth: return 'This month';
      case _Range.prevMonth: return 'Previous month';
      case _Range.last3:     return 'Last 3 months';
      case _Range.last12:    return 'One year';
    }
  }

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

/* ========================= Tiles & bottom nav helpers (unchanged) ========================= */

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

class _DashboardItem {
  final String title;
  final IconData icon;
  final String route;
  const _DashboardItem(this.title, this.icon, this.route);
}
