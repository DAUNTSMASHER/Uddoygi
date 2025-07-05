import 'package:flutter/material.dart';

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.grey[100],
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 🧑 Profile Header
          Container(
            color: Colors.indigo,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 32, color: Colors.indigo),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Admin Panel',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'View profile',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/admin/profile'); // Placeholder for profile screen
                  },
                )
              ],
            ),
          ),

          // 📂 Dashboard
          _drawerItem(context, 'Dashboard', Icons.dashboard, '/admin/dashboard'),

          // 📢 Notices Section
          _drawerHeading('Notices'),
          _drawerItem(context, 'All Notices', Icons.list_alt, '/admin/notices/all'),
          _drawerItem(context, 'Publish Notice', Icons.add_alert, '/admin/notices'),

          // 👥 Employees
          _drawerHeading('Employees'),
          _drawerItem(context, 'Employee Directory', Icons.people, '/admin/employees'),

          // 📊 Reports
          _drawerHeading('Reports'),
          _drawerItem(context, 'Generate Reports', Icons.bar_chart, '/admin/reports'),

          // ❤️ Welfare
          _drawerHeading('Welfare'),
          _drawerItem(context, 'Welfare Scheme', Icons.favorite, '/common/welfare'),

          // ⚠️ Complaints
          _drawerHeading('Complaints'),
          _drawerItem(context, 'Complaints', Icons.report_problem, '/common/complaints'),

          // 💰 Salary
          _drawerHeading('Finance'),
          _drawerItem(context, 'Salary Management', Icons.attach_money, '/admin/salary'),

          // 💬 Messages
          _drawerHeading('Communication'),
          _drawerItem(context, 'Messages', Icons.message, '/common/messages'),

          const Divider(),

          // 🔓 Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
            onTap: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
        ],
      ),
    );
  }

  Widget _drawerHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo),
      ),
    );
  }

  Widget _drawerItem(BuildContext context, String title, IconData icon, String route) {
    return ListTile(
      leading: Icon(icon, color: Colors.indigo),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pop(context); // Close drawer
        Navigator.pushNamed(context, route);
      },
    );
  }
}
