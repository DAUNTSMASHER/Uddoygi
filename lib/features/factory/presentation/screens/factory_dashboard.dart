// lib/features/factory/presentation/screens/factory_dashboard.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/factory/presentation/widgets/factory_drawer.dart';

// Direct imports for your factory sub-screens
import 'package:uddoygi/features/factory/presentation/factory/work_order.dart';
import 'package:uddoygi/features/factory/presentation/factory/purchase_order.dart';
import 'package:uddoygi/features/factory/presentation/factory/QC_report.dart';
import 'package:uddoygi/features/factory/presentation/factory/daily_production.dart';
import 'package:uddoygi/features/factory/presentation/screens/progress_update_screen.dart';

/// ========================== RED THEME (Requested) ==========================
// ===== Refined Red & White Palette (accessible + classy) =====
const Color _navRed      = Color(0xFF9B1C1C); // Deep crimson (AppBar/BottomNav)
const Color _navRedDark  = Color(0xFF7F1D1D); // Pressed/darker state
const Color _labelOnRed  = Colors.white;      // Labels/icons on red

// Page & tiles
const Color _surface     = Color(0xFFFFF7F7); // Soft warm white (page background)
const Color _cardGradA = Color(0xFFD51616); // start (deep red)
const Color _cardGradB = Color(0xFFD32F2F);// Tile gradient end (subtle rose-50)
const Color _boardDark   = Color(0xFFFDECEC); // Overview board (light rose panel)

// Light tiles within overview
const Color _tileA = Color(0xFFFFFFFF);       // Summary tile 1
const Color _tileB = Color(0xFFFFFFFF);       // Summary tile 2
const Color _tileC = Color(0xFFFFFFFF);       // Summary tile 3 (slight contrast)
const Color _tileD = Color(0xFFFFFFFF);       // Summary tile 4

/// Dashboard items (searchable grid)
class _DashboardItem {
  final String title;
  final IconData icon;
  final String route;
  const _DashboardItem(this.title, this.icon, this.route);
}

class FactoryDashboard extends StatefulWidget {
  const FactoryDashboard({Key? key}) : super(key: key);

  @override
  State<FactoryDashboard> createState() => _FactoryDashboardState();
}

class _FactoryDashboardState extends State<FactoryDashboard> {
  String? email;
  String _search = '';
  int _currentTab = 0;

  /// All dashboard entries (same items you had, now searchable)
  final List<_DashboardItem> _allItems = const [
    _DashboardItem('Notices',          Icons.notifications_active, '/factory/notices'),
    _DashboardItem('Welfare',          Icons.volunteer_activism,  '/common/welfare'),
    _DashboardItem('Messages',         Icons.message,             '/common/messages'),
    _DashboardItem('Work Orders',      Icons.work,                ''), // manual route
    _DashboardItem('Purchase Orders',  Icons.shopping_cart,       ''), // manual route
    _DashboardItem('QC Report',        Icons.check_circle,        ''), // manual route
    _DashboardItem('Daily Production', Icons.factory,             ''), // manual route
    _DashboardItem('Updates',          Icons.update,              ''), // manual route
    _DashboardItem('Attendance',       Icons.event_available,     '/factory/attendance'),
    _DashboardItem('Loan Requests',    Icons.request_page,        '/marketing/loan_request'),
    _DashboardItem('Salary & OT',      Icons.attach_money,        '/factory/salary_overtime'),
  ];

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    setState(() => email = session?['email'] as String?);
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await LocalStorageService.clearSession();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  void _onItemTap(_DashboardItem item) {
    switch (item.title) {
      case 'Work Orders':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkOrdersScreen()));
        break;
      case 'Purchase Orders':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseOrdersScreen()));
        break;
      case 'QC Report':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const QCReportScreen()));
        break;
      case 'Daily Production':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyProductionScreen()));
        break;
      case 'Updates':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProgressUpdateScreen()));
        break;
      default:
        if (item.route.isNotEmpty) Navigator.pushNamed(context, item.route);
    }
  }

  // Unread notifications count (very simple)
  Stream<int> _unreadCount() {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('status', isEqualTo: 'unread')
        .snapshots()
        .map((s) => s.docs.length)
        .handleError((_) => 0);
  }

  // ----------- Tabs -----------
  Widget _buildAppBarTitle() {
    final name = _niceName(email ?? 'Factory');
    switch (_currentTab) {
      case 0: return Text('Welcome back, $name', style: const TextStyle(fontWeight: FontWeight.w800));
      case 1: return const Text('Work & QC', style: TextStyle(fontWeight: FontWeight.w800));
      case 2: return const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800));
      case 3: return const Text('Profile', style: TextStyle(fontWeight: FontWeight.w800));
      default: return Text('Welcome back, $name');
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: _navRed,
      foregroundColor: _labelOnRed,
      title: _buildAppBarTitle(),
      actions: [
        // Bell with unread badge
        StreamBuilder<int>(
          stream: _unreadCount(),
          builder: (context, snap) {
            final count = snap.data ?? 0;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  tooltip: 'Notifications',
                  onPressed: () => setState(() => _currentTab = 2),
                ),
                if (count > 0)
                  Positioned(
                    right: 10, top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$count',
                          style: TextStyle(
                            color: _navRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          )),
                    ),
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
    );
  }

  Widget _buildBottomNav() {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.white24,
        highlightColor: Colors.white10,
      ),
      child: BottomNavigationBar(
        backgroundColor: _navRed,
        selectedItemColor: _labelOnRed,
        unselectedItemColor: _labelOnRed.withOpacity(.7),
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.handyman_outlined), label: 'Work/QC'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_none), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  // ----- Tab Pages -----
  Widget _tabDashboard() {
    final filtered = _allItems
        .where((i) => i.title.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    // Responsive columns
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 1100 ? 6 : width >= 900 ? 5 : width >= 600 ? 4 : 3;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        const _FactoryOverview(),
        const SizedBox(height: 16),

        // Search
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))],
          ),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'Search…',
              hintStyle: TextStyle(color: Colors.black54),
              prefixIcon: const Icon(Icons.search, color: Colors.black87),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
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
            return _DashTileRed(
              title: it.title,
              icon: it.icon,
              onTap: () => _onItemTap(it),
            );
          },
        ),
      ],
    );
  }

  Widget _tabWorkQc() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _SectionHeader(label: 'Factory Actions'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ActionChipCard(
              icon: Icons.work_outline,
              label: 'Work Orders',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkOrdersScreen())),
            ),
            _ActionChipCard(
              icon: Icons.shopping_cart_outlined,
              label: 'Purchase Orders',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseOrdersScreen())),
            ),
            _ActionChipCard(
              icon: Icons.fact_check_outlined,
              label: 'QC Report',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QCReportScreen())),
            ),
            _ActionChipCard(
              icon: Icons.factory_outlined,
              label: 'Daily Production',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyProductionScreen())),
            ),
            _ActionChipCard(
              icon: Icons.update,
              label: 'Updates',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProgressUpdateScreen())),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SectionHeader(label: 'Quick Stats'),
        const SizedBox(height: 12),
        const _FactoryOverview(compact: true),
      ],
    );
  }

  Widget _tabNotifications() {
    return const _NotificationsList();
  }

  Widget _tabProfile() {
    final name = _niceName(email ?? 'Factory');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _ProfileCard(name: name, email: email ?? ''),
        const SizedBox(height: 16),
        _SectionHeader(label: 'Shortcuts'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ActionChipCard(
              icon: Icons.event_available,
              label: 'Attendance',
              onTap: () => Navigator.pushNamed(context, '/factory/attendance'),
            ),
            _ActionChipCard(
              icon: Icons.request_page,
              label: 'Loan Requests',
              onTap: () => Navigator.pushNamed(context, '/marketing/loan_request'),
            ),
            _ActionChipCard(
              icon: Icons.attach_money,
              label: 'Salary & OT',
              onTap: () => Navigator.pushNamed(context, '/factory/salary_overtime'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _tabDashboard(),
      _tabWorkQc(),
      _tabNotifications(),
      _tabProfile(),
    ];

    return Scaffold(
      backgroundColor: _surface,
      appBar: _buildAppBar(),
      drawer: const FactoryDrawer(),
      body: pages[_currentTab],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  String _niceName(String s) {
    if (!s.contains('@')) return s;
    final core = s.split('@').first;
    return core.replaceAll('.', ' ').replaceAll('_', ' ');
  }
}

/* ========================= Overview (Factory live board) ========================= */

class _FactoryOverview extends StatelessWidget {
  final bool compact;
  const _FactoryOverview({this.compact = false});

  // --- Date windows ---
  ({DateTime a, DateTime b}) _today() {
    final n = DateTime.now();
    final a = DateTime(n.year, n.month, n.day);
    final b = DateTime(n.year, n.month, n.day, 23, 59, 59, 999);
    return (a: a, b: b);
  }

  ({DateTime a, DateTime b}) _thisMonth() {
    final n = DateTime.now();
    final a = DateTime(n.year, n.month, 1);
    final b = DateTime(n.year, n.month + 1, 0, 23, 59, 59, 999);
    return (a: a, b: b);
  }

  // --- Streams (defensive: work even if some fields are missing) ---

  /// Open Work Orders = status in {open, in_progress}
  Stream<int> _openWorkOrders() {
    return FirebaseFirestore.instance
        .collection('work_orders')
        .where('status', whereIn: ['open', 'in_progress'])
        .snapshots()
        .map((s) => s.docs.length)
        .handleError((_) => 0);
  }

  /// Purchase Orders This Month (count)
  Stream<int> _purchaseOrdersThisMonth() {
    final r = _thisMonth();
    return FirebaseFirestore.instance
        .collection('purchase_orders')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .snapshots()
        .map((s) => s.docs.length)
        .handleError((_) => 0);
  }

  /// QC Pending (count)
  Stream<int> _qcPending() {
    return FirebaseFirestore.instance
        .collection('qc_reports')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.length)
        .handleError((_) => 0);
  }

  /// Today's Output (sum of totalQty or qty) from daily_production
  Stream<num> _todaysOutput() {
    final r = _today();
    return FirebaseFirestore.instance
        .collection('daily_production')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .snapshots()
        .map((s) {
      num sum = 0;
      for (final d in s.docs) {
        final data = d.data();
        final a = data['totalQty'];
        final b = data['qty'];
        if (a is num) {
          sum += a;
        } else if (b is num) {
          sum += b;
        }
      }
      return sum;
    }).handleError((_) => 0);
  }

  String _comma(num n) {
    final s = n.toStringAsFixed(n % 1 == 0 ? 0 : 2);
    final parts = s.split('.');
    final intPart = parts.first;
    final frac = parts.length > 1 ? '.${parts[1]}' : '';
    final b = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      final r = intPart.length - i;
      b.write(intPart[i]);
      if (r > 1 && r % 3 == 1) b.write(',');
    }
    return '${b.toString()}$frac';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: _boardDark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final cardW = compact ? (w - 12) / 2 : (w - 12) / 2; // 2 columns regardless (looks neat on mobile too)
          return Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardW,
                    child: _SquareSummaryCard(
                      color: _tileA,
                      icon: Icons.assignment_turned_in_outlined,
                      label: 'Open Work Orders',
                      streamText: _openWorkOrders().map((n) => '$n'),
                    ),
                  ),
                  SizedBox(
                    width: cardW,
                    child: _SquareSummaryCard(
                      color: _tileB,
                      icon: Icons.shopping_basket_outlined,
                      label: 'POs This Month',
                      streamText: _purchaseOrdersThisMonth().map((n) => '$n'),
                    ),
                  ),
                  SizedBox(
                    width: cardW,
                    child: _SquareSummaryCard(
                      color: _tileC,
                      icon: Icons.fact_check_outlined,
                      label: 'QC Pending',
                      streamText: _qcPending().map((n) => '$n'),
                    ),
                  ),
                  SizedBox(
                    width: cardW,
                    child: _SquareSummaryCard(
                      color: _tileD,
                      icon: Icons.speed_outlined,
                      label: "Today's Output (pcs)",
                      streamText: _todaysOutput().map(_comma),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/* ========================= Reusable summary card ========================= */

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
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.black87,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.data_usage, color: Colors.white, size: 18),
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

/* ========================= Grid tile (Red) ========================= */

class _DashTileRed extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _DashTileRed({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [_cardGradA, _cardGradB],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))],
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
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

/* ========================= Notifications List ========================= */

class _NotificationsList extends StatelessWidget {
  const _NotificationsList();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surface,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('No notifications yet.',
                    style: TextStyle(fontSize: 16, color: Colors.black54)),
              ),
            );
          }
          final docs = snap.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final title = (d['title'] ?? 'Notification') as String;
              final body  = (d['body'] ?? '') as String;
              final status = (d['status'] ?? 'unread') as String;
              final ts = d['createdAt'];
              DateTime? dt;
              if (ts is Timestamp) dt = ts.toDate();

              final isUnread = status == 'unread';
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: Colors.white,
                leading: CircleAvatar(
                  backgroundColor: isUnread ? _navRed : Colors.black26,
                  child: const Icon(Icons.notifications, color: Colors.white, size: 18),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                subtitle: Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (dt != null)
                      Text(_niceTime(dt),
                          style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    const SizedBox(height: 6),
                    if (isUnread)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _navRed,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('NEW',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                onTap: () async {
                  // Mark as read (optional, safe)
                  try {
                    await FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(docs[i].id)
                        .update({'status': 'read'});
                  } catch (_) {}
                },
              );
            },
          );
        },
      ),
    );
  }

  String _niceTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
  }

  String _two(int v) => v < 10 ? '0$v' : '$v';
}

/* ========================= Tiny UI helpers ========================= */

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.dashboard_customize, color: _navRed, size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(
          color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 14,
        )),
      ],
    );
  }
}

class _ActionChipCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionChipCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x1A8B0000)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _navRed),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(
                color: Colors.black87, fontWeight: FontWeight.w700,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String email;
  const _ProfileCard({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: _navRed,
            child: const Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 16,
                )),
                const SizedBox(height: 2),
                Text(email, style: const TextStyle(
                  color: Colors.black54, fontSize: 12,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
