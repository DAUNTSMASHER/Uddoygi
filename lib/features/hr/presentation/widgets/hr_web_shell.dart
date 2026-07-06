// lib/features/hr/presentation/widgets/hr_web_shell.dart
//
// HrWebShell — Adaptive layout wrapper for ALL HR screens.
//
// On desktop / web (width ≥ 900 px):
//   ┌──────────────────────────────────────────────────────┐
//   │  ┌──────────┐  ┌────────────────────────────────┐   │
//   │  │ Sidebar  │  │       Page Content             │   │
//   │  │ (240 px) │  │                                │   │
//   │  └──────────┘  └────────────────────────────────┘   │
//   └──────────────────────────────────────────────────────┘
//
// On mobile (width < 900 px):
//   Standard Scaffold with Drawer (existing behaviour unchanged).
//
// Usage — wrap any HR screen's Scaffold body:
//
//   @override
//   Widget build(BuildContext context) {
//     return HrWebShell(
//       title: 'Attendance',
//       child: /* your existing body widget */,
//     );
//   }
//
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'hr_drawer.dart';
import 'hr_layout_constants.dart';

// ── Use HR layout constants for consistent bars and palette ───────────────────
const Color _sidebar = Color(0xFF042F26);
const Color _border  = Color(0x1A065F46);

// ── Breakpoint ────────────────────────────────────────────────────────────────
const double _kDesktopBreak = 900.0;

bool _isDesktop(BuildContext ctx) =>
    MediaQuery.sizeOf(ctx).width >= _kDesktopBreak;

// ─────────────────────────────────────────────────────────────────────────────
// SHELL
// ─────────────────────────────────────────────────────────────────────────────
class HrWebShell extends StatelessWidget {
  /// Page title shown in the desktop top bar.
  final String title;

  /// The main content widget (replaces Scaffold body).
  final Widget child;

  /// Optional AppBar actions (shown on both mobile and desktop).
  final List<Widget>? actions;

  /// Optional background colour for the content area.
  final Color? backgroundColor;

  const HrWebShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (_isDesktop(context)) {
      return _DesktopShell(
        title:           title,
        actions:         actions,
        backgroundColor: backgroundColor ?? kHrSurface,
        child:           child,
      );
    }
    // Mobile: Scaffold with consistent 10% top bar, 8% bottom bar (HR layout)
    final topH = hrTopBarHeight(context);
    final bottomH = hrBottomBarHeight(context);
    return Scaffold(
      backgroundColor: backgroundColor ?? kHrSurface,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(topH),
        child: AppBar(
          backgroundColor: kHrHeroGreen,
          foregroundColor: kHrTextOnGreen,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: kHrHeaderGradient),
          ),
          title: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: kHrTextOnGreen)),
          actions: actions,
        ),
      ),
      drawer: const HRDrawer(),
      body: HrShellScope(hideChrome: true, child: child),
      bottomNavigationBar: Container(
        height: bottomH,
        decoration: BoxDecoration(
          color: kHrCardBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          border: Border.all(color: kHrCardBorder, width: 1),
          boxShadow: const [
            BoxShadow(
              color: kHrShadowCard,
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(top: false, child: const SizedBox.shrink()),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DESKTOP SHELL
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopShell extends StatelessWidget {
  final String  title;
  final Widget  child;
  final List<Widget>? actions;
  final Color   backgroundColor;

  const _DesktopShell({
    required this.title,
    required this.child,
    required this.backgroundColor,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────────────
          const _HrSidebar(),

          // ── Content area ─────────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top bar (consistent with mobile 10% on large screens if desired)
                _DesktopTopBar(title: title, actions: actions),
                // Page content
                Expanded(child: HrShellScope(hideChrome: true, child: child)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DESKTOP TOP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopTopBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  const _DesktopTopBar({required this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: kHrHeroGreen)),
        const Spacer(),
        if (actions != null) ...actions!,
        const SizedBox(width: 8),
        // User avatar
        _TopBarUserAvatar(),
      ]),
    );
  }
}

class _TopBarUserAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final initials = _initials(user?.displayName ?? user?.email ?? 'HR');
    final photo = user?.photoURL;

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'profile',
          child: Row(children: const [
            Icon(Icons.person_rounded, size: 16, color: kHrHeroGreen),
            SizedBox(width: 10),
            Text('Profile', style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(children: const [
            Icon(Icons.logout_rounded, size: 16, color: Colors.red),
            SizedBox(width: 10),
            Text('Logout',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.red)),
          ]),
        ),
      ],
      onSelected: (v) {
        if (v == 'profile') {
          Navigator.pushNamed(context, '/profile');
        } else if (v == 'logout') {
          final nav = Navigator.of(context);
          FirebaseAuth.instance.signOut().then((_) async {
            await LocalStorageService.clearSession();
            nav.pushNamedAndRemoveUntil('/login', (_) => false);
          });
        }
      },
      child: CircleAvatar(
        radius: 18,
        backgroundColor: kHrSuccessDot,
        backgroundImage:
            (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
        child: (photo == null || photo.isEmpty)
            ? Text(initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12))
            : null,
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'HR';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR
// ─────────────────────────────────────────────────────────────────────────────
class _HrSidebar extends StatefulWidget {
  const _HrSidebar();
  @override
  State<_HrSidebar> createState() => _HrSidebarState();
}

class _HrSidebarState extends State<_HrSidebar> {
  String _cid = '';
  String _currentRoute = '';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context)?.settings.name ?? '';
    if (route != _currentRoute) setState(() => _currentRoute = route);
  }

  Stream<int> _notifStream() {
    if (_cid.isEmpty) return const Stream.empty();
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return DB.colSync(_cid, C.notifications)
        .where('to', isEqualTo: email)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> _msgStream() {
    if (_cid.isEmpty) return const Stream.empty();
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return DB.colSync(_cid, C.messages)
        .where('to', isEqualTo: email)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    final uid   = FirebaseAuth.instance.currentUser?.uid ?? '';
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: _sidebar,
        boxShadow: [
          BoxShadow(
              color: Color(0x22000000),
              blurRadius: 12,
              offset: Offset(2, 0))
        ],
      ),
      child: Column(
        children: [
          // ── Logo / brand header ───────────────────────────────────────
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              gradient: kHrHeaderGradient,
            ),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kHrSuccessDot,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.business_center_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Uddyogi',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15)),
                  Text('HR Panel',
                      style: TextStyle(
                          color: Colors.white60,
                          fontWeight: FontWeight.w500,
                          fontSize: 11)),
                ],
              ),
            ]),
          ),

          // ── User info strip ───────────────────────────────────────────
          if (_cid.isNotEmpty)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: DB.colSync(_cid, C.users).doc(uid).snapshots(),
              builder: (ctx, snap) {
                final d = snap.data?.data() ?? {};
                final name = (d['fullName'] ?? d['name'] ?? 'HR').toString();
                final photo = (d['profilePhotoUrl'] ?? '').toString();
                final initials = _initials(name);
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF053D2E),
                    border: Border(
                        bottom: BorderSide(
                            color: Color(0x22FFFFFF), width: 1)),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: kHrSuccessDot,
                      backgroundImage: photo.isNotEmpty
                          ? NetworkImage(photo)
                          : null,
                      child: photo.isEmpty
                          ? Text(initials,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                          Text(email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10)),
                        ],
                      ),
                    ),
                  ]),
                );
              },
            ),

          // ── Nav items ─────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _SideSection('Main'),
                _SideItem(icon: Icons.dashboard_rounded,       label: 'Dashboard',          route: '/hr/dashboard',            current: _currentRoute),
                _SideItem(icon: Icons.notifications_rounded,   label: 'Alerts',             route: '/common/alert',            current: _currentRoute, badgeStream: _notifStream()),
                _SideItem(icon: Icons.message_rounded,         label: 'Messages',           route: '/common/messages',         current: _currentRoute, badgeStream: _msgStream()),

                _SideSection('People'),
                _SideItem(icon: Icons.people_rounded,          label: 'Directory',          route: '/hr/employee_directory',   current: _currentRoute),
                _SideItem(icon: Icons.schedule_rounded,        label: 'Shift Tracker',      route: '/hr/shift_tracker',        current: _currentRoute),
                _SideItem(icon: Icons.person_search_rounded,   label: 'Recruitment',        route: '/hr/recruitment',          current: _currentRoute),

                _SideSection('Attendance & Leave'),
                _SideItem(icon: Icons.event_available_rounded, label: 'Attendance',         route: '/hr/attendance',           current: _currentRoute),
                _SideItem(icon: Icons.beach_access_rounded,    label: 'Leave Management',   route: '/hr/leave_management',     current: _currentRoute),

                _SideSection('Payroll'),
                _SideItem(icon: Icons.attach_money_rounded,    label: 'Payroll Overview',   route: '/hr/payroll',              current: _currentRoute),
                _SideItem(icon: Icons.receipt_long_rounded,    label: 'Processing',         route: '/hr/payroll_processing',   current: _currentRoute),
                _SideItem(icon: Icons.description_rounded,     label: 'Payslips',           route: '/hr/payslip',              current: _currentRoute),
                _SideItem(icon: Icons.verified_user_rounded,   label: 'Authorization',      route: '/hr/authorization',        current: _currentRoute),
                _SideItem(icon: Icons.receipt_rounded,         label: 'Slip Approvals',     route: '/hr/payment_slip_approvals', current: _currentRoute),
                _SideItem(icon: Icons.manage_accounts_rounded, label: 'Salary Management',  route: '/hr/salary_management',    current: _currentRoute),

                _SideSection('Benefits & Loans'),
                _SideItem(icon: Icons.card_giftcard_rounded,   label: 'Benefits',           route: '/hr/benefits_compensation', current: _currentRoute),
                _SideItem(icon: Icons.account_balance_rounded, label: 'Loan Approval',      route: '/hr/loan_approval',        current: _currentRoute),
                _SideItem(icon: Icons.star_rounded,            label: 'Incentives',         route: '/hr/incentives',           current: _currentRoute),

                _SideSection('Finance'),
                _SideItem(icon: Icons.account_balance_wallet_rounded, label: 'Accounts',   route: '/payments/bank-accounts',  current: _currentRoute),
                _SideItem(icon: Icons.settings_applications_rounded,  label: 'PipraPay',   route: '/payments/piprapay/settings', current: _currentRoute),
                _SideItem(icon: Icons.outbox_rounded,          label: 'Accounts Payable',   route: '/hr/accounts_payable',     current: _currentRoute),
                _SideItem(icon: Icons.payments_rounded,        label: 'Expenses',           route: '/hr/expenses',             current: _currentRoute),
                _SideItem(icon: Icons.trending_up_rounded,     label: 'Credits',            route: '/hr/credits',              current: _currentRoute),
                _SideItem(icon: Icons.account_balance_wallet,  label: 'Balance',            route: '/hr/balance_update',       current: _currentRoute),
                _SideItem(icon: Icons.calculate_rounded,       label: 'Tax',                route: '/hr/tax',                  current: _currentRoute),

                _SideSection('Planning'),
                _SideItem(icon: Icons.shopping_cart_rounded,   label: 'Procurement',        route: '/hr/procurement',          current: _currentRoute),
                _SideItem(icon: Icons.insights_rounded,        label: 'ROI',                route: '/hr/roi',                  current: _currentRoute),
                _SideItem(icon: Icons.account_balance_rounded, label: 'Budget',             route: '/hr/budget',               current: _currentRoute),
                _SideItem(icon: Icons.bar_chart_rounded,       label: 'Budget Forecast',    route: '/hr/budget_forecast',      current: _currentRoute),

                _SideSection('Communication'),
                _SideItem(icon: Icons.campaign_rounded,        label: 'Notices',            route: '/hr/notices',              current: _currentRoute),
                _SideItem(icon: Icons.support_agent_rounded,   label: 'Complaints',         route: '/common/complaints',       current: _currentRoute),

                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── Logout button ─────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: Color(0x22FFFFFF), width: 1)),
            ),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.logout_rounded,
                  color: Colors.red, size: 18),
              title: const Text('Logout',
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                await LocalStorageService.clearSession();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (_) => false);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'HR';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────
class _SideSection extends StatelessWidget {
  final String label;
  const _SideSection(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(label.toUpperCase(),
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR NAV ITEM
// ─────────────────────────────────────────────────────────────────────────────
class _SideItem extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final String       route;
  final String       current;
  final Stream<int>? badgeStream;

  const _SideItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.current,
    this.badgeStream,
  });

  bool get _active => current == route;

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(icon,
        size: 17,
        color: _active ? Colors.white : Colors.white54);

    if (badgeStream != null) {
      iconWidget = StreamBuilder<int>(
        stream: badgeStream,
        builder: (_, snap) {
          final count = snap.data ?? 0;
          if (count == 0) return iconWidget;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              iconWidget,
              Positioned(
                top: -4,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  constraints:
                      const BoxConstraints(minWidth: 14, minHeight: 14),
                  child: Text('$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          );
        },
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: _active
            ? kHrSuccessDot.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _active
              ? kHrSuccessDot.withValues(alpha: 0.4)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: iconWidget,
        title: Text(label,
            style: TextStyle(
                color: _active ? Colors.white : Colors.white70,
                fontWeight:
                    _active ? FontWeight.w800 : FontWeight.w500,
                fontSize: 13)),
        onTap: () => Navigator.pushNamed(context, route),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        minLeadingWidth: 20,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHELL SCOPE
// ─────────────────────────────────────────────────────────────────────────────
class HrShellScope extends StatelessWidget {
  /// Tells child widgets if they should hide their own Scaffold/AppBar
  /// because the shell is already providing one.
  final bool hideChrome;
  final Widget child;

  const HrShellScope({
    super.key,
    required this.hideChrome,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => child;
}
