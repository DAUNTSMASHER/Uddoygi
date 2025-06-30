import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'Admin Panel',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          _createDrawerItem(
              icon: Icons.dashboard,
              text: 'Dashboard',
              onTap: () => Navigator.pushNamed(context, '/admin/dashboard')),
          _createDrawerItem(
              icon: Icons.announcement,
              text: 'Notices',
              onTap: () => Navigator.pushNamed(context, '/admin/notices')),
          _createDrawerItem(
              icon: Icons.people,
              text: 'Employees',
              onTap: () => Navigator.pushNamed(context, '/admin/employees')),
          _createDrawerItem(
              icon: Icons.bar_chart,
              text: 'Reports',
              onTap: () => Navigator.pushNamed(context, '/admin/reports')),
          _createDrawerItem(
              icon: Icons.favorite,
              text: 'Welfare Scheme',
              onTap: () => Navigator.pushNamed(context, '/admin/welfare')),
          _createDrawerItem(
              icon: Icons.report_problem,
              text: 'Complaints',
              onTap: () => Navigator.pushNamed(context, '/admin/complaints')),
          _createDrawerItem(
              icon: Icons.attach_money,
              text: 'Salary',
              onTap: () => Navigator.pushNamed(context, '/admin/salary')),
          const Divider(),
          _createDrawerItem(
              icon: Icons.logout,
              text: 'LOG OUT',
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/', (Route<dynamic> route) => false);
                }
              }),
        ],
      ),
    );
  }

  Widget _createDrawerItem(
      {required IconData icon,
        required String text,
        required GestureTapCallback onTap}) {
    return ListTile(
      title: Text(text),
      leading: Icon(icon),
      onTap: onTap,
    );
  }
}
