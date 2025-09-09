import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/marketing/presentation/screens/products.dart';
import 'package:uddoygi/features/marketing/presentation/screens/renumeration_dashboard.dart';
import '../widgets/marketing_drawer.dart';

/// Palette
const Color _brandTeal = Color(0xFF001863);
const Color _indigoCard = Color(0xFF0B2D9F);
const Color _surface = Color(0xFFF4FBFB);

// Summary board colors
const Color _tileLime   = Color(0xFFFFFFFF);
const Color _tilePurple = Color(0xFFFFFFFF);
const Color _tileCyan   = Color(0xFFF3F3F3);
const Color _boardDark  = Color(0xFF0330AE);

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
    _DashboardItem('Products', Icons.inventory, ''),      // manual route
    _DashboardItem('Renumeration', Icons.paid, ''),       // manual route
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
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsPage(userEmail: email!)));
      }
      return;
    }
    if (item.title == 'Renumeration') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const RenumerationDashboard()));
      return;
    }
    Navigator.pushNamed(context, item.route);
  }

  /// Unread messages badge stream (adjust query to your schema if needed)
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

  @override
  Widget build(BuildContext context) {
    final filtered = _allItems
        .where((i) => i.title.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    // Responsive columns
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 900 ? 5 : width >= 600 ? 4 : 3;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _brandTeal,
        foregroundColor: Colors.white,
        title: Text(
          'Welcome back, ${_niceName(email ?? 'Marketing')}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
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
          // Summary board
          const _MarketingOverview(),
          const SizedBox(height: 16),

          // Search
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search…',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.05,
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
    // Common icons
    final items = <_NavItem>[
      _NavItem('Home', Icons.home_rounded, onTap: () => setState(() => _currentTab = 0)),
      _NavItem('Clients', Icons.people_alt_rounded, onTap: () => Navigator.pushNamed(context, '/marketing/clients')),
      _NavItem('Sales', Icons.point_of_sale_rounded, onTap: () => Navigator.pushNamed(context, '/marketing/sales')),
      _NavItem('Products', Icons.inventory_2_rounded, onTap: () {
        final mail = email;
        if (mail != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsPage(userEmail: mail)));
      }),
      _NavItem('Messages', Icons.message_rounded, onTap: () => Navigator.pushNamed(context, '/common/messages'), badgeStream: _unreadMessagesStream()),
    ];

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(color: _brandTeal),
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
                      Text(it.label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
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

/* ========================= Overview (live, dark board) ========================= */

class _MarketingOverview extends StatelessWidget {
  const _MarketingOverview();

  ({DateTime a, DateTime b}) _thisMonth() {
    final n = DateTime.now();
    final a = DateTime(n.year, n.month, 1);
    final b = DateTime(n.year, n.month + 1, 0, 23, 59, 59);
    return (a: a, b: b);
  }

  Stream<num> _salesThisMonth() {
    final r = _thisMonth();
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
      return sum;
    });
  }

  Stream<int> _selectedInvoices() {
    final r = _thisMonth();
    return FirebaseFirestore.instance
        .collection('invoices')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> _pendingPayments() {
    final r = _thisMonth();
    return FirebaseFirestore.instance
        .collection('invoices')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .where('status', whereIn: ['pending', 'unpaid', 'processing'])
        .snapshots()
        .map((s) => s.docs.length);
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
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: _boardDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            final cardW = (w - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardW,
                  child: _SquareSummaryCard(
                    color: _tileLime,
                    icon: Icons.receipt_long,
                    label: 'Total sale',
                    streamText: _salesThisMonth().map(_money),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: _SquareSummaryCard(
                    color: _tilePurple,
                    icon: Icons.library_books_outlined,
                    label: 'Total campaign',
                    streamText: _selectedInvoices().map((n) => '$n'),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: _SquareSummaryCard(
                    color: _tileCyan,
                    icon: Icons.schedule_send_outlined,
                    label: 'Pending payment',
                    streamText: _pendingPayments().map((n) => '$n'),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: _SquareSummaryCard(
                    color: _tileLime,
                    icon: Icons.playlist_add_check_circle_rounded,
                    label: 'Pending orders',
                    streamText: _selectedInvoices().map((n) => '$n'),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _SquareSummaryCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final Stream<String> streamText;

  const _SquareSummaryCard({
    required this.color,
    required this.icon,
    required this.label,
    required this.streamText,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.85),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StreamBuilder<String>(
              stream: streamText,
              builder: (_, snap) {
                final v = snap.hasData ? snap.data! : '—';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      v,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
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

/* ========================= Grid tiles ========================= */

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
      color: _indigoCard,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [_indigoCard, Color(0xFF1D5DF1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                bottom: -18,
                child: Container(
                  width: 70, height: 70,
                  decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: const BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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

/* ========================= Bottom nav helpers ========================= */

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
        color: Colors.redAccent,
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
