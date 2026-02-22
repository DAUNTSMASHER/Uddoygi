import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uddoygi/profile.dart';

// ── Brand palette (matches web sidebar) ──────────────────────────────────────
const Color _navy     = Color(0xFF1B3A6B);
const Color _navyMid  = Color(0xFF2B5BB8);
const Color _dividerColor = Color(0x1A1B3A6B);

// ── Canonical nav structure — kept in sync with web Sidebar.jsx ──────────────
//
//  Section        │  Items
//  ───────────────┼────────────────────────────────────────────────────────────
//  Main           │  Dashboard
//  People         │  Employees, Recruitment, Shifts
//  Time           │  Attendance, Leave
//  Payroll        │  Payroll, Payslips, Salary, Slip Approvals, Authorization
//  Finance        │  Loans, Credits, Expenses, Budget, Accounts, Tax
//  Comms          │  Notices, Messages, Complaints
//
// Any item added here MUST also be added to:
//   1. _allItems in hr_dashboard.dart
//   2. NAV in packages/hr-web/src/components/layout/Sidebar.jsx
//   3. quickActions in packages/hr-web/src/pages/DashboardPage.jsx

class HRDrawer extends StatefulWidget {
  const HRDrawer({Key? key}) : super(key: key);

  @override
  State<HRDrawer> createState() => _HRDrawerState();
}

class _HRDrawerState extends State<HRDrawer> {
  String _cid = '';

  Stream<int> _unreadNotifications() {
    if (_cid.isEmpty) return const Stream<int>.empty();
    final mail = FirebaseAuth.instance.currentUser?.email ?? '';
    if (mail.isEmpty) return const Stream<int>.empty();
    return DB.colSync(_cid, C.notifications)
        .where('to', isEqualTo: mail)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> _unreadMessages() {
    if (_cid.isEmpty) return const Stream<int>.empty();
    final mail = FirebaseAuth.instance.currentUser?.email ?? '';
    if (mail.isEmpty) return const Stream<int>.empty();
    return DB.colSync(_cid, C.messages)
        .where('to', isEqualTo: mail)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  void _go(String route) {
    Navigator.pop(context);
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final uid   = FirebaseAuth.instance.currentUser?.uid ?? '';
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: DB.colSync(_cid, C.users).doc(uid).snapshots(),
        builder: (ctx, snap) {
          final data = snap.data?.data() ?? {};
          final name = ((data['fullName'] as String?)?.trim().isNotEmpty == true
              ? data['fullName'] as String
              : (data['name'] as String?)) ?? 'HR Panel';
          final photoUrl = (data['profilePhotoUrl'] as String?) ?? '';

          String initials(String s) {
            final parts = s.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
            if (parts.isEmpty) return 'H';
            if (parts.length == 1) return parts.first.characters.first.toUpperCase();
            return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
          }

          return ListView(
            padding: EdgeInsets.zero,
            children: [

              // ── Header ──────────────────────────────────────────────────────
              Container(
                padding: EdgeInsets.fromLTRB(
                    16, MediaQuery.of(context).padding.top + 20, 16, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_navy, _navyMid],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => ProfilePage(userId: uid)));
                      },
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white24,
                        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: photoUrl.isEmpty
                            ? Text(initials(name),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18))
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3)),
                          if (email.isNotEmpty)
                            Text(email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 11)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => ProfilePage(userId: uid)));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_outline,
                                      size: 14, color: Colors.white),
                                  SizedBox(width: 5),
                                  Text('View Profile',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // ── MAIN ────────────────────────────────────────────────────────
              _Section('Main'),
              _Tile(icon: Icons.dashboard_rounded,   label: 'Dashboard',
                  onTap: () => _go('/hr/dashboard')),
              _Divider(),

              // ── PEOPLE ──────────────────────────────────────────────────────
              _Section('People'),
              _Tile(icon: Icons.people_rounded,      label: 'Employees',
                  onTap: () => _go('/hr/employee_directory')),
              _Tile(icon: Icons.how_to_reg_rounded,  label: 'Recruitment',
                  onTap: () => _go('/hr/recruitment')),
              _Tile(icon: Icons.schedule_rounded,    label: 'Shifts',
                  onTap: () => _go('/hr/shift_tracker')),
              _Divider(),

              // ── TIME ────────────────────────────────────────────────────────
              _Section('Time'),
              _Tile(icon: Icons.event_available_rounded, label: 'Attendance',
                  onTap: () => _go('/hr/attendance')),
              _Tile(icon: Icons.beach_access_rounded, label: 'Leave',
                  onTap: () => _go('/hr/leave_management')),
              _Divider(),

              // ── PAYROLL ─────────────────────────────────────────────────────
              _Section('Payroll'),
              _Tile(icon: Icons.attach_money_rounded, label: 'Payroll',
                  onTap: () => _go('/hr/payroll_processing')),
              _Tile(icon: Icons.receipt_long_rounded, label: 'Payslips',
                  onTap: () => _go('/hr/payslip')),
              _Tile(icon: Icons.money_rounded,        label: 'Salary',
                  onTap: () => _go('/hr/salary_management')),
              _Tile(icon: Icons.receipt_long_rounded, label: 'Slip Approvals',
                  onTap: () => _go('/hr/payment_slip_approvals')),
              _Tile(icon: Icons.verified_user_rounded, label: 'Authorization',
                  onTap: () => _go('/hr/authorization')),
              _Divider(),

              // ── FINANCE ─────────────────────────────────────────────────────
              _Section('Finance'),
              _Tile(icon: Icons.account_balance_rounded, label: 'Loans',
                  onTap: () => _go('/hr/loan_approval')),
              _Tile(icon: Icons.trending_up_rounded,  label: 'Credits',
                  onTap: () => _go('/hr/credits')),
              _Tile(icon: Icons.payments_rounded,     label: 'Expenses',
                  onTap: () => _go('/hr/expenses')),
              _Tile(icon: Icons.account_balance_wallet_rounded, label: 'Balance',
                  onTap: () => _go('/hr/balance_update')),
              _Tile(icon: Icons.pie_chart_rounded,    label: 'Budget',
                  onTap: () => _go('/hr/budget')),
              _Tile(icon: Icons.account_balance_wallet_outlined, label: 'Accounts',
                  onTap: () => _go('/payments/bank-accounts')),
              _Tile(icon: Icons.calculate_rounded,    label: 'Tax',
                  onTap: () => _go('/hr/tax')),
              _Tile(icon: Icons.trending_up_rounded,  label: 'ROI',
                  onTap: () => _go('/hr/roi')),
              _Tile(icon: Icons.percent_rounded,      label: 'Incentives',
                  onTap: () => _go('/hr/incentives')),
              _Tile(icon: Icons.card_giftcard_rounded, label: 'Benefits',
                  onTap: () => _go('/hr/benefits_compensation')),
              _Tile(icon: Icons.bar_chart_rounded,    label: 'Budget Forecast',
                  onTap: () => _go('/hr/budget_forecast')),
              _Tile(icon: Icons.shopping_cart_rounded, label: 'Procurement',
                  onTap: () => _go('/hr/procurement')),
              _Divider(),

              // ── HR OPS ──────────────────────────────────────────────────────
              _Section('HR Ops'),
              _Tile(icon: Icons.favorite_rounded,     label: 'Welfare',
                  onTap: () => _go('/hr/welfare')),
              _Divider(),

              // ── COMMS ───────────────────────────────────────────────────────
              _Section('Comms'),
              _Tile(
                icon: Icons.notifications_rounded,
                label: 'Notices',
                badge: _unreadNotifications(),
                onTap: () => _go('/marketing/notices'),
              ),
              _Tile(
                icon: Icons.message_rounded,
                label: 'Messages',
                badge: _unreadMessages(),
                onTap: () => _go('/common/messages'),
              ),
              _Tile(icon: Icons.support_agent_rounded, label: 'Complaints',
                  onTap: () => _go('/common/complaints')),
              _Divider(),

              // ── LOGOUT ──────────────────────────────────────────────────────
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                title: const Text('Logout',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(context);
                  await LocalStorageService.performLogout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/login', (route) => false);
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: _navy,
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 8, thickness: 1, color: _dividerColor);
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Stream<int>? badge;

  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    Widget? trailing;
    if (badge != null) {
      trailing = StreamBuilder<int>(
        stream: badge,
        builder: (_, snap) {
          final n = snap.data ?? 0;
          if (n <= 0) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _navyMid.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _navyMid.withValues(alpha: 0.3)),
            ),
            child: Text(
              n > 99 ? '99+' : '$n',
              style: const TextStyle(
                  color: _navy, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          );
        },
      );
    }

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: _navy, size: 20),
      title: Text(label,
          style: const TextStyle(
              color: _navy, fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
