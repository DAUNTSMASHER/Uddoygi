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

// Summary board colors (like the mock)
const Color _tileLime   = Color(0xFFFFFFFF);
const Color _tilePurple = Color(0xFFFFFFFF);
const Color _tileCyan   = Color(0xFFF3F3F3);
const Color _boardDark  = Color(0xFF0330AE); // board background

class MarketingDashboard extends StatefulWidget {
  const MarketingDashboard({Key? key}) : super(key: key);

  @override
  State<MarketingDashboard> createState() => _MarketingDashboardState();
}

class _MarketingDashboardState extends State<MarketingDashboard> {
  String? email;
  String _search = '';

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
    if (session != null) {
      setState(() => email = session['email'] as String?);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await LocalStorageService.clearSession();
    if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Summary board (like “Payroll” mock)
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
              return _DashTile(
                title: it.title,
                icon: it.icon,
                onTap: () => _onItemTap(it),
              );
            },
          ),
        ],
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

  // ---- date helpers (this month) ----
  ({DateTime a, DateTime b}) _thisMonth() {
    final n = DateTime.now();
    final a = DateTime(n.year, n.month, 1);
    final b = DateTime(n.year, n.month + 1, 0, 23, 59, 59);
    return (a: a, b: b);
  }

  // ---- streams (you can swap to your own fields easily) ----
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

  // ---- helpers ----
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
    // board container with dark bg + rounded corners
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: _boardDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [

          const SizedBox(height: 14),

          // 2×2 summary tiles like the mock
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            final cardW = (w - 12) / 2; // 12 = gap
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardW,
                  child: _SquareSummaryCard(
                    color: _tileLime,
                    icon: Icons.receipt_long,
                    label: 'Total Sale ',
                    streamText: _salesThisMonth().map(_money),
                  ),
                ),
                SizedBox(
                  width: cardW,
                  child: _SquareSummaryCard(
                    color: _tilePurple,
                    icon: Icons.library_books_outlined,
                    label: 'Total Campaign ',
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
                // Empty dark tile with a plus button (visual)
                SizedBox(
                  width: cardW,
                  child: _SquareSummaryCard(
                    color: _tileLime,
                    icon: Icons.receipt_long,
                    label: 'Pending Order ',
                    streamText: _salesThisMonth().map(_money),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _segChip(String text, {bool selected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? Colors.white : const Color(0xFF1B1C20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? Colors.white : Colors.white10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: selected ? Colors.black : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _roundIcon(IconData i) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
      child: Icon(i, color: Colors.black, size: 20),
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
  const _DashTile({required this.title, required this.icon, required this.onTap});

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
            ],
          ),
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
