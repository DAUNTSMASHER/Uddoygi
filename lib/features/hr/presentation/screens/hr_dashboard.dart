// lib/features/hr/presentation/screens/hr_dashboard.dart
import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/hr/presentation/widgets/hr_drawer.dart';
import 'package:uddoygi/features/common/notification.dart';
import 'package:uddoygi/features/common/alert.dart';

// NEW: direct page imports
import 'ROI.dart' show ROIPage;
import 'budget.dart' show BudgetPage;

/// ===== Green theme =====
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
      name = (session?['name'] as String?) ?? current?.displayName ?? current?.email ?? 'HR';
      photoUrl = current?.photoURL;
    });

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

  // DASH TILES
  final List<_DashboardItem> _allItems = const [
    _DashboardItem('Alerts',      Icons.notification_important, '/common/alert'),
    _DashboardItem('Directory',   Icons.people,                 '/hr/employee_directory'),
    _DashboardItem('Attendance',  Icons.event_available,        '/hr/attendance'),
    _DashboardItem('Payroll',     Icons.attach_money,           '/hr/payroll_processing'),
    _DashboardItem('Payslips',    Icons.receipt_long,           '/hr/payslip'),
    _DashboardItem('Loans',       Icons.account_balance,        '/hr/loan_approval'),
    _DashboardItem('Credits',     Icons.trending_up,            '/hr/credits'),
    _DashboardItem('Expenses',    Icons.payments,               '/hr/expenses'),
    _DashboardItem('Balance',     Icons.account_balance_wallet, '/hr/balance_update'),
    _DashboardItem('Notices',     Icons.notifications,          '/marketing/notices'),
    _DashboardItem('Messages',    Icons.message,                '/common/messages'),
    _DashboardItem('Complaints',  Icons.support_agent,          '/common/complaints'),
    _DashboardItem('Procurement', Icons.shopping_cart,          '/hr/procurement'),
    // NEW
    _DashboardItem('ROI',         Icons.insights,               '/hr/roi'),
    _DashboardItem('Budget',      Icons.account_balance,        '/hr/budget'),
  ];

  void _onItemTap(_DashboardItem item) {
    if (item.title == 'Alerts') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertPage()));
      return;
    }
    if (item.title == 'ROI') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ROIPage()));
      return;
    }
    if (item.title == 'Budget') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetPage()));
      return;
    }
    Navigator.pushNamed(context, item.route);
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _niceName(name ?? 'HR');
    final initials = _initialsFor(displayName);

    final filtered = _allItems.where((i) => i.title.toLowerCase().contains(_search.toLowerCase())).toList();

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
                  ? Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Welcome, $displayName',
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPage())),
          ),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: _logout),
        ],
      ),

      drawer: const HRDrawer(),

      bottomNavigationBar: _buildBottomNav(),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // UPDATED: overview with NO icons
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
      _NavItem('Directory', Icons.people_alt_rounded,
          onTap: () => Navigator.pushNamed(context, '/hr/employee_directory')),
      _NavItem('Attendance', Icons.event_available_rounded,
          onTap: () => Navigator.pushNamed(context, '/hr/attendance')),
      _NavItem('Payroll', Icons.attach_money_rounded,
          onTap: () => Navigator.pushNamed(context, '/hr/payroll_processing')),
      _NavItem('Notifications', Icons.notifications,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationPage())),
          badgeStream: _unreadNotificationsStream()),
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
              builder: (_, s) => _BadgeIcon(icon: it.icon, color: color, count: s.data ?? 0),
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

/* ========================= Overview (icon-less cards) ========================= */

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
        return (a: DateTime(now.year, now.month, 1), b: DateTime(now.year, now.month + 1, 0, 23, 59, 59));
      case _Range.prevMonth:
        return (a: DateTime(now.year, now.month - 1, 1), b: DateTime(now.year, now.month, 0, 23, 59, 59));
      case _Range.last3:
        return (a: DateTime(now.year, now.month - 2, 1), b: DateTime(now.year, now.month + 1, 0, 23, 59, 59));
      case _Range.last12:
        return (a: DateTime(now.year, now.month - 11, 1), b: DateTime(now.year, now.month + 1, 0, 23, 59, 59));
    }
  }

  // ====== Existing cards ======
  Stream<String> _employees() =>
      FirebaseFirestore.instance.collection('users').snapshots().map((s) => '${s.docs.length}');

  // Actual pending complaints only
  Stream<String> _pendingComplaints() => FirebaseFirestore.instance
      .collection('complaints')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => '${s.docs.length}');

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

  // ====== NEW: Avg ROI (this month, marketing users) ======
  Stream<String> _avgRoiThisMonth() {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to   = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final fromTs = Timestamp.fromDate(from);
    final toTs   = Timestamp.fromDate(to);
    final monthKey = DateFormat('MMMM_yyyy').format(from).toLowerCase();
    final periodLabel = DateFormat('MMMM yyyy').format(from);

    double _num(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0.0;
      return 0.0;
    }

    bool _inRange(dynamic ts) =>
        ts is Timestamp && ts.compareTo(fromTs) >= 0 && ts.compareTo(toTs) <= 0;

    // Drive computation off incentive updates
    return FirebaseFirestore.instance.collection('marketing_incentives').snapshots().asyncMap((incSnap) async {
      // Marketing users
      final users = await FirebaseFirestore.instance
          .collection('users')
          .where('department', isEqualTo: 'marketing')
          .get();
      final emails = <String>[
        for (final u in users.docs)
          ((u.data()['email'] ?? u.data()['officeEmail'] ?? '') as String).toString().trim().toLowerCase()
      ].where((e) => e.isNotEmpty).toList();

      if (emails.isEmpty) return '—';

      // Incentive per email
      final incByEmail = <String, double>{};
      for (final d in incSnap.docs) {
        final m = d.data();
        final f = _num(m['totalIncentive']);
        if (f <= 0) continue;
        final ue = (m['userEmail'] ?? '').toString().toLowerCase();
        final ae = (m['agentEmail'] ?? '').toString().toLowerCase();
        final ts = m['timestamp'];

        // field-based
        if (_inRange(ts) && (emails.contains(ue) || emails.contains(ae))) {
          final key = emails.contains(ue) ? ue : ae;
          incByEmail.update(key, (v) => v + f, ifAbsent: () => f);
          continue;
        }

        // id-pattern fallback: "<email>_sales_<MMMM>_<yyyy>"
        final idLower = d.id.toLowerCase();
        for (final e in emails) {
          if (idLower.startsWith(e) && idLower.contains(monthKey)) {
            incByEmail.update(e, (v) => v + f, ifAbsent: () => f);
            break;
          }
        }
      }

      // Salaries
      final paySnap = await FirebaseFirestore.instance
          .collection('payrolls')
          .where('period', isEqualTo: periodLabel)
          .get();
      final salaryByEmail = <String, double>{};
      for (final d in paySnap.docs) {
        final m = d.data();
        final mail = (m['officeEmail'] ?? '').toString().toLowerCase();
        if (!emails.contains(mail)) continue;
        final gross = _num(m['grossSalary']);
        final t = gross > 0 ? gross : (_num(m['basicSalary']) > 0 ? _num(m['basicSalary']) : _num(m['netSalary']));
        salaryByEmail[mail] = t;
      }

      // Compute avg ROI
      int count = 0;
      double sumRoi = 0;
      for (final e in emails) {
        final f = incByEmail[e] ?? 0.0;
        final t = salaryByEmail[e] ?? 0.0;
        if (t == 0 && f == 0) continue;

        final N  = f * (100.0 / 15.0);
        final T  = t;            // months = 1
        final EC = T + f + 0.0;  // d = 0
        final NR = N - EC;
        final roi = EC == 0 ? 0.0 : (NR / EC);

        sumRoi += roi;
        count++;
      }

      if (count == 0) return '—';
      final avg = sumRoi / count;
      return '${(avg * 100).toStringAsFixed(1)}%';
    });
  }

  // ====== NEW: Total budget this month (returned in Lakh) ======
  Stream<String> _budgetThisMonth() {
    final now = DateTime.now();
    final key = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final display = DateFormat('MMMM yyyy').format(DateTime(now.year, now.month));

    double _num(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0.0;
      return 0.0;
    }

    // Use stable monthly doc; fall back to legacy
    final ref = FirebaseFirestore.instance.collection('budgets').doc(key);
    return ref.snapshots().asyncMap((snap) async {
      if (snap.exists) {
        final m = snap.data() ?? {};
        final total = _num(m['totalNeed']);
        if (total > 0) return _lakh(total); // <<< Lakh
        final items = (m['items'] as List?) ?? const [];
        double sum = 0;
        for (final it in items) {
          if (it is Map) sum += _num(it['amount']);
        }
        return _lakh(sum); // <<< Lakh
      }

      // Legacy fallback by human-readable month
      final q = await FirebaseFirestore.instance
          .collection('budgets')
          .where('period', isEqualTo: display)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        final m = q.docs.first.data();
        final total = _num(m['totalNeed']);
        if (total > 0) return _lakh(total); // <<< Lakh
        final items = (m['items'] as List?) ?? const [];
        double sum = 0;
        for (final it in items) {
          if (it is Map) sum += _num(it['amount']);
        }
        return _lakh(sum); // <<< Lakh
      }

      return _lakh(0);
    });
  }

  // Helpers
  String _lakh(num n) => '${(n / 100000).toStringAsFixed(2)} L';

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
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_brandGreen, _greenMid], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: _shadowLite, blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Filter (icon removed)
          Row(
            children: [
              const Expanded(
                child: Text('Overview',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              _RangeFilter(value: _range, onChanged: (r) => setState(() => _range = r)),
            ],
          ),
          const SizedBox(height: 14),

          // 3×N grid of stat cards (no icons in the cards)
          LayoutBuilder(builder: (ctx, c) {
            const spacing = 10.0;
            final w = c.maxWidth;
            final cardW = (w - (spacing * 2)) / 3; // three columns
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _StatCard(width: cardW, label: 'Employees',  streamText: _employees()),
                _StatCard(width: cardW, label: 'Avg ROI',    streamText: _avgRoiThisMonth()),
                _StatCard(width: cardW, label: 'Complaints', streamText: _pendingComplaints()), // actual pending
                _StatCard(width: cardW, label: 'Expenses',   streamText: _expensesTotal()),
                _StatCard(width: cardW, label: 'Credits',    streamText: _creditsTotal()),
                _StatCard(width: cardW, label: 'Budget',     streamText: _budgetThisMonth()),   // in Lakh
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
          style: const TextStyle(color: _brandGreen, fontWeight: FontWeight.w700, fontSize: 12),
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

/* ========================= Stat card (NO icon) ========================= */

class _StatCard extends StatelessWidget {
  final double width;
  final String label;
  final Stream<String> streamText;
  const _StatCard({required this.width, required this.label, required this.streamText, Key? key}) : super(key: key);

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
      child: StreamBuilder<String>(
        stream: streamText,
        builder: (_, snap) {
          final v = snap.hasData ? snap.data! : '—';
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AutoSizeText(
                v,
                maxLines: 1,
                minFontSize: 14,
                stepGranularity: 0.5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _brandGreen, fontWeight: FontWeight.w900, fontSize: 20),
              ),
              const SizedBox(height: 2),
              AutoSizeText(
                label,
                maxLines: 2,
                minFontSize: 9,
                stepGranularity: 0.5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _brandGreen, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
          );
        },
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
  const _DashTile({required this.title, required this.icon, required this.onTap, this.badgeCount = 0});

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
                          style: const TextStyle(color: _brandGreen, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (badgeCount > 0)
                Positioned(right: 8, top: 8, child: _Badge(count: badgeCount)),
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
        if (count > 0) Positioned(right: -6, top: -6, child: _Badge(count: count, small: true)),
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
        style: TextStyle(color: Colors.white, fontSize: small ? 9 : 10, fontWeight: FontWeight.w800, height: 1.0),
      ),
    );
  }
}

/* ======================= Optional carousel ======================= */

class _RealtimeSummaryCarousel extends StatelessWidget {
  const _RealtimeSummaryCarousel();

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
  const _LiveStatTile({required this.title, required this.icon, required this.gradient, required this.value});

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
            height: 40,
            width: 40,
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
