import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uddoygi/services/local_storage_service.dart';

class FactoryDrawer extends StatefulWidget {
  const FactoryDrawer({super.key});

  @override
  State<FactoryDrawer> createState() => _FactoryDrawerState();
}

class _FactoryDrawerState extends State<FactoryDrawer> {
  String? userEmail;
  String? userName;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    setState(() {
      userEmail = (session != null && session['email'] != null) ? session['email'] : '';
      userName = (session != null && session['name'] != null)
          ? session['name']
          : (session != null && session['email'] != null ? session['email'] : '');
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await LocalStorageService.clearSession();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.indigo[900],
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: Colors.indigo[800],
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.factory, size: 36, color: Colors.indigo),
              ),
              accountName: Text(userName ?? '', style: const TextStyle(color: Colors.white)),
              accountEmail: Text(userEmail ?? '', style: const TextStyle(color: Colors.white70)),
            ),
            _DrawerTile(
              icon: Icons.dashboard,
              label: 'Dashboard',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/factory/dashboard');
              },
            ),
            _DrawerTile(
              icon: Icons.notifications_active,
              label: 'Notices',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/factory/notices');
              },
            ),
            _DrawerTile(
              icon: Icons.volunteer_activism,
              label: 'Welfare',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/common/welfare');
              },
            ),
            _DrawerTile(
              icon: Icons.message,
              label: 'Messages',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/common/messages');
              },
            ),
            _DrawerTile(
              icon: Icons.work,
              label: 'Work Orders',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/factory/work_orders');
              },
            ),
            _DrawerTile(
              icon: Icons.request_page,
              label: 'Resource Requests',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/factory/resource_requests');
              },
            ),
            _DrawerTile(
              icon: Icons.update,
              label: 'Progress Update',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/factory/progress_update');
              },
            ),
            _DrawerTile(
              icon: Icons.event_available,
              label: 'Attendance',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/factory/attendance');
              },
            ),
            _DrawerTile(
              icon: Icons.request_page,
              label: 'Loan Requests',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/factory/loan_requests');
              },
            ),
            _DrawerTile(
              icon: Icons.money_off,
              label: 'Salary & Overtime',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/factory/salary_overtime');
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onTap: _logout,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }
}
