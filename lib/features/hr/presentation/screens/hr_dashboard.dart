// lib/features/hr/presentation/screens/hr_dashboard.dart
import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/hr/presentation/widgets/hr_drawer.dart';
import 'package:uddoygi/features/hr/presentation/widgets/hr_web_shell.dart';
import 'package:uddoygi/features/common/notification.dart';
import 'package:url_launcher/url_launcher.dart';

import 'budget.dart' show BudgetPage;

// ── Brand colours ────────────────────────────────────────────────────────────
const Color _brandGreen = Color(0xFF065F46);
const Color _greenMid   = Color(0xFF10B981);
const Color _surface    = Color(0xFFF1F8F4);
const Color _cardBorder = Color(0x1A065F46);
const Color _shadowLite = Color(0x14000000);

// ── Section labels for the module grid ───────────────────────────────────────
const _sections = [
  _Section('People',  [0, 1, 2]),
  _Section('Time',    [3, 4]),
  _Section('Payroll', [5, 6, 7, 8, 9]),
  _Section('Finance', [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21]),
  _Section('HR Ops',  [22]),
  _Section('Comms',   [23, 24, 25]),
];

class _Section {
  final String label;
  final List<int> indices;
  const _Section(this.label, this.indices);
}

// ─────────────────────────────────────────────────────────────────────────────

class HRDashboard extends StatefulWidget {
  const HRDashboard({Key? key}) : super(key: key);

  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard> {
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
      name     = (session?['name'] as String?) ?? current?.displayName ?? current?.email ?? 'HR';
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
    if (parts.isEmpty) return 'H';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

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

  // All 26 module tiles — kept in sync with hr_drawer.dart and web Sidebar.jsx
  final List<_DashboardItem> _allItems = const [
    // People [0-2]
    _DashboardItem('Employees',       Icons.people_rounded,                  '/hr/employee_directory'),
    _DashboardItem('Recruitment',     Icons.how_to_reg_rounded,              '/hr/recruitment'),
    _DashboardItem('Shifts',          Icons.schedule_rounded,                '/hr/shift_tracker'),
    // Time [3-4]
    _DashboardItem('Attendance',      Icons.event_available_rounded,         '/hr/attendance'),
    _DashboardItem('Leave',           Icons.beach_access_rounded,            '/hr/leave_management'),
    // Payroll [5-9]
    _DashboardItem('Payroll',         Icons.attach_money_rounded,            '/hr/payroll_processing'),
    _DashboardItem('Payslips',        Icons.receipt_long_rounded,            '/hr/payslip'),
    _DashboardItem('Salary',          Icons.money_rounded,                   '/hr/salary_management'),
    _DashboardItem('Slip Approvals',  Icons.receipt_long_rounded,            '/hr/payment_slip_approvals'),
    _DashboardItem('Authorization',   Icons.verified_user_rounded,           '/hr/authorization'),
    // Finance [10-21]
    _DashboardItem('Loans',           Icons.account_balance_rounded,         '/hr/loan_approval'),
    _DashboardItem('Credits',         Icons.trending_up_rounded,             '/hr/credits'),
    _DashboardItem('Expenses',        Icons.payments_rounded,                '/hr/expenses'),
    _DashboardItem('Balance',         Icons.account_balance_wallet_rounded,  '/hr/balance_update'),
    _DashboardItem('Budget',          Icons.pie_chart_rounded,               '/hr/budget'),
    _DashboardItem('Accounts',        Icons.account_balance_wallet_outlined, '/payments/bank-accounts'),
    _DashboardItem('Tax',             Icons.calculate_rounded,               '/hr/tax'),
    _DashboardItem('ROI',             Icons.trending_up_rounded,             '/hr/roi'),
    _DashboardItem('Incentives',      Icons.percent_rounded,                 '/hr/incentives'),
    _DashboardItem('Benefits',        Icons.card_giftcard_rounded,           '/hr/benefits_compensation'),
    _DashboardItem('Bgt Forecast',    Icons.bar_chart_rounded,               '/hr/budget_forecast'),
    _DashboardItem('Procurement',     Icons.shopping_cart_rounded,           '/hr/procurement'),
    // HR Ops [22]
    _DashboardItem('Welfare',         Icons.favorite_rounded,                '/hr/welfare'),
    // Comms [23-25]
    _DashboardItem('Notices',         Icons.notifications_rounded,           '/marketing/notices'),
    _DashboardItem('Messages',        Icons.message_rounded,                 '/common/messages'),
    _DashboardItem('Complaints',      Icons.support_agent_rounded,           '/common/complaints'),
  ];

  // Pinned quick-access items (most-used, shown as horizontal chips)
  static const _pinnedIndices = [3, 4, 0, 5]; // Attendance, Leave, Employees, Payroll

  void _onItemTap(_DashboardItem item) {
    if (item.title == 'Budget') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetPage()));
      return;
    }
    Navigator.pushNamed(context, item.route);
  }


  @override
  Widget build(BuildContext context) {
    final displayName = _niceName(name ?? 'HR');
    final initials    = _initialsFor(displayName);
    final isDesktop   = MediaQuery.sizeOf(context).width >= 900;
    final cols        = isDesktop ? 4 : 3;

    final filtered = _allItems
        .where((i) => i.title.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    final bodyContent = _buildBody(filtered, cols, isDesktop);

    if (isDesktop) {
      return HrWebShell(
        title: 'Welcome, $displayName',
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: _brandGreen),
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const NotificationPage())),
          ),
        ],
        child: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: Colors.white24,
              backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                  ? NetworkImage(photoUrl!)
                  : null,
              child: (photoUrl == null || photoUrl!.isEmpty)
                  ? Text(initials,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('HR Dashboard',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, height: 1.1)),
                  Text('Hi, $displayName',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.1)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Web access — compact icon button
          IconButton(
            icon: const Icon(Icons.computer_rounded, size: 20),
            tooltip: 'Open on Desktop\nuddyogi-hr.web.app',
            onPressed: () async {
              final uri = Uri.parse('https://uddyogi-hr.web.app');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
          StreamBuilder<int>(
            stream: _notifStream,
            builder: (_, s) => _BadgeIcon(
              icon: Icons.notifications,
              color: Colors.white,
              count: s.data ?? 0,
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const NotificationPage())),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      drawer: const HRDrawer(),
      bottomNavigationBar: _buildBottomNav(),
      body: bodyContent,
    );
  }

  Widget _buildBody(List<_DashboardItem> filtered, int cols, bool isDesktop) {
    final hPad = isDesktop ? 24.0 : 14.0;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([

              // ── 1. Overview stats (compact) ───────────────────────────────
              if (_cid.isNotEmpty) _HROverviewHeader(cid: _cid),
              if (_cid.isNotEmpty) const SizedBox(height: 10),

              // ── 1b. Web portal link banner ────────────────────────────────
              if (_cid.isNotEmpty && _search.isEmpty) _WebPortalBanner(),
              if (_cid.isNotEmpty && _search.isEmpty) const SizedBox(height: 12),

              // ── 2. Quick-access chips ─────────────────────────────────────
              if (_search.isEmpty) ...[
                _QuickAccessRow(
                  items: _pinnedIndices.map((i) => _allItems[i]).toList(),
                  msgStream: _msgStream,
                  onTap: _onItemTap,
                ),
                const SizedBox(height: 12),
              ],

              // ── 3. Search bar (compact) ───────────────────────────────────
              SizedBox(
                height: 42,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search modules…',
                    prefixIcon: const Icon(Icons.search, color: _brandGreen, size: 18),
                    hintStyle: const TextStyle(color: _brandGreen, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _brandGreen),
                    ),
                  ),
                  style: const TextStyle(color: _brandGreen, fontSize: 13),
                ),
              ),
              const SizedBox(height: 14),

              // ── 4. Module grid — grouped by section when not searching ────
              if (_search.isNotEmpty)
                _ModuleGrid(items: filtered, cols: cols, msgStream: _msgStream, onTap: _onItemTap)
              else
                ..._sections.map((sec) {
                  final items = sec.indices.map((i) => _allItems[i]).toList();
                  return _SectionGroup(
                    label: sec.label,
                    items: items,
                    cols: cols,
                    msgStream: _msgStream,
                    onTap: _onItemTap,
                  );
                }),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    final items = <_NavItem>[
      _NavItem('Home',       Icons.home_rounded,
          onTap: () => setState(() => _currentTab = 0)),
      _NavItem('Directory',  Icons.people_alt_rounded,
          onTap: () => Navigator.pushNamed(context, '/hr/employee_directory')),
      _NavItem('Attendance', Icons.event_available_rounded,
          onTap: () => Navigator.pushNamed(context, '/hr/attendance')),
      _NavItem('Payroll',    Icons.attach_money_rounded,
          onTap: () => Navigator.pushNamed(context, '/hr/payroll_processing')),
      _NavItem('Notifs',     Icons.notifications,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NotificationPage())),
          badgeStream: _notifStream),
      _NavItem('Messages',   Icons.message_rounded,
          onTap: () => Navigator.pushNamed(context, '/common/messages'),
          badgeStream: _msgStream),
    ];

    return SafeArea(
      child: Container(
        height: 58,
        decoration: const BoxDecoration(color: _brandGreen),
        child: Row(
          children: items.map((it) {
            final idx      = items.indexOf(it);
            final selected = idx == _currentTab;
            final color    = selected ? Colors.white : Colors.white60;

            final iconWidget = it.badgeStream == null
                ? Icon(it.icon, color: color, size: 22)
                : StreamBuilder<int>(
                    stream: it.badgeStream,
                    builder: (_, s) => _BadgeIcon(
                      icon: it.icon, color: color, count: s.data ?? 0,
                      size: 22,
                    ),
                  );

            return Expanded(
              child: InkWell(
                onTap: () {
                  setState(() => _currentTab = idx);
                  it.onTap();
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    iconWidget,
                    const SizedBox(height: 2),
                    AutoSizeText(
                      it.label,
                      maxLines: 1,
                      minFontSize: 7,
                      stepGranularity: 0.5,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick-access horizontal chip row
// ─────────────────────────────────────────────────────────────────────────────
class _QuickAccessRow extends StatelessWidget {
  final List<_DashboardItem> items;
  final Stream<int> msgStream;
  final void Function(_DashboardItem) onTap;
  const _QuickAccessRow({required this.items, required this.msgStream, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items.map((it) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _QuickChip(item: it, onTap: () => onTap(it)),
          ),
        );
      }).toList()
        ..last = Expanded(
          child: _QuickChip(item: items.last, onTap: () => onTap(items.last)),
        ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final _DashboardItem item;
  final VoidCallback onTap;
  const _QuickChip({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorder),
            boxShadow: const [BoxShadow(color: _shadowLite, blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _brandGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: _brandGreen, size: 18),
              ),
              const SizedBox(height: 5),
              AutoSizeText(
                item.title,
                maxLines: 1,
                minFontSize: 8,
                stepGranularity: 0.5,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _brandGreen, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section group (label + grid)
// ─────────────────────────────────────────────────────────────────────────────
class _SectionGroup extends StatelessWidget {
  final String label;
  final List<_DashboardItem> items;
  final int cols;
  final Stream<int> msgStream;
  final void Function(_DashboardItem) onTap;
  const _SectionGroup({
    required this.label,
    required this.items,
    required this.cols,
    required this.msgStream,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(width: 3, height: 14, decoration: BoxDecoration(
                color: _brandGreen, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: _brandGreen, fontWeight: FontWeight.w800, fontSize: 12,
                      letterSpacing: 0.4)),
            ],
          ),
        ),
        _ModuleGrid(items: items, cols: cols, msgStream: msgStream, onTap: onTap),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Module grid
// ─────────────────────────────────────────────────────────────────────────────
class _ModuleGrid extends StatelessWidget {
  final List<_DashboardItem> items;
  final int cols;
  final Stream<int> msgStream;
  final void Function(_DashboardItem) onTap;
  const _ModuleGrid({required this.items, required this.cols, required this.msgStream, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDesktop = cols >= 4;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: isDesktop ? 1.5 : 1.2,
      ),
      itemBuilder: (_, i) {
        final it = items[i];
        final isMessages = it.title == 'Messages';
        return StreamBuilder<int>(
          stream: isMessages ? msgStream : const Stream<int>.empty(),
          builder: (_, snap) => _DashTile(
            title: it.title,
            icon: it.icon,
            badgeCount: snap.data ?? 0,
            onTap: () => onTap(it),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overview header (compact 2-row stats)
// ─────────────────────────────────────────────────────────────────────────────
enum _Range { thisMonth, prevMonth, last3, last12 }

class _HROverviewHeader extends StatefulWidget {
  final String cid;
  const _HROverviewHeader({required this.cid, Key? key}) : super(key: key);

  @override
  State<_HROverviewHeader> createState() => _HROverviewHeaderState();
}

class _HROverviewHeaderState extends State<_HROverviewHeader> {
  _Range _range = _Range.thisMonth;

  ({DateTime a, DateTime b}) _rangeDates(_Range r) {
    final now = DateTime.now();
    switch (r) {
      case _Range.thisMonth:
        return (a: DateTime(now.year, now.month, 1),     b: DateTime(now.year, now.month + 1, 0, 23, 59, 59));
      case _Range.prevMonth:
        return (a: DateTime(now.year, now.month - 1, 1), b: DateTime(now.year, now.month, 0, 23, 59, 59));
      case _Range.last3:
        return (a: DateTime(now.year, now.month - 2, 1), b: DateTime(now.year, now.month + 1, 0, 23, 59, 59));
      case _Range.last12:
        return (a: DateTime(now.year, now.month - 11, 1),b: DateTime(now.year, now.month + 1, 0, 23, 59, 59));
    }
  }

  String get _cid => widget.cid;

  Stream<String> _employees() =>
      DB.colSync(_cid, C.users).snapshots().map((s) => '${s.docs.length}');

  Stream<String> _pendingLeave() => DB.colSync(_cid, C.leaveRequests)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => '${s.docs.length}');

  Stream<String> _pendingComplaints() => DB.colSync(_cid, C.complaints)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => '${s.docs.length}');

  Stream<String> _expensesTotal() {
    final r = _rangeDates(_range);
    return DB.colSync(_cid, C.expenses)
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

  Stream<String> _budgetThisMonth() {
    final now       = DateTime.now();
    final periodKey = '${now.year}_${now.month.toString().padLeft(2, '0')}';
    return DB.colSync(_cid, C.budgets).doc(periodKey).snapshots().map((snap) {
      if (!snap.exists) return '—';
      final d = snap.data() ?? {};
      final v = d['totalNeed'];
      num n = 0;
      if (v is num) n = v;
      if (v is String) n = num.tryParse(v.replaceAll(',', '')) ?? 0;
      return _money(n);
    });
  }

  Stream<String> _payrollThisMonth() {
    final now         = DateTime.now();
    final periodLabel = DateFormat('MMMM yyyy').format(now);
    return DB.colSync(_cid, C.payrolls)
        .where('period', isEqualTo: periodLabel)
        .snapshots()
        .map((s) {
      num sum = 0;
      for (final d in s.docs) {
        final v = d.data()['netSalary'];
        if (v is num) sum += v;
        if (v is String) sum += num.tryParse(v.replaceAll(',', '')) ?? 0;
      }
      return _money(sum);
    });
  }

  String _money(num n) {
    if (n == 0) return '৳0';
    if (n >= 100000) return '৳${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000)   return '৳${(n / 1000).toStringAsFixed(1)}K';
    return '৳${n.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    // 6 stats in a 3×2 grid
    final stats = [
      _StatDef('Employees',  Icons.people_rounded,           _employees()),
      _StatDef('Leave Req',  Icons.beach_access_rounded,     _pendingLeave()),
      _StatDef('Complaints', Icons.support_agent_rounded,    _pendingComplaints()),
      _StatDef('Payroll',    Icons.attach_money_rounded,     _payrollThisMonth()),
      _StatDef('Expenses',   Icons.payments_rounded,         _expensesTotal()),
      _StatDef('Budget',     Icons.pie_chart_rounded,        _budgetThisMonth()),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [_brandGreen, _greenMid],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: _shadowLite, blurRadius: 12, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Expanded(
                child: Text('Overview',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              ),
              _RangeFilter(value: _range, onChanged: (r) => setState(() => _range = r)),
            ],
          ),
          const SizedBox(height: 12),

          // 3-column stat grid
          LayoutBuilder(builder: (ctx, c) {
            const spacing = 8.0;
            final cardW = (c.maxWidth - spacing * 2) / 3;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: stats.map((s) => _StatCard(
                width: cardW,
                label: s.label,
                icon: s.icon,
                streamText: s.stream,
              )).toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _StatDef {
  final String label;
  final IconData icon;
  final Stream<String> stream;
  const _StatDef(this.label, this.icon, this.stream);
}

// ─────────────────────────────────────────────────────────────────────────────
// Range filter
// ─────────────────────────────────────────────────────────────────────────────
class _RangeFilter extends StatelessWidget {
  final _Range value;
  final ValueChanged<_Range> onChanged;
  const _RangeFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_Range>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: _brandGreen, size: 16),
          dropdownColor: Colors.white,
          style: const TextStyle(color: _brandGreen, fontWeight: FontWeight.w700, fontSize: 11),
          items: const [
            DropdownMenuItem(value: _Range.thisMonth, child: Text('This month')),
            DropdownMenuItem(value: _Range.prevMonth, child: Text('Prev month')),
            DropdownMenuItem(value: _Range.last3,     child: Text('Last 3 mo')),
            DropdownMenuItem(value: _Range.last12,    child: Text('1 year')),
          ],
          onChanged: (r) { if (r != null) onChanged(r); },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat card (compact with icon)
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final double width;
  final String label;
  final IconData icon;
  final Stream<String> streamText;
  const _StatCard({
    required this.width,
    required this.label,
    required this.icon,
    required this.streamText,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: _shadowLite, blurRadius: 8, offset: Offset(0, 3))],
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
              Row(
                children: [
                  Icon(icon, color: _brandGreen, size: 13),
                  const SizedBox(width: 4),
                  Expanded(
                    child: AutoSizeText(
                      label,
                      maxLines: 1,
                      minFontSize: 8,
                      stepGranularity: 0.5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _brandGreen, fontWeight: FontWeight.w600, fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              loading
                  ? SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _brandGreen.withValues(alpha: 0.5)),
                    )
                  : AutoSizeText(
                      v,
                      maxLines: 1,
                      minFontSize: 12,
                      stepGranularity: 0.5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _brandGreen, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dash tile
// ─────────────────────────────────────────────────────────────────────────────
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
  const _DashTile({required this.title, required this.icon, required this.onTap, this.badgeCount = 0});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cardBorder),
            boxShadow: const [BoxShadow(color: _shadowLite, blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _brandGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: _brandGreen, size: 20),
                      ),
                      const SizedBox(height: 6),
                      AutoSizeText(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        minFontSize: 8,
                        stepGranularity: 0.5,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _brandGreen, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              if (badgeCount > 0)
                Positioned(right: 6, top: 6, child: _Badge(count: badgeCount)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom nav helpers
// ─────────────────────────────────────────────────────────────────────────────
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
  final double size;
  final VoidCallback? onTap;
  const _BadgeIcon({
    required this.icon,
    required this.color,
    required this.count,
    this.size = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color, size: size),
        if (count > 0) Positioned(right: -5, top: -5, child: _Badge(count: count, small: true)),
      ],
    );
    if (onTap == null) return w;
    return IconButton(icon: w, onPressed: onTap, padding: EdgeInsets.zero);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Web portal link banner
// ─────────────────────────────────────────────────────────────────────────────
class _WebPortalBanner extends StatelessWidget {
  static const _url = 'https://uddyogi-hr.web.app';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final uri = Uri.parse(_url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cardBorder),
            boxShadow: const [BoxShadow(color: _shadowLite, blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _brandGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.computer_rounded, color: _brandGreen, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Open HR Web Portal',
                      style: TextStyle(
                          color: _brandGreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _url,
                      style: TextStyle(
                          color: _brandGreen.withValues(alpha: 0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded, color: _brandGreen, size: 16),
            ],
          ),
        ),
      ),
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
      padding: EdgeInsets.symmetric(horizontal: small ? 4 : 6, vertical: small ? 1 : 2),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: Colors.white,
            fontSize: small ? 8 : 10,
            fontWeight: FontWeight.w800,
            height: 1.0),
      ),
    );
  }
}
