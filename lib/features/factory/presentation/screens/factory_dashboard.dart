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

/// ===== Palette (aligned with MarketingDashboard look & feel) =====
const Color _brandTeal  = Color(0xFF001863); // AppBar
const Color _indigoCard = Color(0xFF0B2D9F); // Tile base
const Color _surface    = Color(0xFFF4FBFB); // Page bg
const Color _boardDark  = Color(0xFF0330AE); // Overview board bg

// Summary tiles (light)
const Color _tileA = Color(0xFFFFFFFF);
const Color _tileB = Color(0xFFFFFFFF);
const Color _tileC = Color(0xFFF3F3F3);
const Color _tileD = Color(0xFFFFFFFF);

class FactoryDashboard extends StatefulWidget {
  const FactoryDashboard({Key? key}) : super(key: key);

  @override
  State<FactoryDashboard> createState() => _FactoryDashboardState();
}

class _FactoryDashboardState extends State<FactoryDashboard> {
  String? email;
  String _search = '';

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
    _DashboardItem('Salary & OT',      Icons.money_off,           '/factory/salary_overtime'),
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

  @override
  Widget build(BuildContext context) {
    final filtered = _allItems
        .where((i) => i.title.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    // Responsive column count
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 1100 ? 6 : width >= 900 ? 5 : width >= 600 ? 4 : 3;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _brandTeal,
        foregroundColor: Colors.white,
        title: Text(
          'Welcome back, ${_niceName(email ?? 'Factory')}',
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
      drawer: const FactoryDrawer(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // ===== Overview board (live summaries) =====
          const _FactoryOverview(),
          const SizedBox(height: 16),

          // ===== Search bar =====
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search…',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // ===== Grid of tiles =====
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

/* ========================= Overview (Factory live board) ========================= */

class _FactoryOverview extends StatelessWidget {
  const _FactoryOverview();

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
    // If your docs don’t have 'status', this returns 0 (safe).
    return FirebaseFirestore.instance
        .collection('work_orders')
        .where('status', whereIn: ['open', 'in_progress'])
        .snapshots()
        .map((s) => s.docs.length);
  }

  /// Purchase Orders This Month (count)
  Stream<int> _purchaseOrdersThisMonth() {
    final r = _thisMonth();
    return FirebaseFirestore.instance
        .collection('purchase_orders')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .snapshots()
        .map((s) => s.docs.length);
  }

  /// QC Pending (count)
  Stream<int> _qcPending() {
    return FirebaseFirestore.instance
        .collection('qc_reports')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.length);
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
    });
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
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final cardW = (w - 12) / 2; // 2 columns with 12 gap
          return Column(
            children: [
              // 2×2 summary tiles
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

/* ========================= Grid tile ========================= */

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

/* ========================= Model ========================= */

class _DashboardItem {
  final String title;
  final IconData icon;
  final String route;
  const _DashboardItem(this.title, this.icon, this.route);
}
