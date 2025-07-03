import 'package:flutter/material.dart';

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text(
              'Admin Menu',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),

          // Dashboard
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () => Navigator.pushNamed(context, '/admin/dashboard'),
          ),

          // Notices (Section Heading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('Notices', style: TextStyle(fontWeight: FontWeight.bold)),
          ),

          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('All Notices'),
            onTap: () => Navigator.pushNamed(context, '/admin/notices/all'),
          ),
          ListTile(
            leading: const Icon(Icons.add_alert),
            title: const Text('Publish Notice'),
            onTap: () => Navigator.pushNamed(context, '/admin/notices'),
          ),

          // Employees
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Employees'),
            onTap: () => Navigator.pushNamed(context, '/admin/employees'),
          ),

          // Reports
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Reports'),
            onTap: () => Navigator.pushNamed(context, '/admin/reports'),
          ),

          // Welfare
          ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text('Welfare Scheme'),
            onTap: () => Navigator.pushNamed(context, '/admin/welfare'),
          ),

          // Complaints
          ListTile(
            leading: const Icon(Icons.report_problem),
            title: const Text('Complaints'),
            onTap: () => Navigator.pushNamed(context, '/admin/complaints'),
          ),

          // Salary
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Salary'),
            onTap: () => Navigator.pushNamed(context, '/admin/salary'),
          ),

          // Messages
          ListTile(
            leading: const Icon(Icons.message),
            title: const Text('Messages'),
            onTap: () => Navigator.pushNamed(context, '/admin/messages'),
          ),
        ],
      ),
    );
  }
}
