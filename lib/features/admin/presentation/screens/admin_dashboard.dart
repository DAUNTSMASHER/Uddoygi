// lib/features/marketing/presentation/screens/admin_dashboard.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uddoygi/services/local_storage_service.dart';
import '../widgets/admin_drawer.dart';
import '../widgets/admin_dashboard_summary.dart';
import 'package:uddoygi/features/common/notification.dart';

const Color _darkBlue = Color(0xFF3C0765);

// Base sizes (these get scaled with .sp(context))
const double _fontSmall = 13.0;
const double _fontMed   = 16.0;
const double _fontLarge = 18.0;
const double _fontXL    = 20.0;

/* -------------------- Responsive font helper -------------------- */
extension ResponsiveFont on num {
  /// Screen-aware font size with user text scale respected.
  /// Designed around ~390px width devices.
  double sp(BuildContext context, {double min = 10, double max = 28}) {
    final w = MediaQuery.sizeOf(context).width;
    final screenFactor = (w / 390).clamp(0.85, 1.20);
    final userFactor   = MediaQuery.textScaleFactorOf(context).clamp(0.8, 1.4);
    final v = this * screenFactor * userFactor;
    return v.clamp(min, max).toDouble();
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _DashboardItem {
  final String keyId; // used for lastSeen storage
  final String title;
  final IconData icon;
  final String route;
  final List<Query<Map<String, dynamic>>> queries; // sources to count
  const _DashboardItem({
    required this.keyId,
    required this.title,
    required this.icon,
    required this.route,
    required this.queries,
  });
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool showSummary = true;
  bool isLoading   = false;

  String? uid;
  String? name;
  String? photoUrl;

  int _currentTab = 0;

  // Dashboard items + their "new" sources (by createdAt)
  late final List<_DashboardItem> dashboardItems = [
    _DashboardItem(
      keyId: 'notices',
      title: 'Notices',
      icon: Icons.announcement,
      route: '/admin/notices',
      queries: [FirebaseFirestore.instance.collection('notices')],
    ),
    _DashboardItem(
      keyId: 'employees',
      title: 'Employees',
      icon: Icons.people,
      route: '/admin/employees',
      queries: [FirebaseFirestore.instance.collection('users')],
    ),
    _DashboardItem(
      keyId: 'reports',
      title: 'Reports',
      icon: Icons.bar_chart,
      route: '/admin/reports',
      queries: [
        FirebaseFirestore.instance.collection('invoices'),
        FirebaseFirestore.instance.collection('expenses'),
      ],
    ),
    _DashboardItem(
      keyId: 'welfare',
      title: 'Welfare',
      icon: Icons.favorite,
      route: '/common/welfare',
      queries: [FirebaseFirestore.instance.collection('welfare')],
    ),
    _DashboardItem(
      keyId: 'complaints',
      title: 'Complaints',
      icon: Icons.report_problem,
      route: '/common/complaints',
      queries: [FirebaseFirestore.instance.collection('complaints')],
    ),
    _DashboardItem(
      keyId: 'salary',
      title: 'Salary',
      icon: Icons.attach_money,
      route: '/admin/salary',
      queries: [FirebaseFirestore.instance.collection('salaries')],
    ),
    _DashboardItem(
      keyId: 'messages',
      title: 'MSG',
      icon: Icons.message,
      route: '/common/messages',
      queries: [FirebaseFirestore.instance.collection('messages')],
    ),
    _DashboardItem(
      keyId: 'rnd',
      title: 'R&D',
      icon: Icons.science,
      route: '/admin/research',
      queries: [FirebaseFirestore.instance.collection('rnd_updates')],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSessionAndUser();
  }

  Future<void> _loadSessionAndUser() async {
    final session = await LocalStorageService.getSession();
    final current = FirebaseAuth.instance.currentUser;
    setState(() {
      uid = session?['uid'] as String? ?? current?.uid;
      name = session?['name'] as String? ?? current?.displayName ?? current?.email ?? 'Admin';
      photoUrl = current?.photoURL;
    });

    if (uid != null) {
      try {
        final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (snap.exists) {
          final data = snap.data()!;
          setState(() {
            final n = (data['fullName'] as String?)?.trim();
            if (n != null && n.isNotEmpty) name = n;
            final p = (data['profilePhotoUrl'] as String?)?.trim();
            if (p != null && p.isNotEmpty) photoUrl = p;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _refreshSummary() async {
    setState(() => isLoading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    setState(() => isLoading = false);
  }

  Future<void> _openSectionAndClearBadge(_DashboardItem item) async {
    await _markSectionSeen(item.keyId);
    if (!mounted) return;
    setState(() {});
    await Navigator.pushNamed(context, item.route);
    if (!mounted) return;
    setState(() {});
  }

  // ---------- Unread badges like factory dashboard ----------
  Stream<int> _unreadMessagesStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);
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
    if (user == null) return Stream.value(0);
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
    final displayName = (name ?? 'Admin').trim();
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
              backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                  ? NetworkImage(photoUrl!)
                  : null,
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
          // Notification like factory dashboard
          StreamBuilder<int>(
            stream: _unreadNotificationsStream(),
            builder: (_, s) => Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  tooltip: 'Notifications',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationPage()),
                  ),
                ),
                if ((s.data ?? 0) > 0)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: _Badge(count: s.data ?? 0, small: true),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white, size: 20.sp(context, min: 18, max: 24)),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              await LocalStorageService.clearSession();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      drawer: const AdminDrawer(),

      // Bottom navigation like factory dashboard
      bottomNavigationBar: _buildBottomNav(),

      body: RefreshIndicator(
        color: _darkBlue,
        onRefresh: _refreshSummary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Summary section
            _sectionHeader('Summary', showSummary, () {
              setState(() => showSummary = !showSummary);
            }),
            AnimatedCrossFade(
              firstChild: isLoading
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: CircularProgressIndicator(color: _darkBlue),
                ),
              )
                  : const AdminDashboardSummary(),
              secondChild: const SizedBox.shrink(),
              crossFadeState: showSummary ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 250),
            ),
            const SizedBox(height: 28),

            // Quick Actions
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
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dashboardItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.3,
                ),
                itemBuilder: (ctx, i) {
                  final item = dashboardItems[i];
                  return _BadgeActionCard(
                    item: item,
                    onTap: () => _openSectionAndClearBadge(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* -------------------- Bottom Nav -------------------- */
  Widget _buildBottomNav() {
    final items = <_NavItem>[
      _NavItem('Home', Icons.home_rounded, onTap: () => setState(() => _currentTab = 0)),
      _NavItem('Employees', Icons.people_outline,
          onTap: () => Navigator.pushNamed(context, '/admin/employees')),
      _NavItem('Reports', Icons.fact_check_outlined,
          onTap: () => Navigator.pushNamed(context, '/admin/reports')),
      _NavItem('Welfare', Icons.volunteer_activism_outlined,
          onTap: () => Navigator.pushNamed(context, '/common/welfare')),
      _NavItem(
        'Notifications',
        Icons.notifications,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPage())),
        badgeStream: _unreadNotificationsStream(),
      ),
      _NavItem('Messages', Icons.message_rounded,
          onTap: () => Navigator.pushNamed(context, '/common/messages'),
          badgeStream: _unreadMessagesStream()),
    ];

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(color: _darkBlue),
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
                      Text(
                        it.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
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

  Widget _sectionHeader(String title, bool expanded, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: _fontLarge.sp(context, min: 16, max: 26),
                fontWeight: FontWeight.w900,
                color: _darkBlue,
              ),
            ),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: _darkBlue,
              size: 20.sp(context, min: 18, max: 26),
            ),
          ],
        ),
      ),
    );
  }

  String _initialsFor(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'A';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  // ---------- lastSeen helpers (per section) ----------
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

  Future<void> _markSectionSeen(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSeen_$key', DateTime.now().millisecondsSinceEpoch);
  }
}

/* ===================== BADGED ACTION CARD (unchanged) ===================== */

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
    _attachListeners();
  }

  @override
  void didUpdateWidget(covariant _BadgeActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _detachListeners();
    _attachListeners();
  }

  @override
  void dispose() {
    _detachListeners();
    super.dispose();
  }

  Future<void> _attachListeners() async {
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

  void _detachListeners() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _darkBlue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.item.icon,
                            color: _darkBlue,
                            size: 22.sp(context, min: 18, max: 26),
                          ),
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
}

/* ===================== Bottom nav helpers ===================== */

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
