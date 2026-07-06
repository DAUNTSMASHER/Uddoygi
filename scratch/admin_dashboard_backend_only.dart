import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import '../widgets/admin_drawer.dart';
import 'package:uddoygi/features/common/notification.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/core/design_system.dart';
import 'package:uddoygi/widgets/u_card.dart';
import 'package:uddoygi/widgets/u_ai_assistant.dart';

const Color _heroPurple    = Color(0xFF1E0040);
const Color _heroPurpleMid = Color(0xFF4C1D95);
const Color _accentViolet  = Color(0xFF7C3AED);

const LinearGradient _topBarGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_heroPurple, _heroPurpleMid, _accentViolet],
);

const Color _brandPurple  = Color(0xFF2A0A4B);
const Color _textOnDark   = Color(0xFFFFFFFF);
const Color _textPrimary  = Color(0xFF111827);
const Color _textMuted    = Color(0xFF6B7280);
const Color _cardBorder   = Color(0xFFE5E7EB);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _DashboardItem {
  final String keyId;
  final String title;
  final IconData icon;
  final String route;
  final List<Query<Map<String, dynamic>>> queries;
  const _DashboardItem({
    required this.keyId,
    required this.title,
    required this.icon,
    required this.route,
    required this.queries,
  });
}

class _AdminDashboardState extends State<AdminDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _cid = '';
  String? name;
  String? photoUrl;
  int _currentTab = 0;
  bool _showMetrics = true;

  Stream<int> _notifStream = const Stream<int>.empty();
  Stream<int> _msgStream   = const Stream<int>.empty();

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
        _notifStream = _buildNotifStream();
        _msgStream   = _buildMsgStream();
      }
    });
    _loadUser();
  }

  Future<void> _loadUser() async {
    final session = await LocalStorageService.getSession();
    final current = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    setState(() {
      name     = session?['name'] as String? ?? current?.displayName ?? 'Admin';
    });
  }

  Stream<int> _buildNotifStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _cid.isEmpty) return Stream.value(0);
    return DB.colSync(_cid, C.notifications)
        .where('to', isEqualTo: user.email ?? '')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> _buildMsgStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _cid.isEmpty) return Stream.value(0);
    return DB.colSync(_cid, C.messages)
        .where('to', isEqualTo: user.email ?? '')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AdminDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _cid.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(UddoygiDesign.space20),
                      children: [
                        _AdminModeToggle(
                          value: _showMetrics,
                          onChanged: (v) => setState(() => _showMetrics = v),
                        ),
                        if (_showMetrics) ...[
                          const SizedBox(height: 24),
                          _AdminOverviewCard(cid: _cid),
                          const SizedBox(height: 24),
                        ],
                        _buildCategorizedGrids(),
                        const SizedBox(height: 80),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const UAiAssistant(),
        ),
        backgroundColor: _heroPurple,
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(gradient: _topBarGradient),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin Dashboard', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(_cid, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorizedGrids() {
    final items = [
      _DashboardItem(keyId: 'employees', title: 'Employees', icon: Icons.people, route: '/admin/employees', queries: []),
      _DashboardItem(keyId: 'orders', title: 'Orders', icon: Icons.precision_manufacturing, route: '/admin/orders/analysis', queries: []),
      _DashboardItem(keyId: 'inventory', title: 'Inventory', icon: Icons.inventory_2, route: '/admin/products/inventory', queries: []),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.5),
      itemCount: items.length,
      itemBuilder: (context, i) => _buildModuleCard(items[i]),
    );
  }

  Widget _buildModuleCard(_DashboardItem item) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, item.route, arguments: _cid),
      child: UCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: _heroPurpleMid, size: 32),
            const SizedBox(height: 8),
            Text(item.title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(icon: const Icon(Icons.home), onPressed: () {}),
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
    );
  }
}

class _AdminModeToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _AdminModeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Show Metrics', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
        Switch(value: value, onChanged: onChanged, activeColor: _heroPurple),
      ],
    );
  }
}

class _AdminOverviewCard extends StatefulWidget {
  final String cid;
  const _AdminOverviewCard({required this.cid});

  @override
  State<_AdminOverviewCard> createState() => _AdminOverviewCardState();
}

class _AdminOverviewCardState extends State<_AdminOverviewCard> {
  String _filter = 'this_month';

  Query<Map<String, dynamic>> _revenueQuery(String cid) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    return DB.colSync(cid, C.invoices).where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
  }

  Query<Map<String, dynamic>> _expensesQuery(String cid) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    return DB.colSync(cid, C.accountsReceivable).where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start));
  }

  Stream<String> _revenue(String cid) {
    return _revenueQuery(cid).snapshots().map((s) {
      num sum = 0;
      for (final d in s.docs) {
        final data = d.data();
        if ((data['status'] ?? '').toString().toLowerCase() != 'voided') {
          sum += (data['grandTotal'] ?? 0);
        }
      }
      return _fmt(sum);
    });
  }

  Stream<String> _expenses(String cid) {
    return _expensesQuery(cid).snapshots().map((s) {
      num sum = 0;
      for (final d in s.docs) {
        final data = d.data();
        if ((data['status'] ?? '').toString().toLowerCase() != 'voided') {
          sum += (data['amount'] ?? 0);
        }
      }
      return _fmt(sum);
    });
  }

  Stream<String> _profit(String cid) {
    return _revenueQuery(cid).snapshots().asyncMap((revSnap) async {
      num revSum = 0;
      for (final d in revSnap.docs) {
        if ((d.data()['status'] ?? '').toString().toLowerCase() != 'voided') {
          revSum += (d.data()['grandTotal'] ?? 0);
        }
      }
      final expSnap = await _expensesQuery(cid).get();
      num expSum = 0;
      for (final d in expSnap.docs) {
        if ((d.data()['status'] ?? '').toString().toLowerCase() != 'voided') {
          expSum += (d.data()['amount'] ?? 0);
        }
      }
      return _fmt(revSum - expSum);
    });
  }

  static String _fmt(num n) {
    if (n >= 100000) return '৳${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '৳${(n / 1000).toStringAsFixed(1)}K';
    return '৳${n.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return UCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Financial Health', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              Icon(Icons.analytics, color: _textMuted, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatRow('Revenue', _revenue(widget.cid), Icons.trending_up, Colors.green),
          const Divider(),
          _buildStatRow('Expenses', _expenses(widget.cid), Icons.trending_down, Colors.red),
          const Divider(),
          _buildStatRow('Net Profit', _profit(widget.cid), Icons.account_balance_wallet, _heroPurpleMid),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, Stream<String> stream, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.outfit(color: _textMuted)),
          const Spacer(),
          StreamBuilder<String>(
            stream: stream,
            builder: (context, snap) => Text(snap.data ?? '...', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          ),
        ],
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;
  const _BadgeIcon({required this.icon, required this.color, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(icon: Icon(icon, color: color), onPressed: onTap),
        if (count > 0)
          Positioned(right: 8, top: 8, child: CircleAvatar(radius: 8, backgroundColor: Colors.red, child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 8)))),
      ],
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Stream<int>? badge;
  _NavItem(this.label, this.icon, this.onTap, {this.badge});
}
