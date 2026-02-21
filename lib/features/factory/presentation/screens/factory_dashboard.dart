// lib/features/factory/presentation/screens/factory_dashboard.dart
import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/factory/presentation/widgets/factory_drawer.dart';
import 'package:uddoygi/features/common/notification.dart';
import 'package:uddoygi/features/common/stock/stockscreen.dart';
// Direct imports for your factory sub-screens
import 'package:uddoygi/features/factory/presentation/factory/work_order.dart';
import 'package:uddoygi/features/factory/presentation/factory/purchase_order.dart';
import 'package:uddoygi/features/factory/presentation/factory/QC_report.dart';
import 'package:uddoygi/features/factory/presentation/factory/daily_production.dart';
import 'package:uddoygi/features/factory/presentation/screens/progress_update_screen.dart';

/// ===== Red theme (HR structure, just red) =====
const Color _brandRed = Color(0xFF40062D);
const Color _redMid   = Color(0xFF500B49);

class FactoryDashboard extends StatefulWidget {
  const FactoryDashboard({Key? key}) : super(key: key);

  @override
  State<FactoryDashboard> createState() => _FactoryDashboardState();
}

class _FactoryDashboardState extends State<FactoryDashboard> {
  String _cid = '';
  String? email;
  String? uid;
  String? name;
  String? photoUrl;

  String _search = '';
  int _currentTab = 0;

  Stream<int> _notifStream = Stream.value(0);
  Stream<int> _msgStream   = Stream.value(0);

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
        _notifStream = _unreadNotificationsStream();
        _msgStream   = _unreadMessagesStream();
      }
    });
    await _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    final current = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    setState(() {
      email    = session?['email'] as String? ?? current?.email;
      uid      = session?['uid']   as String? ?? current?.uid;
      name     = (session?['name'] as String?) ?? current?.displayName ?? current?.email ?? 'Factory';
      photoUrl = current?.photoURL;
    });

    if (uid != null && _cid.isNotEmpty) {
      try {
        final s = await DB.colSync(_cid, C.users).doc(uid).get();
        if (s.exists && mounted) {
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
    await LocalStorageService.performLogout();
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
    if (user == null || _cid.isEmpty) return Stream<int>.value(0);
    final mail = user.email ?? '';
    return DB.colSync(_cid, C.messages)
        .where('to', isEqualTo: mail)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  /// Unread notifications badge stream
  Stream<int> _unreadNotificationsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _cid.isEmpty) return Stream<int>.value(0);
    final mail = user.email ?? '';
    return DB.colSync(_cid, C.notifications)
        .where('to', isEqualTo: mail)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  // 3-column dashboard tiles (factory-relevant)
  final List<_DashboardItem> _allItems = const [
    _DashboardItem('Stock',          Icons.inventory_2_outlined,  ''),
    _DashboardItem('Work Orders',    Icons.work_outline,          ''),
    _DashboardItem('Purchase Orders',Icons.shopping_cart_outlined,''),
    _DashboardItem('QC Report',      Icons.fact_check_outlined,   ''),
    _DashboardItem('Daily Production',Icons.factory_outlined,     ''),
    _DashboardItem('Updates',        Icons.update_outlined,       ''),
    _DashboardItem('Notices',        Icons.notifications_outlined,'/factory/notices'),
    _DashboardItem('Messages',       Icons.message_outlined,      '/common/messages'),
    _DashboardItem('Attendance',     Icons.event_available_outlined,'/factory/attendance'),
    _DashboardItem('Loan Request',   Icons.request_page_outlined, '/marketing/loan_request'),
    _DashboardItem('Salary & OT',    Icons.payments_outlined,     '/common/salary'),
    _DashboardItem('R&D Request',    Icons.science_outlined,      '/rnd/request'),
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
        Navigator.push(context, MaterialPageRoute(builder: (_) => QCReportScreen()));
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

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _brandRed,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: Colors.white24,
              backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty) ? NetworkImage(photoUrl!) : null,
              child: (photoUrl == null || photoUrl!.isEmpty)
                  ? Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Factory', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500)),
                  Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          StreamBuilder<int>(
            stream: _notifStream,
            builder: (_, s) => Stack(clipBehavior: Clip.none, children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, size: 22),
                tooltip: 'Notifications',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NotificationPage())),
              ),
              if ((s.data ?? 0) > 0)
                Positioned(right: 8, top: 8,
                    child: _Badge(count: s.data ?? 0)),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),

      drawer: const FactoryDrawer(),

      bottomNavigationBar: _buildBottomNav(),

      body: CustomScrollView(
        slivers: [
          // ── Hero overview card ───────────────────────────────────────────
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _FactoryOverviewHeaderRed(),
            ),
          ),

          // ── Section label + search ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 4, height: 18,
                      decoration: BoxDecoration(
                        color: _brandRed,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Quick Actions',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A))),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x14000000)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                      decoration: const InputDecoration(
                        hintText: 'Search features…',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Feature grid ─────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final it = filtered[i];
                  final isMessages = it.title == 'Messages';
                  return StreamBuilder<int>(
                    stream: isMessages ? _msgStream : const Stream<int>.empty(),
                    builder: (_, snap) => _DashTile(
                      title: it.title,
                      icon: it.icon,
                      badgeCount: snap.data ?? 0,
                      onTap: () => _onItemTap(it),
                    ),
                  );
                },
                childCount: filtered.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = <_NavItem>[
      _NavItem('Home',     Icons.home_rounded,          onTap: () => setState(() => _currentTab = 0)),
      _NavItem('Orders',   Icons.work_outline_rounded,  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkOrdersScreen()))),
      _NavItem('QC',       Icons.fact_check_outlined,   onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QCReportScreen()))),
      _NavItem('Production',Icons.factory_outlined,     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyProductionScreen()))),
      _NavItem('Alerts',   Icons.notifications_outlined,onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPage())), badgeStream: _notifStream),
      _NavItem('Messages', Icons.message_rounded,       onTap: () => Navigator.pushNamed(context, '/common/messages'), badgeStream: _msgStream),
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
  String _cid = '';
  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }
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
    final q = DB.colSync(_cid, C.attendance)
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
    Query<Map<String, dynamic>> q = DB.colSync(_cid, C.users)
        .where('role', isEqualTo: 'worker')
        .where('active', isEqualTo: true);
    if (mail != null) q = q.where('managerEmail', isEqualTo: mail);
    return q.snapshots().map((s) => s.docs.length);
  }

  // Completed work orders (completed==true OR terminal stage)
  Stream<int> _completedOrders() {
    return DB.colSync(_cid, C.workOrders)
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
    return DB.colSync(_cid, C.workOrders)
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

    Query<Map<String, dynamic>> q = DB.colSync(_cid, C.dailyProduction)
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

    Query<Map<String, dynamic>> q = DB.colSync(_cid, C.dailyProduction)
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
    Query<Map<String, dynamic>> q = DB.colSync(_cid, C.loans);
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
    return DB.colSync(_cid, C.workOrders).snapshots().map((s) {
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_brandRed, _redMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: _brandRed.withValues(alpha: 0.3),
            blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.factory_rounded, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Factory Overview',
                  style: TextStyle(color: Colors.white,
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            _RangeFilter(
              value: _range,
              onChanged: (r) => setState(() => _range = r),
            ),
          ]),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (_, c) {
            const spacing = 8.0;
            final cardW = (c.maxWidth - spacing * 2) / 3;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _StatCardPercent(
                  width: cardW,
                  label: 'Attendance',
                  numerator: _presentToday(),
                  denominator: _activeWorkers(),
                ),
                // Completed WOs
                _StatCardRed(width: cardW, label: 'Completed', streamText: _completedOrders().map((v) => '$v')),
                _StatCardRed(width: cardW, label: 'Running', streamText: _runningOrders().map((v) => '$v')),
                // Production today
                _StatCardRed(width: cardW, label: 'Monthly Output', streamText: _outputThisMonth()),
                // Due loans
                _StatCardRed(width: cardW, label: 'Due Loans', streamText: _dueLoanAmount()),
                // Avg completion time (range control doesn’t affect this; it’s global)
                _StatCardRed(width: cardW, label: 'Avg. Time', streamText: _avgCompletionTime()),
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
          icon: const Icon(Icons.keyboard_arrow_down, color: _brandRed),
          dropdownColor: Colors.white,
          style: const TextStyle(color: _brandRed, fontWeight: FontWeight.w700, fontSize: 12),
          items: const [
            DropdownMenuItem(value: _Range.thisMonth, child: Text('This month')),
            DropdownMenuItem(value: _Range.prevMonth, child: Text('Prev month')),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: StreamBuilder<String>(
        stream: streamText,
        builder: (_, snap) {
          final loading = snap.connectionState == ConnectionState.waiting && !snap.hasData;
          final v = snap.data ?? '—';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                    )
                  : Text(v,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18)),
              const SizedBox(height: 3),
              Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      fontSize: 10)),
            ],
          );
        },
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: StreamBuilder<int>(
        stream: denominator,
        builder: (_, totalSnap) {
          final total = totalSnap.data ?? 0;
          return StreamBuilder<int>(
            stream: numerator,
            builder: (_, presSnap) {
              final pres = presSnap.data ?? 0;
              final txt = (total <= 0) ? '—' : '${(pres * 100 / total).toStringAsFixed(0)}%';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(txt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18)),
                  const SizedBox(height: 3),
                  Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          fontSize: 10)),
                ],
              );
            },
          );
        },
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

  static Color _accentFor(String t) {
    const map = {
      'Stock':           Color(0xFF40062D),
      'Work Orders':     Color(0xFFB91C1C),
      'Purchase Orders': Color(0xFFB45309),
      'QC Report':       Color(0xFF0891B2),
      'Daily Production':Color(0xFF40062D),
      'Updates':         Color(0xFF16A34A),
      'Notices':         Color(0xFF6366F1),
      'Messages':        Color(0xFF7C3AED),
      'Attendance':      Color(0xFF0D9488),
      'Loan Request':    Color(0xFFB45309),
      'Salary & OT':     Color(0xFF059669),
      'R&D Request':     Color(0xFF7C3AED),
    };
    return map[t] ?? _brandRed;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(title);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: accent.withValues(alpha: 0.08),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x14000000)),
            boxShadow: const [
              BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Stack(
            children: [
              // Top accent stripe
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: accent, size: 22),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(builder: (_, c) {
                        double fs = 11.5;
                        if (title.length > 12 || c.maxWidth < 90) fs = 10.5;
                        if (title.length > 16 || c.maxWidth < 76) fs = 9.5;
                        return Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: const Color(0xFF0F172A),
                              fontSize: fs,
                              fontWeight: FontWeight.w700),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: 8, top: 8,
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
