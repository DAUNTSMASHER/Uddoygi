import 'package:flutter/material.dart';

class HRDrawer extends StatelessWidget {
  const HRDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF7F9FB),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          InkWell(
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/hr/profile'); // 🎯 Future screen
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              color: const Color(0xFF003087),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Color(0xFF003087), size: 30),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'HR Panel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'View Profile',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
          _drawerItem(context, 'Dashboard', Icons.dashboard, '/hr/dashboard'),
          const Divider(),

          _drawerItem(context, 'Employee Directory', Icons.people, '/hr/employee_directory'),
          _drawerItem(context, 'Shift Tracker', Icons.schedule, '/hr/shift_tracker'),
          _drawerItem(context, 'Recruitment', Icons.how_to_reg, '/hr/recruitment'),
          const Divider(),

          _drawerItem(context, 'Attendance', Icons.event, '/hr/attendance'),
          _drawerItem(context, 'Leave Management', Icons.beach_access, '/hr/leave_management'),
          const Divider(),

          _drawerItem(context, 'Payroll Processing', Icons.attach_money, '/hr/payroll_processing'),
          _drawerItem(context, 'Payslips', Icons.receipt_long, '/hr/payslip'),
          _drawerItem(context, 'Salary Management', Icons.money, '/hr/salary_management'),
          const Divider(),

          _drawerItem(context, 'Benefits & Compensation', Icons.card_giftcard, '/hr/benefits_compensation'),
          _drawerItem(context, 'Loan Approval', Icons.account_balance, '/hr/loan_approval'),
          _drawerItem(context, 'Incentives', Icons.emoji_events, '/hr/incentives'),
          const Divider(),

          _drawerItem(context, 'Accounts Payable', Icons.outbox, '/hr/accounts_payable'),
          _drawerItem(context, 'Accounts Receivable', Icons.inbox, '/hr/accounts_receivable'),
          _drawerItem(context, 'General Ledger', Icons.book, '/hr/general_ledger'),
          _drawerItem(context, 'Balance Update', Icons.account_balance_wallet, '/hr/balance_update'),
          _drawerItem(context, 'Tax Management', Icons.calculate, '/hr/tax'),
          const Divider(),

          _drawerItem(context, 'Procurement', Icons.shopping_cart, '/hr/procurement'),
          _drawerItem(context, 'Budget Forecast', Icons.trending_up, '/hr/budget_forecast'),
          const Divider(),

          _drawerItem(context, 'Notices', Icons.notifications, '/hr/notices'),
          _drawerItem(context, 'Messages', Icons.message, '/common/messages'),
          const Divider(),

          _drawerItem(context, 'Complaints', Icons.support_agent, '/common/complaints'),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Logout', style: TextStyle(fontSize: 14, color: Colors.redAccent)),
            onTap: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(BuildContext context, String title, IconData icon, String route) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF003087)),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pop(context); // Close drawer
        Navigator.pushNamed(context, route);
      },
    );
  }
}
