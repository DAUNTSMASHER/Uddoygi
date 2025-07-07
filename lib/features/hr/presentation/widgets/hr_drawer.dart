import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uddoygi/profile.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class HRDrawer extends StatelessWidget {
  const HRDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Drawer(
      backgroundColor: Colors.white,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Error loading profile'));
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!.data()!;
          final name = (data['fullName'] as String?)?.trim().isNotEmpty == true
              ? data['fullName'] as String
              : (data['name'] as String?) ?? 'HR Panel';
          final photoUrl = (data['profilePhotoUrl'] as String?) ?? '';

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                height: 180,
                color: _darkBlue,
                padding:
                const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white,
                      backgroundImage:
                      photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Text(
                        name.isNotEmpty ? name[0] : 'H',
                        style: const TextStyle(
                            fontSize: 36, color: Colors.white),
                      )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 20),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProfilePage(userId: uid),
                                ),
                              );
                            },
                            child: const Text(
                              'View Profile',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfilePage(userId: uid),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // 📊 Dashboard
              _drawerItem(context, 'Dashboard', Icons.dashboard, '/hr/dashboard'),
              const Divider(),

              // 👥 Employee
              _drawerItem(context, 'Employee Directory', Icons.people, '/hr/employee_directory'),
              _drawerItem(context, 'Shift Tracker', Icons.schedule, '/hr/shift_tracker'),
              _drawerItem(context, 'Recruitment', Icons.how_to_reg, '/hr/recruitment'),
              const Divider(),

              // 📅 Attendance
              _drawerItem(context, 'Attendance', Icons.event, '/hr/attendance'),
              _drawerItem(context, 'Leave Management', Icons.beach_access, '/hr/leave_management'),
              const Divider(),

              // 💰 Payroll
              _drawerItem(context, 'Payroll Processing', Icons.attach_money, '/hr/payroll_processing'),
              _drawerItem(context, 'Payslips', Icons.receipt_long, '/hr/payslip'),
              _drawerItem(context, 'Salary Management', Icons.money, '/hr/salary_management'),
              const Divider(),

              // 🎁 Benefits
              _drawerItem(context, 'Benefits & Compensation', Icons.card_giftcard, '/hr/benefits_compensation'),
              _drawerItem(context, 'Loan Approval', Icons.account_balance, '/hr/loan_approval'),
              _drawerItem(context, 'Incentives', Icons.emoji_events, '/hr/incentives'),
              const Divider(),

              // 🧾 Finance
              _drawerItem(context, 'Accounts Payable', Icons.outbox, '/hr/accounts_payable'),
              _drawerItem(context, 'Accounts Receivable', Icons.inbox, '/hr/accounts_receivable'),
              _drawerItem(context, 'General Ledger', Icons.book, '/hr/general_ledger'),
              _drawerItem(context, 'Balance Update', Icons.account_balance_wallet, '/hr/balance_update'),
              _drawerItem(context, 'Tax Management', Icons.calculate, '/hr/tax'),
              const Divider(),

              // 📦 Procurement
              _drawerItem(context, 'Procurement', Icons.shopping_cart, '/hr/procurement'),
              _drawerItem(context, 'Budget Forecast', Icons.trending_up, '/hr/budget_forecast'),
              const Divider(),

              // 🔔 Notices & Messages
              _drawerItem(context, 'Notices', Icons.notifications, '/hr/notices'),
              _drawerItem(context, 'Messages', Icons.message, '/common/messages'),
              const Divider(),

              // ⚠️ Complaints
              _drawerItem(context, 'Complaints', Icons.support_agent, '/common/complaints'),
              const Divider(),

              // 🔓 Logout
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 14, color: Colors.redAccent),
                ),
                onTap: () => Navigator.pushReplacementNamed(context, '/login'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _drawerItem(BuildContext context, String title, IconData icon, String route) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: _darkBlue),
      title: Text(title, style: const TextStyle(color: _darkBlue, fontSize: 14)),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
    );
  }
}
