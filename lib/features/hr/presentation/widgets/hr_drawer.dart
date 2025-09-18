import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uddoygi/profile.dart';

/// Keep palette in sync with HRDashboard
const Color _brandGreen  = Color(0xFF065F46);
const Color _greenMid    = Color(0xFF10B981);
const Color _ink         = _brandGreen;
const Color _divider     = Color(0x1A065F46); // 10% green

class HRDrawer extends StatelessWidget {
  const HRDrawer({Key? key}) : super(key: key);

  Stream<int> _unreadNotificationsStream() {
    final mail = FirebaseAuth.instance.currentUser?.email ?? '';
    if (mail.isEmpty) return const Stream<int>.empty();
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('to', isEqualTo: mail)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> _unreadMessagesStream() {
    final mail = FirebaseAuth.instance.currentUser?.email ?? '';
    if (mail.isEmpty) return const Stream<int>.empty();
    return FirebaseFirestore.instance
        .collection('messages')
        .where('to', isEqualTo: mail)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final email = FirebaseAuth.instance.currentUser?.email;

    return Drawer(
      backgroundColor: Colors.white,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Error loading profile'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userDoc = snap.data!;
          final data = userDoc.data() ?? {};
          final name = (data['fullName'] as String?)?.trim().isNotEmpty == true
              ? data['fullName'] as String
              : (data['name'] as String?) ?? 'HR Panel';
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
              // ===== Header =====
              Container(
                padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_brandGreen, _greenMid],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.white24,
                      backgroundImage: (photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                      child: (photoUrl.isEmpty)
                          ? Text(
                        initials(name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      )
                          : null,
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
                                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                          if (email != null && email.isNotEmpty)
                            Text(email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              backgroundColor: Colors.white.withOpacity(.15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ProfilePage(userId: uid)),
                              );
                            },
                            icon: const Icon(Icons.person_outline, size: 18),
                            label: const Text('View Profile', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ProfilePage(userId: uid)),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ===== Sections =====
              _SectionLabel('Main'),
              _NavTile(title: 'Dashboard', icon: Icons.dashboard, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/dashboard');
              }),
              _divider(),

              _SectionLabel('People'),
              _NavTile(title: 'Employee Directory', icon: Icons.people, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/employee_directory');
              }),
              _NavTile(title: 'Shift Tracker', icon: Icons.schedule, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/shift_tracker');
              }),
              _NavTile(title: 'Recruitment', icon: Icons.how_to_reg, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/recruitment');
              }),
              _divider(),

              _SectionLabel('Attendance & Leave'),
              _NavTile(title: 'Attendance', icon: Icons.event, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/attendance');
              }),
              _NavTile(title: 'Leave Management', icon: Icons.beach_access, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/leave_management');
              }),
              _divider(),

              _SectionLabel('Payroll'),
              _NavTile(title: 'Payroll Processing', icon: Icons.attach_money, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/payroll_processing');
              }),
              _NavTile(title: 'Payslips', icon: Icons.receipt_long, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/payslip');
              }),
              _NavTile(title: 'Salary Management', icon: Icons.money, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/salary_management');
              }),
              _divider(),

              _SectionLabel('Benefits & Loans'),
              _NavTile(title: 'Benefits & Compensation', icon: Icons.card_giftcard, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/benefits_compensation');
              }),
              _NavTile(title: 'Loan Approval', icon: Icons.account_balance, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/loan_approval');
              }),
              _NavTile(title: 'Incentives', icon: Icons.emoji_events, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/incentives');
              }),
              _divider(),

              _SectionLabel('Finance'),
              _NavTile(title: 'Accounts Payable', icon: Icons.outbox, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/accounts_payable');
              }),
              _NavTile(title: 'Accounts Receivable', icon: Icons.inbox, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/accounts_receivable');
              }),
              _NavTile(title: 'General Ledger', icon: Icons.book, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/general_ledger');
              }),
              _NavTile(title: 'Balance Update', icon: Icons.account_balance_wallet, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/balance_update');
              }),
              _NavTile(title: 'Tax Management', icon: Icons.calculate, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/tax');
              }),
              _divider(),

              _SectionLabel('Procurement & Planning'),
              _NavTile(title: 'Procurement', icon: Icons.shopping_cart, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/procurement');
              }),
              _NavTile(title: 'Budget Forecast', icon: Icons.trending_up, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/budget_forecast');
              }),
              // Match dashboard quick links
              _NavTile(title: 'ROI', icon: Icons.insights, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/roi');
              }),
              _NavTile(title: 'Budget', icon: Icons.account_balance, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/hr/budget');
              }),
              _divider(),

              _SectionLabel('Comms'),
              // Use the same route as dashboard (marketing notices)
              _NavTile(
                title: 'Notices',
                icon: Icons.notifications,
                trailingStreamCount: _unreadNotificationsStream(),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/marketing/notices');
                },
              ),
              _NavTile(
                title: 'Messages',
                icon: Icons.message,
                trailingStreamCount: _unreadMessagesStream(),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/common/messages');
                },
              ),
              _NavTile(title: 'Complaints', icon: Icons.support_agent, onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/common/complaints');
              }),
              _divider(),

              // ===== Logout =====
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Logout', style: TextStyle(fontSize: 14, color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await FirebaseAuth.instance.signOut();
                  } catch (_) {}
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  Widget _divider() => Divider(height: 16, thickness: 1, color: Colors.white);
}

/* ======================= Bits ======================= */




class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: _ink,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Stream<int>? trailingStreamCount;

  const _NavTile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.trailingStreamCount,
  });

  @override
  Widget build(BuildContext context) {
    final trailing = trailingStreamCount == null
        ? null
        : StreamBuilder<int>(
      stream: trailingStreamCount,
      builder: (_, s) {
        final n = s.data ?? 0;
        if (n <= 0) return const SizedBox.shrink();
        return _Badge(count: n);
      },
    );

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: _ink),
      title: Text(title, style: const TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _greenMid.withOpacity(.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _greenMid.withOpacity(.35)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}
