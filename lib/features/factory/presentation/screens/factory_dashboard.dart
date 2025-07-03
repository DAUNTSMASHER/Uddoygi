import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/factory/presentation/widgets/factory_drawer.dart';


class FactoryDashboard extends StatefulWidget {
  const FactoryDashboard({super.key});

  @override
  State<FactoryDashboard> createState() => _FactoryDashboardState();
}

class _FactoryDashboardState extends State<FactoryDashboard> {
  String? userEmail;
  String? userName;

  final List<_DashboardItem> dashboardItems = const [
    _DashboardItem('Notices', Icons.notifications_active, Colors.indigo, '/factory/notices'),
    _DashboardItem('Welfare', Icons.volunteer_activism, Colors.deepPurple, '/common/welfare'),
    _DashboardItem('Messages', Icons.message, Colors.blueAccent, '/common/messages'),
    _DashboardItem('Work Orders', Icons.work, Colors.blue, '/factory/work_orders'),
    _DashboardItem('Resource Requests', Icons.request_page, Colors.green, '/factory/resource_requests'),
    _DashboardItem('Progress Update', Icons.update, Colors.orange, '/factory/progress_update'),
    _DashboardItem('Attendance', Icons.event_available, Colors.purple, '/factory/attendance'),
    _DashboardItem('Loan Requests', Icons.request_page, Colors.teal, '/factory/loan_requests'),
    _DashboardItem('Salary & Overtime', Icons.money_off, Colors.red, '/factory/salary_overtime'),
  ];

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
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Factory Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      drawer: const FactoryDrawer(),  // <<<<< Drawer here!
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (userName != null && userName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Welcome, $userName',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                ),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: dashboardItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = dashboardItems[index];
                  return _DashboardTile(item: item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;

  const _DashboardItem(this.title, this.icon, this.color, this.route);
}

class _DashboardTile extends StatelessWidget {
  final _DashboardItem item;
  const _DashboardTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, item.route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: item.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: item.color, width: 2),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(item.icon, size: 40, color: item.color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
