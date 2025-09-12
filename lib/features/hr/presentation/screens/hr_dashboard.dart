// lib/features/hr/presentation/screens/hr_dashboard.dart
import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/hr/presentation/widgets/hr_drawer.dart';
import 'package:uddoygi/features/common/notification.dart';
import 'package:uddoygi/features/common/alert.dart'; // <-- adjust if your path differs

/// ===== Green theme (matches your request) =====
const Color _brandGreen  = Color(0xFF065F46); // deep green
const Color _greenMid    = Color(0xFF10B981); // accent
const Color _surface     = Color(0xFFF1F8F4); // near-white surface
const Color _cardBorder  = Color(0x1A065F46); // 10% green
const Color _shadowLite  = Color(0x14000000);

class HRDashboard extends StatefulWidget {
  const HRDashboard({Key? key}) : super(key: key);

  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard> {
  String? email;
  String? uid;
  String? name;
  String? photoUrl;

  String _search = '';
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    final current = FirebaseAuth.instance.currentUser;

    setState(() {
      email = session?['email'] as String? ?? current?.email;
      uid = session?['uid'] as String? ?? current?.uid;
      name = (session?['name'] as String?) ??
          current?.displayName ??
          current?.email ??
          'HR';
      photoUrl = current?.photoURL;
    });

    // Try to enrich name/photo from users/{uid}
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

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await LocalStorageService.clearSession();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  String _niceName(String s) {
    if (!s.contains('@')) return s;
    final core = s.split('@').first;
    return core.replaceAll('.', ' ').replaceAll('_', ' ');
  }

  String _initialsFor(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'H';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
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

  /// Unread notifications badge stream
  Stream<int> _unreadNotificationsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream<int>.value(0);
    final mail = user.email ?? '';
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('to', isEqualTo: mail)          // adjust to your schema if needed
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  // All dashboard tiles (3-column grid)
  final List<_DashboardItem> _allItems = const [
    _DashboardItem('Alerts', Icons.notification_important, '/common/alert'), // manual route (explicit push below)
    _DashboardItem('Directory', Icons.people, '/hr/employee_directory'),
    _DashboardItem('Attendance', Icons.event_available, '/hr/attendance'),
    _DashboardItem('Leave', Icons.beach_access, '/hr/leave_management'),
    _DashboardItem('Payroll', Icons.attach_money, '/hr/payroll_processing'),
    _DashboardItem('Payslips', Icons.receipt_long, '/hr/payslip'),
    _DashboardItem('Loans', Icons.account_balance, '/hr/loan_approval'),
    _DashboardItem('Credits', Icons.trending_up, '/hr/credits'),
    _DashboardItem('Expenses', Icons.payments, '/hr/expenses'),
    _DashboardItem('Balance', Icons.account_balance_wallet, '/hr/balance_update'),
    _DashboardItem('Notices', Icons.notifications, '/hr/notices'),
    _DashboardItem('Messages', Icons.message, '/common/messages'),
    _DashboardItem('Complaints', Icons.support_agent, '/common/complaints'),
    _DashboardItem('Procurement', Icons.shopping_cart, '/hr/procurement'),
  ];

  void _onItemTap(_DashboardItem item) {
    // Dedicated handling for Alerts (explicit screen import)
    if (item.title == 'Alerts') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertPage()));
      return;
    }
    // Notifications is not a tile here (it's in bottom nav). Others use named routes:
    Navigator.pushNamed(context, item.route);
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _niceName(name ?? 'HR');
    final initials = _initialsFor(displayName);

    final filtered = _allItems
        .where((i) => i.title.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    // Exactly 3 columns (as requested). You can make it responsive if you like.
    const cols = 3;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty) ? NetworkImage(photoUrl!) : null,
              child: (photoUrl == null || photoUrl!.isEmpty)
                  ? Text(
                initials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Welcome, $displayName',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          // Notifications button (top right)
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

      drawer: const HRDrawer(),

      bottomNavigationBar: _buildBottomNav(),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Overview/summary (green)
          const _HROverviewHeader(),
          const SizedBox(height: 16),

          // Search
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search…',
              prefixIcon: const Icon(Icons.search, color: _brandGreen),
              hintStyle: const TextStyle(color: _brandGreen),
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
            style: const TextStyle(color: _brandGreen),
          ),
          const SizedBox(height: 16),

          // 3-column grid of tiles — white cards, green icons/text; labels auto-fit
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
      _NavItem('Directory', Icons.people_alt_rounded,
          onTap: () => Navigator.pushNamed(context, '/hr/employee_directory')),
      _NavItem('Attendance', Icons.event_available_rounded,
          onTap: () => Navigator.pushNamed(context, '/hr/attendance')),
      _NavItem('Payroll', Icons.attach_money_rounded,
          onTap: () => Navigator.pushNamed(context, '/hr/payroll_processing')),
      // Notifications with unread badge
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
        decoration: const BoxDecoration(color: _brandGreen),
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
}

/* ========================= Overview (green header + 3-col stat cards) ========================= */

enum _Range { thisMonth, prevMonth, last3, last12 }

class _HROverviewHeader extends StatefulWidget {
  const _HROverviewHeader({Key? key}) : super(key: key);

  @override
  State<_HROverviewHeader> createState() => _HROverviewHeaderState();
}

class _HROverviewHeaderState extends State<_HROverviewHeader> {
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

  // Streams for stats (adjust to your schema as needed)
  // Employees in directory
  Stream<String> _employees() {
    return FirebaseFirestore.instance.collection('users').snapshots().map((s) => '${s.docs.length}');
  }

  // Pending leaves
  Stream<String> _pendingLeaves() {
    final r = _rangeDates(_range);
    return FirebaseFirestore.instance
        .collection('leaves')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => '${s.docs.length}');
  }

  // Complaints pending
  Stream<String> _pendingComplaints() {
    return FirebaseFirestore.instance
        .collection('complaints')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => '${s.docs.length}');
  }

  // Expenses (sum) within range
  Stream<String> _expensesTotal() {
    final r = _rangeDates(_range);
    return FirebaseFirestore.instance
        .collection('expenses')
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .snapshots()
        .map((s) {
      num sum = 0;
      for (final d in s.docs) {
        final v = d.data()['amount'];
        if (v is num) sum += v;
        if (v is String) sum += num.tryParse(v.replaceAll(',', '')) ?? 0;
      }
      return _money(sum);
    });
  }

  // Credits (sum) within range
  Stream<String> _creditsTotal() {
    final r = _rangeDates(_range);
    return FirebaseFirestore.instance
        .collection('ledger')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(r.a))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(r.b))
        .where('credit', isGreaterThan: 0)
        .snapshots()
        .map((s) {
      num sum = 0;
      for (final d in s.docs) {
        final v = d.data()['credit'];
        if (v is num) sum += v;
        if (v is String) sum += num.tryParse(v.replaceAll(',', '')) ?? 0;
      }
      return _money(sum);
    });
  }

  // Pending procurement requests
  Stream<String> _pendingProcurement() {
    return FirebaseFirestore.instance
        .collection('procurement_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => '${s.docs.length}');
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
          colors: [_brandGreen, _greenMid],
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

          // 3×N grid of stat cards
          LayoutBuilder(builder: (ctx, c) {
            const spacing = 10.0;
            final w = c.maxWidth;
            final cardW = (w - (spacing * 2)) / 3; // three columns
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _StatCard(width: cardW, label: 'Employees',          streamText: _employees()),
                _StatCard(width: cardW, label: 'Pending leaves',     streamText: _pendingLeaves()),
                _StatCard(width: cardW, label: 'Complaints pending', streamText: _pendingComplaints()),
                _StatCard(width: cardW, label: 'Expenses (range)',   streamText: _expensesTotal()),
                _StatCard(width: cardW, label: 'Credits (range)',    streamText: _creditsTotal()),
                _StatCard(width: cardW, label: 'Procurement pending',streamText: _pendingProcurement()),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/* ---------- Filter dropdown ---------- */

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
          icon: const Icon(Icons.keyboard_arrow_down, color: _brandGreen),
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: _brandGreen,
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

/* ========================= Stat card (green) ========================= */

class _StatCard extends StatelessWidget {
  final double width;
  final String label;
  final Stream<String> streamText;
  const _StatCard({required this.width, required this.label, required this.streamText, Key? key})
      : super(key: key);

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
            decoration: BoxDecoration(color: _brandGreen.withOpacity(.08), shape: BoxShape.circle),
            child: const Icon(Icons.assessment, color: _brandGreen, size: 18),
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
                    AutoSizeText(
                      v,
                      maxLines: 1,
                      minFontSize: 14,
                      stepGranularity: 0.5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _brandGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AutoSizeText(
                      label,
                      maxLines: 2,
                      minFontSize: 9,
                      stepGranularity: 0.5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _brandGreen,
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

/* ========================= Tiles & bottom nav helpers ========================= */

class _DashboardItem {
  final String title;
  final IconData icon;
  final String route;
  const _DashboardItem(this.title, this.icon, this.route);
}

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
                      Icon(icon, color: _brandGreen, size: 28),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 28,
                        child: AutoSizeText(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          minFontSize: 9,
                          stepGranularity: 0.5,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _brandGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
        color: _brandGreen,
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

/* ======================= Realtime summary carousel (optional, green) ======================= */

class _RealtimeSummaryCarousel extends StatelessWidget {
  const _RealtimeSummaryCarousel();

  // For future: replace with any HR-specific quick stats you want to rotate through.
  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _LiveStatTile(
        title: 'Welcome to HR',
        icon: Icons.eco,
        gradient: const [Color(0xFF166534), Color(0xFF22C55E)],
        value: 'Stay productive 🌿',
      ),
      _LiveStatTile(
        title: 'Tip',
        icon: Icons.lightbulb,
        gradient: const [Color(0xFF065F46), Color(0xFF10B981)],
        value: 'Use Alerts for urgent items.',
      ),
    ].map((w) => SizedBox(height: 92, child: w)).toList();

    final double bottomSafe = MediaQuery.of(context).padding.bottom;
    final double extra = bottomSafe > 0 ? bottomSafe : 16.0;
    final double h = 92 + extra;

    return SizedBox(
      height: h,
      child: CarouselSlider(
        items: items.map((p) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: p)).toList(),
        options: CarouselOptions(
          height: h,
          autoPlay: true,
          viewportFraction: 1.0,
          enlargeCenterPage: false,
          autoPlayInterval: const Duration(seconds: 5),
        ),
      ),
    );
  }
}

class _LiveStatTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final String value;
  const _LiveStatTile({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.value,
  });

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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AutoSizeText(
                  value,
                  maxLines: 1,
                  minFontSize: 12,
                  stepGranularity: 0.5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                AutoSizeText(
                  title,
                  maxLines: 2,
                  minFontSize: 9,
                  stepGranularity: 0.5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
