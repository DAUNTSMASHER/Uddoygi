// lib/features/factory/presentation/screens/factory_dashboard.dart
import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/factory/presentation/widgets/factory_drawer.dart';
import 'package:uddoygi/features/common/notification.dart';
import 'package:uddoygi/features/common/alert.dart';
import 'package:uddoygi/features/common/stock/stockscreen.dart';
// Direct imports for your factory sub-screens
import 'package:uddoygi/features/factory/presentation/factory/work_order.dart';
import 'package:uddoygi/features/factory/presentation/factory/purchase_order.dart';
import 'package:uddoygi/features/factory/presentation/factory/QC_report.dart';
import 'package:uddoygi/features/factory/presentation/factory/daily_production.dart';
import 'package:uddoygi/features/factory/presentation/screens/progress_update_screen.dart';

/// ===== Red theme (HR structure, just red) =====
const Color _brandRed   = Color(0xFF40062D); // deep red
const Color _redMid     = Color(0xFF500B49); // accent
const Color _surface    = Color(0xFFFFF5F5); // near-white with warm tone
const Color _cardBorder = Color(0x1A7F1D1D); // 10% red
const Color _shadowLite = Color(0x14000000);

class FactoryDashboard extends StatefulWidget {
  const FactoryDashboard({Key? key}) : super(key: key);

  @override
  State<FactoryDashboard> createState() => _FactoryDashboardState();
}

class _FactoryDashboardState extends State<FactoryDashboard> {
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
          'Factory';
      photoUrl = current?.photoURL;
    });

    // Enrich from users/{uid}
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
    if (parts.isEmpty) return 'F';
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
        .where('to', isEqualTo: mail)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  // 3-column dashboard tiles (factory-relevant)
  final List<_DashboardItem> _allItems = const [
    _DashboardItem('Stock', Icons.notification_important, ''),
    _DashboardItem('Work Orders', Icons.work, ''),           // manual push
    _DashboardItem('Purchase Orders', Icons.shopping_cart, ''),
    _DashboardItem('QC Report', Icons.check_circle, ''),
    _DashboardItem('Daily Production', Icons.factory, ''),
    _DashboardItem('Updates', Icons.update, ''),
    _DashboardItem('Notices', Icons.notifications, '/factory/notices'),
    _DashboardItem('Messages', Icons.message, '/common/messages'),
    _DashboardItem('Attendance', Icons.event_available, '/factory/attendance'),
    _DashboardItem('Loan Requests', Icons.request_page, '/marketing/loan_request'),
    _DashboardItem('Salary & OT', Icons.attach_money, '/common/salary'),
  ];

  void _onItemTap(_DashboardItem item) {
    if (item.title == 'Stock') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const StockScreen()));
      return;
    }
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
    final displayName = _niceName(name ?? 'Factory');
    final initials = _initialsFor(displayName);

    final filtered = _allItems
        .where((i) => i.title.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    const cols = 3; // match HR layout

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _brandRed,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty) ? NetworkImage(photoUrl!) : null,
              child: (photoUrl == null || photoUrl!.isEmpty)
                  ? Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Welcome, $displayName',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              )
                  .animate(key: ValueKey(displayName))
                  .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
                  .slideX(begin: 0.08, end: 0)
                  .then(delay: 120.ms)
                  .blur(begin: const Offset(2, 2), end: Offset.zero, duration: 250.ms),
            ),
          ],
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

      drawer: const FactoryDrawer(),

      bottomNavigationBar: _buildBottomNav(),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Overview/summary (red) — now with live factory KPIs
          const _FactoryOverviewHeaderRed(),
          const SizedBox(height: 16),

          // Search
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search…',
              prefixIcon: const Icon(Icons.search, color: _brandRed),
              hintStyle: const TextStyle(color: _brandRed),
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
            style: const TextStyle(color: _brandRed),
          ),
          const SizedBox(height: 16),

          // 3-column grid of tiles
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
      _NavItem('Work', Icons.work_outline_rounded,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkOrdersScreen()))),
      _NavItem('QC', Icons.fact_check_outlined,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QCReportScreen()))),
      _NavItem('Production', Icons.factory_outlined,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyProductionScreen()))),
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
        decoration: const BoxDecoration(color: _brandRed),
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

/* ========================= Overview (red header + KPI cards) ========================= */

enum _Range { thisMonth, prevMonth, last3, last12 }

class _FactoryOverviewHeaderRed extends StatefulWidget {
  const _FactoryOverviewHeaderRed({Key? key}) : super(key: key);

  @override
  State<_FactoryOverviewHeaderRed> createState() => _FactoryOverviewHeaderRedState();
}

class _FactoryOverviewHeaderRedState extends State<_FactoryOverviewHeaderRed> {
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

  // ===== Helpers =====
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

  String _formatAvg(Duration? d) {
    if (d == null || d.inSeconds <= 0) return '—';
    if (d.inDays >= 1) return '${d.inDays}d';
    if (d.inHours >= 1) return '${d.inHours}h';
    return '${d.inMinutes}m';
  }

  DateTime _todayStart() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime _eod(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

  // ===== Streams for KPIs =====

  // Attendance (today): present / active workers (%)
  Stream<int> _presentToday() {
    final user = FirebaseAuth.instance.currentUser;
    final mail = user?.email;
    final start = _todayStart();
    final end = _eod(start);
    final q = FirebaseFirestore.instance
        .collection('attendance')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end));
    final q2 = (mail != null) ? q.where('managerEmail', isEqualTo: mail) : q;
    // Accept common "present" flags; if your schema differs, adjust here.
    return q2.snapshots().map((s) {
      int count = 0;
      for (final d in s.docs) {
        final m = d.data() as Map<String, dynamic>;
        final st = (m['status'] ?? '').toString().toLowerCase();
        final present = st == 'present' || st == 'p' || st == 'in';
        if (present) count++;
      }
      return count;
    });
  }

  Stream<int> _activeWorkers() {
    final user = FirebaseAuth.instance.currentUser;
    final mail = user?.email;
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'worker')
        .where('active', isEqualTo: true);
    if (mail != null) q = q.where('managerEmail', isEqualTo: mail);
    return q.snapshots().map((s) => s.docs.length);
  }

  // Completed work orders (completed==true OR terminal stage)
  Stream<int> _completedOrders() {
    return FirebaseFirestore.instance
        .collection('work_orders')
        .snapshots()
        .map((s) => s.docs.where((d) {
      final m = d.data();
      final bool completed = (m['completed'] == true);
      final String stage = (m['currentStage'] ?? '') as String;
      return completed || stage == 'Submit to the Head office';
    }).length);
  }

  // Running work orders (status==Accepted and not completed & not terminal)
  Stream<int> _runningOrders() {
    return FirebaseFirestore.instance
        .collection('work_orders')
        .where('status', isEqualTo: 'Accepted')
        .snapshots()
        .map((s) => s.docs.where((d) {
      final m = d.data();
      final bool completed = (m['completed'] == true);
      final String stage = (m['currentStage'] ?? '') as String;
      return !completed && stage != 'Submit to the Head office';
    }).length);
  }

  Stream<String> _outputThisMonth() {
    final user = FirebaseAuth.instance.currentUser;
    final mail = user?.email;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('daily_production')
        .where('productionDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('productionDate', isLessThanOrEqualTo: Timestamp.fromDate(end));
    if (mail != null) q = q.where('managerEmail', isEqualTo: mail);

    return q.snapshots().map((s) {
      int sum = 0;
      for (final d in s.docs) {
        final m = d.data();
        final v = m['quantity'];
        if (v is int) sum += v;
        else if (v is num) sum += v.toInt();
        else if (m['totalQty'] is num) sum += (m['totalQty'] as num).toInt();
        else if (m['qty'] is num) sum += (m['qty'] as num).toInt();
      }
      return _comma(sum);
    });
  }

  Stream<String> _outputToday() {
    final user = FirebaseAuth.instance.currentUser;
    final mail = user?.email;
    final start = _todayStart();
    final end = _eod(start);

    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('daily_production')
        .where('productionDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('productionDate', isLessThanOrEqualTo: Timestamp.fromDate(end));

    // match DailyProductionScreen: scope to the manager
    if (mail != null) {
      q = q.where('managerEmail', isEqualTo: mail);
    }

    // sum `quantity` (fallbacks included just in case)
    return q.snapshots().map((snap) {
      int sum = 0;
      for (final d in snap.docs) {
        final m = d.data();
        final v = m['quantity'];
        if (v is int) {
          sum += v;
        } else if (v is num) {
          sum += v.toInt();
        } else if (m['totalQty'] is num) {
          sum += (m['totalQty'] as num).toInt();
        } else if (m['qty'] is num) {
          sum += (m['qty'] as num).toInt();
        }
      }
      return _comma(sum);
    });
  }


  // Due loan amount (sum of dues)
  Stream<String> _dueLoanAmount() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('loan_requests');
    // If your schema has status 'paid'/'closed', exclude those:
    // q = q.where('status', whereIn: ['approved','disbursed','due']);
    return q.snapshots().map((s) {
      num totalDue = 0;
      for (final d in s.docs) {
        final m = d.data();
        if (m['dueAmount'] is num) {
          totalDue += (m['dueAmount'] as num);
        } else {
          final num amount = (m['approvedAmount'] ?? m['amount'] ?? 0) is num
              ? (m['approvedAmount'] ?? m['amount']) as num
              : 0;
          final num paid = (m['repaidAmount'] ?? m['paid'] ?? 0) is num
              ? (m['repaidAmount'] ?? m['paid']) as num
              : 0;
          final due = amount - paid;
          if (due > 0) totalDue += due;
        }
      }
      return '৳${_comma(totalDue)}';
    });
  }

  // Average time to complete an order
  Stream<String> _avgCompletionTime() {
    return FirebaseFirestore.instance.collection('work_orders').snapshots().map((s) {
      int count = 0;
      int totalMs = 0;
      for (final d in s.docs) {
        final m = d.data();
        final bool done = (m['completed'] == true) ||
            ((m['currentStage'] ?? '') == 'Submit to the Head office');
        if (!done) continue;

        DateTime? start;
        if (m['createdAt'] is Timestamp) start = (m['createdAt'] as Timestamp).toDate();
        else if (m['timestamp'] is Timestamp) start = (m['timestamp'] as Timestamp).toDate();
        else if (m['orderDate'] is Timestamp) start = (m['orderDate'] as Timestamp).toDate();

        final DateTime? end = (m['completedAt'] is Timestamp)
            ? (m['completedAt'] as Timestamp).toDate()
            : null;

        if (start == null || end == null) continue;
        final ms = end.millisecondsSinceEpoch - start.millisecondsSinceEpoch;
        if (ms > 0) {
          totalMs += ms;
          count++;
        }
      }
      final dur = (count == 0) ? null : Duration(milliseconds: (totalMs / count).round());
      return _formatAvg(dur);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_brandRed, _redMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: _shadowLite, blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Range filter
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

          // 3×2 grid of KPI cards (compact)
          LayoutBuilder(builder: (ctx, c) {
            const spacing = 6.0;
            final w = c.maxWidth;
            final cardW = (w - (spacing * 2)) / 3; // three columns
            final rng = _rangeDates(_range);
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                // Attendance %
                _StatCardPercent(
                  width: cardW,
                  label: 'Attendance (today)',
                  numerator: _presentToday(),
                  denominator: _activeWorkers(),
                ),
                // Completed WOs
                _StatCardRed(width: cardW, label: 'Completed orders', streamText: _completedOrders().map((v) => '$v')),
                // Running WOs
                _StatCardRed(width: cardW, label: 'Running orders', streamText: _runningOrders().map((v) => '$v')),
                // Production today
                _StatCardRed(width: cardW, label: "This month's production", streamText: _outputThisMonth()),
                // Due loans
                _StatCardRed(width: cardW, label: 'Due loan amount', streamText: _dueLoanAmount()),
                // Avg completion time (range control doesn’t affect this; it’s global)
                _StatCardRed(width: cardW, label: 'Avg. complete time', streamText: _avgCompletionTime()),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/* ---------- Filter dropdown (red) ---------- */

class _RangeFilter extends StatelessWidget {
  final _Range value;
  final ValueChanged<_Range> onChanged;
  const _RangeFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(

    );
  }
}

/* ========================= Stat cards ========================= */

class _StatCardRed extends StatelessWidget {
  final double width;
  final String label;
  final Stream<String> streamText;
  const _StatCardRed({required this.width, required this.label, required this.streamText, Key? key})
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
            decoration: BoxDecoration(color: _brandRed.withOpacity(.08), shape: BoxShape.circle),
            child: const Icon(Icons.assessment, color: _brandRed, size: 18),
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
                    // VALUE (unchanged, readable)
                    AutoSizeText(
                      v,
                      maxLines: 1,
                      minFontSize: 14,
                      stepGranularity: 0.5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _brandRed,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // LABEL — exactly 5sp and up to 2 lines
                    SizedBox(
                      height: 18, // enough to fit ~2 lines at 5sp
                      child: AutoSizeText(
                        label,
                        maxLines: 2,
                        minFontSize: 5,
                        maxFontSize: 7,      // lock to 5sp
                        stepGranularity: 0.1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _brandRed,
                          fontWeight: FontWeight.w500,
                          fontSize: 7,        // lock to 5sp
                          height: 1.05,
                        ),
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


// Attendance percent card: two streams (present / active)
class _StatCardPercent extends StatelessWidget {
  final double width;
  final String label;
  final Stream<int> numerator;   // present today
  final Stream<int> denominator; // active workers
  const _StatCardPercent({
    required this.width,
    required this.label,
    required this.numerator,
    required this.denominator,
    Key? key,
  }) : super(key: key);

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
            decoration: BoxDecoration(color: _brandRed.withOpacity(.08), shape: BoxShape.circle),
            child: const Icon(Icons.how_to_reg, color: _brandRed, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StreamBuilder<int>(
              stream: denominator,
              builder: (_, totalSnap) {
                final total = totalSnap.data ?? 0;
                return StreamBuilder<int>(
                  stream: numerator,
                  builder: (_, presSnap) {
                    final pres = presSnap.data ?? 0;
                    final String txt =
                    (total <= 0) ? '—' : '${(pres * 100 / total).toStringAsFixed(0)}%';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AutoSizeText(
                          txt,
                          maxLines: 1,
                          minFontSize: 14,
                          stepGranularity: 0.5,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _brandRed,
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AutoSizeText(
                          label,
                          maxLines: 2,
                          minFontSize: 6,
                          stepGranularity: 0.5,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _brandRed,
                            fontWeight: FontWeight.w400,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    );
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

/* ========================= Tiles & bottom nav helpers (red) ========================= */

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
                      Icon(icon, color: _brandRed, size: 28),
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
                            color: _brandRed,
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
        color: _brandRed,
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
